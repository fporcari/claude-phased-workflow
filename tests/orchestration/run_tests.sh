#!/bin/bash
# Orchestration regression tests for the run-all-phases script.
# Runs the real bash script (extracted from the SKILL.md) against a mock
# `claude` binary over seven scenarios: model/cap selection under the /goal
# guard, repair success, repair failure, idempotent repair marker,
# fable->opus fallback, progress guard, and the pre-2.1.139 prompt fallback.
TESTDIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$TESTDIR/../../plugins/phased-workflow/skills/run-all-phases/SKILL.md"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
OT="$WORK"
mkdir -p "$OT/bin"
cp "$TESTDIR/mock-bin/claude" "$OT/bin/claude"
cp "$TESTDIR/mockops.py" "$OT/mockops.py"
python3 - "$SKILL" "$OT/runner.sh" <<'PYEOF'
import re, sys
text = open(sys.argv[1]).read()
blocks = re.findall(r'```bash\n(.*?)```', text, re.S)
open(sys.argv[2], 'w').write(max(blocks, key=len))
PYEOF
bash -n "$OT/runner.sh" || { echo "runner syntax error"; exit 1; }
export OPS="$OT/mockops.py"
PASS=0; FAIL=0

fixture3() {  # 3 phases: sonnet/opus/fable with low/medium/high effort
cat > .claude/MEMORY.md <<'EOF'
# Context: orch-test
Parent: main
Mode: autonomous

## Work Plan
- [ ] **Phase 1**: phase one
  - Details: do thing one
  - Done: check one
- [ ] **Phase 2**: phase two
  - Details: do thing two
  - Done: check two
- [ ] **Phase 3**: phase three
  - Details: do thing three
  - Done: check three

## Suggested execution config
| Phase | Effort | Model | Sourcerer |
|-------|--------|-------|-----------|
| Phase 1 | low | sonnet | no |
| Phase 2 | medium | opus | no |
| Phase 3 | high | fable | no |
EOF
}

fixture2() {  # 2 phases
cat > .claude/MEMORY.md <<'EOF'
# Context: orch-test
Parent: main
Mode: autonomous

## Work Plan
- [ ] **Phase 1**: phase one
  - Details: do thing one
  - Done: check one
- [ ] **Phase 2**: phase two
  - Details: do thing two
  - Done: check two

## Suggested execution config
| Phase | Effort | Model | Sourcerer |
|-------|--------|-------|-----------|
| Phase 1 | low | sonnet | no |
| Phase 2 | low | opus | no |
EOF
}

setup() {
  DIR="$OT/scenarios/$1"
  rm -rf "$DIR"; mkdir -p "$DIR/.claude"; cd "$DIR" || exit 1
  git init -q
}

finish_setup() {
  git add -A >/dev/null 2>&1; git commit -qm init >/dev/null 2>&1
  : > .claude/invocations.log
}

run() { PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1; }

assert() {
  if eval "$2"; then PASS=$((PASS+1)); echo "  ok: $1"
  else FAIL=$((FAIL+1)); echo "  FAIL: $1"; fi
}

echo "== S1: happy path, /goal guard + model/cap selection =="
setup S1; fixture3
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "3 phase calls" '[ "$(grep -c "auto-phase skill" .claude/invocations.log)" = 3 ]'
assert "phase prompts use /goal" '[ "$(grep -c -- "-p /goal Use the auto-phase skill" .claude/invocations.log)" = 3 ]'
assert "phase1 sonnet cap 50"  'grep -q -- "--model sonnet --permission-mode auto --max-budget-usd 50" .claude/invocations.log'
assert "phase2 opus cap 100"   'grep -q -- "--model opus --permission-mode auto --max-budget-usd 100" .claude/invocations.log'
assert "phase3 fable cap 400 (doubled)" 'grep -q -- "--model fable --permission-mode auto --max-budget-usd 400" .claude/invocations.log'
assert "all phases [x]" '[ "$(grep -c "^- \[x\]" .claude/MEMORY.md)" = 3 ]'
assert "no repair launched" '! grep -q "repair-phase skill" .claude/invocations.log'

echo "== S2: phase fails -> fable repair succeeds -> loop continues =="
setup S2; fixture2
printf '%s\n' 'python3 "$OPS" fail1; exit 0' 'python3 "$OPS" repair_ok; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "repair via /goal on fable cap 300" 'grep -q -- "-p /goal Use the repair-phase skill.*--model fable --permission-mode auto --max-budget-usd 300" .claude/invocations.log'
assert "repair succeeded message" 'grep -q "Repair succeeded" out.log'
assert "loop continued to phase 2" '[ "$(grep -c "auto-phase skill" .claude/invocations.log)" = 2 ]'
assert "all phases [x]" '[ "$(grep -c "^- \[x\]" .claude/MEMORY.md)" = 2 ]'
assert "Repaired note present" 'grep -q "> Repaired:" .claude/MEMORY.md'

echo "== S3: phase fails -> repair fails -> stop =="
setup S3; fixture2
printf '%s\n' 'python3 "$OPS" fail1; exit 0' 'python3 "$OPS" repair_fail; exit 0' > .claude/mock-queue
finish_setup; run
assert "repair failed message" 'grep -q "Repair failed. Stopping" out.log'
assert "only 1 phase + 1 repair call" '[ "$(grep -c "CALL:" .claude/invocations.log)" = 2 ]'
assert "Repair attempted note persisted" 'grep -q "> Repair attempted:" .claude/MEMORY.md'
assert "phase 2 untouched" 'grep -q "^- \[ \] \*\*Phase 2\*\*" .claude/MEMORY.md'

echo "== S4: [!] with prior Repair attempted -> stop without new repair =="
setup S4; fixture2
python3 - <<'EOF'
s = open('.claude/MEMORY.md').read()
s = s.replace('- [ ] **Phase 1**: phase one',
  '- [!] **Phase 1**: phase one\n  > Issue: boom\n  > Attempted: 1) fix A -> err1\n  > Repair attempted: 2026-07-18T00:00:00Z - nope', 1)
open('.claude/MEMORY.md','w').write(s)
EOF
printf '%s\n' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "stops citing prior repair" 'grep -q "repair was already attempted" out.log'
assert "no repair call" '! grep -q "repair-phase skill" .claude/invocations.log'

echo "== S5: fable repair crashes -> opus fallback repairs =="
setup S5; fixture2
printf '%s\n' 'python3 "$OPS" fail1; exit 0' 'exit 1' 'python3 "$OPS" repair_ok; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "fallback message" 'grep -q "retrying with opus" out.log'
assert "opus repair cap 200" 'grep -q -- "-p /goal Use the repair-phase skill.*--model opus --permission-mode auto --max-budget-usd 200" .claude/invocations.log'
assert "repair succeeded, loop continued" 'grep -q "Repair succeeded" out.log && [ "$(grep -c "^- \[x\]" .claude/MEMORY.md)" = 2 ]'

echo "== S6: no progress -> stop =="
setup S6; fixture2
printf '%s\n' 'python3 "$OPS" noop; exit 0' > .claude/mock-queue
finish_setup; run
assert "no-progress stop" 'grep -q "No progress in the last run" out.log'
assert "single call only" '[ "$(grep -c "CALL:" .claude/invocations.log)" = 1 ]'

echo "== S7: CLI older than 2.1.139 -> plain prompt fallback =="
setup S7; fixture2
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
MOCK_CLAUDE_VERSION=2.1.100 run
assert "fallback notice printed" 'grep -q "goal guard unavailable" out.log'
assert "plain /auto-phase prompt used" 'grep -q -- "-p /auto-phase --model" .claude/invocations.log'
assert "no /goal in calls" '! grep -q -- "-p /goal" .claude/invocations.log'
assert "all phases [x]" '[ "$(grep -c "^- \[x\]" .claude/MEMORY.md)" = 2 ]'

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
