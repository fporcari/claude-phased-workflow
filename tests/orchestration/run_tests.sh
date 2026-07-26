#!/bin/bash
# Regression tests for the phased-workflow chain.
# S1-S13 run the real shipped run-all-phases.sh
# against a mock `claude` binary: model/effort/cap selection under the /goal
# guard, repair success and failure, the idempotent repair marker, fable->opus
# fallback, progress guard, baseline attribution (reopen / [~]), inert Roadmap,
# and the pre-2.1.139 prompt fallback. S14-S16 are static checks on what the
# repo ships: no frozen copies of the shipped contracts (S14), every skill
# inside its own allowed-tools (S15), every skill on the KB sync list (S16).
TESTDIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER_SRC="$TESTDIR/../../plugins/phased-workflow/scripts/run-all-phases.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
OT="$WORK"
mkdir -p "$OT/bin"
cp "$TESTDIR/mock-bin/claude" "$OT/bin/claude"
cp "$TESTDIR/mockops.py" "$OT/mockops.py"
cp "$RUNNER_SRC" "$OT/runner.sh"
bash -n "$OT/runner.sh" || { echo "runner syntax error"; exit 1; }
export OPS="$OT/mockops.py"
PASS=0; FAIL=0

fixture3() {  # 3 phases: sonnet/opus/fable with low/medium/high effort
cat > .phased/active/toy/plan.md <<'EOF'
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
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | sonnet |
| Phase 2 | medium | opus |
| Phase 3 | high | fable |
EOF
}

fixture2() {  # 2 phases
cat > .phased/active/toy/plan.md <<'EOF'
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
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | sonnet |
| Phase 2 | low | opus |
EOF
}

setup() {
  DIR="$OT/scenarios/$1"
  rm -rf "$DIR"; mkdir -p "$DIR/.claude" "$DIR/.phased/active/toy"; cd "$DIR" || exit 1
  git init -q
}

finish_setup() {
  git add -A >/dev/null 2>&1; git commit -qm init >/dev/null 2>&1
  : > .claude/invocations.log
}

run() { PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1; }
# The production invocation path is the user's shell, which on macOS is zsh.
# Constructs that are valid bash can abort under zsh (e.g. `$VAR[^0-9]` parses
# as an array subscript), and `zsh -n` does NOT catch it — only a real run does.
run_zsh() { PATH="$OT/bin:$PATH" zsh "$OT/runner.sh" > out.log 2>&1; }

assert() {
  if eval "$2"; then PASS=$((PASS+1)); echo "  ok: $1"
  else FAIL=$((FAIL+1)); echo "  FAIL: $1"; fi
}

echo "== S1: happy path — light mode for low effort, full for the rest =="
setup S1; fixture3
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "phase1 (low) uses LIGHT contract" 'grep -q -- "-p /goal Execute the next pending.*--model sonnet --effort [a-z]* --permission-mode auto --max-budget-usd 50" .claude/invocations.log'
assert "light contract demands bookkeeping notes" 'grep -q -- "> Done: and > Files: notes recorded" .claude/invocations.log'
assert "phases 2-3 use FULL skill contract" '[ "$(grep -c -- "-p /goal Use the auto-phase skill" .claude/invocations.log)" = 2 ]'
assert "phase2 opus cap 100"   'grep -q -- "--model opus --effort [a-z]* --permission-mode auto --max-budget-usd 100" .claude/invocations.log'
assert "phase3 fable cap 400 (doubled)" 'grep -q -- "--model fable --effort [a-z]* --permission-mode auto --max-budget-usd 400" .claude/invocations.log'
assert "all phases [x]" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 3 ]'
assert "no repair launched" '! grep -q "repair-phase skill" .claude/invocations.log'

echo "== S2: phase fails -> fable repair succeeds -> loop continues =="
setup S2; fixture2
printf '%s\n' 'python3 "$OPS" fail1; exit 0' 'python3 "$OPS" repair_ok; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "repair via /goal on fable cap 300" 'grep -q -- "-p /goal Use the repair-phase skill.*--model fable --effort [a-z]* --permission-mode auto --max-budget-usd 300" .claude/invocations.log'
assert "repair succeeded message" 'grep -q "Repair succeeded" out.log'
assert "loop continued to phase 2 (both low -> light)" '[ "$(grep -c -- "-p /goal Execute the next pending" .claude/invocations.log)" = 2 ]'
assert "all phases [x]" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'
assert "Repaired note present" 'grep -q "> Repaired:" .phased/active/toy/plan.md'

echo "== S3: phase fails -> repair fails -> stop =="
setup S3; fixture2
printf '%s\n' 'python3 "$OPS" fail1; exit 0' 'python3 "$OPS" repair_fail; exit 0' > .claude/mock-queue
finish_setup; run
assert "repair failed message" 'grep -q "Repair failed. Stopping" out.log'
assert "only 1 phase + 1 repair call" '[ "$(grep -c "CALL:" .claude/invocations.log)" = 2 ]'
assert "Repair attempted note persisted" 'grep -q "> Repair attempted:" .phased/active/toy/plan.md'
assert "phase 2 untouched" 'grep -q "^- \[ \] \*\*Phase 2\*\*" .phased/active/toy/plan.md'

echo "== S4: [!] with prior Repair attempted -> stop without new repair =="
setup S4; fixture2
python3 - <<'EOF'
s = open('.phased/active/toy/plan.md').read()
s = s.replace('- [ ] **Phase 1**: phase one',
  '- [!] **Phase 1**: phase one\n  > Issue: boom\n  > Attempted: 1) fix A -> err1\n  > Repair attempted: 2026-07-18T00:00:00Z - nope', 1)
open('.phased/active/toy/plan.md','w').write(s)
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
assert "opus repair cap 200" 'grep -q -- "-p /goal Use the repair-phase skill.*--model opus --effort [a-z]* --permission-mode auto --max-budget-usd 200" .claude/invocations.log'
assert "repair succeeded, loop continued" 'grep -q "Repair succeeded" out.log && [ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'

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
assert "all phases [x]" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'

echo "== S8: roadmap.md is inert and triggers the rolling-wave reminder =="
# The roadmap lives OUTSIDE plan.md (one level above active/), so it survives
# finalize moving the plan into done/ — and a roadmap bullet is structurally
# incapable of being read as a phase line.
setup S8; fixture2
cat > .phased/roadmap.md <<'ROADEOF'
# Roadmap
- Macro 1 (current): base layer — detailed in active/toy/plan.md as Phases 1..2
- Macro 2: API endpoints on top of the base layer
- Macro 3: UI wiring
ROADEOF
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "only the 2 real phases executed" '[ "$(grep -c "CALL:" .claude/invocations.log)" = 2 ]'
assert "roadmap reminder printed" 'grep -q "Roadmap (pending macro-phases" out.log'
assert "roadmap entries listed" 'grep -q "Macro 2: API endpoints" out.log'
assert "all phases [x]" '[ "$(grep -c "^- \\[x\\]" .phased/active/toy/plan.md)" = 2 ]'
assert "roadmap left out of the plan file" '! grep -q "Macro 2" .phased/active/toy/plan.md'

echo "== S9: zsh (the real invocation shell) — model/effort/cap selection survives =="
setup S9; fixture3
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run_zsh
assert "zsh: phase1 sonnet/low cap 50" 'grep -q -- "--model sonnet --effort low --permission-mode auto --max-budget-usd 50" .claude/invocations.log'
assert "zsh: phase2 opus/medium cap 100" 'grep -q -- "--model opus --effort medium --permission-mode auto --max-budget-usd 100" .claude/invocations.log'
assert "zsh: phase3 fable/high cap 400" 'grep -q -- "--model fable --effort high --permission-mode auto --max-budget-usd 400" .claude/invocations.log'
assert "zsh: no shell error leaked" '! grep -qi "bad math expression\|parse error" out.log'
assert "zsh: all phases [x]" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 3 ]'

echo "== S10: relaunch on a [!] WITHOUT a repair marker -> repair launches =="
setup S10; fixture2
python3 - <<'EOF'
s = open('.phased/active/toy/plan.md').read()
s = s.replace('- [ ] **Phase 1**: phase one',
  '- [!] **Phase 1**: phase one\n  > Issue: boom\n  > Attempted: 1) fix A -> err1', 1)
open('.phased/active/toy/plan.md','w').write(s)
EOF
printf '%s\n' 'python3 "$OPS" repair_ok; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "no phase session started" '! grep -q "auto-phase skill\|Execute the next pending" .claude/invocations.log'
assert "repair launched" 'grep -q "repair-phase skill" .claude/invocations.log'
assert "repair succeeded message" 'grep -q "Repair succeeded" out.log'
assert "phase 1 repaired" 'grep -q "^- \[x\] \*\*Phase 1\*\*" .phased/active/toy/plan.md'

echo "== S11: Case A reopen ([x] count drops) -> repair runs, progress guard silent =="
setup S11; fixture2
python3 - <<'EOF'
s = open('.phased/active/toy/plan.md').read()
s = s.replace('- [ ] **Phase 1**: phase one', '- [x] **Phase 1**: phase one', 1)
open('.phased/active/toy/plan.md','w').write(s)
EOF
printf '%s\n' 'python3 "$OPS" reopen; exit 0' 'python3 "$OPS" repair_ok; exit 0' > .claude/mock-queue
finish_setup; run
assert "progress guard did NOT fire" '! grep -q "No progress in the last run" out.log'
assert "repair launched after reopen" 'grep -q "repair-phase skill" .claude/invocations.log'
assert "reopened phase back to [x]" 'grep -q "^- \[x\] \*\*Phase 1\*\*" .phased/active/toy/plan.md'

echo "== S12: baseline red and unattributable -> [~] stops the run =="
setup S12; fixture2
printf '%s\n' 'python3 "$OPS" blocked; exit 0' > .claude/mock-queue
finish_setup; run
assert "blocked stop message" 'grep -q "blocked \[~\]" out.log'
assert "single call only" '[ "$(grep -c "CALL:" .claude/invocations.log)" = 1 ]'
assert "no repair attempted" '! grep -q "repair-phase skill" .claude/invocations.log'

echo "== S13: xhigh effort -> cap 250 =="
setup S13
cat > .phased/active/toy/plan.md <<'EOF'
# Context: orch-test
Parent: main
Mode: autonomous

## Work Plan
- [ ] **Phase 1**: phase one
  - Details: do thing one
  - Done: check one

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | xhigh | opus |
EOF
printf '%s\n' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "xhigh cap 250 and effort passed" 'grep -q -- "--model opus --effort xhigh --permission-mode auto --max-budget-usd 250" .claude/invocations.log'
assert "xhigh uses the FULL skill contract" 'grep -q -- "-p /goal Use the auto-phase skill" .claude/invocations.log'

echo "== S14: shipped contracts are the ones measured (no frozen copies) =="
# Free tier, no session: guards the invalidator that silently makes a paid
# benchmark night measure a previous version of the chain.
SKILL_RAP="$RUNNER_SRC"
BENCH="$TESTDIR/../benchmark/bench.sh"
extract() { python3 - "$SKILL_RAP" "$1" <<'PYX'
import re, sys
t = open(sys.argv[1], encoding='utf-8').read()
v = re.findall(rf"^\s*{re.escape(sys.argv[2])}='([^']*)'\s*$", t, re.M)
sys.stdout.write(max(v, key=len) if v else '')
PYX
}
XP="$(extract PHASE_PROMPT)"; XL="$(extract LIGHT_PROMPT)"
assert "PHASE_PROMPT is extractable as a single-quoted one-liner" '[ -n "$XP" ]'
assert "LIGHT_PROMPT is extractable as a single-quoted one-liner" '[ -n "$XL" ]'
assert "light contract carries the baseline check" 'printf "%s" "$XL" | grep -q "run the tests and the linter"'
assert "light contract carries the attribution/reopen clause" 'printf "%s" "$XL" | grep -q "reopen THAT phase"'
assert "phase contract admits the Case A reopen outcome" 'printf "%s" "$XP" | grep -q "reopened from \[x\] to \[!\]"'
assert "phase contract admits the Case B [~] outcome" 'printf "%s" "$XP" | grep -q "marked \[~\]"'
assert "bench.sh holds NO frozen copy of a shipped contract" '! grep -qE "^(GOAL_CONTRACT|SLIM_GOAL_CONTRACT)=" "$BENCH"'
assert "bench.sh extracts the contracts live" 'grep -q "extract_contract PHASE_PROMPT" "$BENCH" && grep -q "extract_contract LIGHT_PROMPT" "$BENCH"'
assert "bench.sh passes --effort" 'grep -q -- "--effort" "$BENCH"'

echo "== S15: every skill stays inside its own allowed-tools =="
# Free tier, no session. A skill body is instructions; allowed-tools decides
# which of them can run. The gap is silent at authoring time and fatal at
# runtime, and it produced three real defects (write-workflow's gh/Sourcerer
# calls, close-context's grep|head|sed pipes, pull-request's code-review skill).
SKILLS_DIR="$TESTDIR/../../plugins/phased-workflow/skills"
CHECKER="$TESTDIR/check_allowlists.py"
ALLOW_OUT="$(python3 "$CHECKER" "$SKILLS_DIR" 2>&1)"; ALLOW_RC=$?
[ "$ALLOW_RC" = 0 ] || echo "$ALLOW_OUT"
assert "no skill exceeds its allowed-tools" '[ "$ALLOW_RC" = 0 ]'
assert "every skill declares frontmatter with allowed-tools" \
  '[ "$(grep -l "^allowed-tools:" "$SKILLS_DIR"/*/SKILL.md | wc -l | tr -d " ")" = "$(ls -d "$SKILLS_DIR"/*/ | wc -l | tr -d " ")" ]'
# The checker is only worth having if it fails on the defect it describes.
MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$MUT/"
python3 - "$MUT/close-context/SKILL.md" <<'PYM'
import sys
p = sys.argv[1]
open(p, 'w').write(open(p).read().replace(', Bash(sed:*)', '', 1))
PYM
python3 "$CHECKER" "$MUT" >/dev/null 2>&1; MUT_RC=$?
rm -rf "$MUT"
assert "checker fails when an allowlist entry is removed" '[ "$MUT_RC" != 0 ]'

echo "== S16: every repo skill is on the KB sync list =="
# `/update-skills` delivers what the KB holds. A skill added to the repo and
# forgotten in tools/kb-sync.py MAPPING never reaches another machine — that is
# how `pull-request` and `issue` went missing from the topic.
KBSYNC="$TESTDIR/../../tools/kb-sync.py"
UNMAPPED="$(for d in "$SKILLS_DIR"/*/; do n="$(basename "$d")"; \
  grep -q "skills/$n/SKILL.md" "$KBSYNC" || echo "$n"; done)"
[ -z "$UNMAPPED" ] || echo "  unmapped: $(echo "$UNMAPPED" | tr '\n' ' ')"
assert "no repo skill is absent from kb-sync MAPPING" '[ -z "$UNMAPPED" ]'
assert "kb-sync exposes an audit mode for KB-only entries" 'grep -q -- "--audit" "$KBSYNC"'

echo "== S17: /import-workflow — classification and the mid-run git sequence =="
# /import-workflow is a prompt, so a mock `claude` would only test the mock.
# What IS testable is the deterministic ground underneath it: the classifier it
# calls, and the git sequence it prescribes for a source that carries [x]
# phases. That path is the one that can destroy work — a fresh wf/ branch built
# over a half-finished 3.x run strands the commits the [x] phases refer to.
NEXTPHASE="$TESTDIR/../../plugins/phased-workflow/scripts/next-phase.py"

# -- the classifier reads a pre-4.0 MEMORY.md unchanged (the phase-line format
#    did not change, which is why the skill reuses it instead of eyeballing)
LEGACY="$OT/legacy-MEMORY.md"
cat > "$LEGACY" <<'EOF'
# Context: legacy-branch
Parent: develop

## Work Plan
- [x] **Phase 1**: model layer
  > Done: table created
  > Files: pkg/model/foo.py
- [ ] **Phase 2**: UI
EOF
LEG_OUT="$(python3 "$NEXTPHASE" "$LEGACY" 2>&1)"
assert "classifier parses a pre-4.0 MEMORY.md" 'printf "%s" "$LEG_OUT" | grep -q "1 \[x\] model layer"'
assert "classifier reports the [x] that forces adoption" 'printf "%s" "$LEG_OUT" | grep -q "^  1 \[x\]"'
assert "classifier still finds the next pending phase" 'printf "%s" "$LEG_OUT" | grep -q "recommendation: next: 2"'

# -- the mid-run git sequence must not rewrite the commits that were already there
setup S17
for n in 1 2 3; do echo "pre$n" > "pre$n.txt"; git add "pre$n.txt"; git commit -qm "real commit $n"; done
PRE_HASHES="$(git log --format=%H | tail -3 | tr '\n' ' ')"
# import in place: adopt this branch, plan committed on top, nothing rebased
cp "$LEGACY" .phased/active/toy/plan.md
git add .phased && git commit -qm "wf: import plan for toy"
IMPORT_BASE="$(git log -1 --diff-filter=A --format=%H -- .phased/active/toy/plan.md)"
echo ui > ui.py; git add -A; git commit -qm "wf(phase 2): UI"
# finalize, adopted shape
git tag "wf-archive/toy" HEAD
git reset --soft "$IMPORT_BASE"^ && git rm -r -q -f .phased && git commit -qm "feat: imported work"
POST_HASHES="$(git log --format=%H | tail -3 | tr '\n' ' ')"

assert "import commit is not empty" '[ -n "$IMPORT_BASE" ]'
assert "pre-existing commits survive byte-identical" '[ "$PRE_HASHES" = "$POST_HASHES" ]'
assert "exactly one commit consolidates the workflow" \
  '[ "$(git log --format=%H "$IMPORT_BASE"^..HEAD | wc -l | tr -d " ")" = "1" ]'
assert "no .phased/ in the consolidated commit" '! git show --stat --format= HEAD | grep -q phased'
assert "per-phase history stays reachable via the archive tag" \
  'git log --oneline "wf-archive/toy" | grep -q "wf(phase 2)"'

# -- the two invariants whose silent deletion would be catastrophic. This is a
#    text check on a prompt: it guards against a future edit dropping the rule,
#    NOT against the model ignoring it. Same limitation as the S14 contracts.
IMPORT_SKILL="$SKILLS_DIR/import-workflow/SKILL.md"
assert "skill still adopts the current branch on a source with [x] phases" \
  'grep -q "adopt the current branch" "$IMPORT_SKILL"'
assert "skill still forbids rewriting history on that path" \
  'grep -q "no rebase, no reset" "$IMPORT_SKILL"'
assert "skill still classifies via the parser, not by eye" \
  'grep -q "next-phase.py <source>" "$IMPORT_SKILL"'

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
