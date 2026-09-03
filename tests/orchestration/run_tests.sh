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
# Monitor watches (phase-done, phase-failed, phase-needs-foreman, phase-blocked,
# run-end), each emitted verbatim
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
# orphan branch); S62 the worktree the launcher creates and its GenroPy
# activation, plus the real activate_gnr_context's exclude-not-gitignore.
#
# Static checks on what the repo ships: no frozen copies of the shipped
# contracts and the light contract's per-phase-commit clause intact (S14),
# every skill inside its own allowed-tools (S15), the Done:/Verify: verification
# contract single-source in refs/contracts.md and cited by its consumers — the -agent
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
# call sites append one too). S29 checks the resume evidence:
# live via direct invocation (the selector reports the WIP commit ref, the
# validator warns — never blocks — on the three states that leave a resume
# session blind: several [>], a [>] with no "In execution since", a WIP note
# with no commit: ref; a healthy [>] draws zero warnings) and static (the
# structured > WIP: format is single-source in refs/phase-execution.md,
# cited by /execute-phase, never restated). S30 checks the foreman protocol
# (chat hierarchy and cross-session messaging): single-source in refs/foreman.md's
# '## The foreman', the shared core carrying the one 'Notify the foreman'
# step, every taking/deposing/notifying skill citing it, resume-workflow
# keeping the assume-command migration, no skill restating foreman.json, the
# commands-not-executes rule in the section, no skill sending a phase back
# to the foreman chat, and the clarify? question (5.18.0) owned by the
# section — ask-user reply path included — and cited by /execute-phase —
# proven by mutation. S16 retired with the KB mirror
# in 5.0.0; the number stays vacant.
TESTDIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER_SRC="$TESTDIR/../../plugins/wf/scripts/run-workflow.sh"
NEXT_PHASE_SRC="$TESTDIR/../../plugins/wf/scripts/next-phase.py"
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
cp "$TESTDIR/../../plugins/wf/scripts/next-phase.py" "$OT/next-phase.py"
bash -n "$OT/runner.sh" || { echo "runner syntax error"; exit 1; }
export OPS="$OT/mockops.py"

# Pre-flight: prerequisites are declared, never left to fail as raw FAILs — a
# missing tool must read as a prerequisite, not as a regression. python3 and
# git are hard requirements; zsh is only needed by the zsh-shell scenarios,
# which SKIP (counted apart from FAIL) where it is not installed.
for tool in python3 git; do
  command -v "$tool" >/dev/null 2>&1 \
    || { echo "PREREQ: $tool not installed — the suite cannot run."; exit 2; }
done
HAVE_ZSH=""
command -v zsh >/dev/null 2>&1 && HAVE_ZSH=1

PASS=0; FAIL=0; SKIP=0

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
  # Local identity: on a machine with no global git identity every commit in a
  # throwaway repo dies as "fatal: Failed to resolve 'HEAD'" — 8 assertions red
  # for a reason no message named.
  git config user.email wf-tests@harness.local
  git config user.name "wf test harness"
  # This sandbox's own control-file prefix: the launcher names stop request,
  # consult answer and apply outcome from it, and it carries the repo key, so
  # two scenarios (or two real checkouts) sharing the slug `toy` cannot
  # consume each other's signals.
  WF_T="$(python3 "$NEXT_PHASE_SRC" --transport "$DIR/.phased/active/toy/plan.md")"
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

skip() { SKIP=$((SKIP+1)); echo "  SKIP: $1"; }

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
assert "no repair launched" '! grep -q "repair-phase-agent skill" .claude/invocations.log'
assert "wall time recorded per session, with the config that ate it" 'grep -qE "Session wall time: [0-9]+m[0-9]{2}s — phase 1 \(sonnet/low/light\)" out.log'
assert "wall times summarised at the end" 'grep -q "Session wall times:" out.log && grep -qE "  phase 3 \(fable/high/full\): [0-9]+m[0-9]{2}s" out.log'
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
assert "repair via /goal on fable cap 300" 'grep -q -- "-p /goal Use the repair-phase-agent skill.*--model fable --effort [a-z]* --permission-mode auto --max-budget-usd 300" .claude/invocations.log'
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
assert "no repair call" '! grep -q "repair-phase-agent skill" .claude/invocations.log'

echo "== S5: fable repair crashes -> opus fallback repairs =="
setup S5; fixture2
printf '%s\n' 'python3 "$OPS" fail1; exit 0' 'exit 1' 'python3 "$OPS" repair_ok; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "fallback message" 'grep -q "retrying with opus" out.log'
assert "opus repair cap 200" 'grep -q -- "-p /goal Use the repair-phase-agent skill.*--model opus --effort [a-z]* --permission-mode auto --max-budget-usd 200" .claude/invocations.log'
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
assert "namespaced /wf:execute-phase-agent prompt used" 'grep -q -- "-p /wf:execute-phase-agent --model" .claude/invocations.log'
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
assert "S7b: namespaced /wf:repair-phase-agent prompt used" 'grep -q -- "-p /wf:repair-phase-agent --model fable" .claude/invocations.log'
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
if [ -n "$HAVE_ZSH" ]; then
  setup S9; fixture3
  printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
  finish_setup; run_zsh
  assert "zsh: phase1 sonnet/low cap 50" 'grep -q -- "--model sonnet --effort low --permission-mode auto --max-budget-usd 50" .claude/invocations.log'
  assert "zsh: phase2 opus/medium cap 100" 'grep -q -- "--model opus --effort medium --permission-mode auto --max-budget-usd 100" .claude/invocations.log'
  assert "zsh: phase3 fable/high cap 400" 'grep -q -- "--model fable --effort high --permission-mode auto --max-budget-usd 400" .claude/invocations.log'
  assert "zsh: no shell error leaked" '! grep -qi "bad math expression\|parse error" out.log'
  assert "zsh: all phases [x]" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 3 ]'
else
  skip "S9: zsh not installed — the zsh-shell assertions did not run (the production shell on macOS is untested here)"
fi

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
assert "repair launched first, before any phase session" 'head -1 .claude/invocations.log | grep -q "repair-phase-agent skill"'
assert "repair succeeded message" 'grep -q "Repair succeeded" out.log'
assert "phase 1 repaired" 'grep -q "^- \[x\] \*\*Phase 1\*\*" .phased/active/toy/plan.md'
# "continuing with next phase" used to be a lie here: the repair consumed the
# only loop iteration (budget = pending count) and Phase 2 silently never ran.
assert "loop actually continued to phase 2 after repair" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'

echo "== S11: Case A reopen ([x] count drops) -> repair runs, progress guard silent =="
setup S11; fixture2
python3 - <<'EOF'
s = open('.phased/active/toy/plan.md').read()
s = s.replace('- [ ] **Phase 1**: phase one', '- [x] **Phase 1**: phase one', 1)
open('.phased/active/toy/plan.md','w').write(s)
EOF
printf '%s\n' 'python3 "$OPS" reopen; exit 0' 'python3 "$OPS" repair_ok; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "progress guard did NOT fire" '! grep -q "No progress in the last run" out.log'
assert "repair launched after reopen" 'grep -q "repair-phase-agent skill" .claude/invocations.log'
assert "reopened phase back to [x]" 'grep -q "^- \[x\] \*\*Phase 1\*\*" .phased/active/toy/plan.md'
assert "pending phase still ran after the repair round" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'

echo "== S12: baseline red and unattributable -> [~] stops the run =="
setup S12; fixture2
printf '%s\n' 'python3 "$OPS" blocked; exit 0' > .claude/mock-queue
finish_setup; run
assert "blocked stop message" 'grep -q "blocked \[~\]" out.log'
assert "single call only" '[ "$(grep -c "CALL:" .claude/invocations.log)" = 1 ]'
assert "no repair attempted" '! grep -q "repair-phase-agent skill" .claude/invocations.log'

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
SKILLS_DIR="$TESTDIR/../../plugins/wf/skills"
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
NEXTPHASE="$TESTDIR/../../plugins/wf/scripts/next-phase.py"

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

# -- three sources, three roads: the classifier reads Channel: where the source
#    carries one, and a source without it stays legacy. Importing must not add
#    the field to somebody else's plan, and the three cases must not collapse.
s17_source() {  # $1..$n = header lines; prints the payload's channel, or LEGACY
  S17_S="$OT/src-plan.md"
  { echo "# Context: imported"; echo "Parent: develop"
    for S17_H in "$@"; do echo "$S17_H"; done
    echo ""; echo "## Work Plan"; echo "- [ ] **Phase 1**: one"; } > "$S17_S"
  python3 "$NEXTPHASE" --json "$S17_S" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["meta"].get("channel","LEGACY"))'
}
assert "S17: a source carrying Channel: in-chat is read as in-chat" \
  '[ "$(s17_source "Mode: interactive" "Channel: in-chat")" = "in-chat" ]'
assert "S17: a source carrying Channel: relayed is read as relayed" \
  '[ "$(s17_source "Mode: interactive" "Channel: relayed")" = "relayed" ]'
assert "S17: a legacy source stays legacy — no channel is invented for it" \
  '[ "$(s17_source "Mode: interactive")" = "LEGACY" ]'
# The three roads must have three different operational effects in the skill,
# not three mentions: relayed and legacy take command, in-chat does not.
S17_IMP="$SKILLS_DIR/import-workflow/SKILL.md"
assert "S17: the relayed import takes command and opens a new chat" \
  'grep -q "relayed road, and only there, write .foreman.json." "$S17_IMP" &&
   grep -qE "relayed →.*new chat" "$S17_IMP"'
assert "S17: the in-chat import takes no command and continues here" \
  'grep -qE "No .foreman.json., no take-command" "$S17_IMP" &&
   grep -qE "in-chat →.*/execute-phase here" "$S17_IMP"'
assert "S17: a legacy source is routed with the relayed road, explicitly" \
  'grep -q "legacy plan carrying no .Channel:., importing" "$S17_IMP"'
assert "S17: the relay layer is not read on an in-chat import" \
  'grep -q "on .Channel: in-chat. the import creates no relay and never reads it" "$S17_IMP"'
# Mutation: the three roads collapse back into one.
S17_MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$S17_MUT/"
sed -i.bak 's/relayed road, and only there, write `foreman.json`/write `foreman.json`/' \
  "$S17_MUT/import-workflow/SKILL.md" && rm -f "$S17_MUT/import-workflow/SKILL.md.bak"
assert "S17: the guard fails when the import writes foreman.json on every road" \
  '! grep -q "relayed road, and only there, write .foreman.json." "$S17_MUT/import-workflow/SKILL.md"'
rm -rf "$S17_MUT"

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
assert "S18: the [!] decoy launched no repair" '! grep -q "repair-phase-agent skill" .claude/invocations.log'
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

# The same rule over the python readers: the plan format has ONE reader,
# next-phase.py, so a phase-state class or a **Phase pattern anywhere else is a
# second implementation. The dashboard's core.py carried exactly that.
PLUGIN_SRC="$TESTDIR/../../plugins/wf/scripts"
GUARD_OUT="$(python3 "$STATE_GUARD" "$PLUGIN_SRC/next-phase.py" "$PLUGIN_SRC/wfdash"/*.py)"
[ -z "$GUARD_OUT" ] || echo "  offending: $GUARD_OUT"
assert "S18: no python plan reader duplicates the phase format" '[ -z "$GUARD_OUT" ]'
# Mutation: give a second module the marker regex back — the guard must go red.
S18_MUT="$(mktemp -d)"
cp "$PLUGIN_SRC/wfdash/core.py" "$S18_MUT/core.py"
printf "%s\n" "PHASE_RE = re.compile(r'^- \\[([ x!~>])\\] \\*\\*Phase (\\d+)\\*\\*:')" \
  >> "$S18_MUT/core.py"
assert "S18: the guard fails when a second reader takes the plan format back" \
  '! python3 "$STATE_GUARD" "$S18_MUT/core.py" >/dev/null 2>&1'
rm -rf "$S18_MUT"
# Mutation: give server.py back the slicer it carried — an ESCAPED marker
# regex, the shape the guard used to miss and the reason it was widened.
S18_MUT="$(mktemp -d)"
cp "$PLUGIN_SRC/wfdash/server.py" "$S18_MUT/server.py"
printf "%s\n" "PHASE_LINE = re.compile(r'^- \\[.\\] \\*\\*Phase (\\d+)\\*\\*')" \
  >> "$S18_MUT/server.py"
assert "S18: the guard fails when the escaped marker regex comes back" \
  '! python3 "$STATE_GUARD" "$S18_MUT/server.py" >/dev/null 2>&1'
rm -rf "$S18_MUT"

echo "== S19: next-phase.py --validate gates the launcher before any session =="
# The validator shares the selector's own regexes, so a plan it rejects is one
# the loop could not drive correctly. The launcher runs it once before the loop
# and stops on a non-zero result, printing it verbatim — no session spent.
NEXTPHASE="$TESTDIR/../../plugins/wf/scripts/next-phase.py"

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

# Channel: the routing field. Legacy absence, both legal pairings, and every
# rejection — an unknown value, the invalid autonomous+in-chat combination, and
# the near-miss field name that would otherwise read as "no header" and route a
# workflow to the legacy road in silence.
s19_channel() {  # $@ = header lines after Parent:; prints validator output
  S19_CP="$OT/chan-plan.md"
  { echo "# Context: chan"; echo "Parent: main"
    for S19_H in "$@"; do echo "$S19_H"; done
    echo ""; echo "## Work Plan"
    echo "- [ ] **Phase 1**: phase one"; echo "  - Done: check one"
    case "$*" in
      *autonomous*) echo ""; echo "## Suggested execution config"
                    echo "| Phase | Effort | Model |"; echo "|---|---|---|"
                    echo "| Phase 1 | low | opus |" ;;
    esac
  } > "$S19_CP"
  python3 "$NEXTPHASE" --validate "$S19_CP" 2>&1
}
S19_O="$(s19_channel "Mode: interactive")"
assert "S19: a legacy plan with no Channel: validates clean" \
  '[ -z "$(printf "%s" "$S19_O" | grep "error:")" ]'
S19_O="$(s19_channel "Mode: interactive" "Channel: in-chat")"
assert "S19: interactive + in-chat validates clean" \
  '[ -z "$(printf "%s" "$S19_O" | grep "error:")" ]'
S19_O="$(s19_channel "Mode: interactive" "Channel: relayed")"
assert "S19: interactive + relayed validates clean" \
  '[ -z "$(printf "%s" "$S19_O" | grep "error:")" ]'
S19_O="$(s19_channel "Mode: autonomous" "Channel: relayed")"
assert "S19: autonomous + relayed validates clean" \
  '[ -z "$(printf "%s" "$S19_O" | grep "error:")" ]'
S19_O="$(s19_channel "Mode: autonomous" "Channel: in-chat")"
assert "S19: autonomous + in-chat is rejected" \
  'printf "%s" "$S19_O" | grep -q "error:.*autonomous with Channel: in-chat"'
S19_O="$(s19_channel "Mode: interactive" "Chanel: in-chat")"
assert "S19: a near-miss channel field name is rejected, not ignored" \
  'printf "%s" "$S19_O" | grep -q "error:.*channel value under the name .Chanel."'
S19_O="$(s19_channel "Mode: interactive" "Channel: inchat")"
assert "S19: an unknown Channel: value is rejected" \
  'printf "%s" "$S19_O" | grep -q "error:.*Channel: .inchat. is not one of"'
S19_O="$(s19_channel "Mode: interactive" "Channel: in-chat")"
assert "S19: and its summary line reports zero errors" \
  'printf "%s" "$S19_O" | grep -q "^validate: 0 error(s)"'
# The channel reaches consumers through the ONE reader, in the JSON payload.
s19_channel "Mode: interactive" "Channel: in-chat" >/dev/null
S19_META="$(python3 "$NEXTPHASE" --json "$OT/chan-plan.md" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["meta"].get("channel",""))')"
assert "S19: the payload carries the channel to every consumer" '[ "$S19_META" = "in-chat" ]'
# A malformed Channel: line must not degrade to "no header" either.
S19_O="$(s19_channel "Mode: interactive" "Channel: in-chat (fast)")"
assert "S19: a malformed Channel: line is rejected" \
  'printf "%s" "$S19_O" | grep -q "error: malformed Channel:"'

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

# (i) a MALFORMED Mode: line ("Mode: autonomous (fast lane)") is an error, not
# a silent no-header read — the same threat as (f), one notch earlier: a line
# the value-check cannot even parse must not degrade into the interactive
# default either.
MODE_MALFORMED_PLAN="$OT/mode-malformed-plan.md"
cat > "$MODE_MALFORMED_PLAN" <<'EOF'
# Context: mode-malformed
Parent: main
Mode: autonomous (fast lane)

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
S21_SKILLS="$TESTDIR/../../plugins/wf/skills"
S21_REFS="$TESTDIR/../../plugins/wf/refs"
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
git config user.email wf-tests@harness.local
git config user.name "wf test harness"
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
  >> "$S23_MUT/quality-check-agent/SKILL.md"
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
S24_REFS="$TESTDIR/../../plugins/wf/refs"
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
assert "S25: each completed phase emits its 'EVENT: phase-done' with progress" \
  '[ "$(grep -c "^EVENT: phase-done" out.log)" = 3 ] && grep -q "^EVENT: phase-done 1 1/3$" out.log && grep -q "^EVENT: phase-done 3 3/3$" out.log'
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
assert "S25: token extraction found all five events" '[ "$(s25_tokens | wc -l | tr -d " ")" = 5 ]'
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
  grep 'EVENT' "$1" 2>/dev/null | grep -oE '\b(phase|run)-[a-z-]+\b' \
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
S26_SCRIPTS="$TESTDIR/../../plugins/wf/scripts"
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
sed -i.bak 's|REPAIR_PROMPT="/\$PLUGIN_NAME:repair-phase-agent"|REPAIR_PROMPT="/repair-phase"|' \
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
# LIGHT_PROMPT defect was a second copy nobody updated). So: contracts.md owns it,
# the consumers — the -agent variants included — cite it by section name and
# name verify.md, and a consumer that restates the when vocabulary must
# restate it VERBATIM: a paraphrase is drift and is flagged.
s27_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S27_C="$2/contracts.md"
  grep -q '^## Verification: `Done:` and `Verify:`' "$S27_C" 2>/dev/null \
    || echo "$S27_C: missing the '## Verification: Done: and Verify:' section"
  grep -q 'deferred: needs Phase M' "$S27_C" 2>/dev/null \
    || echo "$S27_C: the Verification section does not define the deferred when"
  grep -q 'verify\.md' "$S27_C" 2>/dev/null \
    || echo "$S27_C: the Verification section does not name verify.md"
  # Every consumer of the contract cites the section instead of re-deriving it.
  for S27_S in write-workflow execute-phase quality-check; do
    S27_F="$1/$S27_S/SKILL.md"
    grep -q 'Verification' "$S27_F" 2>/dev/null \
      || echo "$S27_F: does not cite contracts.md's Verification section"
  done
  # A consumer may restate the when vocabulary only VERBATIM — the source is
  # pinned above, and an unpinned copy is free to drift into a paraphrase the
  # executor would then write into real plans. Concrete instances
  # ("deferred: needs Phase 3") are the vocabulary applied, not a paraphrase.
  for S27_S in write-workflow execute-phase execute-phase-agent quality-check; do
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
  grep -q 'verify\.md' "$1/quality-check/SKILL.md" 2>/dev/null \
    || echo "$1/quality-check/SKILL.md: does not present verify.md"
  grep -q 'verify\.md' "$1/quality-check-agent/SKILL.md" 2>/dev/null \
    || echo "$1/quality-check-agent/SKILL.md: does not collect verify.md"
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
S27_MUT="$(mktemp -d)"; mkdir -p "$S27_MUT/refs"; cp "$S24_REFS"/*.md "$S27_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S27_MUT/"
sed 's/^## Verification.*/## Verification (renamed)/' "$S24_REFS/contracts.md" \
  > "$S27_MUT/refs/contracts.md"
assert "S27: the guard fails when contracts.md stops owning the contract" \
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
# The quality-check AGENT stops collecting verify.md — on the worktree path
# that silently empties the QA pass, so the guard covers the -agent consumers too.
S27_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S27_MUT/"
sed -i.bak '/verify\.md/d' "$S27_MUT/quality-check-agent/SKILL.md" \
  && rm -f "$S27_MUT/quality-check-agent/SKILL.md.bak"
assert "S27: the guard fails when the quality-check agent stops collecting verify.md" \
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

echo "== S29: the resume path leaves machine-readable evidence =="
# A [>] phase is resumed by a session that was not there: the > WIP: note's
# commit: ref is the hash it diffs from instead of trusting prose. Live half:
# the selector surfaces that ref, and the validator warns — never blocks — on
# the three states that leave a resume blind. Static half: the structured
# format lives once, in refs/phase-execution.md, and /execute-phase cites it.
NEXTPHASE="$TESTDIR/../../plugins/wf/scripts/next-phase.py"
S29_DIR="$OT/s29"; mkdir -p "$S29_DIR"

cat > "$S29_DIR/healthy.md" <<'EOF'
# Context: s29
Parent: main
Mode: interactive

## Work Plan
- [x] **Phase 1**: done phase
  > Done: it works
  > Files: a.py
- [>] **Phase 2**: big phase
  > In execution since 2026-01-01T10:00:00
  > WIP: done: schema landed | missing: the grid | next: wire the store | commit: abc1234
EOF
S29_OUT="$(python3 "$NEXTPHASE" "$S29_DIR/healthy.md" 2>&1)"
assert "S29a: the resume-candidate line carries the WIP commit ref" \
  'printf "%s" "$S29_OUT" | grep -q "resume-candidate: 2 (age: .*wip: yes, wip-commit: abc1234)"'
S29_VOUT="$(python3 "$NEXTPHASE" --validate "$S29_DIR/healthy.md" 2>&1)"; S29_VRC=$?
assert "S29b: healthy [>] evidence draws zero warnings (exit 0)" \
  '[ "$S29_VRC" = 0 ] && printf "%s" "$S29_VOUT" | grep -q "0 error(s), 0 warning(s)"'

cat > "$S29_DIR/blind.md" <<'EOF'
# Context: s29
Parent: main
Mode: interactive

## Work Plan
- [>] **Phase 1**: no since note
  > WIP: did some stuff, dunno
- [>] **Phase 2**: second in-exec
  > In execution since 2026-01-01T10:00:00
EOF
S29_BOUT="$(python3 "$NEXTPHASE" --validate "$S29_DIR/blind.md" 2>&1)"; S29_BRC=$?
assert "S29c: several [>] phases draw the dead-session warning" \
  'printf "%s" "$S29_BOUT" | grep -q "several phases in execution (\[>\]): 1, 2"'
assert "S29d: a [>] with no In-execution-since note is named" \
  'printf "%s" "$S29_BOUT" | grep -q "phase 1 is \[>\] with no .> In execution since."'
assert "S29e: a WIP note with no commit: ref is named, with the format" \
  'printf "%s" "$S29_BOUT" | grep -q "phase 1 has a .> WIP:. note with no commit: ref" && printf "%s" "$S29_BOUT" | grep -q "commit: <hash>"'
assert "S29f: resume-evidence findings warn but never block (exit 0)" \
  '[ "$S29_BRC" = 0 ]'
S29_SOUT="$(python3 "$NEXTPHASE" "$S29_DIR/blind.md" 2>&1)"
assert "S29g: the status line says out loud that the commit ref is missing" \
  'printf "%s" "$S29_SOUT" | grep -q "wip: yes (no commit ref)"'

# Static half: the format is single-source and cited, not restated.
S29_REF="$TESTDIR/../../plugins/wf/refs/phase-execution.md"
S29_SKILL="$TESTDIR/../../plugins/wf/skills/execute-phase/SKILL.md"
assert "S29h: the structured > WIP: format lives in phase-execution.md" \
  'grep -q "> WIP: done: .*| missing: .*| next: .*| commit: " "$S29_REF"'
assert "S29h: phase-execution.md declares itself the single source" \
  'grep -q "single source of its format" "$S29_REF"'
assert "S29i: /execute-phase cites WIP checkpoints and restates no format" \
  'grep -q "WIP checkpoints" "$S29_SKILL" && ! grep -q "> WIP: <" "$S29_SKILL" && ! grep -q "> WIP: done:" "$S29_SKILL"'

echo "== S30: the foreman protocol lives once and is cited, not restated =="
# One chat commands each workflow (the foreman), executor chats message it —
# file format, take-command mechanics and message formats are prose spread
# over several skills, the exact shape that drifts. So: foreman.md owns the
# protocol under '## The foreman', the shared core carries the one 'Notify
# the foreman' step both execute modes cite, every skill that takes or hands
# over command cites the section, and nobody restates the foreman.json body.
s30_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S30_C="$2/foreman.md"
  grep -q '^## The foreman' "$S30_C" 2>/dev/null \
    || echo "$S30_C: missing the '## The foreman' section"
  grep -q 'foreman\.json' "$S30_C" 2>/dev/null \
    || echo "$S30_C: the foreman section does not name foreman.json"
  grep -q 'Best-effort' "$S30_C" 2>/dev/null \
    || echo "$S30_C: the foreman section does not state the best-effort rule"
  grep -q 'list_sessions' "$S30_C" 2>/dev/null \
    || echo "$S30_C: the foreman section does not define the title lookup"
  grep -q '^## Notify the foreman' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: missing the 'Notify the foreman' step"
  # Every skill that takes command, deposes, notifies or reads the rationale
  # cites the section instead of re-deriving it.
  for S30_S in write-workflow import-workflow resume-workflow execute-phase \
               execute-phase-agent finalize-workflow run-workflow; do
    S30_F="$1/$S30_S/SKILL.md"
    grep -qi 'foreman' "$S30_F" 2>/dev/null \
      || echo "$S30_F: does not cite foreman.md's The foreman section"
  done
  # resume-workflow owns the migration: no foreman on file → assume command.
  grep -q 'assume command' "$1/resume-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/resume-workflow/SKILL.md: lost the assume-command migration path"
  # Nobody but foreman.md carries the foreman.json body or the message formats.
  for S30_S in write-workflow import-workflow resume-workflow execute-phase \
               execute-phase-agent finalize-workflow run-workflow; do
    S30_F="$1/$S30_S/SKILL.md"
    if grep -qE '"foreman":|"since":|\[wf:' "$S30_F" 2>/dev/null; then
      echo "$S30_F: restates the foreman.json body or message format (single source: foreman.md)"
    fi
  done
  # The rename suggestion is restated only verbatim: the shared suffix must
  # appear identical in the source and in both skills that close with it.
  S30_SUFFIX="address phase chats report to"
  for S30_F in "$S30_C" "$1/write-workflow/SKILL.md" "$1/import-workflow/SKILL.md"; do
    grep -q "$S30_SUFFIX" "$S30_F" 2>/dev/null \
      || echo "$S30_F: the rename suggestion drifted from the canonical wording"
  done
  # The foreman commands and does not execute: the rule lives in the section,
  # and no skill sends a phase back to the chat that holds the plan.
  grep -q 'commands; it does not execute' "$S30_C" 2>/dev/null \
    || echo "$S30_C: the foreman section lost the commands-not-executes rule"
  # 5.18.0 — clarify?: the channel's second question. The section owns it
  # (format, opposite decision policy, ask-user reply path, timeout fallback);
  # /execute-phase cites the routing and restates nothing (the format check
  # above already forbids the message body in skills).
  grep -q 'clarify?' "$S30_C" 2>/dev/null \
    || echo "$S30_C: the foreman section does not define clarify?"
  grep -q 'ask-user' "$S30_C" 2>/dev/null \
    || echo "$S30_C: clarify? lost the ask-user reply path"
  grep -qi 'clarify' "$1/execute-phase/SKILL.md" 2>/dev/null \
    || echo "$1/execute-phase/SKILL.md: does not route plan ambiguities via clarify?"
  # 6.0.1 — the foreman must be able to answer unattended: take-command
  # advises the permission setup, and the clarify reply precedes the plan
  # edit so it cannot die behind a commit's permission prompt.
  grep -q 'without asking' "$S30_C" 2>/dev/null \
    || echo "$S30_C: take-command lost the unattended-permissions advice"
  # 6.0.2 — the decision survives a dead reply path: notes.md committed
  # before replying, the plan edit travels in the reply and is applied by
  # the child on acceptance, the timeout re-reads the disk before falling
  # back to the human, and the reply tool is named (SendMessage does not
  # resolve desktop sessions).
  grep -q 'BEFORE replying' "$S30_C" 2>/dev/null \
    || echo "$S30_C: clarify? lost the decision-on-disk-before-reply step"
  grep -q 'applies the foreman' "$S30_C" 2>/dev/null \
    || echo "$S30_C: clarify? lost the child-applies-on-acceptance step"
  grep -q 'IS the reply' "$S30_C" 2>/dev/null \
    || echo "$S30_C: the clarify timeout no longer re-reads the disk"
  grep -q 'does not resolve desktop sessions' "$S30_C" 2>/dev/null \
    || echo "$S30_C: the reply tool for desktop sessions is no longer named"
  # 6.0.3 — the chat titles itself: set_session_title accepts the literal
  # "self" (2.1.234), so the protocol's last manual step is gone. The section
  # says so and no longer claims otherwise, and every skill that titles a chat
  # declares the tool it needs to do it.
  grep -q '"self"' "$S30_C" 2>/dev/null \
    || echo "$S30_C: take-command no longer names the self-rename"
  if grep -q 'nor rename itself' "$S30_C" 2>/dev/null; then
    echo "$S30_C: still claims a session cannot rename itself"
  fi
  for S30_S in write-workflow import-workflow resume-workflow execute-phase; do
    S30_F="$1/$S30_S/SKILL.md"
    grep -q 'set_session_title' "$S30_F" 2>/dev/null \
      || echo "$S30_F: does not title its chat (set_session_title)"
  done
  # 6.6.0 — repair splits by environment, not by method: the base asks the
  # human and can hand a phase back, the -agent variant is [!]-only and closes
  # on its own, and the launcher must reach the unattended one.
  grep -q 'Two ways in' "$1/repair-phase/SKILL.md" 2>/dev/null \
    || echo "$1/repair-phase/SKILL.md: repair has no interactive way in"
  grep -q 'Ask what is wrong' "$1/repair-phase/SKILL.md" 2>/dev/null \
    || echo "$1/repair-phase/SKILL.md: no longer asks the human what is wrong"
  grep -q 'Handing a defect to repair' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: the phase chat has no way to hand a defect out"
  [ -f "$1/repair-phase-agent/SKILL.md" ] \
    || echo "$1/repair-phase-agent: the unattended repair variant is missing"
  # 6.5.0 — a phase that outgrows its chat has two answers, and the cleaner one
  # closes it on the sub-result reached. The refusal stays where it belongs: a
  # RED criterion is repair territory, an UNREACHED one is a narrowed Done:.
  grep -q 'When the phase outgrows its chat' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: no fork between closing short and handing over"
  grep -q 'closed short' "$S30_C" 2>/dev/null \
    || echo "$S30_C: no message carries a short close to the foreman"
  grep -q 'closed short' "$1/close-phase/SKILL.md" 2>/dev/null \
    || echo "$1/close-phase/SKILL.md: a Done: unreached for scope is still a plain refusal"
  grep -q 'closed short' "$1/resume-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/resume-workflow/SKILL.md: nobody writes the phase for the remainder"
  # 6.4.0 — a deferred tool is not an absent tool. The whole channel bug came
  # back through the word EXIST: list_sessions is invisible until ToolSearch
  # loads it, so "that tool does not exist" read true and licensed ListAgents.
  grep -q 'missing from your tool list is not' "$S30_C" 2>/dev/null \
    || echo "$S30_C: absence is no longer bound to a failed ToolSearch"
  grep -q 'ToolSearch' "$S30_C" 2>/dev/null \
    || echo "$S30_C: the section does not name ToolSearch as the way to look"
  # 6.4.0 — the mirror of the foreman rule: a phase chat does not supervise.
  # /resume-workflow takes command where no session bears the title, so a phase
  # chat running it becomes a foreman that also executes.
  grep -q 'executes; it does not supervise' "$S30_C" 2>/dev/null \
    || echo "$S30_C: nothing stops a phase chat from supervising"
  # Channel-qualified since the phase-sizing change: the ban is the relayed
  # road's, where two chats must not both command. A line that names the
  # in-chat channel is describing the co-located road the design introduces,
  # not breaking the relayed rule — and the fork's own file must say so.
  grep -q 'is the relayed' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: the no-supervision rule is not scoped to a road"
  for S30_F in "$1"/*/SKILL.md; do
    if grep -E 'resume-workflow[^|]*in this (chat|session)|run /wf:resume-workflow here' \
        "$S30_F" 2>/dev/null | grep -qv 'in-chat'; then
      echo "$S30_F: recommends /resume-workflow in the current chat (a phase chat does not supervise)"
    fi
  done
  # 6.4.0 — handing over: a named move, its rationale on disk, and the arriving
  # chat able to tell a live one to commit and stand down.
  grep -q '^## Handing over' "$1/execute-phase/SKILL.md" 2>/dev/null \
    || echo "$1/execute-phase/SKILL.md: the handover is still only a context-window reaction"
  grep -q 'stop working on this phase' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: the arriving chat cannot tell a live one to stand down"
  # 6.1.0 — a message is answered with the delta, not by redrawing the board,
  # and the launch command lost the argument that only existed to title a chat.
  grep -q 'answers with the DELTA' "$S30_C" 2>/dev/null \
    || echo "$S30_C: a foreman receiving a message still redraws its board"
  grep -q 'Never on an incoming message' "$2/board.md" 2>/dev/null \
    || echo "$2/board.md: the board is still drawn on an incoming message"
  if grep -q 'execute-phase Phase N' "$2/board.md" 2>/dev/null; then
    echo "$2/board.md: the card command still carries the chat-title argument"
  fi
  # 6.2.0 — the board is a strip, not a working view: the controls went where
  # the conversation already goes. Nothing on it is clickable, and no skill
  # sends the user back to a textarea that no longer exists.
  grep -q 'Nothing on it is clickable' "$2/board.md" 2>/dev/null \
    || echo "$2/board.md: the board no longer declares itself read-only"
  for S30_F in "$2/board.md" "$1"/*/SKILL.md; do
    if grep -qE 'state select|copy command|notes and problems|export fix prompt' \
        "$S30_F" 2>/dev/null; then
      echo "$S30_F: still specifies a board control (the strip has none)"
    fi
  done
  for S30_F in "$1"/*/SKILL.md; do
    if grep -E 'execute-phase[^|]*in this (chat|session)|in this (chat|session)[^|]*execute-phase' "$S30_F" 2>/dev/null | grep -qv 'in-chat'; then
      echo "$S30_F: recommends /execute-phase in the current chat (the foreman does not execute)"
    fi
  done
  return 0
}
S30_OUT="$(s30_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S30_OUT" ] || echo "  offending: $S30_OUT"
assert "S30: the foreman protocol is single-source and cited" '[ -z "$S30_OUT" ]'
# Mutations re-run the SAME guard on a copy.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed 's/^## The foreman.*/## The site manager (renamed)/' "$S24_REFS/foreman.md" \
  > "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S30_MUT/refs/phase-execution.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
assert "S30: the guard fails when foreman.md stops owning the protocol" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
S30_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed -i.bak '/[Ff]oreman/d' "$S30_MUT/resume-workflow/SKILL.md" \
  && rm -f "$S30_MUT/resume-workflow/SKILL.md.bak"
assert "S30: the guard fails when resume-workflow drops the takeover" \
  '[ -n "$(s30_guard "$S30_MUT" "$S24_REFS")" ]'
rm -rf "$S30_MUT"
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
cp "$S24_REFS/foreman.md" "$S30_MUT/refs/foreman.md"
sed '/^## Notify the foreman/,+7d' "$S24_REFS/phase-execution.md" \
  > "$S30_MUT/refs/phase-execution.md"
assert "S30: the guard fails when the shared core stops notifying" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# A skill restates the foreman.json body — the copy defect the single-source
# rule exists for.
S30_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
printf '\n  "foreman": "wf:<slug>:foreman",\n' >> "$S30_MUT/execute-phase/SKILL.md"
assert "S30: the guard fails when a skill restates the foreman.json body" \
  '[ -n "$(s30_guard "$S30_MUT" "$S24_REFS")" ]'
rm -rf "$S30_MUT"
# The commands-not-executes rule leaves the section.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed '/commands; it does not execute/d' "$S24_REFS/foreman.md" \
  > "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S30_MUT/refs/phase-execution.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
assert "S30: the guard fails when the foreman may execute a phase" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# A skill points the next phase back at this chat — the 5.17.1 defect itself.
S30_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
printf '\nRun the next phase with /execute-phase in this chat.\n' \
  >> "$S30_MUT/resume-workflow/SKILL.md"
assert "S30: the guard fails when a skill sends the next phase back to this chat" \
  '[ -n "$(s30_guard "$S30_MUT" "$S24_REFS")" ]'
rm -rf "$S30_MUT"
# clarify? leaves the section — the 5.18.0 channel disappears.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed 's/clarify?//g' "$S24_REFS/foreman.md" > "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S30_MUT/refs/phase-execution.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
assert "S30: the guard fails when foreman.md stops defining clarify?" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# The ask-user reply path leaves the section — the foreman-in-doubt branch dies.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed 's/ask-user//g' "$S24_REFS/foreman.md" > "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S30_MUT/refs/phase-execution.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
assert "S30: the guard fails when clarify? loses the ask-user reply path" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# /execute-phase stops routing plan ambiguities upward — the defect of #13.
S30_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed -i.bak '/[Cc]larify/d' "$S30_MUT/execute-phase/SKILL.md" \
  && rm -f "$S30_MUT/execute-phase/SKILL.md.bak"
assert "S30: the guard fails when /execute-phase drops the clarify routing" \
  '[ -n "$(s30_guard "$S30_MUT" "$S24_REFS")" ]'
rm -rf "$S30_MUT"
# Take-command stops advising the unattended permissions — the 6.0.1 field
# finding: a foreman on default permissions decides and dies on the prompt.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed 's/without asking//g' "$S24_REFS/foreman.md" > "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S30_MUT/refs/phase-execution.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
assert "S30: the guard fails when take-command drops the permissions advice" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# The decision stops landing on disk before the reply — the 6.0.2 invariant
# that saved the field test when both message channels died.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed 's/BEFORE replying/when convenient/g' "$S24_REFS/foreman.md" > "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S30_MUT/refs/phase-execution.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
assert "S30: the guard fails when the decision no longer lands on disk first" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# The timeout stops re-reading the disk — back to burning a decision that exists.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed 's/IS the reply/may exist/g' "$S24_REFS/foreman.md" > "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S30_MUT/refs/phase-execution.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
assert "S30: the guard fails when the clarify timeout stops re-reading the disk" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# The unattended repair variant is gone, so the launcher would reach the
# interactive one and hang on its first question.
S30_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
rm -rf "$S30_MUT/repair-phase-agent"
assert "S30: the guard fails when the unattended repair variant is missing" \
  '[ -n "$(s30_guard "$S30_MUT" "$S24_REFS")" ]'
rm -rf "$S30_MUT"
# Repair goes back to grading itself: no question at the start.
S30_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed -i.bak 's/## Step 1: Ask what is wrong/## Step 1: Read the failure/' \
  "$S30_MUT/repair-phase/SKILL.md" && rm -f "$S30_MUT/repair-phase/SKILL.md.bak"
assert "S30: the guard fails when repair stops asking the human" \
  '[ -n "$(s30_guard "$S30_MUT" "$S24_REFS")" ]'
rm -rf "$S30_MUT"
# Closing short disappears: an overrun phase has nowhere to go but a handover.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
cp "$S24_REFS/foreman.md" "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
sed 's/When the phase outgrows its chat/Checkpoints, again/' \
  "$S24_REFS/phase-execution.md" > "$S30_MUT/refs/phase-execution.md"
assert "S30: the guard fails when a phase cannot be closed short" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# EXIST comes back, and with it the reading that a deferred tool is absent.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed 's/missing from your tool list is not/absent from your tool list is not/' \
  "$S24_REFS/foreman.md" > "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S30_MUT/refs/phase-execution.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
assert "S30: the guard fails when absence stops meaning a failed ToolSearch" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# The phase chat is allowed to supervise again.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed 's/executes; it does not supervise/does what it likes/' \
  "$S24_REFS/foreman.md" > "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S30_MUT/refs/phase-execution.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
assert "S30: the guard fails when a phase chat may supervise" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# A skill sends the user to /resume-workflow in the chat running the phase.
S30_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
printf '\nWhen the plan needs reshaping, run /wf:resume-workflow here.\n' \
  >> "$S30_MUT/execute-phase/SKILL.md"
assert "S30: the guard fails when a skill supervises from the phase chat" \
  '[ -n "$(s30_guard "$S30_MUT" "$S24_REFS")" ]'
rm -rf "$S30_MUT"
# The section goes back to claiming a chat cannot rename itself — the stale
# field test that cost the protocol its one manual step.
S30_MUT="$(mktemp -d)"; mkdir -p "$S30_MUT/refs"; cp "$S24_REFS"/*.md "$S30_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed 's/A session cannot read its own id/A session can neither read its own id nor rename itself/' \
  "$S24_REFS/foreman.md" > "$S30_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S30_MUT/refs/phase-execution.md"
cp "$S24_REFS/board.md" "$S30_MUT/refs/board.md"
assert "S30: the guard fails when the section denies the self-rename" \
  '[ -n "$(s30_guard "$S30_MUT" "$S30_MUT/refs")" ]'
rm -rf "$S30_MUT"
# A skill titles its chat without declaring the tool that does it.
S30_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S30_MUT/"
sed -i.bak 's/set_session_title//g' "$S30_MUT/execute-phase/SKILL.md" \
  && rm -f "$S30_MUT/execute-phase/SKILL.md.bak"
assert "S30: the guard fails when a titling skill drops set_session_title" \
  '[ -n "$(s30_guard "$S30_MUT" "$S24_REFS")" ]'
rm -rf "$S30_MUT"

echo "== S31: cross-phase awareness and the reporting register ship and are cited =="
# Two 5.13.0 invariants. (a) Workers treat the whole plan as context, not a
# queue: the shared core carries the plan-is-context paragraph (both execute
# modes load it), and the light contract — which loads no skill — carries its
# own cross-phase clause. (b) Reports to the decision-maker are phrased for
# someone who does not know the implementation: foreman.md owns
# '## The reporting register', the presenting skills cite it, nobody restates
# its rules.
s31_guard() {  # $1 = a skills dir, $2 = a refs dir, $3 = launcher path; prints one line per violation
  S31_C="$2/foreman.md"
  grep -q '^## The reporting register' "$S31_C" 2>/dev/null \
    || echo "$S31_C: missing the '## The reporting register' section"
  grep -q 'stay technical English' "$S31_C" 2>/dev/null \
    || echo "$S31_C: the register section lost the artifacts-stay-technical boundary"
  grep -q 'The plan is context' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: missing the plan-is-context paragraph"
  grep -q 'does not complicate later phases' "$3" 2>/dev/null \
    || echo "$3: the light contract lost its cross-phase clause"
  for S31_S in quality-check finalize-workflow run-workflow; do
    S31_F="$1/$S31_S/SKILL.md"
    grep -qi 'reporting register' "$S31_F" 2>/dev/null \
      || echo "$S31_F: does not cite foreman.md's reporting register"
  done
  # Nobody but foreman.md carries the register's rules.
  for S31_S in write-workflow import-workflow resume-workflow execute-phase \
               execute-phase-agent quality-check finalize-workflow run-workflow; do
    S31_F="$1/$S31_S/SKILL.md"
    if grep -q 'Name things by what they do' "$S31_F" 2>/dev/null; then
      echo "$S31_F: restates the reporting register (single source: foreman.md)"
    fi
  done
  return 0
}
S31_OUT="$(s31_guard "$SKILLS_DIR" "$S24_REFS" "$RUNNER_SRC")"
[ -z "$S31_OUT" ] || echo "  offending: $S31_OUT"
assert "S31: cross-phase awareness and the register are single-source and cited" \
  '[ -z "$S31_OUT" ]'
# Mutations re-run the SAME guard on a copy.
S31_MUT="$(mktemp -d)"; mkdir -p "$S31_MUT/refs"; cp "$S24_REFS"/*.md "$S31_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S31_MUT/"
sed 's/^## The reporting register.*/## How to talk (renamed)/' "$S24_REFS/foreman.md" \
  > "$S31_MUT/refs/foreman.md"
cp "$S24_REFS/phase-execution.md" "$S31_MUT/refs/phase-execution.md"
assert "S31: the guard fails when foreman.md stops owning the register" \
  '[ -n "$(s31_guard "$S31_MUT" "$S31_MUT/refs" "$RUNNER_SRC")" ]'
rm -rf "$S31_MUT"
S31_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S31_MUT/"
sed -i.bak '/[Rr]eporting register/d' "$S31_MUT/run-workflow/SKILL.md" \
  && rm -f "$S31_MUT/run-workflow/SKILL.md.bak"
assert "S31: the guard fails when a presenting skill drops the citation" \
  '[ -n "$(s31_guard "$S31_MUT" "$S24_REFS" "$RUNNER_SRC")" ]'
rm -rf "$S31_MUT"
S31_MUT="$(mktemp -d)"
sed '/does not complicate later phases/d' "$RUNNER_SRC" > "$S31_MUT/run-workflow.sh"
assert "S31: the guard fails when the light contract loses the cross-phase clause" \
  '[ -n "$(s31_guard "$SKILLS_DIR" "$S24_REFS" "$S31_MUT/run-workflow.sh")" ]'
rm -rf "$S31_MUT"
S31_MUT="$(mktemp -d)"; mkdir -p "$S31_MUT/refs"; cp "$S24_REFS"/*.md "$S31_MUT/refs/"
cp "$S24_REFS/foreman.md" "$S31_MUT/refs/foreman.md"
sed '/The plan is context/d' "$S24_REFS/phase-execution.md" \
  > "$S31_MUT/refs/phase-execution.md"
assert "S31: the guard fails when the shared core loses plan-is-context" \
  '[ -n "$(s31_guard "$SKILLS_DIR" "$S31_MUT/refs" "$RUNNER_SRC")" ]'
rm -rf "$S31_MUT"

echo "== S32: the closing report has a shape, a gate, and one detail question =="
# Three 5.14.0 invariants. (a) foreman.md owns the report shape (one verdict
# line + one line per finding) and the per-channel delivery rule — the two
# closing reports are a report page where one can render, the degraded chat
# path gets exactly ONE detail question, one-way surfaces the short form
# only. (b) The report-judge agent ships as a comprehension probe,
# fresh-context by design, with the CANNOT ANSWER convention. (c) The two
# closing-report skills cite the gate — run-workflow with the Agent tool it
# needs — and nobody restates the shape.
S32_AGENTS="$TESTDIR/../../plugins/wf/agents"
s32_guard() {  # $1 = a skills dir, $2 = a refs dir, $3 = an agents dir; prints one line per violation
  S32_C="$2/foreman.md"
  grep -q 'one verdict line' "$S32_C" 2>/dev/null \
    || echo "$S32_C: the register lost the report shape (one verdict line + one line per finding)"
  grep -q 'short form only' "$S32_C" 2>/dev/null \
    || echo "$S32_C: the register lost the one-way-surfaces delivery rule"
  grep -q 'report page' "$S32_C" 2>/dev/null \
    || echo "$S32_C: the register lost the report page (hypertext delivery)"
  grep -q 'display: render' "$S32_C" 2>/dev/null \
    || echo "$S32_C: the page delivery no longer asks for the render explicitly"
  grep -q 'report-judge' "$S32_C" 2>/dev/null \
    || echo "$S32_C: the register lost the report-judge gate"
  S32_A="$3/report-judge.md"
  if [ ! -f "$S32_A" ]; then
    echo "$S32_A: the report-judge agent is missing"
  else
    grep -q 'CANNOT ANSWER' "$S32_A" 2>/dev/null \
      || echo "$S32_A: lost the CANNOT ANSWER convention (the probe must not guess)"
    grep -qi 'fresh context' "$S32_A" 2>/dev/null \
      || echo "$S32_A: lost the fresh-context clause"
  fi
  for S32_S in quality-check run-workflow; do
    S32_F="$1/$S32_S/SKILL.md"
    grep -q 'report-judge' "$S32_F" 2>/dev/null \
      || echo "$S32_F: does not cite the report-judge gate"
  done
  grep -q '^allowed-tools:.*Agent' "$1/run-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/run-workflow/SKILL.md: Agent missing from allowed-tools (the gate cannot run)"
  # Nobody but foreman.md carries the shape rule.
  for S32_S in write-workflow import-workflow resume-workflow execute-phase \
               execute-phase-agent quality-check finalize-workflow run-workflow; do
    S32_F="$1/$S32_S/SKILL.md"
    if grep -q 'one verdict line' "$S32_F" 2>/dev/null; then
      echo "$S32_F: restates the report shape (single source: foreman.md)"
    fi
  done
  return 0
}
S32_OUT="$(s32_guard "$SKILLS_DIR" "$S24_REFS" "$S32_AGENTS")"
[ -z "$S32_OUT" ] || echo "  offending: $S32_OUT"
assert "S32: the report shape, the gate and the question are single-source and cited" \
  '[ -z "$S32_OUT" ]'
# Mutations re-run the SAME guard on a copy.
S32_MUT="$(mktemp -d)"; mkdir -p "$S32_MUT/refs"; cp "$S24_REFS"/*.md "$S32_MUT/refs/"
sed 's/one verdict line/a verdict somewhere/' "$S24_REFS/foreman.md" \
  > "$S32_MUT/refs/foreman.md"
assert "S32: the guard fails when foreman.md loses the report shape" \
  '[ -n "$(s32_guard "$SKILLS_DIR" "$S32_MUT/refs" "$S32_AGENTS")" ]'
rm -rf "$S32_MUT"
S32_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S32_MUT/"
sed -i.bak '/report-judge/d' "$S32_MUT/run-workflow/SKILL.md" \
  && rm -f "$S32_MUT/run-workflow/SKILL.md.bak"
assert "S32: the guard fails when a closing-report skill drops the gate" \
  '[ -n "$(s32_guard "$S32_MUT" "$S24_REFS" "$S32_AGENTS")" ]'
rm -rf "$S32_MUT"
S32_MUT="$(mktemp -d)"
assert "S32: the guard fails when the report-judge agent is missing" \
  '[ -n "$(s32_guard "$SKILLS_DIR" "$S24_REFS" "$S32_MUT")" ]'
rm -rf "$S32_MUT"
S32_MUT="$(mktemp -d)"; mkdir -p "$S32_MUT/refs"; cp "$S24_REFS"/*.md "$S32_MUT/refs/"
sed '/report page/d' "$S24_REFS/foreman.md" > "$S32_MUT/refs/foreman.md"
assert "S32: the guard fails when foreman.md loses the report page" \
  '[ -n "$(s32_guard "$SKILLS_DIR" "$S32_MUT/refs" "$S32_AGENTS")" ]'
rm -rf "$S32_MUT"
# The page lives outside the project folder, where a client left to choose
# attaches it as a download card — the field defect this clause answers.
S32_MUT="$(mktemp -d)"; mkdir -p "$S32_MUT/refs"; cp "$S24_REFS"/*.md "$S32_MUT/refs/"
sed 's/`display: render`/the client default/' "$S24_REFS/foreman.md" \
  > "$S32_MUT/refs/foreman.md"
assert "S32: the guard fails when the page delivery drops the explicit render" \
  '[ -n "$(s32_guard "$SKILLS_DIR" "$S32_MUT/refs" "$S32_AGENTS")" ]'
rm -rf "$S32_MUT"
# A skill restates the shape rule — the copy defect single-source exists for.
S32_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S32_MUT/"
printf '\nThe report is one verdict line plus one line per finding.\n' \
  >> "$S32_MUT/execute-phase/SKILL.md"
assert "S32: the guard fails when a skill restates the report shape" \
  '[ -n "$(s32_guard "$S32_MUT" "$S24_REFS" "$S32_AGENTS")" ]'
rm -rf "$S32_MUT"

echo "== S33: the QA pass is a page and the review depth is the user's call =="
# Two 5.16.0 invariants. (a) contracts.md owns the QA page — the checklist HTML
# the user works through while exercising the result; a work sheet, not a
# closing report, so the report-judge gate does not apply and only contracts.md
# knows its filename. (b) quality-check's pre-commit review asks its depth
# (Extended / Light / None) instead of always paying the extended pass, Light
# is scoped to cross-phase issues only, and the report-judge probe is skipped
# on a clean review — the token cost tracks what a human has already vetted.
s33_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S33_C="$2/contracts.md"
  grep -q 'QA page' "$S33_C" 2>/dev/null \
    || echo "$S33_C: the Verification section lost the QA page"
  grep -q -- '-qa\.html' "$S33_C" 2>/dev/null \
    || echo "$S33_C: the QA page lost its out-of-tree filename"
  grep -q 'work sheet, not a closing report' "$S33_C" 2>/dev/null \
    || echo "$S33_C: the QA page lost the work-sheet clause (report-judge would creep in)"
  S33_F="$1/quality-check/SKILL.md"
  grep -q 'QA page' "$S33_F" 2>/dev/null \
    || echo "$S33_F: Step 2 no longer delivers the QA pass as the QA page"
  grep -qE 'AskUserQuestion.+Extended.+Light.+None' "$S33_F" 2>/dev/null \
    || echo "$S33_F: the review depth question (Extended / Light / None) is gone"
  grep -q 'cross-phase issues only' "$S33_F" 2>/dev/null \
    || echo "$S33_F: Light lost its cross-phase-only scope"
  grep -q 'skip the probe when the review returns no findings' "$S33_F" 2>/dev/null \
    || echo "$S33_F: the zero-findings probe skip is gone"
  # Nobody but contracts.md carries the page filename.
  for S33_S in "$1"/*/SKILL.md; do
    if grep -q -- '-qa\.html' "$S33_S" 2>/dev/null; then
      echo "$S33_S: hardcodes the QA page filename (single source: contracts.md)"
    fi
  done
  return 0
}
S33_OUT="$(s33_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S33_OUT" ] || echo "  offending: $S33_OUT"
assert "S33: the QA page and the depth question are single-source and cited" \
  '[ -z "$S33_OUT" ]'
# Mutations re-run the SAME guard on a copy.
S33_MUT="$(mktemp -d)"; mkdir -p "$S33_MUT/refs"; cp "$S24_REFS"/*.md "$S33_MUT/refs/"
sed '/QA page/d' "$S24_REFS/contracts.md" > "$S33_MUT/refs/contracts.md"
assert "S33: the guard fails when contracts.md loses the QA page" \
  '[ -n "$(s33_guard "$SKILLS_DIR" "$S33_MUT/refs")" ]'
rm -rf "$S33_MUT"
S33_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S33_MUT/"
sed -i.bak 's/Extended\*\* \/ \*\*Light\*\* \/ \*\*None/one depth/' \
  "$S33_MUT/quality-check/SKILL.md" && rm -f "$S33_MUT/quality-check/SKILL.md.bak"
assert "S33: the guard fails when quality-check drops the depth question" \
  '[ -n "$(s33_guard "$S33_MUT" "$S24_REFS")" ]'
rm -rf "$S33_MUT"
S33_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S33_MUT/"
printf '\nWrite the checklist to /tmp/phased-workflow/<slug>-qa.html directly.\n' \
  >> "$S33_MUT/execute-phase/SKILL.md"
assert "S33: the guard fails when a skill hardcodes the QA page filename" \
  '[ -n "$(s33_guard "$S33_MUT" "$S24_REFS")" ]'
rm -rf "$S33_MUT"

echo "== S34: a phase with checks left to the human does not close itself =="
# Interactive mode used to close a phase the moment its tests were green, and
# hand the human's own checks to /finalize-workflow — so a `ui` phase whose
# browser pass could not run closed on a result nobody had looked at. The gate
# is: a `Verify: now` step left to the human keeps the phase [>], its work
# committed, until the human says it passed. The selector is what makes it
# survive a dead chat, so it is tested for real, not only greped.
S34_NP="$TESTDIR/../../plugins/wf/scripts/next-phase.py"
S34_PLAN="$OT/testing-gate-plan.md"
cat > "$S34_PLAN" <<'EOF'
# Context: toy
Parent: develop
Mode: interactive

## Work Plan
- [x] **Phase 1**: model
  > Done: table created
  > Files: pkg/model/foo.py
- [>] **Phase 2**: the wizard
  > In execution since 2026-08-18T10:00:00Z
  > Testing: awaiting the human's `Verify: now` checks | commit: abc1234
  > Verify: now — walk the wizard and compare it with mockups/phase-2.html
- [ ] **Phase 3**: the grid
EOF
S34_OUT="$(python3 "$S34_NP" "$S34_PLAN" 2>&1)"
assert "S34: a [>] phase awaiting checks is reported blocked, not resumable" \
  'printf "%s" "$S34_OUT" | grep -q "recommendation: blocked: phase 2 is complete and awaiting"'
assert "S34: the blocked line names the command that clears it" \
  'printf "%s" "$S34_OUT" | grep -q "close-phase"'
assert "S34: Testing is a known note field (no unknown-field warning)" \
  '! printf "%s" "$S34_OUT" | grep -qi "unknown note field.*Testing"'
# The contrast: the same phase without the note is ordinary unfinished work.
grep -v 'Testing:' "$S34_PLAN" > "$S34_PLAN.nowait"
S34_OUT2="$(python3 "$S34_NP" "$S34_PLAN.nowait" 2>&1)"
assert "S34: without the note the same phase is a resume candidate" \
  'printf "%s" "$S34_OUT2" | grep -q "recommendation: resume-candidate: 2"'
# And the documentation side: one owner for the mechanic, citations elsewhere.
s34_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S34_PE="$2/phase-execution.md"
  grep -q "Awaiting the human's checks" "$S34_PE" 2>/dev/null \
    || echo "$S34_PE: missing the 'Awaiting the human's checks' mechanic"
  grep -q '> Testing:' "$S34_PE" 2>/dev/null \
    || echo "$S34_PE: the mechanic does not define the > Testing: note"
  grep -q 'gates the close in interactive mode' "$2/contracts.md" 2>/dev/null \
    || echo "$2/contracts.md: a Verify: now step no longer gates the close"
  for S34_S in execute-phase close-phase; do
    S34_F="$1/$S34_S/SKILL.md"
    grep -q 'Testing:' "$S34_F" 2>/dev/null \
      || echo "$S34_F: does not handle the phase held open for the human"
  done
  # The format lives in one place: a skill may name the note, never respell it.
  for S34_F in "$1"/*/SKILL.md; do
    if grep -q 'Testing: awaiting' "$S34_F" 2>/dev/null; then
      echo "$S34_F: restates the > Testing: format (single source: phase-execution.md)"
    fi
  done
  # 6.2.1 — the gate's third exit. A person judging the result wrong is not a
  # failed Done:, and marking it [!] aims an automatic repair at green code.
  grep -q 'machine verdict, never a human one' "$2/common.md" 2>/dev/null \
    || echo "$2/common.md: [!] is no longer bounded to a machine verdict"
  grep -q 'Three ways out of the gate' "$S34_PE" 2>/dev/null \
    || echo "$S34_PE: the gate has no exit for a result rejected at the root"
  grep -qi "Never \`\[!\]\` on a person's judgment" "$S34_PE" 2>/dev/null \
    || echo "$S34_PE: the gate does not forbid [!] on a human's judgment"
  # 6.3.0 — the gate is also what holds the report back, and a rejected result
  # travels up as its own line so the foreman knows the plan is about to move.
  grep -q 'Nothing is closed and nobody is told before' "$S34_PE" 2>/dev/null \
    || echo "$S34_PE: the gate no longer holds the [x], the commit and the message"
  grep -q 'result rejected' "$2/common.md" 2>/dev/null \
    || echo "$2/common.md: no message carries a rejected result to the foreman"
  grep -q 'result rejected' "$1/close-phase/SKILL.md" 2>/dev/null \
    || echo "$1/close-phase/SKILL.md: closes a rejected result as an ordinary done"
  grep -q 'Re-planning after a rejected result' "$1/resume-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/resume-workflow/SKILL.md: has no re-planning path for a rejected result"
  return 0
}
S34_G="$(s34_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S34_G" ] || echo "  offending: $S34_G"
assert "S34: the gate is single-source and cited" '[ -z "$S34_G" ]'
S34_MUT="$(mktemp -d)"; mkdir -p "$S34_MUT/refs"; cp "$S24_REFS"/*.md "$S34_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S34_MUT/"
cp "$S24_REFS/common.md" "$S34_MUT/refs/common.md"
sed "s/Awaiting the human's checks/Checkpoints again/" \
  "$S24_REFS/phase-execution.md" > "$S34_MUT/refs/phase-execution.md"
assert "S34: the guard fails when the shared core drops the mechanic" \
  '[ -n "$(s34_guard "$S34_MUT" "$S34_MUT/refs")" ]'
rm -rf "$S34_MUT"
S34_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S34_MUT/"
printf '\n> Testing: awaiting the human checks | commit: <hash>\n' \
  >> "$S34_MUT/close-phase/SKILL.md"
assert "S34: the guard fails when a skill respells the note format" \
  '[ -n "$(s34_guard "$S34_MUT" "$S24_REFS")" ]'
rm -rf "$S34_MUT"
# [!] goes back to meaning whatever a session decides it means.
S34_MUT="$(mktemp -d)"; mkdir -p "$S34_MUT/refs"; cp "$S24_REFS"/*.md "$S34_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S34_MUT/"
cp "$S24_REFS/phase-execution.md" "$S34_MUT/refs/phase-execution.md"
sed 's/machine verdict, never a human one/state/' "$S24_REFS/common.md" \
  > "$S34_MUT/refs/common.md"
assert "S34: the guard fails when [!] stops being a machine verdict" \
  '[ -n "$(s34_guard "$S34_MUT" "$S34_MUT/refs")" ]'
rm -rf "$S34_MUT"
# The gate stops holding the report back — a phase reported done unchecked.
S34_MUT="$(mktemp -d)"; mkdir -p "$S34_MUT/refs"; cp "$S24_REFS"/*.md "$S34_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S34_MUT/"
cp "$S24_REFS/common.md" "$S34_MUT/refs/common.md"
sed 's/Nothing is closed and nobody is told before/Close and report when/' \
  "$S24_REFS/phase-execution.md" > "$S34_MUT/refs/phase-execution.md"
assert "S34: the guard fails when the gate stops holding the report" \
  '[ -n "$(s34_guard "$S34_MUT" "$S34_MUT/refs")" ]'
rm -rf "$S34_MUT"
# The rejection has no line of its own to travel up on.
S34_MUT="$(mktemp -d)"; mkdir -p "$S34_MUT/refs"; cp "$S24_REFS"/*.md "$S34_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S34_MUT/"
cp "$S24_REFS/phase-execution.md" "$S34_MUT/refs/phase-execution.md"
sed 's/result rejected/done/g' "$S24_REFS/common.md" > "$S34_MUT/refs/common.md"
assert "S34: the guard fails when a rejected result travels up as a plain done" \
  '[ -n "$(s34_guard "$S34_MUT" "$S34_MUT/refs")" ]'
rm -rf "$S34_MUT"
# The gate loses the exit for a result the human rejects at the root.
S34_MUT="$(mktemp -d)"; mkdir -p "$S34_MUT/refs"; cp "$S24_REFS"/*.md "$S34_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S34_MUT/"
cp "$S24_REFS/common.md" "$S34_MUT/refs/common.md"
sed 's/Three ways out of the gate/Two ways out/' "$S24_REFS/phase-execution.md" \
  > "$S34_MUT/refs/phase-execution.md"
assert "S34: the guard fails when the gate loses its rejection exit" \
  '[ -n "$(s34_guard "$S34_MUT" "$S34_MUT/refs")" ]'
rm -rf "$S34_MUT"

echo "== S35: the contract is authored once and no child rewrites it =="
# Three 6.8.0 invariants. (a) contracts.md owns the contract-tests contract —
# plan-time tests under .phased at two precisions (executable / skeleton),
# read-only for the child, integrity-checked at close — and owns the
# authored-checks ownership rule (ui Verify: lists pre-established at
# planning, changes routed through the foreman). (b) The shared core carries
# the copy-verbatim mechanic and /execute-phase's gate carries the
# compatibility line, so a conflict with a pending phase surfaces before
# approval. (c) close-phase checks the in-tree copy against the plan copy,
# and an unattended phase closes [!] rather than edit a contract into
# passing.
s35_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S35_C="$2/contracts.md"
  grep -q '^## Contract tests' "$S35_C" 2>/dev/null \
    || echo "$S35_C: missing the '## Contract tests' section"
  grep -q 'read-only for the child' "$S35_C" 2>/dev/null \
    || echo "$S35_C: the contract lost the child's read-only rule"
  grep -q 'foreman-owned' "$S35_C" 2>/dev/null \
    || echo "$S35_C: the authored checks lost their owner"
  grep -q 'tests/phase-N' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: the shared core lost the copy-verbatim mechanic"
  grep -q 'compatibility line' "$1/execute-phase/SKILL.md" 2>/dev/null \
    || echo "$1/execute-phase/SKILL.md: the gate lost its compatibility line"
  grep -q 'Contract tests' "$1/write-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/write-workflow/SKILL.md: planning no longer offers contract tests"
  grep -q 'tests/phase-N' "$1/close-phase/SKILL.md" 2>/dev/null \
    || echo "$1/close-phase/SKILL.md: the close no longer checks test integrity"
  grep -q -- '--contract-block' "$1/close-phase/SKILL.md" 2>/dev/null \
    || echo "$1/close-phase/SKILL.md: the close no longer diffs the contract fields against the plan commit"
  grep -q 'cannot pass as written closes the phase' "$1/execute-phase-agent/SKILL.md" 2>/dev/null \
    || echo "$1/execute-phase-agent/SKILL.md: an unattended phase may edit a contract test into passing"
  return 0
}
S35_OUT="$(s35_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S35_OUT" ] || echo "  offending: $S35_OUT"
assert "S35: the contract fields are single-source, checked at gate and close" \
  '[ -z "$S35_OUT" ]'
# Mutations re-run the SAME guard on a copy.
# contracts.md stops owning the contract-tests section.
S35_MUT="$(mktemp -d)"; mkdir -p "$S35_MUT/refs"; cp "$S24_REFS"/*.md "$S35_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S35_MUT/"
sed 's/^## Contract tests.*/## Tests, roughly/' "$S24_REFS/contracts.md" \
  > "$S35_MUT/refs/contracts.md"
cp "$S24_REFS/phase-execution.md" "$S35_MUT/refs/phase-execution.md"
assert "S35: the guard fails when contracts.md stops owning contract tests" \
  '[ -n "$(s35_guard "$S35_MUT" "$S35_MUT/refs")" ]'
rm -rf "$S35_MUT"
# The child may edit the contract again.
S35_MUT="$(mktemp -d)"; mkdir -p "$S35_MUT/refs"; cp "$S24_REFS"/*.md "$S35_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S35_MUT/"
sed 's/read-only for the child/editable when needed/' "$S24_REFS/contracts.md" \
  > "$S35_MUT/refs/contracts.md"
cp "$S24_REFS/phase-execution.md" "$S35_MUT/refs/phase-execution.md"
assert "S35: the guard fails when the child may edit the contract" \
  '[ -n "$(s35_guard "$S35_MUT" "$S35_MUT/refs")" ]'
rm -rf "$S35_MUT"
# The close stops checking the copies.
S35_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S35_MUT/"
sed -i.bak 's|tests/phase-N|the phase tests|g' "$S35_MUT/close-phase/SKILL.md" \
  && rm -f "$S35_MUT/close-phase/SKILL.md.bak"
assert "S35: the guard fails when the close stops checking integrity" \
  '[ -n "$(s35_guard "$S35_MUT" "$S24_REFS")" ]'
rm -rf "$S35_MUT"
# The close stops diffing the contract FIELDS against the plan commit.
S35_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S35_MUT/"
sed -i.bak 's|--contract-block|--phase-notes|g' "$S35_MUT/close-phase/SKILL.md" \
  && rm -f "$S35_MUT/close-phase/SKILL.md.bak"
assert "S35: the guard fails when the close stops diffing the contract fields" \
  '[ -n "$(s35_guard "$S35_MUT" "$S24_REFS")" ]'
rm -rf "$S35_MUT"
# And the extraction the close relies on is real: --contract-block returns the
# five foreman-owned fields, continuations attached, and neither `>` notes nor
# the other fields — so a deleted Done: shows up as a diff, not as silence.
S35_NP="$TESTDIR/../../plugins/wf/scripts/next-phase.py"
S35_TMP="$(mktemp -d)"
cat > "$S35_TMP/plan.md" <<'S35PLAN'
## Work Plan

- [>] **Phase 1**: toy
  - Details: prose the child may rewrite
  - Done: tests green
    on the touched files
  - Verify: run the narrow test
  - Files: a.py
  > Done: recorded by the child
S35PLAN
S35_CB="$(python3 "$S35_NP" --contract-block 1 "$S35_TMP/plan.md")"
assert "S35: --contract-block carries the fields and their continuations" \
  'printf "%s" "$S35_CB" | grep -q "Done: tests green" &&
   printf "%s" "$S35_CB" | grep -q "on the touched files" &&
   printf "%s" "$S35_CB" | grep -q "Verify: run the narrow test"'
assert "S35: --contract-block excludes notes and non-contract fields" \
  '! printf "%s" "$S35_CB" | grep -q "recorded by the child" &&
   ! printf "%s" "$S35_CB" | grep -q "Details:"'
sed -i.bak '/Done: tests green/,+1d' "$S35_TMP/plan.md" && rm -f "$S35_TMP/plan.md.bak"
assert "S35: a deleted Done: changes the extraction" \
  '[ "$(python3 "$S35_NP" --contract-block 1 "$S35_TMP/plan.md")" != "$S35_CB" ]'
rm -rf "$S35_TMP"
# The gate loses the compatibility line.
S35_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S35_MUT/"
sed -i.bak '/compatibility line/d' "$S35_MUT/execute-phase/SKILL.md" \
  && rm -f "$S35_MUT/execute-phase/SKILL.md.bak"
assert "S35: the guard fails when the gate loses the compatibility line" \
  '[ -n "$(s35_guard "$S35_MUT" "$S24_REFS")" ]'
rm -rf "$S35_MUT"

echo "== S36: the doctor diagnoses blind and never reopens a closed phase =="
# Three 6.9.0 invariants. (a) /doctor ships and is reachable: help and
# resume-workflow both route to it. (b) Its retro-fit authors the tests
# BLIND — from the plan's promises, never from the code, whose deviations a
# sighted author would ratify — while the verifier that fills skeleton
# bodies is the only one allowed to see the code. (c) It diagnoses only:
# read-only on source, findings reported and persisted to notes.md, a red
# retro-test on a [x] phase never reopens it (result-rejected family, never
# [!]).
s36_guard() {  # $1 = a skills dir; prints one line per violation
  S36_D="$1/doctor/SKILL.md"
  [ -f "$S36_D" ] || { echo "$S36_D: the doctor skill is missing"; return 0; }
  grep -q 'ratifies the code' "$S36_D" 2>/dev/null \
    || echo "$S36_D: the retro-fit lost its blindness rationale"
  grep -q 'Read-only on source code' "$S36_D" 2>/dev/null \
    || echo "$S36_D: the doctor may edit source"
  grep -q 'never reopened' "$S36_D" 2>/dev/null \
    || echo "$S36_D: a red retro-test may reopen a closed phase"
  grep -q 'Contract tests' "$S36_D" 2>/dev/null \
    || echo "$S36_D: does not cite common.md's contract-tests contract"
  grep -q '/wf:doctor' "$1/help/SKILL.md" 2>/dev/null \
    || echo "$1/help/SKILL.md: the map lost /wf:doctor"
  grep -q '/doctor' "$1/resume-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/resume-workflow/SKILL.md: the map lost /doctor"
  return 0
}
S36_OUT="$(s36_guard "$SKILLS_DIR")"
[ -z "$S36_OUT" ] || echo "  offending: $S36_OUT"
assert "S36: the doctor ships blind, read-only, and routed from the maps" \
  '[ -z "$S36_OUT" ]'
# Mutations re-run the SAME guard on a copy.
# The author agent goes sighted.
S36_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S36_MUT/"
sed -i.bak '/ratifies the code/d' "$S36_MUT/doctor/SKILL.md" \
  && rm -f "$S36_MUT/doctor/SKILL.md.bak"
assert "S36: the guard fails when the author agent goes sighted" \
  '[ -n "$(s36_guard "$S36_MUT")" ]'
rm -rf "$S36_MUT"
# The doctor starts fixing what it finds.
S36_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S36_MUT/"
sed -i.bak 's/Read-only on source code/Fix what you find/' "$S36_MUT/doctor/SKILL.md" \
  && rm -f "$S36_MUT/doctor/SKILL.md.bak"
assert "S36: the guard fails when the doctor may fix source" \
  '[ -n "$(s36_guard "$S36_MUT")" ]'
rm -rf "$S36_MUT"
# The maps stop routing to it.
S36_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S36_MUT/"
sed -i.bak '/wf:doctor/d' "$S36_MUT/help/SKILL.md" \
  && rm -f "$S36_MUT/help/SKILL.md.bak"
assert "S36: the guard fails when help stops routing to the doctor" \
  '[ -n "$(s36_guard "$S36_MUT")" ]'
rm -rf "$S36_MUT"

echo "== S37: a future consumer's contract travels backwards =="
# Three 6.10.0 invariants (issue #15). (a) contracts.md owns 'Must not break:' —
# the plan header field carrying contracts owned by later macro-phases — and
# write-workflow asks the consumer question that fills it. (b) The gate's
# compatibility line and the shared core treat those lines and the roadmap's
# remaining macros as premises of pending-phase rank. (c) quality-check runs the
# roadmap check at macro close, and the doctor can turn a consumer measured
# late into skeletons run against what an earlier macro built.
s37_guard() {  # $1 = a skills dir, $2 = a refs dir, $3 = launcher path; prints one line per violation
  grep -q '^## Must not break:' "$2/contracts.md" 2>/dev/null \
    || echo "$2/contracts.md: missing the 'Must not break:' section"
  grep -q 'Must not break' "$3" 2>/dev/null \
    || echo "$3: the light contract no longer carries the programme contract"
  grep -q 'Must not break' "$1/run-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/run-workflow/SKILL.md: the inspector coherence look no longer reads the programme contract"
  grep -q 'consumer question' "$1/write-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/write-workflow/SKILL.md: planning lost the consumer question"
  grep -q 'who consumes it' "$2/write-workflow-autonomous.md" 2>/dev/null \
    || echo "$2/write-workflow-autonomous.md: the roadmap bullet lost its consumers"
  grep -q 'Must not break:' "$1/execute-phase/SKILL.md" 2>/dev/null \
    || echo "$1/execute-phase/SKILL.md: the compatibility line no longer reads the programme contract"
  grep -q 'Must not break:' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: plan-is-context no longer ranks the programme contract"
  grep -q 'roadmap check' "$1/quality-check/SKILL.md" 2>/dev/null \
    || echo "$1/quality-check/SKILL.md: the macro close lost the roadmap check"
  grep -q 'measured late' "$1/doctor/SKILL.md" 2>/dev/null \
    || echo "$1/doctor/SKILL.md: the doctor lost the late-consumer road"
  return 0
}
S37_OUT="$(s37_guard "$SKILLS_DIR" "$S24_REFS" "$RUNNER_SRC")"
[ -z "$S37_OUT" ] || echo "  offending: $S37_OUT"
assert "S37: the programme contract is single-source and read at gate, close and doctor" \
  '[ -z "$S37_OUT" ]'
# Mutations re-run the SAME guard on a copy.
# contracts.md stops owning the field.
S37_MUT="$(mktemp -d)"; mkdir -p "$S37_MUT/refs"; cp "$S24_REFS"/*.md "$S37_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S37_MUT/"
sed 's/^## Must not break:.*/## Nice to keep/' "$S24_REFS/contracts.md" \
  > "$S37_MUT/refs/contracts.md"
cp "$S24_REFS/phase-execution.md" "$S37_MUT/refs/phase-execution.md"
cp "$S24_REFS/write-workflow-autonomous.md" "$S37_MUT/refs/write-workflow-autonomous.md"
assert "S37: the guard fails when contracts.md stops owning the field" \
  '[ -n "$(s37_guard "$S37_MUT" "$S37_MUT/refs" "$RUNNER_SRC")" ]'
rm -rf "$S37_MUT"
# Planning stops asking who consumes the work.
S37_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S37_MUT/"
sed -i.bak '/consumer question/d' "$S37_MUT/write-workflow/SKILL.md" \
  && rm -f "$S37_MUT/write-workflow/SKILL.md.bak"
assert "S37: the guard fails when planning drops the consumer question" \
  '[ -n "$(s37_guard "$S37_MUT" "$S24_REFS" "$RUNNER_SRC")" ]'
rm -rf "$S37_MUT"
# The macro closes without looking at the roadmap.
S37_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S37_MUT/"
sed -i.bak '/roadmap check/d' "$S37_MUT/quality-check/SKILL.md" \
  && rm -f "$S37_MUT/quality-check/SKILL.md.bak"
assert "S37: the guard fails when the macro close skips the roadmap" \
  '[ -n "$(s37_guard "$S37_MUT" "$S24_REFS" "$RUNNER_SRC")" ]'
rm -rf "$S37_MUT"
# The light contract sheds the programme contract.
S37_MUT="$(mktemp -d)"
sed 's/Must not break/nice to keep/g' "$RUNNER_SRC" > "$S37_MUT/run-workflow.sh"
assert "S37: the guard fails when the light contract sheds the programme contract" \
  '[ -n "$(s37_guard "$SKILLS_DIR" "$S24_REFS" "$S37_MUT/run-workflow.sh")" ]'
rm -rf "$S37_MUT"

echo "== S38: the split is scoped, judged, and lands at the right border =="
# Three 6.11.0 invariants. (a) Every macro of a split gets a mini-scope at
# split time — the only moment the whole programme is in one context — with
# the itinerary fields (Starts from:/Ends at:) and the contract halves
# (Delivers / Requires of earlier work). (b) A fresh-context coherence judge
# checks the itinerary and the contract graph before the split is presented.
# (c) Downstream, the consumer question reads the later macros' Requires
# lines instead of memory, and quality-check compares the delivered state with
# the macro's declared Ends at:.
s38_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S38_A="$2/write-workflow-autonomous.md"
  grep -q 'mini-scope' "$S38_A" 2>/dev/null \
    || echo "$S38_A: the split lost its per-macro mini-scope"
  grep -q 'Ends at:' "$S38_A" 2>/dev/null \
    || echo "$S38_A: the mini-scope lost the itinerary fields"
  grep -q 'coherence judge' "$S38_A" 2>/dev/null \
    || echo "$S38_A: the split lost the fresh-eyes judge"
  grep -q 'in transit' "$S38_A" 2>/dev/null \
    || echo "$S38_A: the judge reads the graph as a chain (transit rule gone)"
  grep -q 'in transit' "$2/contracts.md" 2>/dev/null \
    || echo "$2/contracts.md: the contract lost its producer-to-consumer transit rule"
  grep -q 'Requires of earlier work' "$1/write-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/write-workflow/SKILL.md: the consumer question no longer reads the roadmap's Requires"
  grep -q 'in transit' "$1/write-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/write-workflow/SKILL.md: a macro no longer inherits the contracts crossing it"
  grep -q 'Ends at:' "$1/quality-check/SKILL.md" 2>/dev/null \
    || echo "$1/quality-check/SKILL.md: the macro close no longer checks the delivered border"
  grep -q 'in transit' "$1/quality-check/SKILL.md" 2>/dev/null \
    || echo "$1/quality-check/SKILL.md: the macro close no longer checks the luggage in transit"
  return 0
}
S38_OUT="$(s38_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S38_OUT" ] || echo "  offending: $S38_OUT"
assert "S38: the mini-scope, the judge and the border checks all ship" \
  '[ -z "$S38_OUT" ]'
# Mutations re-run the SAME guard on a copy.
# The itinerary fields disappear from the mini-scope.
S38_MUT="$(mktemp -d)"; mkdir -p "$S38_MUT/refs"; cp "$S24_REFS"/*.md "$S38_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S38_MUT/"
sed '/Ends at:/d' "$S24_REFS/write-workflow-autonomous.md" \
  > "$S38_MUT/refs/write-workflow-autonomous.md"
cp "$S24_REFS/contracts.md" "$S38_MUT/refs/contracts.md"
assert "S38: the guard fails when the itinerary fields disappear" \
  '[ -n "$(s38_guard "$S38_MUT" "$S38_MUT/refs")" ]'
rm -rf "$S38_MUT"
# The split goes unjudged.
S38_MUT="$(mktemp -d)"; mkdir -p "$S38_MUT/refs"; cp "$S24_REFS"/*.md "$S38_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S38_MUT/"
sed 's/coherence judge/vibe check/g' "$S24_REFS/write-workflow-autonomous.md" \
  > "$S38_MUT/refs/write-workflow-autonomous.md"
cp "$S24_REFS/contracts.md" "$S38_MUT/refs/contracts.md"
assert "S38: the guard fails when the split goes unjudged" \
  '[ -n "$(s38_guard "$S38_MUT" "$S38_MUT/refs")" ]'
rm -rf "$S38_MUT"
# The graph collapses back into a chain — the transit rule disappears.
S38_MUT="$(mktemp -d)"; mkdir -p "$S38_MUT/refs"; cp "$S24_REFS"/*.md "$S38_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S38_MUT/"
cp "$S24_REFS/write-workflow-autonomous.md" "$S38_MUT/refs/write-workflow-autonomous.md"
sed 's/in transit/nearby/g' "$S24_REFS/contracts.md" > "$S38_MUT/refs/contracts.md"
assert "S38: the guard fails when the transit rule disappears" \
  '[ -n "$(s38_guard "$S38_MUT" "$S38_MUT/refs")" ]'
rm -rf "$S38_MUT"
# The macro closes without looking at its own border.
S38_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S38_MUT/"
sed -i.bak '/Ends at:/d' "$S38_MUT/quality-check/SKILL.md" \
  && rm -f "$S38_MUT/quality-check/SKILL.md.bak"
assert "S38: the guard fails when the close skips the delivered border" \
  '[ -n "$(s38_guard "$S38_MUT" "$S24_REFS")" ]'
rm -rf "$S38_MUT"

echo "== S39: sessions are not phases — a WIP resume does not starve the tail =="
# The loop budget used to be the initial [ ] count, but a phase that dies
# leaving [>] consumes TWO sessions for one decrement: with the old bound the
# last phase never ran and the run ended silently with work pending. The bound
# is now twice the pending count, and exhausting it says so out loud.
setup S39; fixture2
printf '%s\n' 'python3 "$OPS" wip1; exit 0' 'python3 "$OPS" resume1; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S39: WIP resume announced" 'grep -q "Phase left in WIP state" out.log'
assert "S39: 3 sessions for 2 phases" '[ "$(grep -c "CALL:" .claude/invocations.log)" = 3 ]'
assert "S39: both phases [x] — the tail phase still ran" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'
assert "S39: no exhaustion message on a completed run" '! grep -q "Session budget exhausted" out.log'
# Perpetual WIP: every session leaves [>] alive, no deliberate stop ever fires —
# the bound is the only thing that ends the run, and it must say so.
setup S39_exhaust; fixture2
printf '%s\n' 'python3 "$OPS" wip1; exit 0' 'python3 "$OPS" noop; exit 0' 'python3 "$OPS" noop; exit 0' 'python3 "$OPS" noop; exit 0' > .claude/mock-queue
finish_setup; run
assert "S39: bound stops a perpetual-WIP run" '[ "$(grep -c "CALL:" .claude/invocations.log)" = 4 ]'
assert "S39: exhaustion is declared, not silent" 'grep -q "Session budget exhausted" out.log'
assert "S39: exhausted run still ends stopped, not ok" 'grep -q "EVENT: run-end stopped" out.log'

echo "== S40: messaging floors live once, and the channel is declared, not discovered =="
# The messaging layer rides the most unstable platform surface the plugin
# touches (three version floors grew up scattered). foreman.md owns the
# floors; the state-reporting skills declare which channel branch is alive
# instead of letting a dead one surface as a silent skip.
s40_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  grep -q 'Channel floors' "$2/foreman.md" 2>/dev/null \
    || echo "$2/foreman.md: missing the 'Channel floors' single source"
  grep -q '2\.1\.224' "$2/foreman.md" 2>/dev/null \
    || echo "$2/foreman.md: the SendMessage floor left its single source"
  grep -rq '2\.1\.224' "$1" 2>/dev/null \
    && echo "$1: a skill restates the SendMessage floor (single source: foreman.md)"
  grep -q 'Channel floors' "$1/resume-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/resume-workflow/SKILL.md: the report does not declare the live channel"
  grep -q 'Channel floors' "$1/run-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/run-workflow/SKILL.md: the relay does not declare its channel up front"
  return 0
}
S40_OUT="$(s40_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S40_OUT" ] || echo "  offending: $S40_OUT"
assert "S40: floors single-source and the channel declared" '[ -z "$S40_OUT" ]'
# Mutations re-run the SAME guard on a copy.
S40_MUT="$(mktemp -d)"; mkdir -p "$S40_MUT/refs"; cp "$S24_REFS"/*.md "$S40_MUT/refs/"
cp -R "$SKILLS_DIR"/. "$S40_MUT/"
sed 's/Channel floors/Version notes/g' "$S24_REFS/foreman.md" > "$S40_MUT/refs/foreman.md"
assert "S40: the guard fails when foreman.md stops owning the floors" \
  '[ -n "$(s40_guard "$SKILLS_DIR" "$S40_MUT/refs")" ]'
rm -rf "$S40_MUT"
S40_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S40_MUT/"
printf '\nCLI SendMessage needs >= 2.1.224.\n' >> "$S40_MUT/execute-phase/SKILL.md"
assert "S40: the guard fails when a skill restates a floor" \
  '[ -n "$(s40_guard "$S40_MUT" "$S24_REFS")" ]'
rm -rf "$S40_MUT"
S40_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S40_MUT/"
sed -i.bak '/Channel floors/d' "$S40_MUT/resume-workflow/SKILL.md" \
  && rm -f "$S40_MUT/resume-workflow/SKILL.md.bak"
assert "S40: the guard fails when the report stops declaring the channel" \
  '[ -n "$(s40_guard "$S40_MUT" "$S24_REFS")" ]'
rm -rf "$S40_MUT"

echo "== S42: the version the README announces is the version that ships =="
# plugin.json is bumped per release, CHANGELOG gets its entry — and the
# README's own "**Version X**" line silently stayed at 6.12.0 for four
# releases: the one surface a visitor reads first was the one nothing
# checked. The three must agree.
S42_V=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' \
  "$TESTDIR/../../plugins/wf/.claude-plugin/plugin.json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
assert "S42: README announces the shipped version ($S42_V)" \
  'grep -q "\*\*Version $S42_V\*\*" "$TESTDIR/../../README.md"'
assert "S42: CHANGELOG opens with the shipped version" \
  '[ "$(grep -m1 -o "^## [0-9.]*" "$TESTDIR/../../CHANGELOG.md")" = "## $S42_V" ]'
# The marketplace manifest is a SECOND copy of the version (metadata + the
# plugin entry) — it sat at 6.12.0 for four releases while plugin.json moved.
assert "S42: marketplace.json carries the shipped version everywhere" \
  '[ "$(grep -c "\"version\": \"$S42_V\"" "$TESTDIR/../../.claude-plugin/marketplace.json")" = "$(grep -c "\"version\":" "$TESTDIR/../../.claude-plugin/marketplace.json")" ]'
# Two more README claims nothing watched: the changelog table is a WINDOW on
# CHANGELOG.md and had lost 6.24.0 inside the range it covers, and the
# "N assertions over M scenarios" line is a claim about this very file that was
# measured once and left to rot — a stale copy of it cost the wfdash graft
# eight defects, its plan trusting the README over run_tests.sh.
S42_OUT="$(python3 "$TESTDIR/check_readme_continuity.py" "$TESTDIR/../..")"
[ -z "$S42_OUT" ] || echo "  offending: $S42_OUT"
assert "S42: the README's changelog table and suite numbers hold" '[ -z "$S42_OUT" ]'
# Mutations, on a copy carrying only what the guard reads.
S42_MUT="$(mktemp -d)"; mkdir -p "$S42_MUT/tests/orchestration"
cp "$TESTDIR/../../CHANGELOG.md" "$S42_MUT/"
cp "$TESTDIR/run_tests.sh" "$S42_MUT/tests/orchestration/"
S42_GAP=$(grep -o '^| [0-9][0-9.]* |' "$TESTDIR/../../README.md" | sed -n 2p | tr -d '| ')
grep -v "^| $S42_GAP |" "$TESTDIR/../../README.md" > "$S42_MUT/README.md"
assert "S42: the guard fails when the changelog table skips a version" \
  '[ -n "$(python3 "$TESTDIR/check_readme_continuity.py" "$S42_MUT")" ]'
sed 's/\*\*[0-9]* assertions over/**999 assertions over/' \
  "$TESTDIR/../../README.md" > "$S42_MUT/README.md"
assert "S42: the guard fails when the README's assertion count drifts" \
  '[ -n "$(python3 "$TESTDIR/check_readme_continuity.py" "$S42_MUT")" ]'
rm -rf "$S42_MUT"

echo "== S41: the doctrine mass is measured, and growth pays its budget =="
# check_doc_mass.py: a skill's closure (SKILL.md + every ref it cites) is the
# doctrine a session ingests before working; the 6.14.0 split exists because
# that mass had outgrown what a session reliably follows. The ceiling turns
# the instruction-mass arms race into a number a merge has to look at.
S41_OUT="$(python3 "$TESTDIR/check_doc_mass.py" "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S41_OUT" ] || echo "  offending: $S41_OUT"
assert "S41: every skill closure fits the doc-mass budget" '[ -z "$S41_OUT" ]'
# Mutations. A ref bloats past the budget for its consumers.
S41_MUT="$(mktemp -d)"; mkdir -p "$S41_MUT/refs"; cp "$S24_REFS"/*.md "$S41_MUT/refs/"
python3 - "$S41_MUT/refs/contracts.md" <<'EOF'
import sys
with open(sys.argv[1], 'a') as f:
    f.write("padding line\n" * 1200)
EOF
assert "S41: the guard fails when a ref bloats past the budget" \
  '[ -n "$(python3 "$TESTDIR/check_doc_mass.py" "$SKILLS_DIR" "$S41_MUT/refs")" ]'
rm -rf "$S41_MUT"
# A skill cites a ref that does not ship.
S41_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S41_MUT/"
printf '\nSee ${CLAUDE_PLUGIN_ROOT}/refs/ghost-layer.md for details.\n' \
  >> "$S41_MUT/execute-phase/SKILL.md"
assert "S41: the guard fails on a citation of a ref that does not ship" \
  '[ -n "$(python3 "$TESTDIR/check_doc_mass.py" "$S41_MUT" "$S24_REFS")" ]'
rm -rf "$S41_MUT"

echo "== S43: plan-defect claim — the foreman consult gate before repair =="
# Live: a [!] whose > Issue: leads with "plan-defect claim" makes the launcher
# emit phase-needs-foreman and HOLD the repair, polling the answer file outside
# the repo. stop → no repair, foreman-stop; repair → fresh-eyes session. The
# hold has NO default deadline (6.31.0: the field's one TRUE claim was handed
# to a repair by the 600s window while the user slept, and the repair bent the
# code to the wrong test) — RUN_WORKFLOW_CONSULT_TIMEOUT is the explicit
# opt-in, and a stop request during the hold ends the run with the phase
# still [!]. An ordinary [!] never touches the gate.
# (a) explicit timeout → declared, falls through to repair
setup S43a; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" repair_ok_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
RUN_WORKFLOW_CONSULT_TIMEOUT=1 PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
assert "S43: the claim emits 'EVENT: phase-needs-foreman 1'" 'grep -q "^EVENT: phase-needs-foreman 1$" out.log'
assert "S43: the timeout is declared and falls through to repair" 'grep -q "No foreman answer within 1s" out.log && grep -q "Repair succeeded" out.log'
assert "S43: the run completed after the timed-out consult" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'
# (b) foreman answers stop → no repair, phase kept [!], answer file consumed
setup S43b; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
rm -f "$WF_T-foreman-answer"
( for _ in $(seq 1 150); do grep -q "phase-needs-foreman" out.log 2>/dev/null && { echo stop > "$WF_T-foreman-answer"; break; }; sleep 0.2; done ) &
S43_W=$!
RUN_WORKFLOW_CONSULT_TIMEOUT=30 PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
wait "$S43_W" 2>/dev/null
assert "S43: the foreman's stop is honoured" 'grep -q "Foreman answered: stop" out.log'
assert "S43: no repair launched on a foreman stop" '! grep -q "repair-phase-agent skill" .claude/invocations.log'
assert "S43: the phase stays [!] for the foreman" 'grep -q "^- \[!\] \*\*Phase 1\*\*" .phased/active/toy/plan.md'
assert "S43: the answer file was consumed" '[ ! -f "$WF_T-foreman-answer" ]'
# (c) foreman answers repair → fresh-eyes session runs, no timeout wait
setup S43c; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" repair_ok_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
rm -f "$WF_T-foreman-answer"
( for _ in $(seq 1 150); do grep -q "phase-needs-foreman" out.log 2>/dev/null && { echo repair > "$WF_T-foreman-answer"; break; }; sleep 0.2; done ) &
S43_W=$!
RUN_WORKFLOW_CONSULT_TIMEOUT=30 PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
wait "$S43_W" 2>/dev/null
assert "S43: the foreman's repair answer is honoured" 'grep -q "Foreman answered: repair" out.log'
assert "S43: repair ran and the run completed" 'grep -q "Repair succeeded" out.log && [ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'
# (d) an ordinary [!] (no claim) never opens the gate
setup S43d; fixture2
printf '%s\n' 'python3 "$OPS" fail1; exit 0' 'python3 "$OPS" repair_ok; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
RUN_WORKFLOW_CONSULT_TIMEOUT=1 PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
assert "S43: an ordinary [!] skips the gate entirely" '! grep -q "phase-needs-foreman" out.log'
# (e) no timeout set → the launcher holds; an answer arriving well past the old
# window is honoured, and nothing ever "timed out"
setup S43e; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" repair_ok_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
rm -f "$WF_T-foreman-answer"
( for _ in $(seq 1 150); do grep -q "phase-needs-foreman" out.log 2>/dev/null && { sleep 3; echo repair > "$WF_T-foreman-answer"; break; }; sleep 0.2; done ) &
S43_W=$!
run
wait "$S43_W" 2>/dev/null
assert "S43: with no timeout the hold is declared open-ended" 'grep -q "holding for the foreman'"'"'s answer" out.log && ! grep -q "waiting up to" out.log'
assert "S43: the late answer is honoured, nothing timed out" 'grep -q "Foreman answered: repair" out.log && ! grep -q "No foreman answer within" out.log'
assert "S43: the run completed after the open-ended hold" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'
# (f) a stop request during the hold ends the run cleanly: no repair, the
# phase stays [!] for the foreman, both control files consumed
setup S43f; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
rm -f "$WF_T-foreman-answer" "$WF_T-stop-request"
( for _ in $(seq 1 150); do grep -q "phase-needs-foreman" out.log 2>/dev/null && { echo stop > "$WF_T-stop-request"; break; }; sleep 0.2; done ) &
S43_W=$!
run
wait "$S43_W" 2>/dev/null
assert "S43: a stop request during the hold ends the run" 'grep -q "Stop requested" out.log && grep -q "^EVENT: run-end stopped-by-request " out.log'
assert "S43: no repair launched on a stop request" '! grep -q "repair-phase-agent skill" .claude/invocations.log'
assert "S43: the phase stays [!] and the stop file was consumed" 'grep -q "^- \[!\] \*\*Phase 1\*\*" .phased/active/toy/plan.md && [ ! -f "$WF_T-stop-request" ]'
# (g) the reply line itself is an answer: the foreman writes `plan-defect: repair`
# (the wording foreman.md gives the reply path) and the launcher reads the verb
setup S43g; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" repair_ok_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
rm -f "$WF_T-foreman-answer"
( for _ in $(seq 1 150); do grep -q "phase-needs-foreman" out.log 2>/dev/null && { echo "plan-defect: repair" > "$WF_T-foreman-answer"; break; }; sleep 0.2; done ) &
S43_W=$!
run
wait "$S43_W" 2>/dev/null
assert "S43: the reply-path spelling is read as the verb" 'grep -q "Foreman answered: repair" out.log && ! grep -q "not understood" out.log'
# (h) an answer the launcher does not understand is reported for what it is —
# not a timeout — and the hold goes on until a real one arrives (6.31.1: the
# field foreman's `plan-defect: apply` fell through as "No foreman answer
# within 600s" and a fable repair was spent on a phase already being applied)
setup S43h; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" repair_ok_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
rm -f "$WF_T-foreman-answer"
( for _ in $(seq 1 150); do grep -q "phase-needs-foreman" out.log 2>/dev/null && { echo maybe > "$WF_T-foreman-answer"; break; }; sleep 0.2; done
  for _ in $(seq 1 150); do grep -q "not understood" out.log 2>/dev/null && [ ! -f "$WF_T-foreman-answer" ] && { echo repair > "$WF_T-foreman-answer"; break; }; sleep 0.2; done ) &
S43_W=$!
run
wait "$S43_W" 2>/dev/null
assert "S43: an unknown answer is reported by name, never as a timeout" 'grep -q "Foreman answer not understood: '"'"'maybe'"'"'" out.log && ! grep -q "No foreman answer within" out.log'
assert "S43: the hold survives the unknown answer and honours the next one" 'grep -q "Foreman answered: repair" out.log && [ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'
# Static half: the claim token is single-source in contracts.md and spoken by
# every consumer — the launcher's gate grep, the child that writes it, the
# repair that tests it, the foreman section that judges it.
s43_guard() {  # $1 = refs dir, $2 = skills dir, $3 = launcher; one line per gap
  grep -q 'plan-defect claim' "$1/contracts.md" 2>/dev/null || echo "contracts.md: claim token missing"
  grep -q 'Plan-defect claims' "$1/foreman.md" 2>/dev/null || echo "foreman.md: claims section missing"
  grep -qi 'plan-defect claim' "$3" 2>/dev/null || echo "launcher: gate grep missing"
  grep -q 'plan-defect claim' "$2/execute-phase-agent/SKILL.md" 2>/dev/null || echo "execute-phase-agent: claim token missing"
  grep -q 'plan-defect claim' "$2/repair-phase/SKILL.md" 2>/dev/null || echo "repair-phase: claim token missing"
  # 6.31.0: the hold is open-ended, and every consumer says so — a numeric
  # default creeping back into the launcher is the regression this guards.
  grep -qE 'CONSULT_TIMEOUT:-[0-9]' "$3" 2>/dev/null && echo "launcher: the consult carries a default deadline"
  grep -q 'holds until answered' "$1/foreman.md" 2>/dev/null || echo "foreman.md: the hold is not declared open-ended"
  grep -q 'holds until answered' "$2/run-workflow/SKILL.md" 2>/dev/null || echo "run-workflow: the hold is not declared open-ended"
  grep -q 'cost bound' "$2/repair-phase/SKILL.md" 2>/dev/null || echo "repair-phase: no cost bound on satisfying the contract"
  # 6.31.1: both spellings of the answer are read, and an unknown one is named.
  grep -q "sed 's/^plan-defect://'" "$3" 2>/dev/null || echo "launcher: the reply-path spelling of the answer is not read"
  grep -q 'not understood' "$3" 2>/dev/null || echo "launcher: an unknown answer is not reported by name"
}
S43_OUT="$(s43_guard "$S24_REFS" "$SKILLS_DIR" "$RUNNER_SRC")"
[ -z "$S43_OUT" ] || echo "  offending: $S43_OUT"
assert "S43: the claim token is single-source and spoken by every consumer" '[ -z "$S43_OUT" ]'
# Mutation: dropping the token from contracts.md must bite.
S43_MUT="$(mktemp -d)"
cp -R "$S24_REFS"/. "$S43_MUT/"
sed -i.bak 's/plan-defect claim/gone/g' "$S43_MUT/contracts.md" && rm -f "$S43_MUT/contracts.md.bak"
assert "S43: the guard fails when contracts.md loses the claim token" \
  '[ -n "$(s43_guard "$S43_MUT" "$SKILLS_DIR" "$RUNNER_SRC")" ]'
rm -rf "$S43_MUT"
# Mutation: the launcher regaining a default deadline must bite.
S43_MUT="$(mktemp -d)"
sed 's/RUN_WORKFLOW_CONSULT_TIMEOUT:-}/RUN_WORKFLOW_CONSULT_TIMEOUT:-600}/' "$RUNNER_SRC" > "$S43_MUT/runner.sh"
assert "S43: the guard fails when the launcher regains a default deadline" \
  '[ -n "$(s43_guard "$S24_REFS" "$SKILLS_DIR" "$S43_MUT/runner.sh")" ]'
rm -rf "$S43_MUT"

echo "== S44: the quality-check stamp is single-source and gates finalize =="
# 6.18.0 split /finalize-workflow: the quality work (QA pass, naming review,
# scope coherence, pre-commit review) moved to /quality-check, which stamps
# the plan; finalize gates on the stamp and asks before closing without one.
# Static guard: contracts.md owns the stamp format, quality-check writes it,
# finalize greps for it and keeps the missing-stamp question; the launcher's
# closing pointer names quality-check so autonomous runs land on the new path.
s44_guard() {  # $1 = skills dir, $2 = refs dir, $3 = launcher; one line per gap
  grep -q 'The quality-check stamp' "$2/contracts.md" 2>/dev/null \
    || echo "contracts.md: the stamp section is gone"
  grep -q '> Quality check:' "$2/contracts.md" 2>/dev/null \
    || echo "contracts.md: the stamp format line is gone"
  grep -q '> Quality check:' "$1/quality-check/SKILL.md" 2>/dev/null \
    || echo "quality-check: no longer writes the stamp"
  grep -q '> Quality check:' "$1/finalize-workflow/SKILL.md" 2>/dev/null \
    || echo "finalize-workflow: no longer gates on the stamp"
  grep -q 'Run `/quality-check` first' "$1/finalize-workflow/SKILL.md" 2>/dev/null \
    || echo "finalize-workflow: lost the missing-stamp question"
  grep -q 'quality-check' "$3" 2>/dev/null \
    || echo "launcher: the closing pointer no longer names quality-check"
  # 6.32.0: the QA fix is the foreman's second exception to "commands, does not
  # execute", and every consumer names it — the ref, the skill that performs
  # it, the lessons pass that reads it, the launcher's closing pointer.
  grep -q 'QA fix' "$2/foreman.md" 2>/dev/null \
    || echo "foreman.md: the QA-fix exception is gone"
  grep -q '^\*\*QA fixes\.\*\*' "$1/quality-check/SKILL.md" 2>/dev/null \
    || echo "quality-check: the QA fixes paragraph is gone"
  grep -q 'QA fixes' "$1/finalize-workflow/SKILL.md" 2>/dev/null \
    || echo "finalize-workflow: the lessons pass no longer reads QA fixes"
  grep -q 'QA fix' "$1/run-workflow/SKILL.md" 2>/dev/null \
    || echo "run-workflow: the closing pointer no longer names the QA fix"
}
S44_OUT="$(s44_guard "$SKILLS_DIR" "$S24_REFS" "$RUNNER_SRC")"
[ -z "$S44_OUT" ] || echo "  offending: $S44_OUT"
assert "S44: the stamp is single-source, written and gated on" '[ -z "$S44_OUT" ]'
# Mutation: finalize losing the gate must bite.
S44_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S44_MUT/"
sed -i.bak '/> Quality check:/d' "$S44_MUT/finalize-workflow/SKILL.md" \
  && rm -f "$S44_MUT/finalize-workflow/SKILL.md.bak"
assert "S44: the guard fails when finalize stops gating on the stamp" \
  '[ -n "$(s44_guard "$S44_MUT" "$S24_REFS" "$RUNNER_SRC")" ]'
rm -rf "$S44_MUT"
# Mutation: quality-check losing the QA fixes paragraph must bite.
S44_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S44_MUT/"
sed -i.bak '/^\*\*QA fixes\.\*\*/d' "$S44_MUT/quality-check/SKILL.md" \
  && rm -f "$S44_MUT/quality-check/SKILL.md.bak"
assert "S44: the guard fails when quality-check loses the QA fixes paragraph" \
  '[ -n "$(s44_guard "$S44_MUT" "$S24_REFS" "$RUNNER_SRC")" ]'
rm -rf "$S44_MUT"

echo "== S45: minimality covers surface AND prose, named once, checked everywhere =="
# 6.19.0: the minimality contract names the over-engineering idioms (accessors
# for public attributes, delegate-only wrappers, narrating comments, docstrings
# restating the signature) so no check re-derives them. contracts.md owns the
# list; the phase verifier hunts it (surface JUDGMENT, prose MECHANICAL), the
# launcher steer prevents it on every unattended session, and the naming
# review's Necessity column cites the named anti-patterns.
s45_guard() {  # $1 = refs dir, $2 = agents dir, $3 = launcher; one line per gap
  grep -q 'surface and prose alike' "$1/contracts.md" 2>/dev/null \
    || echo "contracts.md: minimality no longer covers prose"
  grep -q 'attributes the language already exposes' "$1/contracts.md" 2>/dev/null \
    || echo "contracts.md: the accessor anti-pattern is gone"
  grep -q 'narrate the line below' "$1/contracts.md" 2>/dev/null \
    || echo "contracts.md: the narrating-comment anti-pattern is gone"
  grep -q 'already exposes as public' "$2/phase-verifier.md" 2>/dev/null \
    || echo "phase-verifier: no longer hunts the accessor anti-pattern"
  grep -q 'comment density' "$2/phase-verifier.md" 2>/dev/null \
    || echo "phase-verifier: prose findings lost the repo-density measure"
  grep -q 'no accessor methods for attributes the language already exposes' "$3" 2>/dev/null \
    || echo "launcher: the steer lost the minimal-code line"
  grep -q 'already exposes as public' "$1/naming-review.md" 2>/dev/null \
    || echo "naming-review.md: the Necessity column lost the named anti-patterns"
}
S45_AGENTS="$TESTDIR/../../plugins/wf/agents"
S45_OUT="$(s45_guard "$S24_REFS" "$S45_AGENTS" "$RUNNER_SRC")"
[ -z "$S45_OUT" ] || echo "  offending: $S45_OUT"
assert "S45: the verbosity anti-patterns are single-source and checked everywhere" '[ -z "$S45_OUT" ]'
# Mutation: contracts.md losing the prose half must bite.
S45_MUT="$(mktemp -d)"; mkdir -p "$S45_MUT/refs"; cp "$S24_REFS"/*.md "$S45_MUT/refs/"
sed 's/surface and prose alike/callables only/' "$S24_REFS/contracts.md" \
  > "$S45_MUT/refs/contracts.md"
assert "S45: the guard fails when minimality stops covering prose" \
  '[ -n "$(s45_guard "$S45_MUT/refs" "$S45_AGENTS" "$RUNNER_SRC")" ]'
rm -rf "$S45_MUT"

echo "== S46: a killed unattended run names itself at resume =="
# 6.20.0: a host-app restart killed launcher, Monitor and phase session in one
# blow (sql-recipe-pipeline); the EVENT log outside the repo was the only
# surviving channel, and /resume-workflow's report never said a run had been
# in flight. Static guard: run-workflow tees to the shared log path, and
# resume-workflow checks that same path, names the mid-flight death, and
# offers the reset + relaunch as one option.
s46_guard() {  # $1 = skills dir; one line per gap
  grep -q -- '-run\.log' "$1/run-workflow/SKILL.md" 2>/dev/null \
    || echo "run-workflow: the log left the shared path"
  grep -q -- '-run\.log' "$1/resume-workflow/SKILL.md" 2>/dev/null \
    || echo "resume-workflow: no longer checks the run log path"
  grep -q 'unattended run was in flight' "$1/resume-workflow/SKILL.md" 2>/dev/null \
    || echo "resume-workflow: the mid-flight death is not named"
  grep -q 'reset + relaunch' "$1/resume-workflow/SKILL.md" 2>/dev/null \
    || echo "resume-workflow: the reset + relaunch path is not offered"
  return 0
}
S46_OUT="$(s46_guard "$SKILLS_DIR")"
[ -z "$S46_OUT" ] || echo "  offending: $S46_OUT"
assert "S46: the run log is checked, the death named, the relaunch offered" '[ -z "$S46_OUT" ]'
# Mutation: resume-workflow losing the run-log check must bite.
S46_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S46_MUT/"
sed -i.bak 's|-run\.log|-gone|g' "$S46_MUT/resume-workflow/SKILL.md" \
  && rm -f "$S46_MUT/resume-workflow/SKILL.md.bak"
assert "S46: the guard fails when resume-workflow stops checking the log" \
  '[ -n "$(s46_guard "$S46_MUT")" ]'
rm -rf "$S46_MUT"

echo "== S47: negative assertions are swept against the other phases' law =="
# 6.21.0 (sql-recipe-pipeline): a plan-time contract test banned a substring
# that another phase's golden file and a third's round-trip made mandatory —
# a defect present since planning, surfaced mid-run as a consult at the price
# of a failed session. Static guard: the autonomous planning ref runs the
# sweep after contract-test authoring, and the run inspector re-reads the
# pending phases' contract tests when a phase closes on a bent decision.
s47_guard() {  # $1 = refs dir, $2 = skills dir; one line per gap
  grep -q 'negative assertion' "$1/write-workflow-autonomous.md" 2>/dev/null \
    || echo "write-workflow-autonomous: the negative-assertion sweep is gone"
  grep -q 'every OTHER phase' "$1/write-workflow-autonomous.md" 2>/dev/null \
    || echo "write-workflow-autonomous: the sweep no longer crosses phases"
  grep -q 'negative assertion' "$2/run-workflow/SKILL.md" 2>/dev/null \
    || echo "run-workflow: the inspector no longer re-reads negative assertions"
  grep -q 'bent decision' "$2/run-workflow/SKILL.md" 2>/dev/null \
    || echo "run-workflow: the bent-decision trigger is gone"
}
S47_OUT="$(s47_guard "$S24_REFS" "$SKILLS_DIR")"
[ -z "$S47_OUT" ] || echo "  offending: $S47_OUT"
assert "S47: the sweep is planned and the inspector re-checks on a bend" '[ -z "$S47_OUT" ]'
# Mutation: the planning ref losing the sweep must bite.
S47_MUT="$(mktemp -d)"; mkdir -p "$S47_MUT/refs"; cp "$S24_REFS"/*.md "$S47_MUT/refs/"
sed -i.bak 's/negative assertion/gone/g' "$S47_MUT/refs/write-workflow-autonomous.md" \
  && rm -f "$S47_MUT/refs/write-workflow-autonomous.md.bak"
assert "S47: the guard fails when the sweep leaves the planning ref" \
  '[ -n "$(s47_guard "$S47_MUT/refs" "$SKILLS_DIR")" ]'
rm -rf "$S47_MUT"

echo "== S48: graceful stop — finish the phase in flight, then stop =="
# 6.22.0: with credits counted, "close the current phase and do not launch the
# next" had no channel — the field workaround was an external kill on the
# closing EVENT, racing the next launch. The launcher now checks a stop-request
# file between sessions (same transport as the consult answer) and honours
# RUN_WORKFLOW_MAX_PHASES=N as an upfront bound.
# (a) request armed mid-run (by the first phase's own session here) → the
# launched phase completes, the next never starts, the file is consumed
setup S48a; fixture2
rm -f "$WF_T-stop-request"
printf '%s\n' "python3 \"\$OPS\" complete; echo stop > '$WF_T-stop-request'; exit 0" 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S48: the stop request is honoured between sessions" 'grep -q "Stop requested" out.log'
assert "S48: the phase in flight completed, the next never launched" \
  '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 1 ] && [ "$(grep -c -- "-p /goal" .claude/invocations.log)" = 1 ]'
assert "S48: run-end says stopped-by-request 1/2" 'grep -q "^EVENT: run-end stopped-by-request 1/2$" out.log'
assert "S48: the stop request was consumed" '[ ! -f "$WF_T-stop-request" ]'
# (b) a stale request from an earlier run is removed at start, declared, and
# does not stop the fresh run
setup S48b; fixture2
echo stop > "$WF_T-stop-request"
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S48: a stale request is removed at start, declared" 'grep -q "stale stop request" out.log'
assert "S48: the fresh run completes despite the stale file" 'grep -q "^EVENT: run-end ok 2/2$" out.log'
# (c) RUN_WORKFLOW_MAX_PHASES=1 → one phase lands, the run stops naming the bound
setup S48c; fixture2
printf '%s\n' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
RUN_WORKFLOW_MAX_PHASES=1 PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
assert "S48: the phase budget stop names the bound" 'grep -q "Phase budget reached: 1 done as requested (RUN_WORKFLOW_MAX_PHASES=1)" out.log'
assert "S48: one phase landed, one stayed pending" \
  '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 1 ] && grep -q "^EVENT: run-end stopped-by-request 1/2$" out.log'
# (d) a budget larger than the work never fires — the run ends ok
setup S48d; fixture2
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
RUN_WORKFLOW_MAX_PHASES=5 PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
assert "S48: an unspent budget leaves the run an ordinary completion" \
  '! grep -q "Phase budget reached" out.log && grep -q "^EVENT: run-end ok 2/2$" out.log'
# (e) a non-numeric budget is ignored, declared
setup S48e; fixture2
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
RUN_WORKFLOW_MAX_PHASES=soon PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
assert "S48: a non-numeric budget is ignored, declared" \
  'grep -q "not a positive number" out.log && grep -q "^EVENT: run-end ok 2/2$" out.log'
# Static half: the channel and the bound are documented where the inspector
# reads them, and present in the launcher.
s48_guard() {  # $1 = skills dir, $2 = launcher; one line per gap
  grep -q 'stop-request' "$2" 2>/dev/null || echo "launcher: the stop-request channel is gone"
  grep -q 'RUN_WORKFLOW_MAX_PHASES' "$2" 2>/dev/null || echo "launcher: the phase budget is gone"
  grep -q -- '-stop-request' "$1/run-workflow/SKILL.md" 2>/dev/null \
    || echo "run-workflow: the stop channel is undocumented"
  grep -q 'RUN_WORKFLOW_MAX_PHASES' "$1/run-workflow/SKILL.md" 2>/dev/null \
    || echo "run-workflow: the phase budget is undocumented"
}
S48_OUT="$(s48_guard "$SKILLS_DIR" "$RUNNER_SRC")"
[ -z "$S48_OUT" ] || echo "  offending: $S48_OUT"
assert "S48: stop channel and phase budget shipped and documented" '[ -z "$S48_OUT" ]'
# Mutation: the skill losing the stop channel must bite.
S48_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S48_MUT/"
sed -i.bak 's|-stop-request|-gone|g' "$S48_MUT/run-workflow/SKILL.md" \
  && rm -f "$S48_MUT/run-workflow/SKILL.md.bak"
assert "S48: the guard fails when the skill loses the stop channel" \
  '[ -n "$(s48_guard "$S48_MUT" "$RUNNER_SRC")" ]'
rm -rf "$S48_MUT"

echo "== S49: plan-defect apply — the foreman's edit lands without a repair =="
# 6.23.0: when the claim carries its own before→after edit, a repair session
# is disproportionate spend and a stop kills the rest of the run. Third verb:
# apply — the launcher keeps holding on a second file while the inspector
# applies the edit, re-runs the Done and reports; green → the phase is
# already [x] on disk and the run continues, anything else → the repair
# judges the claim as usual.
# (a) apply → green: no repair, the run continues to completion
setup S49a; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
rm -f "$WF_T-foreman-answer" "$WF_T-apply-outcome"
( for _ in $(seq 1 150); do
    if grep -q "phase-needs-foreman" out.log 2>/dev/null; then
      echo apply > "$WF_T-foreman-answer"
      MEM=.phased/active/toy/plan.md python3 "$OPS" apply_ok
      echo green > "$WF_T-apply-outcome"
      break
    fi; sleep 0.2; done ) &
S49_W=$!
RUN_WORKFLOW_CONSULT_TIMEOUT=30 RUN_WORKFLOW_APPLY_TIMEOUT=30 PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
wait "$S49_W" 2>/dev/null
assert "S49: the apply answer is honoured and the hold declared" 'grep -q "Foreman answered: apply" out.log'
assert "S49: green lands the phase without a repair" \
  'grep -q "Apply landed green" out.log && ! grep -q "repair-phase-agent skill" .claude/invocations.log'
assert "S49: the applied phase carries the Applied note and the run completed" \
  'grep -q "> Applied:" .phased/active/toy/plan.md && grep -q "^EVENT: run-end ok 2/2$" out.log'
assert "S49: the applied phase still emits phase-done" 'grep -q "^EVENT: phase-done 1 1/2$" out.log'
assert "S49: the outcome file was consumed" '[ ! -f "$WF_T-apply-outcome" ]'
# The launcher itself created (or tightened) the transport dir on the consult
# path: owner-only whatever the umask — the directory is what protects the
# answer and outcome files inside it.
assert "S49: the launcher leaves the transport directory 0700" \
  '[ "$(python3 -c "import os,stat,sys;print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode)))" "$(dirname "$WF_T-foreman-answer")")" = "0o700" ]'
# (b) apply → red: the applier stood down, the repair judges the claim
setup S49b; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" repair_ok_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
rm -f "$WF_T-foreman-answer" "$WF_T-apply-outcome"
( for _ in $(seq 1 150); do
    if grep -q "phase-needs-foreman" out.log 2>/dev/null; then
      echo apply > "$WF_T-foreman-answer"
      echo red > "$WF_T-apply-outcome"
      break
    fi; sleep 0.2; done ) &
S49_W=$!
RUN_WORKFLOW_CONSULT_TIMEOUT=30 RUN_WORKFLOW_APPLY_TIMEOUT=30 PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
wait "$S49_W" 2>/dev/null
assert "S49: a red outcome falls through to the repair" \
  'grep -q "Apply outcome: red — proceeding to repair" out.log && grep -q "Repair succeeded" out.log'
assert "S49: the run completed after the red apply" '[ "$(grep -c "^- \[x\]" .phased/active/toy/plan.md)" = 2 ]'
# (c) apply → no outcome in the window: declared, the repair proceeds
setup S49c; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" repair_ok_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
rm -f "$WF_T-foreman-answer" "$WF_T-apply-outcome"
( for _ in $(seq 1 150); do
    if grep -q "phase-needs-foreman" out.log 2>/dev/null; then
      echo apply > "$WF_T-foreman-answer"
      break
    fi; sleep 0.2; done ) &
S49_W=$!
RUN_WORKFLOW_CONSULT_TIMEOUT=30 RUN_WORKFLOW_APPLY_TIMEOUT=1 PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
wait "$S49_W" 2>/dev/null
assert "S49: the apply window is declared when it closes empty" \
  'grep -q "No apply outcome within 1s" out.log && grep -q "Repair succeeded" out.log'
# (d) green claimed but the plan still shows [!]: declared, the repair judges
setup S49d; fixture2
printf '%s\n' 'python3 "$OPS" fail_claim; exit 0' 'python3 "$OPS" repair_ok_claim; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
rm -f "$WF_T-foreman-answer" "$WF_T-apply-outcome"
( for _ in $(seq 1 150); do
    if grep -q "phase-needs-foreman" out.log 2>/dev/null; then
      echo apply > "$WF_T-foreman-answer"
      echo green > "$WF_T-apply-outcome"
      break
    fi; sleep 0.2; done ) &
S49_W=$!
RUN_WORKFLOW_CONSULT_TIMEOUT=30 RUN_WORKFLOW_APPLY_TIMEOUT=30 PATH="$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
wait "$S49_W" 2>/dev/null
assert "S49: a green that left the [!] standing is not believed" \
  'grep -q "Apply reported green but the plan still shows" out.log && grep -q "Repair succeeded" out.log'
# Static half: the apply road is owned by foreman.md, spoken by the inspector,
# licensed by the claim's before→after form in contracts.md, and present in
# the launcher.
s49_guard() {  # $1 = refs dir, $2 = skills dir, $3 = launcher; one line per gap
  grep -q 'plan-defect: apply' "$1/foreman.md" 2>/dev/null \
    || echo "foreman.md: the apply road is gone"
  grep -q 'apply-outcome' "$1/foreman.md" 2>/dev/null \
    || echo "foreman.md: the outcome file is gone"
  grep -q 'needs, as before-text' "$1/contracts.md" 2>/dev/null \
    || echo "contracts.md: the claim no longer demands the before→after form"
  grep -q 'plan-defect: apply' "$2/run-workflow/SKILL.md" 2>/dev/null \
    || echo "run-workflow: the inspector no longer speaks the apply verb"
  grep -q 'apply-outcome' "$2/run-workflow/SKILL.md" 2>/dev/null \
    || echo "run-workflow: the outcome file is undocumented"
  grep -q 'RUN_WORKFLOW_APPLY_TIMEOUT' "$3" 2>/dev/null \
    || echo "launcher: the apply window is gone"
  grep -q 'apply-outcome' "$3" 2>/dev/null \
    || echo "launcher: the outcome file left the gate"
}
S49_OUT="$(s49_guard "$S24_REFS" "$SKILLS_DIR" "$RUNNER_SRC")"
[ -z "$S49_OUT" ] || echo "  offending: $S49_OUT"
assert "S49: the apply road is owned, spoken, licensed and shipped" '[ -z "$S49_OUT" ]'
# Mutation: foreman.md losing the apply road must bite.
S49_MUT="$(mktemp -d)"
cp -R "$S24_REFS"/. "$S49_MUT/"
sed -i.bak 's/plan-defect: apply/gone/g' "$S49_MUT/foreman.md" && rm -f "$S49_MUT/foreman.md.bak"
assert "S49: the guard fails when foreman.md loses the apply road" \
  '[ -n "$(s49_guard "$S49_MUT" "$SKILLS_DIR" "$RUNNER_SRC")" ]'
rm -rf "$S49_MUT"

echo "== S50: every cited agent name carries the plugin: namespace =="
# S26's rule, one surface over: an agent spawned by NAME resolves the same way a
# slash command does. A bare `phase-verifier` is not an error the session
# reports — it either finds an un-namespaced copy under ~/.claude/agents/ (which
# install.sh exists to supersede, and which shadowed a stale verifier for real)
# or nothing, and the skill then falls through to its declared general-purpose
# fallback, losing the shipped prompt in silence. Both outcomes look like a
# working spawn in the log. The names come from what the plugin actually ships,
# never a retyped list; only BACKTICKED citations count — `the report-judge
# gate` names a mechanism, `\`wf:report-judge\`` names an id.
S50_AGENTS="$TESTDIR/../../plugins/wf/agents"
s50_guard() {  # $1 = agents dir, $2 = skills dir, $3 = refs dir; one line per gap
  for S50_A in "$1"/*.md; do
    [ -f "$S50_A" ] || continue
    S50_N=$(basename "$S50_A" .md)
    grep -rn -- "\`$S50_N\`" "$2" "$3" 2>/dev/null \
      | while IFS= read -r S50_HIT; do
          case "$S50_HIT" in
            *"\`wf:$S50_N\`"*) ;;
            *) echo "${S50_HIT%%:*}: cites \`$S50_N\` un-namespaced — needs \`wf:$S50_N\`" ;;
          esac
        done
  done
}
S50_OUT="$(s50_guard "$S50_AGENTS" "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S50_OUT" ] || echo "  offending: $S50_OUT"
assert "S50: every backticked agent citation is namespaced" '[ -z "$S50_OUT" ]'
assert "S50: the guard actually saw the shipped agents" \
  '[ "$(ls "$S50_AGENTS"/*.md 2>/dev/null | wc -l | tr -d " ")" -ge 3 ]'
assert "S50: the guard actually saw the spawn sites" \
  '[ -n "$(grep -rl -- "\`wf:phase-verifier\`" "$SKILLS_DIR" 2>/dev/null)" ]'
# Mutation: the same guard on a copy where one spawn site drops its namespace.
S50_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S50_MUT/"
sed -i.bak 's/`wf:phase-verifier`/`phase-verifier`/' \
  "$S50_MUT/execute-phase-agent/SKILL.md" && rm -f "$S50_MUT/execute-phase-agent/SKILL.md.bak"
grep -q -- '`phase-verifier`' "$S50_MUT/execute-phase-agent/SKILL.md" \
  || echo "  S50 mutation did not apply — the spawn-site shape changed"
assert "S50: the guard fails when a spawn site loses its namespace" \
  '[ -n "$(s50_guard "$S50_AGENTS" "$S50_MUT" "$S24_REFS")" ]'
rm -rf "$S50_MUT"

echo "== S51: the wfdash tests run in the harness, and the surface stays optional =="
# The dashboard's own tests are bare-assert python scripts; they live in
# tests/wfdash/ and until now nothing ran them. Wired in here they execute
# under both bash and zsh with everything else, and CI needs no new step.
# They are cwd-independent (each resolves the plugin through __file__), so the
# scenario does not setup/cd like the launcher ones.
S51_TESTS="$TESTDIR/../wfdash"
S51_N=0
for S51_T in "$S51_TESTS"/test_*.py; do
  [ -f "$S51_T" ] || continue
  S51_N=$((S51_N+1))
  assert "S51: $(basename "$S51_T" .py)" 'python3 "$S51_T" >/dev/null 2>&1'
done
assert "S51: the scenario actually saw the wfdash tests" '[ "$S51_N" -ge 12 ]'
# Static half, S21 idiom: the surface cannot become mandatory. The guard lives
# in check_optional_surface.py so the mutations below re-run the REAL check.
OPT_GUARD="$TESTDIR/check_optional_surface.py"
OPT_OUT="$(python3 "$OPT_GUARD" "$SKILLS_DIR" "$S24_REFS")"
[ -z "$OPT_OUT" ] || echo "  offending: $OPT_OUT"
assert "S51: every dashboard mention states or cites its fallback, and none is a step" \
  '[ -z "$OPT_OUT" ]'
assert "S51: the guard actually saw the dashboard mentions" \
  '[ -n "$(grep -l "The dashboard, where it exists" "$S24_REFS"/*.md 2>/dev/null)" ]'
# Mutation 1: the fallback clause deleted from the section that owns it.
S51_MUT="$(mktemp -d)"
cp -R "$S24_REFS"/. "$S51_MUT/"
python3 - "$S51_MUT/board.md" <<'S51PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index('- **The fallback is declared, never silent.**')
j = s.index('- **It proposes, the chat acts.**')
open(p, 'w').write(s[:i] + s[j:])
S51PY
assert "S51: the guard fails when the fallback clause is deleted" \
  '! python3 "$OPT_GUARD" "$S51_MUT" >/dev/null 2>&1'
rm -rf "$S51_MUT"
# Mutation 2: a skill that turns the surface into a step.
S51_MUT2="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S51_MUT2/"
printf '\nOpen the dashboard, then continue with the next phase.\n' \
  >> "$S51_MUT2/resume-workflow/SKILL.md"
assert "S51: the guard fails when a skill makes the dashboard a step" \
  '! python3 "$OPT_GUARD" "$S51_MUT2" >/dev/null 2>&1'
rm -rf "$S51_MUT2"

echo "== S52: the addendum's own plan template passes the launcher's pre-flight =="
# The template in refs/write-workflow-autonomous.md shows the execution config
# table; --validate matches ^Phase \d+$ on the Phase cell. The two were changed
# independently and drifted: the template's final row read
# "| Phase N+1 (review) |", so a plan written exactly to the template was
# rejected by the gate /run-workflow runs before spending a session. This
# renders the template applying ONLY the substitutions an author must make
# anyway — the N+1 placeholder becomes a real number, the "..." cells real
# values, the "[... more phases ...]" marker goes — so a structural defect in
# the template survives them and lands on the validator.
S52_NP="$TESTDIR/../../plugins/wf/scripts/next-phase.py"
s52_render() {  # $1 = refs dir, $2 = plan file to write
  python3 - "$1/write-workflow-autonomous.md" "$2" <<'S52PY'
import sys
src, out = sys.argv[1], sys.argv[2]
text = open(src).read()
block = text[text.index('## Plan format'):].split('```')[1]
plan = '\n'.join(ln for ln in block.splitlines()
                 if '[... more phases ...]' not in ln)
plan = plan.replace('N+1', '2')
plan = plan.replace('| Phase 1 | ... | ... |', '| Phase 1 | medium | opus |')
open(out, 'w').write(plan + '\n')
S52PY
}
S52_TMP="$(mktemp -d)"
s52_render "$S24_REFS" "$S52_TMP/plan.md"
S52_OUT="$(python3 "$S52_NP" --validate "$S52_TMP/plan.md" 2>&1)"
S52_RC=$?
[ "$S52_RC" = 0 ] || echo "  offending: $S52_OUT"
assert "S52: the rendered template reaches the validator as a two-phase plan" \
  '[ "$(grep -c "^- \[ \] \*\*Phase" "$S52_TMP/plan.md")" = 2 ]'
assert "S52: a plan written to the template passes the gate" '[ "$S52_RC" = 0 ]'
assert "S52: and passes it with zero errors, not on warnings alone" \
  'printf "%s" "$S52_OUT" | grep -q "validate: 0 error"'
# The close's contract-field extraction must see the template's own spelling:
# the autonomous template writes `Pattern reference:` where the interactive one
# writes `Pattern:`, and an extractor matching only the short form silently
# dropped the field from the very plans the launcher runs (reproduced).
S52_CB="$(python3 "$S52_NP" --contract-block 1 "$S52_TMP/plan.md")"
assert "S52: --contract-block sees the template's 'Pattern reference:' field" \
  'printf "%s" "$S52_CB" | grep -q "Pattern reference:"'
assert "S52: and the other contract fields of the rendered template" \
  'printf "%s" "$S52_CB" | grep -q "Done:" && printf "%s" "$S52_CB" | grep -q "Files:"'
rm -rf "$S52_TMP"
# Mutation: the parenthetical back in the Phase cell — the exact drift.
S52_MUT="$(mktemp -d)"; mkdir -p "$S52_MUT/refs"; cp "$S24_REFS"/*.md "$S52_MUT/refs/"
sed -i.bak 's/| Phase N+1 | xhigh | opus |/| Phase N+1 (review) | xhigh | opus |/' \
  "$S52_MUT/refs/write-workflow-autonomous.md" \
  && rm -f "$S52_MUT/refs/write-workflow-autonomous.md.bak"
s52_render "$S52_MUT/refs" "$S52_MUT/plan.md"
assert "S52: the scenario fails when the template's Phase cell carries a parenthetical" \
  '! python3 "$S52_NP" --validate "$S52_MUT/plan.md" >/dev/null 2>&1'
rm -rf "$S52_MUT"

echo "== S53: a plan with contract tests refuses its light phases =="
# The effort level is chosen for the WORK ("mechanical -> low"), and it also
# silently decides which DOCTRINE the phase receives: Effort=low runs in light
# mode, without the read-only contract rule or the plan-defect claim road. The
# wfdash-open-findings run measured it — all three light phases edited their own
# contract test, one deleting `wf:contract:` lines that bound a later phase; the
# two full-mode phases did not touch it. A warning inside a run already
# launched protects nothing, so the pre-flight refuses the combination before
# the first session; RUN_WORKFLOW_ALLOW_LIGHT_CONTRACTS=1 is the explicit,
# deterministic override, and the autonomous planning ref forbids the
# combination at authoring time.

# (a) tests/ present and a low phase in the table → refused, no session spent
setup S53a; fixture3
mkdir -p .phased/active/toy/tests/phase-1
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S53a: the launcher refuses a contract-test plan carrying a light phase" \
  'grep -q "carries contract tests and runs Phase 1 at Effort=low" out.log'
assert "S53a: the refusal names the override" \
  'grep -q "RUN_WORKFLOW_ALLOW_LIGHT_CONTRACTS=1" out.log'
assert "S53a: NO claude session was launched" '[ ! -s .claude/invocations.log ]'

# (a2) same plan, override set → the run proceeds, with the note
setup S53a2; fixture3
mkdir -p .phased/active/toy/tests/phase-1
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup
export RUN_WORKFLOW_ALLOW_LIGHT_CONTRACTS=1; run; unset RUN_WORKFLOW_ALLOW_LIGHT_CONTRACTS
assert "S53a2: the override runs anyway and says so" \
  'grep -q "runs it anyway" out.log'
assert "S53a2: sessions were launched under the override" '[ -s .claude/invocations.log ]'

# (b) same plan, no tests/ directory → no warning (the run is ordinary)
setup S53b; fixture3
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S53b: no contract tests, no warning" '! grep -q "carries contract tests" out.log'

# (c) contract tests but every phase above low → no warning
setup S53c; fixture3
mkdir -p .phased/active/toy/tests/phase-1
sed -i.bak 's/| Phase 1 | low | sonnet |/| Phase 1 | medium | opus |/' .phased/active/toy/plan.md \
  && rm -f .phased/active/toy/plan.md.bak
printf '%s\n' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' 'python3 "$OPS" complete; exit 0' > .claude/mock-queue
finish_setup; run
assert "S53c: contract tests with no light phase raise nothing" \
  '! grep -q "carries contract tests" out.log'

# Static half: the doctrine that owns the rule, and the launcher that speaks it.
s53_guard() {  # $1 = refs dir, $2 = launcher source; one line per gap
  grep -q 'Never `low` on a phase that carries contract tests' \
    "$1/write-workflow-autonomous.md" 2>/dev/null \
    || echo "write-workflow-autonomous: the never-low-with-contract-tests rule is gone"
  grep -q 'carries contract tests' "$2" 2>/dev/null \
    || echo "run-workflow.sh: the pre-flight no longer warns about light phases"
  grep -q 'PLAN_DIR/tests' "$2" 2>/dev/null \
    || echo "run-workflow.sh: the warning no longer looks for the plan's tests/"
}
S53_OUT="$(s53_guard "$S24_REFS" "$RUNNER_SRC")"
[ -z "$S53_OUT" ] || echo "  offending: $S53_OUT"
assert "S53: the rule is owned by the planning ref and spoken by the launcher" \
  '[ -z "$S53_OUT" ]'
# Mutation: the planning ref loses the rule.
S53_MUT="$(mktemp -d)"; mkdir -p "$S53_MUT/refs"; cp "$S24_REFS"/*.md "$S53_MUT/refs/"
sed -i.bak 's/Never `low` on a phase that carries contract tests/Prefer low everywhere/' \
  "$S53_MUT/refs/write-workflow-autonomous.md" \
  && rm -f "$S53_MUT/refs/write-workflow-autonomous.md.bak"
assert "S53: the guard fails when the planning ref drops the rule" \
  '[ -n "$(s53_guard "$S53_MUT/refs" "$RUNNER_SRC")" ]'
rm -rf "$S53_MUT"
# Mutation: the launcher loses the warning.
S53_MUT="$(mktemp -d)"
sed '/carries contract tests/d' "$RUNNER_SRC" > "$S53_MUT/run-workflow.sh"
assert "S53: the guard fails when the launcher drops the warning" \
  '[ -n "$(s53_guard "$S24_REFS" "$S53_MUT/run-workflow.sh")" ]'
rm -rf "$S53_MUT"

echo "== S54: every shell creation of the transport is owner-only =="
# outbox.py creates the transport 0700 and heals it on every append, but the
# SHELL side reaches it first on a run with no dashboard: the launcher's
# consult path and the skill's tee snippet. `mkdir -p` under umask 022 leaves
# 0755 — `install -d -m 700` sets the mode whatever the umask and tightens a
# lax directory an older release left. S49 asserts the live mode; this guard
# pins the idiom so a refactor cannot quietly reintroduce mkdir.
s54_guard() {  # $1 = launcher source, $2 = run-workflow SKILL.md
  grep -q 'install -d -m 700 "\$CONSULT_DIR"' "$1" 2>/dev/null \
    || echo "$1: the consult path no longer creates the transport 0700"
  grep -q 'install -d -m 700' "$2" 2>/dev/null \
    || echo "$2: the tee snippet no longer creates the transport 0700"
  if grep -q 'mkdir -p .*phased-workflow' "$1" "$2" 2>/dev/null; then
    echo "the transport is created with mkdir -p again (umask decides the mode)"
  fi
}
S54_SKILL="$SKILLS_DIR/run-workflow/SKILL.md"
S54_OUT="$(s54_guard "$RUNNER_SRC" "$S54_SKILL")"
[ -z "$S54_OUT" ] || echo "  offending: $S54_OUT"
assert "S54: launcher and skill create the transport with install -d -m 700" \
  '[ -z "$S54_OUT" ]'
# Mutation: the launcher goes back to mkdir -p.
S54_MUT="$(mktemp -d)"
sed 's|install -d -m 700 "\$CONSULT_DIR"|mkdir -p "$CONSULT_DIR"|' "$RUNNER_SRC" \
  > "$S54_MUT/run-workflow.sh"
assert "S54: the guard fails when the launcher reverts to mkdir -p" \
  '[ -n "$(s54_guard "$S54_MUT/run-workflow.sh" "$S54_SKILL")" ]'
# Mutation: the skill snippet goes back to mkdir -p.
sed 's|install -d -m 700|mkdir -p|' "$S54_SKILL" > "$S54_MUT/SKILL.md"
assert "S54: the guard fails when the skill snippet reverts to mkdir -p" \
  '[ -n "$(s54_guard "$RUNNER_SRC" "$S54_MUT/SKILL.md")" ]'
rm -rf "$S54_MUT"

echo "== S55: two checkouts sharing a slug do not share control files =="
# The stop request, the consult answer, the apply outcome and the run log were
# named from the slug alone under one uid directory, so two checkouts carrying
# the same plan — a root and the worktree the launcher itself creates for it,
# or simply two clones — read and CONSUMED each other's signals. Reproduced by
# running two suites at once: S49 went red on both. The prefix now carries a
# repo key, computed once in next-phase.py and used by the launcher and the
# skills alike.
S55_A="$(mktemp -d)/a"; S55_B="$(mktemp -d)/b"
mkdir -p "$S55_A/.phased/active/toy" "$S55_B/.phased/active/toy"
S55_PA="$(python3 "$NEXT_PHASE_SRC" --transport "$S55_A/.phased/active/toy/plan.md")"
S55_PB="$(python3 "$NEXT_PHASE_SRC" --transport "$S55_B/.phased/active/toy/plan.md")"
assert "S55: the same slug in two checkouts yields two prefixes" \
  '[ "$S55_PA" != "$S55_PB" ]'
assert "S55: both prefixes keep the slug readable" \
  'case "$S55_PA" in */toy-*) true;; *) false;; esac'
assert "S55: both live in the same per-uid transport directory" \
  '[ "$(dirname "$S55_PA")" = "$(dirname "$S55_PB")" ]'
# The same plan asked twice answers the same: the prefix is a function of the
# checkout, not of the moment — a launcher and a skill must agree on it.
assert "S55: the prefix is stable across calls" \
  '[ "$(python3 "$NEXT_PHASE_SRC" --transport "$S55_A/.phased/active/toy/plan.md")" = "$S55_PA" ]'
# And the two languages name ONE directory: next-phase.py (the launcher and the
# skills) and wfdash/outbox.py (the dashboard queue) both compute it.
S55_OUTBOX_DIR="$(python3 -c 'import sys;sys.path.insert(0,sys.argv[1]);import outbox;print(outbox.TMP)' \
  "$TESTDIR/../../plugins/wf/scripts/wfdash")"
assert "S55: next-phase.py and outbox.py name the same transport directory" \
  '[ "$(dirname "$S55_PA")" = "$S55_OUTBOX_DIR" ]'
# The launcher speaks the same prefix, not a private copy of the computation.
assert "S55: the launcher asks next-phase.py for the prefix" \
  'grep -q -- "--transport" "$RUNNER_SRC"'
assert "S55: and names its control files from it" \
  'grep -q "STOP_REQUEST=\"\$TRANSPORT-stop-request\"" "$RUNNER_SRC" &&
   grep -q "ANSWER_FILE=\"\$TRANSPORT-foreman-answer\"" "$RUNNER_SRC" &&
   grep -q "APPLY_OUTCOME_FILE=\"\$TRANSPORT-apply-outcome\"" "$RUNNER_SRC"'
rm -rf "$S55_A" "$S55_B"

echo "== S56: the covering decision is channel-independent =="
# Deep point 1 of the phase-sizing change (issue #22). The close gates on a
# covering decision recorded in notes.md; on the relayed channel that decision
# arrives as a foreman message, so today the record and the message land in one
# step. A channel that drops the message must not drop the gate with it — and
# no existing guard would have noticed, because none asserts the gate holds
# where there is no foreman. Two halves: contracts.md owns the rule in words,
# and the gate's own lines must carry no channel condition.
s56_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S56_C="$2/contracts.md"
  grep -q 'record is mandatory on both channels' "$S56_C" 2>/dev/null \
    || echo "$S56_C: the decision record is no longer mandatory on both channels"
  grep -q 'message is mandatory only on' "$S56_C" 2>/dev/null \
    || echo "$S56_C: the message is no longer scoped to the relayed channel"
  grep -q 'No channel waives a contractual gate' "$S56_C" 2>/dev/null \
    || echo "$S56_C: nothing states that a channel cannot waive a gate"
  # The gate itself survives in every skill that runs it. It has three sites,
  # not one: the close, and the audit that re-checks the same divergence.
  [ "$(grep -c 'covering decision' "$1/close-phase/SKILL.md" 2>/dev/null)" -ge 2 ] \
    || echo "$1/close-phase/SKILL.md: the covering-decision gate lost one of its two arms"
  grep -q 'covering decision' "$1/doctor/SKILL.md" 2>/dev/null \
    || echo "$1/doctor/SKILL.md: the audit no longer requires a covering decision"
  grep -q 'covered by a decision' "$S56_C" 2>/dev/null \
    || echo "$S56_C: the contract no longer requires a covering decision"
  # And it is unconditional: a gate line that names a channel is a gate that
  # one channel can skip. This is the mechanical half — deletion is caught
  # above, weakening is caught here.
  for S56_F in "$1/close-phase/SKILL.md" "$1/doctor/SKILL.md"; do
    if grep 'covering decision' "$S56_F" 2>/dev/null \
        | grep -qE 'relayed|foreman\.json|Channel:'; then
      echo "$S56_F: the covering-decision gate is conditional on the channel"
    fi
  done
  # The silent-skip clause is scoped to the MESSAGE, never to the record.
  grep -q 'the record is written either way' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: the silent notify skip is not scoped to the message"
  # No routing instruction may name the relay without naming its road: an
  # unqualified "goes to the foreman" is a relay the in-chat channel cannot
  # escape, which is how the branch stays half-built while every test passes.
  grep -q '^## Routing a decision' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: the routing fork has no single source"
  # Swept everywhere the fork has to hold, not only where it was first written.
  # The two sections that OWN the fork are exempt — they are what the others
  # cite — and nothing else may name the relay without naming its road.
  for S56_ROUTE in "$1/execute-phase/SKILL.md" "$1/import-workflow/SKILL.md" \
                   "$1/resume-workflow/SKILL.md" "$2/phase-execution.md" \
                   "$2/contracts.md"; do
    case "$S56_ROUTE" in
      *execute-phase*|*import-workflow*|*resume-workflow*)
        grep -q 'Routing a decision\|relayed road\|Channel: relayed' "$S56_ROUTE" 2>/dev/null \
          || echo "$S56_ROUTE: names no road at all — the fork does not reach it" ;;
    esac
    while IFS= read -r S56_L; do
      [ -n "$S56_L" ] || continue
      echo "$S56_ROUTE: unconditional relay — \"$(echo "$S56_L" | cut -c1-60)…\""
    done <<EOF
$(awk '/^## /{sec=$0} sec !~ /Routing a decision|Notify the foreman/' "$S56_ROUTE" 2>/dev/null \
  | grep -E 'clarify\?|to the foreman|the foreman chat is told|write .foreman\.json.|Read .*foreman\.json' \
  | grep -vE 'in-chat|relayed|legacy|Routing a decision')
EOF
  done
  # Nobody anywhere licenses a close without one.
  for S56_F in "$1"/*/SKILL.md "$2"/*.md; do
    if grep -qEi 'without a covering decision|covering decision is (only|not) (required|needed)|skip the covering decision' \
        "$S56_F" 2>/dev/null; then
      echo "$S56_F: licenses a close with no covering decision"
    fi
  done
  return 0
}
S56_OUT="$(s56_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S56_OUT" ] || echo "  offending: $S56_OUT"
assert "S56: the covering-decision gate holds on both channels" '[ -z "$S56_OUT" ]'
# Mutation A — the gate is deleted from the skill that runs it.
S56_MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$S56_MUT/"
sed -i.bak '/covering decision/d' "$S56_MUT/close-phase/SKILL.md" \
  && rm -f "$S56_MUT/close-phase/SKILL.md.bak"
assert "S56: the guard fails when the close drops the covering-decision gate" \
  '[ -n "$(s56_guard "$S56_MUT" "$S24_REFS")" ]'
rm -rf "$S56_MUT"
# Mutation B — the gate survives but only on the relayed channel: the exact
# defect the message/record split invites.
S56_MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$S56_MUT/"
sed -i.bak 's/A diff with no covering decision/On Channel: relayed, a diff with no covering decision/' \
  "$S56_MUT/close-phase/SKILL.md" && rm -f "$S56_MUT/close-phase/SKILL.md.bak"
assert "S56: the guard fails when the gate becomes channel-conditional" \
  '[ -n "$(s56_guard "$S56_MUT" "$S24_REFS")" ]'
rm -rf "$S56_MUT"
# Mutation C — a routing rule loses its channel qualifier: the half-built
# in-chat branch, which every other test in the suite would pass.
S56_MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$S56_MUT/"
sed -i.bak 's/routed before the gate per \*Routing a decision\*/sent up as `clarify?` before the gate/' \
  "$S56_MUT/execute-phase/SKILL.md" && rm -f "$S56_MUT/execute-phase/SKILL.md.bak"
assert "S56: the guard fails when a routing rule keeps an unconditional relay" \
  '[ -n "$(s56_guard "$S56_MUT" "$S24_REFS")" ]'
rm -rf "$S56_MUT"
# Mutation D — the audit stops asking for one, while the close still does:
# the gate half nobody would notice missing.
S56_MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$S56_MUT/"
sed -i.bak 's/A divergence with no covering decision/A divergence/' \
  "$S56_MUT/doctor/SKILL.md" && rm -f "$S56_MUT/doctor/SKILL.md.bak"
assert "S56: the guard fails when the audit drops its arm of the gate" \
  '[ -n "$(s56_guard "$S56_MUT" "$S24_REFS")" ]'
rm -rf "$S56_MUT"
# Mutation E — contracts.md stops owning the rule.
S56_MUT="$(mktemp -d)"; mkdir -p "$S56_MUT/refs"; cp "$S24_REFS"/*.md "$S56_MUT/refs/"
sed -i.bak '/record is mandatory on both channels/d' "$S56_MUT/refs/contracts.md" \
  && rm -f "$S56_MUT/refs/contracts.md.bak"
assert "S56: the guard fails when contracts.md stops owning the rule" \
  '[ -n "$(s56_guard "$SKILLS_DIR" "$S56_MUT/refs")" ]'
rm -rf "$S56_MUT"

echo "== S57: authored-check ownership survives the channel =="
# Deep point 2. Authored checks are owned by the plan's author and are never
# the executing phase's to edit; the relayed channel expresses that ownership
# as "foreman-owned". Read carelessly, "no foreman on the in-chat channel"
# becomes "no owner", and a child editing its own contract test turns legal —
# the defect S35 exists to prevent, arriving through a door S35 does not watch.
s57_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S57_C="$2/contracts.md"
  grep -q 'a position, not a chat' "$S57_C" 2>/dev/null \
    || echo "$S57_C: authored-check ownership is still bound to a chat"
  grep -q 'co-located with the executor' "$S57_C" 2>/dev/null \
    || echo "$S57_C: the in-chat channel has no owner for the authored checks"
  grep -q 'read-only for the child' "$S57_C" 2>/dev/null \
    || echo "$S57_C: the contract lost the child's read-only rule"
  # The read-only rule carries no channel qualifier: it holds on both.
  if grep 'read-only for the child' "$S57_C" 2>/dev/null \
      | grep -qE 'relayed|in-chat|Channel:'; then
    echo "$S57_C: the child's read-only rule is conditional on the channel"
  fi
  # Nobody licenses the executing phase to edit its own contract.
  for S57_F in "$1"/*/SKILL.md "$2"/*.md; do
    if grep -qEi 'may edit its own contract|edit(s)? the contract itself|rewrite its own contract test' \
        "$S57_F" 2>/dev/null; then
      echo "$S57_F: licenses the executing phase to edit its own contract"
    fi
  done
  return 0
}
S57_OUT="$(s57_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S57_OUT" ] || echo "  offending: $S57_OUT"
assert "S57: authored-check ownership is a position, not a chat" '[ -z "$S57_OUT" ]'
# Mutation A — the ownership clause leaves contracts.md.
S57_MUT="$(mktemp -d)"; mkdir -p "$S57_MUT/refs"; cp "$S24_REFS"/*.md "$S57_MUT/refs/"
sed -i.bak '/a position, not a chat/d' "$S57_MUT/refs/contracts.md" \
  && rm -f "$S57_MUT/refs/contracts.md.bak"
assert "S57: the guard fails when ownership goes back to being a chat" \
  '[ -n "$(s57_guard "$SKILLS_DIR" "$S57_MUT/refs")" ]'
rm -rf "$S57_MUT"
# Mutation B — the in-chat channel is granted the exemption.
S57_MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$S57_MUT/"
printf '\nOn Channel: in-chat the phase may edit its own contract test.\n' \
  >> "$S57_MUT/execute-phase/SKILL.md"
assert "S57: the guard fails when in-chat licenses a self-edited contract" \
  '[ -n "$(s57_guard "$S57_MUT" "$S24_REFS")" ]'
rm -rf "$S57_MUT"

echo "== S58: a planned batch is not an interrupted phase =="
# Batches promote the existing `partial` commit from escape hatch to planned
# subdivision, which makes an old rule ambiguous: "[>] with no WIP note and no
# partial commit carries no evidence" read the other way round says a partial
# commit means an interrupted session. On a batched phase it means work in
# progress. The shared core must carry both readings explicitly, the invariant
# must name the phase commit as the only closing one, and nothing may turn a
# batch boundary into a gate.
s58_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  grep -q 'planned batch is not an interrupted phase' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: nothing distinguishes a planned batch from an interrupted phase"
  # Two mechanics, not one: the checkpoint writes the WIP note, the batch does
  # not, and each lives under its own heading. A single merged section is how
  # the distinction rots back into "three triggers, one mechanic".
  grep -q '^## WIP checkpoints$' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: WIP checkpoints lost their own section"
  grep -q '^## Planned batches$' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: planned batches have no section of their own"
  grep -q 'A batch is not a checkpoint' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: a batch and a checkpoint are the same thing again"
  grep -qE 'no .> WIP:. note and no handover' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: a batch still writes the interruption note"
  # The canonical form, and the commit that names which batch it is — without
  # them the plan's list and the log cannot be lined up.
  grep -q '> Batches: 1 <label>' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: Batches: has no canonical form"
  grep -q 'partial — batch M/K' "$2/phase-execution.md" 2>/dev/null \
    || echo "$2/phase-execution.md: the batch commit does not name the batch"
  grep -q '> Batches: 1 ' "$1/write-workflow/SKILL.md" 2>/dev/null \
    || echo "$1/write-workflow/SKILL.md: the plan template carries no Batches: example"
  grep -q 'phase commit' "$2/common.md" 2>/dev/null \
    || echo "$2/common.md: the commit invariant no longer names the phase commit"
  grep -q 'partial' "$2/common.md" 2>/dev/null \
    || echo "$2/common.md: the invariant does not admit the partial commits before it"
  grep -q 'Batches:' "$2/contracts.md" 2>/dev/null \
    || echo "$2/contracts.md: the contract layer does not define Batches:"
  # A batch is a commit, never a gate: the whole point is that it costs no
  # context reset and no approval.
  for S58_F in "$1"/*/SKILL.md "$2"/*.md; do
    if grep -qEi 'gate (at|on) (each|every) batch|batch gate|approval per batch' \
        "$S58_F" 2>/dev/null; then
      echo "$S58_F: turns a batch boundary into a gate"
    fi
  done
  # The reader knows the field: an unknown note field is only a warning, so a
  # Batches: note nobody declared would degrade in silence.
  grep -q "'Batches'" "$TESTDIR/../../plugins/wf/scripts/next-phase.py" 2>/dev/null \
    || echo "next-phase.py: Batches is not a known note field"
  return 0
}
# The reader holds the canonical form to its shape: a canonical note is clean, a
# prose list and a gap in the numbering both warn — the two ways the plan's list
# stops lining up with the `batch M/K` commits.
s58_plan() {  # $1 = the Batches body; prints validator output
  S58_P="$OT/batch-plan.md"
  { echo "# Context: b"; echo "Parent: main"; echo "Mode: interactive"
    echo "Channel: in-chat"; echo ""; echo "## Work Plan"
    echo "- [ ] **Phase 1**: phase one"; echo "  > Batches: $1"
    echo "  - Done: check one"; } > "$S58_P"
  python3 "$NEXTPHASE" --validate "$S58_P" 2>&1
}
assert "S58: a canonical Batches: note validates clean" \
  '[ -z "$(s58_plan "1 model | 2 view | 3 tests" | grep -E "error:|warning:")" ]'
assert "S58: a prose Batches: body warns" \
  's58_plan "model, view, tests" | grep -q "warning: .> Batches:. body is not"'
assert "S58: a gap in the batch numbering warns" \
  's58_plan "1 model | 3 view" | grep -q "warning: .> Batches:. items must be numbered"'
assert "S58: neither warning ever blocks a run" \
  '[ -z "$(s58_plan "model, view" | grep "error:")" ]'
S58_OUT="$(s58_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S58_OUT" ] || echo "  offending: $S58_OUT"
assert "S58: planned batches and interrupted phases are told apart" '[ -z "$S58_OUT" ]'
# Mutation A — the distinction leaves the shared core.
S58_MUT="$(mktemp -d)"; mkdir -p "$S58_MUT/refs"; cp "$S24_REFS"/*.md "$S58_MUT/refs/"
sed -i.bak '/planned batch is not an interrupted phase/d' "$S58_MUT/refs/phase-execution.md" \
  && rm -f "$S58_MUT/refs/phase-execution.md.bak"
assert "S58: the guard fails when the two readings collapse" \
  '[ -n "$(s58_guard "$SKILLS_DIR" "$S58_MUT/refs")" ]'
rm -rf "$S58_MUT"
# Mutation B — the two sections merge back into one mechanic: the words
# "Batches:" and "partial" all survive, only the distinction dies.
S58_MUT="$(mktemp -d)"; mkdir -p "$S58_MUT/refs"; cp "$S24_REFS"/*.md "$S58_MUT/refs/"
sed -i.bak 's/^## Planned batches$/### Planned batches (same mechanic)/' \
  "$S58_MUT/refs/phase-execution.md" && rm -f "$S58_MUT/refs/phase-execution.md.bak"
assert "S58: the guard fails when batches lose their own mechanic" \
  '[ -n "$(s58_guard "$SKILLS_DIR" "$S58_MUT/refs")" ]'
rm -rf "$S58_MUT"
# Mutation C — a batch starts writing the interruption note, which is how the
# next reader mistakes work in progress for an abandoned phase.
S58_MUT="$(mktemp -d)"; mkdir -p "$S58_MUT/refs"; cp "$S24_REFS"/*.md "$S58_MUT/refs/"
sed -i.bak 's/no `> WIP:` note and no handover/the `> WIP:` note as usual/' \
  "$S58_MUT/refs/phase-execution.md" && rm -f "$S58_MUT/refs/phase-execution.md.bak"
assert "S58: the guard fails when a batch writes the interruption note" \
  '[ -n "$(s58_guard "$SKILLS_DIR" "$S58_MUT/refs")" ]'
rm -rf "$S58_MUT"
# Mutation D — the canonical form leaves, so plan list and log cannot line up.
S58_MUT="$(mktemp -d)"; mkdir -p "$S58_MUT/refs"; cp "$S24_REFS"/*.md "$S58_MUT/refs/"
sed -i.bak '/> Batches: 1 <label>/d' "$S58_MUT/refs/phase-execution.md" \
  && rm -f "$S58_MUT/refs/phase-execution.md.bak"
assert "S58: the guard fails when Batches: loses its canonical form" \
  '[ -n "$(s58_guard "$SKILLS_DIR" "$S58_MUT/refs")" ]'
rm -rf "$S58_MUT"
# Mutation E — a batch grows a gate, which is the whole cost the design refuses.
S58_MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$S58_MUT/"
printf '\nPresent the work at a gate on each batch.\n' >> "$S58_MUT/execute-phase/SKILL.md"
assert "S58: the guard fails when a batch boundary becomes a gate" \
  '[ -n "$(s58_guard "$S58_MUT" "$S24_REFS")" ]'
rm -rf "$S58_MUT"

echo "== S59: reconnaissance precedes the questions =="
# Nine clarify rounds on one run, and almost every one repaired a plan written
# before the code was read (issue #22). Two skills ask the user things: the
# scoping interrogation and the planning fork. Both must look first, and both
# must name the four defect classes the field actually produced, so the pass is
# a checklist rather than a good intention.
s59_guard() {  # $1 = a skills dir; prints one line per violation
  S59_SCOPE="$1/scope-workflow/SKILL.md"
  S59_WRITE="$1/write-workflow/SKILL.md"
  # Ordering: the ground is established before the decision tree is mapped.
  S59_GROUND=$(grep -n '^## Step 2: Establish the ground' "$S59_SCOPE" 2>/dev/null | cut -d: -f1)
  S59_TREE=$(grep -n '^## Step 3: Map the decision tree' "$S59_SCOPE" 2>/dev/null | cut -d: -f1)
  if [ -z "$S59_GROUND" ] || [ -z "$S59_TREE" ] || [ "$S59_GROUND" -ge "$S59_TREE" ]; then
    echo "$S59_SCOPE: the interrogation no longer follows the ground pass"
  fi
  grep -q 'looked up, never asked' "$S59_SCOPE" 2>/dev/null \
    || echo "$S59_SCOPE: a fact may be asked instead of looked up"
  # The four classes, in both skills that write or shape a plan.
  for S59_F in "$S59_SCOPE" "$S59_WRITE"; do
    for S59_K in literal behaviour remedy arithmetic; do
      grep -qi "$S59_K" "$S59_F" 2>/dev/null \
        || echo "$S59_F: the recon checklist lost the '$S59_K' class"
    done
  done
  # Planning looks before it sizes.
  grep -q 'look, before deciding anything' "$S59_WRITE" 2>/dev/null \
    || echo "$S59_WRITE: the plan is built without a look at the code first"
  grep -q 'you have not seen' "$S59_WRITE" 2>/dev/null \
    || echo "$S59_WRITE: the evidence rule on Files:/Decisions: is gone"
  # The brief hands over the channel with the mode, or /write-workflow re-asks
  # what one question at a time should already have settled.
  grep -q '^Channel: <in-chat|relayed>' "$S59_SCOPE" 2>/dev/null \
    || echo "$S59_SCOPE: the scoping brief hands over no channel"
  return 0
}
S59_OUT="$(s59_guard "$SKILLS_DIR")"
[ -z "$S59_OUT" ] || echo "  offending: $S59_OUT"
assert "S59: both asking skills look before they ask" '[ -z "$S59_OUT" ]'
# Mutation A — the ground pass moves after the decision tree.
S59_MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$S59_MUT/"
python3 - "$S59_MUT/scope-workflow/SKILL.md" <<'PYEOF'
import re, sys
p = sys.argv[1]
t = open(p).read()
t = t.replace('## Step 2: Establish the ground', '## Step 4: Establish the ground')
t = t.replace('## Step 3: Map the decision tree', '## Step 2: Map the decision tree')
t = t.replace('## Step 4: Establish the ground', '## Step 3: Establish the ground')
open(p, 'w').write(t)
PYEOF
assert "S59: the guard fails when the questions come before the ground" \
  '[ -n "$(s59_guard "$S59_MUT")" ]'
rm -rf "$S59_MUT"
# Mutation B — the checklist loses a class, the cheapest way for it to rot.
S59_MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$S59_MUT/"
sed -i.bak 's/arithmetic/counting/g' "$S59_MUT/write-workflow/SKILL.md" \
  && rm -f "$S59_MUT/write-workflow/SKILL.md.bak"
assert "S59: the guard fails when the recon checklist loses a class" \
  '[ -n "$(s59_guard "$S59_MUT")" ]'
rm -rf "$S59_MUT"
assert "S59: the scoping brief hands the channel over with the mode" \
  'grep -q "^Channel: <in-chat|relayed>" "$SKILLS_DIR/scope-workflow/SKILL.md"'
# Mutation C — the brief hands over the mode and no channel.
S59_MUT="$(mktemp -d)"; cp -R "$SKILLS_DIR"/. "$S59_MUT/"
sed -i.bak '/^Channel: <in-chat|relayed>/d' "$S59_MUT/scope-workflow/SKILL.md" \
  && rm -f "$S59_MUT/scope-workflow/SKILL.md.bak"
assert "S59: the guard fails when the brief hands over no channel" \
  '[ -n "$(s59_guard "$S59_MUT")" ]'
rm -rf "$S59_MUT"

echo "== S60: every entrance forks, and the two roads do different things =="
# A relay half-removed is worse than one left whole: the in-chat branch reads as
# supported while every instruction still routes through a chat that does not
# exist. Presence of the word "in-chat" proves nothing — this guard asks, per
# entrance, that the relayed road keeps its effect AND the in-chat road states
# the opposite effect. Six entrances, one per operational consequence.
s60_guard() {  # $1 = a skills dir, $2 = a refs dir; prints one line per violation
  S60_IMP="$1/import-workflow/SKILL.md"
  S60_RES="$1/resume-workflow/SKILL.md"
  S60_CORE="$2/phase-execution.md"
  # (1) import + in-chat writes no foreman.json; relayed still does.
  grep -qE 'No .foreman\.json., no take-command' "$S60_IMP" 2>/dev/null \
    || echo "$S60_IMP: an in-chat import still takes command"
  grep -q 'relayed road, and only there, write `foreman.json`' "$S60_IMP" 2>/dev/null \
    || echo "$S60_IMP: the relayed import no longer writes foreman.json"
  # (2) import + in-chat continues here; relayed still opens a new chat.
  grep -q 'in-chat → no relay and no foreman' "$S60_IMP" 2>/dev/null \
    || echo "$S60_IMP: the in-chat close does not say where the work continues"
  grep -qE 'in-chat →.*/execute-phase here' "$S60_IMP" 2>/dev/null \
    || echo "$S60_IMP: an in-chat import still sends the user to another chat"
  grep -qE 'relayed →.*new chat' "$S60_IMP" 2>/dev/null \
    || echo "$S60_IMP: the relayed import lost its new-chat instruction"
  # (3) resume names the channel, and does not always name a foreman.
  grep -q 'One \*\*Channel\*\* line closes the point' "$S60_RES" 2>/dev/null \
    || echo "$S60_RES: the report still always names a Foreman line"
  grep -qE 'in-chat.*continues in this conversation|continues in this conversation' "$S60_RES" 2>/dev/null \
    || echo "$S60_RES: an in-chat resume does not say the work continues here"
  grep -q 'in this same conversation on `Channel: in-chat`' "$S60_RES" 2>/dev/null \
    || echo "$S60_RES: the skill map still sends every phase to a new chat"
  grep -q 'no relay to take command of' "$S60_RES" 2>/dev/null \
    || echo "$S60_RES: an in-chat resume still runs the take-command protocol"
  # (4) close-short reports on both roads, and re-plans on both.
  grep -q 'Report that it closed short' "$S60_CORE" 2>/dev/null \
    || echo "$S60_CORE: closing short still reports only to the foreman"
  grep -qE 'closed short.*`Channel: in-chat`|said at the gate on' "$S60_CORE" 2>/dev/null \
    || echo "$S60_CORE: the short close has no in-chat road"
  grep -q 'sized with the user at this same gate' "$S60_CORE" 2>/dev/null \
    || echo "$S60_CORE: the remainder is still always the foreman's to size"
  # (5) a rejected result routes by the table, not straight to the foreman.
  grep -q 'the `result rejected` outcome and the' "$S60_CORE" 2>/dev/null \
    || echo "$S60_CORE: a rejected result still messages the foreman unconditionally"
  # (6) the second failed repair goes out by road, not to the foreman by name.
  grep -q 'goes out as `blocked`' "$S60_CORE" 2>/dev/null \
    || echo "$S60_CORE: a second failed repair still goes to the foreman by name"
  grep -q 'to the user here on `Channel: in-chat`' "$S60_CORE" 2>/dev/null \
    || echo "$S60_CORE: blocked has no in-chat destination"
  S60_REP="$1/repair-phase/SKILL.md"
  S60_DOC="$1/doctor/SKILL.md"
  S60_HLP="$1/help/SKILL.md"
  # (7) a failed repair reports blocked by road, and its title needs no relay.
  grep -q 'report `blocked` per' "$S60_REP" 2>/dev/null \
    || echo "$S60_REP: a failed repair still sends the foreman the blocked line unconditionally"
  grep -q 'said to the user at this gate on `Channel: in-chat`' "$S60_REP" 2>/dev/null \
    || echo "$S60_REP: a failed in-chat repair has nobody to report to"
  if grep 'Title this chat' "$S60_REP" 2>/dev/null | grep -q 'foreman\.md'; then
    echo "$S60_REP: titling the repair chat still loads the relay layer"
  fi
  # (8) a confirmed plan-defect is fixed by the plan's owner, by road.
  grep -q 'fixed from there by whoever owns the plan' "$S60_REP" 2>/dev/null \
    || echo "$S60_REP: a confirmed plan-defect is still always the foreman's to fix"
  # The fresh-eyes hand-back is NOT the relay and must survive on both roads.
  grep -q 'not the workflow.s relay' "$S60_REP" 2>/dev/null \
    || echo "$S60_REP: the hand-back to the phase chat lost its exemption"
  # (9) doctor re-plans by road, and (10) names an owner, not a chat.
  grep -q 'this same conversation on `Channel: in-chat`' "$S60_DOC" 2>/dev/null \
    || echo "$S60_DOC: re-planning still always goes to the foreman chat"
  grep -q 'a position, not a chat' "$S60_DOC" 2>/dev/null \
    || echo "$S60_DOC: the decision on an edited contract is still a chat's, not a position's"
  if grep -n 'Close with the next step' -A3 "$S60_DOC" 2>/dev/null \
      | grep -q 'in the foreman chat for'; then
    echo "$S60_DOC: the closing next step is still foreman-only"
  fi
  # (11) help teaches both roads for a rejected result, and (12) for resume.
  grep -q 'on `in-chat` there is nobody to tell' "$S60_HLP" 2>/dev/null \
    || echo "$S60_HLP: a rejected result is still always told to the foreman"
  grep -q 'on `in-chat` the conversation that' "$S60_HLP" 2>/dev/null \
    || echo "$S60_HLP: the resume route is still always a fresh chat"
  # help teaches; an unqualified instruction there teaches the relayed road as
  # if it were the only one. Three places say where resume runs — the
  # introduction, the route list, the closing line — and each is checked on its
  # own, because qualifying the middle one is exactly what happened first.
  S60_HLP_INTRO="$(sed -n '1,20p' "$S60_HLP" 2>/dev/null)"
  S60_HLP_CLOSE="$(grep -A4 'Close with one line' "$S60_HLP" 2>/dev/null)"
  printf '%s' "$S60_HLP_INTRO" | grep -q 'in-chat' \
    || echo "$S60_HLP: the introduction names one road only"
  printf '%s' "$S60_HLP_CLOSE" | grep -q 'in-chat' \
    || echo "$S60_HLP: the closing line names one road only"
  # And no instruction anywhere sends the user to a chat without naming a road.
  while IFS= read -r S60_L; do
    [ -n "$S60_L" ] || continue
    echo "$S60_HLP: unqualified fresh chat — \"$(echo "$S60_L" | cut -c1-52)…\""
  done <<EOF
$(grep -nE 'in a fresh chat|open a fresh chat|a fresh chat on `/|one fresh chat' "$S60_HLP" 2>/dev/null \
  | grep -vE 'in-chat|relayed|legacy')
EOF
  grep -q 'a fresh chat per phase on `relayed`' "$S60_HLP" 2>/dev/null \
    || echo "$S60_HLP: the interactive build is still one fresh chat per phase"
  # The fork covers outcomes and re-plannings, not questions alone.
  grep -q 'an \*\*outcome\*\*' "$S60_CORE" 2>/dev/null \
    || echo "$S60_CORE: the fork does not route outcomes"
  grep -q 'a \*\*re-planning\*\*' "$S60_CORE" 2>/dev/null \
    || echo "$S60_CORE: the fork does not route re-plannings"
  return 0
}
S60_OUT="$(s60_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S60_OUT" ] || echo "  offending: $S60_OUT"
assert "S60: both roads are spelled out at every entrance" '[ -z "$S60_OUT" ]'
# Six mutations, one per operational consequence — each leaves the vocabulary
# in place and changes only what actually happens on one road.
s60_mutate() {  # $1 = relative file, $2 = sed script; prints the guard's output
  S60_M="$(mktemp -d)"; mkdir -p "$S60_M/refs"
  cp -R "$SKILLS_DIR"/. "$S60_M/"; cp "$S24_REFS"/*.md "$S60_M/refs/"
  sed -i.bak "$2" "$S60_M/$1" && rm -f "$S60_M/$1.bak"
  s60_guard "$S60_M" "$S60_M/refs"
  rm -rf "$S60_M"
}
assert "S60: fails when an in-chat import creates foreman.json" \
  '[ -n "$(s60_mutate import-workflow/SKILL.md "s/No \`foreman.json\`, no take-command/A \`foreman.json\` all the same/")" ]'
assert "S60: fails when an in-chat import prescribes a new chat" \
  '[ -n "$(s60_mutate import-workflow/SKILL.md "s|in-chat → no relay and no foreman: to carry on, /execute-phase here|in-chat → to carry on, launch /execute-phase in a new chat|")" ]'
assert "S60: fails when closing short always goes to the foreman" \
  '[ -n "$(s60_mutate refs/phase-execution.md "s/Report that it closed short/Tell the foreman it closed short/")" ]'
assert "S60: fails when a rejected result always sends the message" \
  '[ -n "$(s60_mutate refs/phase-execution.md "s/the \`result rejected\` outcome and the/the foreman gets the \`result rejected\` line and the/")" ]'
assert "S60: fails when a second failed repair always goes to the foreman" \
  '[ -n "$(s60_mutate refs/phase-execution.md "s/goes out as \`blocked\`/goes to the foreman as \`blocked\`/")" ]'
assert "S60: fails when an in-chat resume prescribes a new chat or a foreman" \
  '[ -n "$(s60_mutate resume-workflow/SKILL.md "s/One \*\*Channel\*\* line closes the point/One **Foreman** line closes the point/")" ]'
assert "S60: fails when an in-chat failed repair sends blocked to the foreman" \
  '[ -n "$(s60_mutate repair-phase/SKILL.md "s/report \`blocked\` per/send the foreman the \`blocked\` line per/")" ]'
assert "S60: fails when a confirmed plan-defect is always the foreman's to fix" \
  '[ -n "$(s60_mutate repair-phase/SKILL.md "s/fixed from there by whoever owns the plan/fixed from there by the foreman/")" ]'
assert "S60: fails when the repair title reloads the relay layer" \
  '[ -n "$(s60_mutate repair-phase/SKILL.md "s|on \`session_id: \"self\"\`.|on \`session_id: \"self\"\` (\`foreman.md\` → *The foreman*).|")" ]'
assert "S60: fails when doctor always re-plans in the foreman chat" \
  '[ -n "$(s60_mutate doctor/SKILL.md "s/this same conversation on \`Channel: in-chat\`/the foreman chat in every case/")" ]'
assert "S60: fails when doctor gives the decision to a chat, not a position" \
  '[ -n "$(s60_mutate doctor/SKILL.md "s/a position, not a chat/the foreman.s alone/")" ]'
assert "S60: fails when help teaches the foreman for every rejected result" \
  '[ -n "$(s60_mutate help/SKILL.md "s/on \`in-chat\` there is nobody to tell/on \`in-chat\` tell the foreman chat too/")" ]'
assert "S60: fails when help prescribes a fresh chat for every resume" \
  '[ -n "$(s60_mutate help/SKILL.md "s/on \`in-chat\` the conversation that/in a fresh chat, whatever the channel, and the conversation that/")" ]'
assert "S60: fails when help's introduction goes back to one road" \
  '[ -n "$(s60_mutate help/SKILL.md "1,20s/on \`Channel: in-chat\`//")" ]'
assert "S60: fails when help's closing line goes back to one road" \
  '[ -n "$(s60_mutate help/SKILL.md "s|of an actual workflow, ./wf:resume-workflow. — a fresh chat on|of an actual workflow, open a fresh chat on \`/wf:resume-workflow\`. Not on|")" ]'

echo "== S61: the foreman's own model is a written hint, like Run: =="
# 6.33.0: a chat's model and effort are chosen when it opens, so the foreman's
# suggested fable / high is written where the next foreman is opened from —
# the ref owns it, write-workflow's closing line and resume-workflow's fresh-chat
# Next step repeat it.
s61_guard() {  # $1 = skills dir, $2 = refs dir; one line per gap
  grep -q "The foreman's own model" "$2/foreman.md" 2>/dev/null \
    || echo "foreman.md: the foreman's own model paragraph is gone"
  grep -q 'Suggested `fable` / `high`' "$2/foreman.md" 2>/dev/null \
    || echo "foreman.md: the hint lost its value"
  grep -q 'successor foreman chat opens on fable / high' "$1/write-workflow/SKILL.md" 2>/dev/null \
    || echo "write-workflow: the closing line no longer carries the foreman hint"
  grep -q "The foreman's own model" "$1/resume-workflow/SKILL.md" 2>/dev/null \
    || echo "resume-workflow: the fresh-chat Next step no longer quotes the foreman hint"
}
S61_OUT="$(s61_guard "$SKILLS_DIR" "$S24_REFS")"
[ -z "$S61_OUT" ] || echo "  offending: $S61_OUT"
assert "S61: the foreman hint is owned by the ref and repeated where a foreman opens" '[ -z "$S61_OUT" ]'
S61_MUT="$(mktemp -d)"
cp -R "$S24_REFS"/. "$S61_MUT/"
sed -i.bak "/The foreman's own model is advice too/d" "$S61_MUT/foreman.md" \
  && rm -f "$S61_MUT/foreman.md.bak"
assert "S61: the guard fails when the ref loses the paragraph" \
  '[ -n "$(s61_guard "$SKILLS_DIR" "$S61_MUT")" ]'
rm -rf "$S61_MUT"
S61_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S61_MUT/"
sed -i.bak 's/successor foreman chat opens on fable \/ high/successor foreman chat opens/' "$S61_MUT/write-workflow/SKILL.md" \
  && rm -f "$S61_MUT/write-workflow/SKILL.md.bak"
assert "S61: the guard fails when write-workflow drops the value" \
  '[ -n "$(s61_guard "$S61_MUT" "$S24_REFS")" ]'
rm -rf "$S61_MUT"

echo "== S62: a worktree the launcher creates gets the GenroPy activation =="
# 6.34.0: the worktree opens at planning by default, and the GenroPy env must
# be written into it BEFORE any session starts there — Claude Code reads the
# worktree's settings.local.json at session start. Live: a plan on a wf/ branch
# with no checkout, the launcher run from the root, a mock activate_gnr_context
# on PATH — the worktree is created, the root settings copied, the activation
# run from inside the worktree (its pwd is how the real script finds it), and
# announced; without the script on PATH nothing about it is said. Then the real
# activate_gnr_context against a fake ~/.gnr: `.gnr/` lands in the common
# info/exclude and .gitignore stays untouched, since a phase commit stages with
# `git add -A`. Static: agent-session.sh mirrors the launcher's call, and
# write-workflow names the worktree command and the activation — by mutation.
s62_repo() {  # $1 = scenario dir: root on main, plan on wf/s62 with no checkout
  rm -rf "$1"; mkdir -p "$1/.claude"; cd "$1" || exit 1
  git init -q -b main
  git config user.email wf-tests@harness.local
  git config user.name "wf test harness"
  echo base > base.txt; git add -A; git commit -qm base
  echo '{"env":{"S62":"root"}}' > .claude/settings.local.json
  git worktree add -q "$1-tmp" -b wf/s62 main
  mkdir -p "$1-tmp/.phased/active/toy"
  ( cd "$1-tmp" && fixture2 )
  git -C "$1-tmp" add -A; git -C "$1-tmp" commit -qm "wf: plan for toy"
  git worktree remove --force "$1-tmp"
}
mkdir -p "$OT/gnrbin"
printf '%s\n' '#!/bin/bash' 'pwd > "$S62_ACTIVATION_LOG"' > "$OT/gnrbin/activate_gnr_context"
chmod +x "$OT/gnrbin/activate_gnr_context"
s62_repo "$OT/scenarios/S62"
S62_ACTIVATION_LOG="$OT/scenarios/S62.activation" PATH="$OT/gnrbin:$OT/bin:$PATH" bash "$OT/runner.sh" > out.log 2>&1
assert "S62: the launcher creates the worktree for the plan with no checkout" \
  'grep -q "creating its worktree at .*/.claude/worktrees/toy" out.log && [ -f .claude/worktrees/toy/.phased/active/toy/plan.md ]'
assert "S62: the root settings.local.json is copied into the worktree" \
  'grep -q S62 .claude/worktrees/toy/.claude/settings.local.json'
assert "S62: activate_gnr_context runs from inside the worktree" \
  'grep -q "/scenarios/S62/.claude/worktrees/toy$" "$OT/scenarios/S62.activation"'
assert "S62: the activation is announced" 'grep -q "GenroPy environment activated in .*/.claude/worktrees/toy" out.log'
# The machine running the suite may have the real script installed (it is,
# on the author's), so "not on PATH" is built, not assumed.
S62_PATH="$OT/bin:$(printf '%s' "$PATH" | tr ':' '\n' | while read -r d; do
  [ -n "$d" ] && [ ! -x "$d/activate_gnr_context" ] && printf '%s:' "$d"; done | sed 's/:$//')"
s62_repo "$OT/scenarios/S62b"
PATH="$S62_PATH" bash "$OT/runner.sh" > out.log 2>&1
assert "S62: without the script on PATH the worktree is still created and GenroPy is not mentioned" \
  '[ -f .claude/worktrees/toy/.phased/active/toy/plan.md ] && ! grep -qi "genropy" out.log'
# The real activation against a fake system config: exclude, not .gitignore.
S62_HOME="$OT/scenarios/S62-home"; mkdir -p "$S62_HOME/.gnr/siteconfig"
printf '%s\n' '<?xml version="1.0"?>' '<environment><gnrdaemon host="localhost" port="40404"/></environment>' > "$S62_HOME/.gnr/environment.xml"
printf '%s\n' '<?xml version="1.0"?>' '<siteconfig><wsgi port="8080"/></siteconfig>' > "$S62_HOME/.gnr/siteconfig/default.xml"
S62_WT="$OT/scenarios/S62b/.claude/worktrees/toy"
S62_ACT_OUT="$(cd "$S62_WT" && HOME="$S62_HOME" VIRTUAL_ENV= bash "$TESTDIR/../../plugins/genropy-worktree/bin/activate_gnr_context" 2>&1)"
[ -f "$S62_WT/.gnr/environment.xml" ] || echo "  activation output: $S62_ACT_OUT"
assert "S62: the real activation generates the worktree's .gnr/ and its Claude Code env" \
  '[ -f "$S62_WT/.gnr/environment.xml" ] && grep -q GENRO_GNRFOLDER "$S62_WT/.claude/settings.local.json"'
assert "S62: .gnr/ is excluded through the common info/exclude" \
  'grep -qx ".gnr/" "$OT/scenarios/S62b/.git/info/exclude" && git -C "$S62_WT" check-ignore -q .gnr/'
assert "S62: .gitignore is not created or edited by the activation" \
  '[ ! -e "$S62_WT/.gitignore" ] && [ -z "$(git -C "$S62_WT" status --porcelain -- .gitignore)" ]'
s62_guard() {  # $1 = skills dir, $2 = scripts dir; one line per gap
  grep -q 'git worktree add .claude/worktrees/<slug> -b wf/<slug>' "$1/write-workflow/SKILL.md" 2>/dev/null \
    || echo "write-workflow: the worktree command is gone from Step 4"
  grep -q 'activate_gnr_context' "$1/write-workflow/SKILL.md" 2>/dev/null \
    || echo "write-workflow: the activation step is gone"
  grep -q 'cd "$PLAN_CHECKOUT" && activate_gnr_context' "$2/run-workflow.sh" 2>/dev/null \
    || echo "run-workflow.sh: the activation call is gone"
  grep -q 'cd "$PLAN_CHECKOUT" && activate_gnr_context' "$2/agent-session.sh" 2>/dev/null \
    || echo "agent-session.sh: the activation call is gone"
}
S62_SCRIPTS="$TESTDIR/../../plugins/wf/scripts"
S62_OUT="$(s62_guard "$SKILLS_DIR" "$S62_SCRIPTS")"
[ -z "$S62_OUT" ] || echo "  offending: $S62_OUT"
assert "S62: the worktree and its activation are named where the worktree opens" '[ -z "$S62_OUT" ]'
S62_MUT="$(mktemp -d)"
cp -R "$SKILLS_DIR"/. "$S62_MUT/"
sed -i.bak '/activate_gnr_context/d' "$S62_MUT/write-workflow/SKILL.md" && rm -f "$S62_MUT/write-workflow/SKILL.md.bak"
assert "S62: the guard fails when write-workflow drops the activation" \
  '[ -n "$(s62_guard "$S62_MUT" "$S62_SCRIPTS")" ]'
rm -rf "$S62_MUT"
S62_MUT="$(mktemp -d)"
cp "$S62_SCRIPTS"/*.sh "$S62_MUT/"
sed -i.bak '/activate_gnr_context/d' "$S62_MUT/agent-session.sh" && rm -f "$S62_MUT/agent-session.sh.bak"
assert "S62: the guard fails when agent-session.sh drops the activation" \
  '[ -n "$(s62_guard "$SKILLS_DIR" "$S62_MUT")" ]'
rm -rf "$S62_MUT"

echo ""
if [ "$SKIP" -gt 0 ]; then
  echo "RESULT: $PASS passed, $FAIL failed, $SKIP skipped"
else
  echo "RESULT: $PASS passed, $FAIL failed"
fi
[ "$FAIL" = 0 ]
