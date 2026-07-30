#!/bin/bash
# Regression tests for the phased-workflow chain.
#
# Live scenarios (mock `claude`): S1-S13 run the real shipped run-workflow.sh —
# model/effort/cap selection under the /goal guard, repair success and failure,
# the idempotent repair marker, fable->opus fallback, progress guard, baseline
# attribution (reopen / [~]), inert Roadmap, and the pre-2.1.139 prompt
# fallback. S19 exercises the --validate gate (and that warnings are printed,
# not discarded), including Mode: header semantics — unknown value rejected,
# malformed line rejected, interactive-plus-table warned, no header reading as
# interactive; S20 the announced fallbacks (missing selector, unknown
# model/effort); S25 the EVENT contract — the stable EVENT: lines the parent
# Monitor watches (phase-failed, phase-blocked, run-end), each emitted verbatim
# at its site, run-end on EVERY exit path (early exits included) with the phase
# number read by an anchored sed (live), plus a static drift guard coupling
# those tokens to run-workflow/SKILL.md in BOTH directions, proven by
# mutation. S18 is a hybrid: live (prose bullets in ## Notes stay inert)
# plus a static guard (check_state_matches.py — every phase-state match goes
# through the single-source helpers or carries the **Phase anchor), proven by
# mutation.
#
# Real-git scenarios (no mock): S17 drives /import-workflow's classifier and
# its mid-run git sequence; S22 the --plans location service (root, worktree,
# orphan branch).
#
# Static checks on what the repo ships: no frozen copies of the shipped
# contracts and the light contract's per-phase-commit clause intact (S14),
# every skill inside its own allowed-tools (S15), the Done:/Verify: verification
# contract single-source in common.md and cited by its consumers — the -agent
# variants included — with the when vocabulary restated only verbatim (S27,
# proven by mutation), no skill or ref addressing
# ~/.claude/ (S21, check_home_paths.py, proven by mutation), every -agent
# skill a thin variant citing its base (S23, proven by mutation), and
# /write-workflow's automation fork being real — the Step 2 heading and the
# Mode: interactive header present, the old "don't ask" default and the
# reference's duplicate "Confirm with the user" gone (S24, proven by mutation),
# and every shipped `claude -p` sub-session prompt — call sites AND prompt
# assignments alike — carrying a `/<plugin>:<skill>` namespace rather than a
# bare slash that dies with "Unknown command" (S26, proven by mutation, plus
# the S7b live repair run on the pre-2.1.139 path). S28 checks the per-model
# --append-system-prompt steering: live (each phase session carries the common
# steer plus its own model's line, never another's) and static (both repair
# call sites append one too). S16 retired with the KB mirror in 5.0.0; the
# number stays vacant.
TESTDIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER_SRC="$TESTDIR/../../plugins/phased-workflow/scripts/run-workflow.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
OT="$WORK"
mkdir -p "$OT/bin"
cp "$TESTDIR/mock-bin/claude" "$OT/bin/claude"
cp "$TESTDIR/mockops.py" "$OT/mockops.py"
cp "$RUNNER_SRC" "$OT/runner.sh"
# The launcher now resolves its selector next to itself, so the suite must place
# next-phase.py beside the copied runner — otherwise it exercises whatever is
# installed on the machine (or the silent file-order fallback when nothing is).
cp "$TESTDIR/../../plugins/phased-workflow/scripts/next-phase.py" "$OT/next-phase.py"
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
assert "phases 2-3 use FULL skill contract" '[ "$(grep -c -- "-p /goal Use the execute-phase-agent skill" .claude/invocations.log)" = 2 ]'
assert "phase2 opus cap 100"   'grep -q -- "--model opus --effort [a-z]* --permission-mode auto --max-budget-usd 100" .claude/invocations.log'
assert "phase3 fable cap 400 (doubled)" 'grep -q -- "--model fable --effort [a-z]* --permission-mode auto --max-budget-usd 400" .claude/invocations.log'
assert "all phases [x]" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 3 ]'
assert "no repair launched" '! grep -q "repair-phase skill" .claude/invocations.log'
# $HOME-independence: the launcher now resolves its selector beside itself, so a
# run must no longer depend on $HOME. Re-run the happy path with HOME pointing at
# a nonexistent dir and prove phases still complete and per-phase models still read.
setup S1_nohome; fixture3
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; HOME=/nonexistent PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
assert "run completes with HOME=/nonexistent" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 3 ]'
assert "per-phase model still read under HOME=/nonexistent" 'grep -q -- "--model fable --effort [a-z]* --permission-mode auto --max-budget-usd 400" .claude/invocations.log'

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
assert "namespaced /phased-workflow:execute-phase-agent prompt used" 'grep -q -- "-p /phased-workflow:execute-phase-agent --model" .claude/invocations.log'
assert "no /goal in calls" '! grep -q -- "-p /goal" .claude/invocations.log'
assert "all phases [x]" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'
# (b) same old CLI, repair path: REPAIR_PROMPT is the OTHER plain-prompt
# assignment, and it used to ship a bare slash that no static scan of the call
# sites could see — so the repair path gets its own live run.
setup S7b; fixture2
python3 - <<'EOF'
s = open('.phased/active/toy/plan.md').read()
s = s.replace('- [ ] **Phase 1**: phase one',
  '- [!] **Phase 1**: phase one\n  > Issue: boom\n  > Attempted: 1) fix A -> err1', 1)
open('.phased/active/toy/plan.md','w').write(s)
EOF
printf '%s\n' 'python3 "$OPS" repair_ok; exit 0' > .claude/mock-queue
finish_setup
MOCK_CLAUDE_VERSION=2.1.100 run
assert "S7b: namespaced /phased-workflow:repair-phase prompt used" 'grep -q -- "-p /phased-workflow:repair-phase --model fable" .claude/invocations.log'
assert "S7b: no bare-slash repair prompt" '! grep -q -- "-p /repair-phase" .claude/invocations.log'
assert "S7b: repair succeeded on the old CLI too" 'grep -q "Repair succeeded" out.log'

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
assert "no phase session started" '! grep -q "execute-phase-agent skill\|Execute the next pending" .claude/invocations.log'
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
assert "xhigh uses the FULL skill contract" 'grep -q -- "-p /goal Use the execute-phase-agent skill" .claude/invocations.log'

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
# Guards the clause, NOT the model obeying it — same limitation as the other S14
# contract checks. Until 4.1.0 the light contract ended 'Never commit.', so a
# low-effort phase left its work uncommitted.
assert "light contract no longer forbids committing" '! printf "%s" "$XL" | grep -q "Never commit"'
assert "light contract carries the per-phase commit clause" 'printf "%s" "$XL" | grep -q "wf(phase"'
assert "phase contract admits the Case A reopen outcome" 'printf "%s" "$XP" | grep -q "reopened from \[x\] to \[!\]"'
assert "phase contract admits the Case B [~] outcome" 'printf "%s" "$XP" | grep -q "marked \[~\]"'
assert "bench.sh holds NO frozen copy of a shipped contract" '! grep -qE "^(GOAL_CONTRACT|SLIM_GOAL_CONTRACT)=" "$BENCH"'
assert "bench.sh extracts the contracts live" 'grep -q "extract_contract PHASE_PROMPT" "$BENCH" && grep -q "extract_contract LIGHT_PROMPT" "$BENCH"'
assert "bench.sh passes --effort" 'grep -q -- "--effort" "$BENCH"'

echo "== S15: every skill stays inside its own allowed-tools =="
# Free tier, no session. A skill body is instructions; allowed-tools decides
# which of them can run. The gap is silent at authoring time and fatal at
# runtime, and it produced three real defects (write-workflow's gh/Sourcerer
# calls, the worktree skills' grep|head|sed pipes and bare cat/pwd steps,
# pull-request's code-review skill).
SKILLS_DIR="$TESTDIR/../../plugins/phased-workflow/skills"
CHECKER="$TESTDIR/check_allowlists.py"
ALLOW_OUT="$(python3 "$CHECKER" "$SKILLS_DIR" 2>&1)"; ALLOW_RC=$?
[ "$ALLOW_RC" = 0 ] || echo "$ALLOW_OUT"
assert "no skill exceeds its allowed-tools" '[ "$ALLOW_RC" = 0 ]'
assert "every skill declares frontmatter with allowed-tools" \
  '[ "$(grep -l "^allowed-tools:" "$SKILLS_DIR"/*/SKILL.md | wc -l | tr -d " ")" = "$(ls -d "$SKILLS_DIR"/*/ | wc -l | tr -d " ")" ]'
# The checker is only worth having if it fails on the defect it describes.
MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$MUT/"
python3 - "$MUT/finalize-workflow/SKILL.md" <<'PYM'
import sys
p = sys.argv[1]
open(p, 'w').write(open(p).read().replace(', Bash(sed:*)', '', 1))
PYM
python3 "$CHECKER" "$MUT" >/dev/null 2>&1; MUT_RC=$?
rm -rf "$MUT"
assert "checker fails when an allowlist entry is removed" '[ "$MUT_RC" != 0 ]'
# A command written in prose needs the same permission as one inside a fence.
# Reading only fences let `pull-request` gain an inline python3 call and still
# report clean, while the same command in finalize-workflow's fence was caught
# — a hole in a check whose whole value is that it does not have one. The
# target is `issue`: the only skill whose allowlist has neither python3 nor
# unrestricted Bash, so the finding can only come from the inline scan.
MUT2="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$MUT2/"
cat >> "$MUT2/issue/SKILL.md" <<'EOF'

Resolve the phase with `python3 ~/.claude/scripts/next-phase.py --resolve` first.
EOF
MUT2_OUT="$(python3 "$CHECKER" "$MUT2" 2>&1)"; MUT2_RC=$?
rm -rf "$MUT2"
assert "checker fails on a command instructed inline in prose" '[ "$MUT2_RC" != 0 ]'
assert "the inline finding names the offending command" \
  'echo "$MUT2_OUT" | grep -q "issue: runs .python3."'
# ...but a bare command name in prose is a mention, not an instruction.
MUT3="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$MUT3/"
printf '\nA worktree would only cost a `cd`, and the `git` history stays readable.\n' \
  >> "$MUT3/issue/SKILL.md"
python3 "$CHECKER" "$MUT3" >/dev/null 2>&1; MUT3_RC=$?
rm -rf "$MUT3"
assert "a bare command name in prose is not read as an instruction" '[ "$MUT3_RC" = 0 ]'

# S16 (every skill on the KB sync list) was retired with tools/kb-sync.py:
# as of 5.0.0 the KB holds only the install guide — the plugin is the single
# distribution road, so there is no mirror left to drift. Number kept vacant.

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
# Intent, not formatting: the skill must hand the source to the parser. Matching the
# exact string "next-phase.py <source>" broke when the invocation was quoted for a
# home directory containing a space — a legitimate refactor failing a test that
# asserted a layout rather than a behaviour.
assert "skill still classifies via the parser, not by eye" \
  'grep -qE "next-phase\.py\"? <source>" "$IMPORT_SKILL"'

echo "== S18: prose bullets in ## Notes are inert; state greps are single-source =="
# A column-0 "- [!]" / "- [~]" bullet in a Notes section used to launch a real
# fable repair session (cap $300) or halt a healthy run. Every phase-state
# match now goes through the phase_re/phase_count/phase_any/phase_lines helpers,
# so such decoys are structurally invisible. Modelled on S8 (roadmap-inert).
setup S18; fixture2
cat >> .phased/active/toy/plan.md <<'EOF'

## Notes
- [x] decided to use sqlite
- [!] the parser rewrite is open upstream
- [~] waiting on the upstream release
- [>] follow up later
WIP: rewrite the tokenizer
EOF
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S18: both real phases reached [x]" '[ "$(grep -c "^- \[x\] \*\*Phase" .phased/active/toy/plan.md)" = 2 ]'
assert "S18: exactly 2 phase sessions ran" '[ "$(grep -c "CALL:" .claude/invocations.log)" = 2 ]'
assert "S18: the [!] decoy launched no repair" '! grep -q "repair-phase skill" .claude/invocations.log'
assert "S18: the [!] decoy did not report a failed phase" '! grep -q "A phase failed" out.log'
assert "S18: the [~] decoy did not block the run" '! grep -q "A phase is blocked" out.log'
assert "S18: no false no-progress stop" '! grep -q "No progress in the last run" out.log'

# Static regression guard: no unqualified phase-state match may re-enter the
# launcher. Every grep whose pattern carries a bracketed state (\[x\], \[ \],
# \[!\], \[~\], \[>\], or the \[[ x!~>]\] class) must be one of the four
# single-source helper definitions — and non-grep matchers (the awk block in
# first_bang_block) must carry the \*\*Phase anchor. The guard lives in
# check_state_matches.py so the mutation below re-runs the REAL check, not a
# re-implementation (the S15 idiom).
STATE_GUARD="$TESTDIR/check_state_matches.py"
GUARD_OUT="$(python3 "$STATE_GUARD" "$RUNNER_SRC")"
[ -z "$GUARD_OUT" ] || echo "  offending: $GUARD_OUT"
assert "S18: no phase-state match bypasses the helpers or the anchor" '[ -z "$GUARD_OUT" ]'
# Mutation: strip the \*\*Phase anchor everywhere (the pre-4.1.0 shape of the
# awk patterns) — the guard must go red on the awk lines it used to skip.
S18_MUT="$(mktemp -d)"
sed 's/\\\*\\\*Phase//g' "$RUNNER_SRC" > "$S18_MUT/runner.sh"
assert "S18: the guard fails when the awk anchor is stripped" \
  '! python3 "$STATE_GUARD" "$S18_MUT/runner.sh" >/dev/null 2>&1'
rm -rf "$S18_MUT"

echo "== S19: next-phase.py --validate gates the launcher before any session =="
# The validator shares the selector's own regexes, so a plan it rejects is one
# the loop could not drive correctly. The launcher runs it once before the loop
# and stops on a non-zero result, printing it verbatim — no session spent.
NEXTPHASE="$TESTDIR/../../plugins/phased-workflow/scripts/next-phase.py"

# (a) a healthy plan validates clean and the run proceeds to completion
setup S19a; fixture3
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S19a: healthy plan passes the gate" '! grep -q "Plan validation failed" out.log'
assert "S19a: run proceeded and completed all phases" '[ "$(grep -c "^- \[x\] \*\*Phase" .phased/active/toy/plan.md)" = 3 ]'

# (b) a phase line with a space before the colon is rejected; NO session starts
setup S19b
cat > .phased/active/toy/plan.md <<'EOF'
# Context: orch-test
Parent: main
Mode: autonomous

## Work Plan
- [ ] **Phase 1** : phase one
  - Done: check one
- [ ] **Phase 2**: phase two
  - Done: check two

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | sonnet |
| Phase 2 | low | opus |
EOF
printf '%s\n' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S19b: malformed phase line is rejected" 'grep -q "Plan validation failed" out.log'
assert "S19b: the gate names the offending line" 'grep -q "Phase 1\*\* : phase one" out.log'
assert "S19b: NO claude session was launched" '[ ! -s .claude/invocations.log ]'

# (c) Mode: autonomous with the execution-config table removed is rejected
setup S19c
cat > .phased/active/toy/plan.md <<'EOF'
# Context: orch-test
Parent: main
Mode: autonomous

## Work Plan
- [ ] **Phase 1**: phase one
  - Done: check one
EOF
printf '%s\n' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S19c: missing config table is rejected" 'grep -q "Plan validation failed" out.log'
assert "S19c: the gate names the missing table" 'grep -q "requires a .* Suggested execution config" out.log'
assert "S19c: NO claude session was launched" '[ ! -s .claude/invocations.log ]'

# (d) an Effort outside the supported set is rejected, naming the bad value
setup S19d
cat > .phased/active/toy/plan.md <<'EOF'
# Context: orch-test
Parent: main
Mode: autonomous

## Work Plan
- [ ] **Phase 1**: phase one
  - Done: check one

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | turbo | opus |
EOF
printf '%s\n' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S19d: bad Effort is rejected" 'grep -q "Plan validation failed" out.log'
assert "S19d: the gate names the bad Effort value" 'grep -q "Effort .turbo. is not one of" out.log'
assert "S19d: NO claude session was launched" '[ ! -s .claude/invocations.log ]'

# direct invocation: an unknown note field is a warning, not an error (exit 0)
WARN_PLAN="$OT/warn-plan.md"
cat > "$WARN_PLAN" <<'EOF'
# Context: warn
Parent: main
Mode: autonomous

## Work Plan
- [ ] **Phase 1**: phase one
  > Foo: not a documented field
  - Done: check one

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | opus |
EOF
WARN_OUT="$(python3 "$NEXTPHASE" --validate "$WARN_PLAN" 2>&1)"; WARN_RC=$?
assert "S19: an unknown note field warns but does not fail (exit 0)" '[ "$WARN_RC" = 0 ]'
assert "S19: the warning names the unknown field" 'printf "%s" "$WARN_OUT" | grep -q "warning: unknown note field .> Foo:"'

# (e) a warnings-only plan still runs, and the launcher PRINTS the warnings —
# the two-severity design is mute if warning lines are computed and discarded.
setup S19e
cat > .phased/active/toy/plan.md <<'EOF'
# Context: orch-test
Parent: main
Mode: autonomous

## Work Plan
- [x] **Phase 1**: phase one
  - Done: check one

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | opus |

## Notes
- [ ] a prose checkbox that draws a warning
EOF
printf '%s\n' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S19e: warnings-only plan is not blocked" '! grep -q "Plan validation failed" out.log'
assert "S19e: the warning lines are printed, not discarded" 'grep -q "warning: checkbox bullet outside" out.log'
assert "S19e: the launcher flags them as non-blocking" 'grep -q "NOTE: plan validation reported warnings" out.log'

# (f) a live run on a plan whose Mode: value is unknown is rejected, the gate
# names the bad value, and NO session starts — a typo must not degrade silently
# into the interactive default.
setup S19f
cat > .phased/active/toy/plan.md <<'EOF'
# Context: orch-test
Parent: main
Mode: robot

## Work Plan
- [ ] **Phase 1**: phase one
  - Done: check one

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | opus |
EOF
printf '%s\n' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S19f: unknown Mode value is rejected" 'grep -q "Plan validation failed" out.log'
assert "S19f: the gate names the bad Mode value" "grep -q \"Mode: 'robot' is not one of\" out.log"
assert "S19f: NO claude session was launched" '[ ! -s .claude/invocations.log ]'

# (g) direct --validate on a Mode: interactive plan carrying a config table
# exits 0 with exactly one warning line naming the table — a half-converted plan
# warns but never blocks.
MODE_INT_PLAN="$OT/mode-interactive-plan.md"
cat > "$MODE_INT_PLAN" <<'EOF'
# Context: mode-int
Parent: main
Mode: interactive

## Work Plan
- [ ] **Phase 1**: phase one
  - Done: check one

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | opus |
EOF
MI_OUT="$(python3 "$NEXTPHASE" --validate "$MODE_INT_PLAN" 2>&1)"; MI_RC=$?
assert "S19g: interactive-plus-table is a warning, not an error (exit 0)" '[ "$MI_RC" = 0 ]'
assert "S19g: exactly one warning line is printed" '[ "$(printf "%s\n" "$MI_OUT" | grep -c "warning:")" = 1 ]'
assert "S19g: the warning names the execution-config table" 'printf "%s" "$MI_OUT" | grep -q "Suggested execution config"'

# (h) direct --validate on a plan with no Mode: line and no table exits 0 with
# no Mode finding at all — a legacy plan reads as interactive.
MODE_NONE_PLAN="$OT/mode-none-plan.md"
cat > "$MODE_NONE_PLAN" <<'EOF'
# Context: mode-none
Parent: main

## Work Plan
- [ ] **Phase 1**: phase one
  - Done: check one
EOF
MN_OUT="$(python3 "$NEXTPHASE" --validate "$MODE_NONE_PLAN" 2>&1)"; MN_RC=$?
assert "S19h: no Mode: line and no table validates clean (exit 0)" '[ "$MN_RC" = 0 ]'
assert "S19h: no Mode finding is emitted" '! printf "%s" "$MN_OUT" | grep -qi "Mode:"'

# (i) a MALFORMED Mode: line ("Mode: autonomous (robottino)") is an error, not
# a silent no-header read — the same threat as (f), one notch earlier: a line
# the value-check cannot even parse must not degrade into the interactive
# default either.
MODE_MALFORMED_PLAN="$OT/mode-malformed-plan.md"
cat > "$MODE_MALFORMED_PLAN" <<'EOF'
# Context: mode-malformed
Parent: main
Mode: autonomous (robottino)

## Work Plan
- [ ] **Phase 1**: phase one
  - Done: check one
EOF
MM_OUT="$(python3 "$NEXTPHASE" --validate "$MODE_MALFORMED_PLAN" 2>&1)"; MM_RC=$?
assert "S19i: malformed Mode: line is an error (exit 1)" '[ "$MM_RC" = 1 ]'
assert "S19i: the finding names the malformed line" 'printf "%s" "$MM_OUT" | grep -q "malformed Mode: line"'

echo "== S20: every silent fallback announces itself with a NOTE =="
# Force the fallback path. After Phase 2 the launcher resolves its selector
# beside itself, so a runner copied to a directory with no sibling next-phase.py
# cannot run the selector and drops to file order — the exact path the NOTE must
# make audible. The validation gate self-skips the same way (no selector), so
# nothing stops the loop before the fallback fires.
NOSEL="$OT/no-selector"
mkdir -p "$NOSEL"
cp "$OT/runner.sh" "$NOSEL/runner.sh"   # deliberately WITHOUT next-phase.py beside it
run_nosel() { PATH="$OT/bin:$PATH" bash "$NOSEL/runner.sh" > out.log 2>&1; }

# (a) selector missing -> file-order fallback, loud, naming the barrier cost
setup S20a; fixture2
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run_nosel
assert "S20a: the selector fallback prints a NOTE" 'grep -q "falling back to plan file order" out.log'
assert "S20a: the NOTE names the fallback's consequence" 'grep -q "resumes and attention/blocked handling" out.log'
assert "S20a: both phases still complete on file order" '[ "$(grep -c "^- \[x\] \*\*Phase" .phased/active/toy/plan.md)" = 2 ]'

# (b) unsupported Model and Effort cells -> both NOTEs, safe defaults applied.
# With no selector beside the runner the validation gate is skipped, so the bad
# row reaches the case blocks that this phase made loud.
setup S20b
cat > .phased/active/toy/plan.md <<'EOF'
# Context: orch-test
Parent: main
Mode: autonomous

## Work Plan
- [ ] **Phase 1**: phase one
  - Done: check one
- [ ] **Phase 2**: phase two
  - Done: check two

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | turbo | banana |
| Phase 2 | low | opus |
EOF
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run_nosel
assert "S20b: unrecognised Model warns loudly" 'grep -q "unrecognised Model .banana." out.log'
assert "S20b: unrecognised Effort warns loudly" 'grep -q "unrecognised Effort .turbo." out.log'
assert "S20b: the call still used the safe defaults" 'grep -q -- "--model opus --effort high" .claude/invocations.log'

echo "== S21: skills and refs address the plugin, not ~/.claude =="
# The plugin ships its own scripts/ and refs/; a skill or ref that still points a
# reader at ~/.claude/ (or $HOME/.claude/) sends them to a path the plugin no
# longer owns. The one legitimate mention is refs/common.md naming
# ~/.claude/settings.json as a file auto mode must not self-modify — a different
# file, and a description, not a path the plugin resolves. Static check, S18 idiom.
# The guard lives in check_home_paths.py so the mutation below re-runs the
# REAL check, not an inline copy of its logic (the S15 idiom).
S21_SKILLS="$TESTDIR/../../plugins/phased-workflow/skills"
S21_REFS="$TESTDIR/../../plugins/phased-workflow/refs"
HOME_GUARD="$TESTDIR/check_home_paths.py"
HOME_OUT="$(python3 "$HOME_GUARD" "$S21_SKILLS" "$S21_REFS")"
[ -z "$HOME_OUT" ] || echo "  offending: $HOME_OUT"
assert "S21: no skill or ref addresses ~/.claude/ or \$HOME/.claude/" '[ -z "$HOME_OUT" ]'
# The guard is only worth having if it fails on the defect it describes.
S21_MUT="$(mktemp -d)"; cp -R "$S21_SKILLS" "$S21_MUT/skills"
printf '\nSee `python3 ~/.claude/scripts/next-phase.py --resolve` for the plan.\n' \
  >> "$S21_MUT/skills/execute-phase-agent/SKILL.md"
assert "S21: the guard fails when a ~/.claude/ path is reintroduced" \
  '! python3 "$HOME_GUARD" "$S21_MUT/skills" >/dev/null 2>&1'
rm -rf "$S21_MUT"

echo "== S22: --plans finds every reachable plan — root, worktree, orphan branch =="
# The location service behind "launched from anywhere": the current root's
# plan, a linked worktree's, and a wf/* branch with no worktree at all, read
# without checkout. Real git repo, no mock.
S22_ROOT="$OT/scenarios/S22"
rm -rf "$S22_ROOT"; mkdir -p "$S22_ROOT"; cd "$S22_ROOT" || exit 1
git init -q -b main
echo base > base.txt; git add -A; git commit -qm base
plan_fixture() {  # $1 = dir, $2 = second-phase status
  mkdir -p "$1"
  printf '%s\n' "# Context: s22" "Parent: main" "" "## Work Plan" \
    "- [x] **Phase 1**: done one" \
    "- [$2] **Phase 2**: pending two" > "$1/plan.md"
}
# (a) plan on a branch checked out in the root
git switch -qc wf/in-root
plan_fixture .phased/active/rootplan " "
git add -A; git commit -qm "wf: plan for rootplan"
# (b) plan in a linked worktree on its own branch
git worktree add -q "$OT/scenarios/S22-wt" -b wf/in-worktree main
plan_fixture "$OT/scenarios/S22-wt/.phased/active/wtplan" "!"
git -C "$OT/scenarios/S22-wt" add -A
git -C "$OT/scenarios/S22-wt" commit -qm "wf: plan for wtplan"
# (c) plan on a wf/ branch with no checkout anywhere
git worktree add -q "$OT/scenarios/S22-tmp" -b wf/orphan main
plan_fixture "$OT/scenarios/S22-tmp/.phased/active/orphanplan" ">"
git -C "$OT/scenarios/S22-tmp" add -A
git -C "$OT/scenarios/S22-tmp" commit -qm "wf: plan for orphanplan"
git worktree remove --force "$OT/scenarios/S22-tmp"

PLANS_OUT="$(python3 "$OT/next-phase.py" --plans 2>&1)"
assert "S22: exactly three plans found" '[ "$(printf "%s\n" "$PLANS_OUT" | grep -c "^plan|")" = "3" ]'
# Suffix match on the checkout paths: macOS reports /private/var where mktemp
# said /var, so an absolute-path equality would fail on the symlink alone.
assert "S22: root plan carries its branch and checkout path" \
  'printf "%s\n" "$PLANS_OUT" | grep "branch|wf/in-root" | grep -q "worktree|.*scenarios/S22|"'
assert "S22: worktree plan reports the worktree, not the root" \
  'printf "%s\n" "$PLANS_OUT" | grep "branch|wf/in-worktree" | grep -q "worktree|.*scenarios/S22-wt|"'
assert "S22: orphan-branch plan is read without a checkout" \
  'printf "%s\n" "$PLANS_OUT" | grep "branch|wf/orphan" | grep -q "worktree|-"'
assert "S22: orphan location is branch:path, not a filesystem path" \
  'printf "%s\n" "$PLANS_OUT" | grep -q "plan|wf/orphan:.phased/active/orphanplan/plan.md"'
assert "S22: phase counts come from the parsed plan" \
  'printf "%s\n" "$PLANS_OUT" | grep "branch|wf/in-root" | grep -q "phases|1/2"'
assert "S22: states classified per plan (failed / running / clean)" \
  'printf "%s\n" "$PLANS_OUT" | grep "branch|wf/in-worktree" | grep -q "state|failed" &&
   printf "%s\n" "$PLANS_OUT" | grep "branch|wf/orphan" | grep -q "state|running" &&
   printf "%s\n" "$PLANS_OUT" | grep "branch|wf/in-root" | grep -q "state|clean"'

echo "== S23: -agent skills are thin variants, not second copies =="
# The -agent suffix names the environment ("nobody in here can answer you"),
# not a second body: a variant that restates its base recreates the 4.1.0
# LIGHT_PROMPT 'Never commit' defect — the sibling copy nobody updates. The
# guard enforces the structural half: every skills/<name>-agent/SKILL.md
# cites its base skill by name, the base exists, and the file stays under a
# 100-line ceiling (thin = constraints + delegation, never the whole body).
s23_guard() {  # $1 = a skills dir; prints one line per violation
  for S23_D in "$1"/*-agent/; do
    [ -d "$S23_D" ] || continue
    S23_F="$S23_D/SKILL.md"
    S23_B="$(basename "$S23_D")"; S23_B="${S23_B%-agent}"
    [ -d "$1/$S23_B" ] || echo "$S23_F: base skill '$S23_B' does not exist"
    grep -q "Base skill: $S23_B" "$S23_F" 2>/dev/null \
      || echo "$S23_F: missing 'Base skill: $S23_B' citation"
    S23_L=$(wc -l < "$S23_F" | tr -d ' ')
    [ "$S23_L" -le 100 ] \
      || echo "$S23_F: $S23_L lines — over the 100-line thin-variant ceiling"
  done
}
S23_OUT="$(s23_guard "$SKILLS_DIR")"
[ -z "$S23_OUT" ] || echo "  offending: $S23_OUT"
assert "S23: every -agent skill cites its base and stays thin" '[ -z "$S23_OUT" ]'
assert "S23: the guard actually saw the -agent skills" \
  '[ "$(ls -d "$SKILLS_DIR"/*-agent/ | wc -l | tr -d " ")" -ge 2 ]'
# Mutations re-run the SAME guard function (not a re-implementation) on a copy.
S23_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S23_MUT/"
sed -i.bak '/Base skill:/d' "$S23_MUT/execute-phase-agent/SKILL.md" \
  && rm -f "$S23_MUT/execute-phase-agent/SKILL.md.bak"
assert "S23: the guard fails when the base citation is dropped" \
  '[ -n "$(s23_guard "$S23_MUT")" ]'
rm -rf "$S23_MUT"
S23_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S23_MUT/"
awk 'BEGIN{for(i=0;i<101;i++) print "- padding: a body large enough to be a copy"}' \
  >> "$S23_MUT/finalize-workflow-agent/SKILL.md"
assert "S23: the guard fails when an -agent variant grows a full body" \
  '[ -n "$(s23_guard "$S23_MUT")" ]'
rm -rf "$S23_MUT"

echo "== S24: the automation fork is real, not decorative =="
# /write-workflow's Step 2 asks the automation question up front and its plan
# template carries Mode: interactive; the old "interactive by default; don't
# ask" instruction and the reference's duplicate "Confirm with the user" line
# are gone (with the fork, that question would be asked twice). The guard also
# checks the fork's consumers: run-workflow's pre-flight reads Mode: interactive
# and offers the conversion, and import-workflow writes a Mode: header. Mutation
# proves it bites.
S24_REFS="$TESTDIR/../../plugins/phased-workflow/refs"
s24_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S24_W="$1/write-workflow/SKILL.md"
  S24_A="$2/write-workflow-autonomous.md"
  grep -q "## Step 2: The automation fork" "$S24_W" 2>/dev/null \
    || echo "$S24_W: missing '## Step 2: The automation fork' heading"
  grep -q "Mode: interactive" "$S24_W" 2>/dev/null \
    || echo "$S24_W: missing 'Mode: interactive' plan header"
  if grep -q "don't ask" "$S24_W" 2>/dev/null; then
    echo "$S24_W: still carries the retired \"don't ask\" default"
  fi
  if grep -q "Confirm with the user" "$S24_A" 2>/dev/null; then
    echo "$S24_A: still asks the automation question a second time"
  fi
  S24_R="$1/run-workflow/SKILL.md"
  S24_I="$1/import-workflow/SKILL.md"
  grep -q "Mode: interactive" "$S24_R" 2>/dev/null \
    || echo "$S24_R: pre-flight does not read the 'Mode: interactive' header"
  grep -q "Offer the conversion" "$S24_R" 2>/dev/null \
    || echo "$S24_R: missing the interactive-to-autonomous conversion offer"
  grep -qE "Mode: (interactive|autonomous)" "$S24_I" 2>/dev/null \
    || echo "$S24_I: does not write a Mode: header into the imported plan"
  return 0
}
S24_OUT="$(s24_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S24_OUT" ] || echo "  offending: $S24_OUT"
assert "S24: write-workflow forks on automation and drops the old default" '[ -z "$S24_OUT" ]'
# Mutations re-run the SAME guard on a copy of the skills dir (real refs passed through).
S24_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S24_MUT/"
sed -i.bak '/## Step 2: The automation fork/d' "$S24_MUT/write-workflow/SKILL.md" \
  && rm -f "$S24_MUT/write-workflow/SKILL.md.bak"
assert "S24: the guard fails when the fork heading is dropped" \
  '[ -n "$(s24_guard "$S24_MUT" "$S24_REFS")" ]'
rm -rf "$S24_MUT"
S24_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S24_MUT/"
printf "\ndon't ask\n" >> "$S24_MUT/write-workflow/SKILL.md"
assert "S24: the guard fails when \"don't ask\" is reintroduced" \
  '[ -n "$(s24_guard "$S24_MUT" "$S24_REFS")" ]'
rm -rf "$S24_MUT"
# The fork's consumers: dropping run-workflow's conversion offer must bite too.
S24_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S24_MUT/"
sed -i.bak '/Offer the conversion/d' "$S24_MUT/run-workflow/SKILL.md" \
  && rm -f "$S24_MUT/run-workflow/SKILL.md.bak"
assert "S24: the guard fails when run-workflow drops the conversion offer" \
  '[ -n "$(s24_guard "$S24_MUT" "$S24_REFS")" ]'
rm -rf "$S24_MUT"

echo "== S25: the EVENT contract — the stable lines the parent Monitor watches =="
# Live half: each of the three event tokens is emitted at its site, verbatim,
# with the phase number the launcher's own helpers resolve. Static half below:
# the tokens the launcher emits and the ones run-workflow/SKILL.md documents
# must not drift apart, or the parent watches for lines that never come.
setup S25a; fixture2
printf '%s\n' 'python3 "$OPS" fail1; exit 0' 'python3 "$OPS" repair_fail; exit 0' > .claude/mock-queue
finish_setup; run
assert "S25: a failed phase emits 'EVENT: phase-failed 1'" 'grep -q "^EVENT: phase-failed 1$" out.log'
assert "S25: phase-failed is emitted once per failure" '[ "$(grep -c "^EVENT: phase-failed" out.log)" = 1 ]'
setup S25b; fixture2
printf '%s\n' 'python3 "$OPS" blocked; exit 0' > .claude/mock-queue
finish_setup; run
assert "S25: a blocked phase emits 'EVENT: phase-blocked 1'" 'grep -q "^EVENT: phase-blocked 1$" out.log'
setup S25c; fixture3
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S25: a clean run emits 'EVENT: run-end ok 3/3'" 'grep -q "^EVENT: run-end ok 3/3$" out.log'
assert "S25: run-end is emitted exactly once" '[ "$(grep -c "^EVENT: run-end" out.log)" = 1 ]'
# Static drift guard: every EVENT token the launcher emits must be named in the
# skill that tells the parent which lines to watch. Tokens are extracted live
# from the shipped launcher (the S14 idiom — measure what ships, not a copy).
s25_tokens() { grep -oE 'EVENT: [a-z-]+' "$RUNNER_SRC" | awk '{print $2}' | sort -u; }
s25_static_guard() {  # $1 = a run-workflow SKILL.md; one line per missing token
  for S25_T in $(s25_tokens); do
    grep -q "$S25_T" "$1" 2>/dev/null || echo "$1: missing EVENT token '$S25_T'"
  done
}
S25_SKILL="$SKILLS_DIR/run-workflow/SKILL.md"
S25_STATIC_OUT="$(s25_static_guard "$S25_SKILL")"
[ -z "$S25_STATIC_OUT" ] || echo "  offending: $S25_STATIC_OUT"
assert "S25: run-workflow/SKILL.md names every EVENT token the launcher emits" '[ -z "$S25_STATIC_OUT" ]'
assert "S25: token extraction found all three events" '[ "$(s25_tokens | wc -l | tr -d " ")" = 3 ]'
# Mutation re-runs the SAME guard on a copy with the phase-failed token dropped.
S25_MUT="$(mktemp -d)"
cp "$S25_SKILL" "$S25_MUT/SKILL.md"
sed -i.bak 's/phase-failed//g' "$S25_MUT/SKILL.md" && rm -f "$S25_MUT/SKILL.md.bak"
assert "S25: the static guard fails when the phase-failed token is dropped" \
  '[ -n "$(s25_static_guard "$S25_MUT/SKILL.md")" ]'
rm -rf "$S25_MUT"
# Reverse direction: a token the SKILL names but the launcher never emits is
# the failure the forward guard's own rationale describes — the parent watching
# for a line that never comes. Tokens are read from the skill's EVENT-speaking
# lines only; `run-workflow` (the skill's own name) is excluded by name.
s25_skill_tokens() {
  grep 'EVENT' "$1" 2>/dev/null | grep -oE '\b(phase|run)-[a-z]+\b' \
    | grep -vx 'run-workflow' | sort -u
}
s25_reverse_guard() {  # $1 = a run-workflow SKILL.md; one line per ghost token
  S25_EMITTED="$(s25_tokens)"
  for S25_T in $(s25_skill_tokens "$1"); do
    printf '%s\n' "$S25_EMITTED" | grep -qx "$S25_T" \
      || echo "$1: names EVENT token '$S25_T' the launcher never emits"
  done
}
S25_REV_OUT="$(s25_reverse_guard "$S25_SKILL")"
[ -z "$S25_REV_OUT" ] || echo "  offending: $S25_REV_OUT"
assert "S25: the skill names no EVENT token the launcher never emits" '[ -z "$S25_REV_OUT" ]'
S25_MUT="$(mktemp -d)"
cp "$S25_SKILL" "$S25_MUT/SKILL.md"
printf '\nAlso watch the `EVENT:` token `phase-repaired`.\n' >> "$S25_MUT/SKILL.md"
assert "S25: the reverse guard fails on a token the launcher never emits" \
  '[ -n "$(s25_reverse_guard "$S25_MUT/SKILL.md")" ]'
rm -rf "$S25_MUT"

# (d) the phase number in the event is read with an ANCHORED sed: a title that
# itself contains "Phase 10" must not hijack the number (greedy `.*Phase` did).
setup S25d
cat > .phased/active/toy/plan.md <<'EOF'
# Context: orch-test
Parent: main
Mode: autonomous

## Work Plan
- [!] **Phase 1**: prep for Phase 10 rollout
  > Issue: boom
  > Attempted: 1) fix A -> err1
- [ ] **Phase 2**: phase two
  - Details: do thing two
  - Done: check two

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | opus |
| Phase 2 | low | opus |
EOF
printf '%s\n' 'python3 "$OPS" repair_fail; exit 0' > .claude/mock-queue
finish_setup; run
assert "S25d: the event carries the PHASE number, not the title's" 'grep -q "^EVENT: phase-failed 1$" out.log'
assert "S25d: no event with the title's number" '! grep -q "^EVENT: phase-failed 10" out.log'

# (e) run-end is emitted on EVERY exit path, not only through the loop: an
# all-[x] plan exits before the loop ("No phases remaining") and the parent
# Monitor still needs its terminator.
setup S25e
cat > .phased/active/toy/plan.md <<'EOF'
# Context: orch-test
Parent: main
Mode: autonomous

## Work Plan
- [x] **Phase 1**: phase one
  > Done: done
  > Files: a.py

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | low | opus |
EOF
finish_setup; run
assert "S25e: all-[x] early exit still emits run-end" 'grep -q "^EVENT: run-end ok 1/1$" out.log'
assert "S25e: run-end is emitted exactly once" '[ "$(grep -c "^EVENT: run-end" out.log)" = 1 ]'
assert "S25e: no session was launched" '[ ! -s .claude/invocations.log ]'

# (f) same for the validation-failure exit: the run stopped, so the status is
# `stopped` even though the phases the plan carries are untouched.
setup S25f
cat > .phased/active/toy/plan.md <<'EOF'
# Context: orch-test
Parent: main
Mode: robot

## Work Plan
- [ ] **Phase 1**: phase one
  - Done: check one
EOF
finish_setup; run
assert "S25f: validation-failure exit still emits run-end" 'grep -q "^EVENT: run-end stopped 0/1$" out.log'
assert "S25f: run-end is emitted exactly once" '[ "$(grep -c "^EVENT: run-end" out.log)" = 1 ]'

echo "== S26: every claude -p sub-session prompt carries a plugin: namespace =="
# A slash command in a headless `claude -p` session resolves only against
# ~/.claude/commands/ or a plugin's namespaced id `/<plugin>:<skill>`. A bare
# `/<skill>` prompt dies with "Unknown command" and the sub-session does nothing
# — the same "shipped contract no test executes" defect class as 4.1.0's
# LIGHT_PROMPT 'Never commit'. The guard flags any literal `claude -p "/..."`
# argument that starts with a slash and carries no colon; the /goal contracts
# (which begin `/goal` but embed `Condition:`) and the variable-based `"$..."`
# calls are correctly left alone.
S26_SCRIPTS="$TESTDIR/../../plugins/phased-workflow/scripts"
s26_guard() {  # $1 = a scripts dir; one line per bare-slash claude -p prompt
  for S26_F in "$1"/*.sh; do
    [ -f "$S26_F" ] || continue
    grep -oE 'claude -p "[^"]*"' "$S26_F" 2>/dev/null \
      | sed -E 's/^claude -p "//; s/"$//' \
      | while IFS= read -r S26_ARG; do
          case "$S26_ARG" in
            /*) case "$S26_ARG" in
                  *:*) ;;
                  *) echo "$S26_F: bare-slash prompt '$S26_ARG' — needs a plugin: namespace" ;;
                esac ;;
          esac
        done
    # Prompt ASSIGNMENTS too. Both 5.1.0 regressions lived in PHASE_PROMPT /
    # REPAIR_PROMPT assignments, not at the call sites — `claude -p "$VAR"` is
    # rightly ignored above, so the value must be checked where it is SET, or
    # the exact defect class this guard was written for comes back unseen.
    # The /goal contracts pass the same *:* test (they embed `Condition:`).
    grep -oE "^[[:space:]]*[A-Z_]+_PROMPT=('[^']*'|\"[^\"]*\")" "$S26_F" 2>/dev/null \
      | sed -E "s/^[[:space:]]*[A-Z_]+_PROMPT=[\"']//; s/[\"']$//" \
      | while IFS= read -r S26_ARG; do
          case "$S26_ARG" in
            /*) case "$S26_ARG" in
                  *:*) ;;
                  *) echo "$S26_F: bare-slash prompt assignment '$S26_ARG' — needs a plugin: namespace" ;;
                esac ;;
          esac
        done
  done
}
S26_OUT="$(s26_guard "$S26_SCRIPTS")"
[ -z "$S26_OUT" ] || echo "  offending: $S26_OUT"
assert "S26: every shipped claude -p prompt is namespaced or a /goal contract" '[ -z "$S26_OUT" ]'
assert "S26: the guard actually saw the launcher's claude -p calls" \
  '[ -n "$(grep -oE "claude -p \"[^\"]*\"" "$S26_SCRIPTS/run-workflow.sh")" ]'
# Mutation re-runs the SAME guard on a copy where a bare-slash prompt returns.
S26_MUT="$(mktemp -d)"
cp "$S26_SCRIPTS"/*.sh "$S26_MUT/"
printf '\nclaude -p "/execute-phase-agent"\n' >> "$S26_MUT/agent-session.sh"
assert "S26: the guard fails when a bare-slash prompt is reintroduced" \
  '[ -n "$(s26_guard "$S26_MUT")" ]'
rm -rf "$S26_MUT"
# Mutation on the ASSIGNMENT half: the pre-2.1.139 REPAIR_PROMPT loses its
# namespace — the exact regression that once left the whole suite green.
S26_MUT="$(mktemp -d)"
cp "$S26_SCRIPTS"/*.sh "$S26_MUT/"
sed -i.bak 's|REPAIR_PROMPT="/\$PLUGIN_NAME:repair-phase"|REPAIR_PROMPT="/repair-phase"|' \
  "$S26_MUT/run-workflow.sh" && rm -f "$S26_MUT/run-workflow.sh.bak"
grep -q 'REPAIR_PROMPT="/repair-phase"' "$S26_MUT/run-workflow.sh" \
  || echo "  S26 mutation did not apply — the assignment shape changed"
assert "S26: the guard fails when a prompt ASSIGNMENT loses its namespace" \
  '[ -n "$(s26_guard "$S26_MUT")" ]'
rm -rf "$S26_MUT"

echo "== S27: the Done:/Verify: contract lives once and is cited, not restated =="
# Interactive mode splits verification in two — Done: for the machine, Verify:
# for the human, each Verify: step carrying a when (now / deferred: needs Phase
# M) and the deferred ones accumulating in verify.md. That contract is prose
# spread over several files, which is exactly the shape that drifts (the 4.1.0
# LIGHT_PROMPT defect was a second copy nobody updated). So: common.md owns it,
# the consumers — the -agent variants included — cite it by section name and
# name verify.md, and a consumer that restates the when vocabulary must
# restate it VERBATIM: a paraphrase is drift and is flagged.
s27_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S27_C="$2/common.md"
  grep -q '^## Verification: `Done:` and `Verify:`' "$S27_C" 2>/dev/null \
    || echo "$S27_C: missing the '## Verification: Done: and Verify:' section"
  grep -q 'deferred: needs Phase M' "$S27_C" 2>/dev/null \
    || echo "$S27_C: the Verification section does not define the deferred when"
  grep -q 'verify\.md' "$S27_C" 2>/dev/null \
    || echo "$S27_C: the Verification section does not name verify.md"
  # Every consumer of the contract cites the section instead of re-deriving it.
  for S27_S in write-workflow execute-phase finalize-workflow; do
    S27_F="$1/$S27_S/SKILL.md"
    grep -q 'Verification' "$S27_F" 2>/dev/null \
      || echo "$S27_F: does not cite common.md's Verification section"
  done
  # A consumer may restate the when vocabulary only VERBATIM — the source is
  # pinned above, and an unpinned copy is free to drift into a paraphrase the
  # executor would then write into real plans. Concrete instances
  # ("deferred: needs Phase 3") are the vocabulary applied, not a paraphrase.
  for S27_S in write-workflow execute-phase execute-phase-agent finalize-workflow; do
    S27_F="$1/$S27_S/SKILL.md"
    if grep 'deferred:' "$S27_F" 2>/dev/null \
        | grep -vE 'deferred: needs Phase ([0-9]+|M)' | grep -q .; then
      echo "$S27_F: paraphrases the deferred when (canonical: 'deferred: needs Phase M')"
    fi
  done
  # The files that must know where deferred checks land — the -agent variants
  # included: on the worktree path they ARE the executor and the QA collector.
  grep -q 'verify\.md' "$1/execute-phase/SKILL.md" 2>/dev/null \
    || echo "$1/execute-phase/SKILL.md: does not append deferred checks to verify.md"
  grep -q 'verify\.md' "$1/execute-phase-agent/SKILL.md" 2>/dev/null \
    || echo "$1/execute-phase-agent/SKILL.md: does not append deferred checks to verify.md"
  grep -q 'verify\.md' "$1/finalize-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/finalize-workflow/SKILL.md: does not present verify.md"
  grep -q 'verify\.md' "$1/finalize-workflow-agent/SKILL.md" 2>/dev/null \
    || echo "$1/finalize-workflow-agent/SKILL.md: does not collect verify.md"
  return 0
}
S27_OUT="$(s27_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S27_OUT" ] || echo "  offending: $S27_OUT"
assert "S27: the verification contract is single-source and cited" '[ -z "$S27_OUT" ]'
# Mutations re-run the SAME guard on a copy.
S27_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S27_MUT/"
sed -i.bak '/verify\.md/d' "$S27_MUT/execute-phase/SKILL.md" \
  && rm -f "$S27_MUT/execute-phase/SKILL.md.bak"
assert "S27: the guard fails when a phase stops writing verify.md" \
  '[ -n "$(s27_guard "$S27_MUT" "$S24_REFS")" ]'
rm -rf "$S27_MUT"
S27_MUT="$(mktemp -d)"; mkdir -p "$S27_MUT/refs"
cp -R "$SKILLS_DIR"/. "$S27_MUT/"
sed 's/^## Verification.*/## Verification (renamed)/' "$S24_REFS/common.md" \
  > "$S27_MUT/refs/common.md"
assert "S27: the guard fails when common.md stops owning the contract" \
  '[ -n "$(s27_guard "$S27_MUT" "$S27_MUT/refs")" ]'
rm -rf "$S27_MUT"
# A consumer's restated vocabulary drifts into a paraphrase — the copy defect
# the single-source rule exists for, previously invisible to this guard.
S27_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S27_MUT/"
sed -i.bak 's/deferred: needs Phase M/deferred: after Phase M/g' \
  "$S27_MUT/execute-phase/SKILL.md" && rm -f "$S27_MUT/execute-phase/SKILL.md.bak"
assert "S27: the guard fails when a consumer paraphrases the when vocabulary" \
  '[ -n "$(s27_guard "$S27_MUT" "$S24_REFS")" ]'
rm -rf "$S27_MUT"
# The finalize AGENT stops collecting verify.md — on the worktree path that
# silently empties the QA pass, so the guard covers the -agent consumers too.
S27_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S27_MUT/"
sed -i.bak '/verify\.md/d' "$S27_MUT/finalize-workflow-agent/SKILL.md" \
  && rm -f "$S27_MUT/finalize-workflow-agent/SKILL.md.bak"
assert "S27: the guard fails when the finalize agent stops collecting verify.md" \
  '[ -n "$(s27_guard "$S27_MUT" "$S24_REFS")" ]'
rm -rf "$S27_MUT"

echo "== S28: per-model steering reaches every sub-session =="
# The launcher appends a model-matched --append-system-prompt to each session:
# a common token-discipline steer (headless output is a log nobody reads live)
# plus one line damping the chosen model's known drift. Live half: on the
# happy path each phase carries the common steer AND its own model's line,
# never another model's. Static half: the repair call sites (fable, and the
# opus fallback) append a steer too, so no session is ever launched bare.
setup S28; fixture3
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S28: every phase session carries the common steer" \
  '[ "$(grep -c -- "--append-system-prompt You run unattended" .claude/invocations.log)" = 3 ]'
assert "S28: sonnet phase carries the literal-execution steer" \
  'grep -- "--model sonnet" .claude/invocations.log | grep -q "close the phase \[!\]"'
assert "S28: opus phase carries the no-over-verification steer" \
  'grep -- "--model opus" .claude/invocations.log | grep -q "Do not verify beyond the Done criteria"'
assert "S28: fable phase carries the act-not-replan steer" \
  'grep -- "--model fable" .claude/invocations.log | grep -q "do not re-derive decisions"'
assert "S28: the sonnet phase does not carry the fable steer" \
  '! grep -- "--model sonnet" .claude/invocations.log | grep -q "re-derive decisions"'
assert "S28: both repair call sites append a steer" \
  '[ "$(grep -c -- "--append-system-prompt \"\$STEER_COMMON" "$RUNNER_SRC")" = 2 ]'

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
