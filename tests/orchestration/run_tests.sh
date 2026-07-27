#!/bin/bash
# Regression tests for the phased-workflow chain.
# S1-S13 run the real shipped run-workflow.sh
# against a mock `claude` binary: model/effort/cap selection under the /goal
# guard, repair success and failure, the idempotent repair marker, fable->opus
# fallback, progress guard, baseline attribution (reopen / [~]), inert Roadmap,
# and the pre-2.1.139 prompt fallback. S14-S16 are static checks on what the
# repo ships: no frozen copies of the shipped contracts (S14), every skill
# inside its own allowed-tools (S15), every skill on the KB sync list (S16).
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
assert "phases 2-3 use FULL skill contract" '[ "$(grep -c -- "-p /goal Use the auto-phase skill" .claude/invocations.log)" = 2 ]'
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

# Static regression guard: no unqualified phase-state grep may re-enter the
# launcher. Every grep whose pattern carries a bracketed state (\[x\], \[ \],
# \[!\], \[~\], \[>\], or the \[[ x!~>]\] class) must be one of the four
# single-source helper definitions. Follows the S14 extract() heredoc idiom.
GUARD_OUT="$(python3 - "$RUNNER_SRC" <<'PYG'
import re, sys
lines = open(sys.argv[1], encoding='utf-8').read().splitlines()
helper = re.compile(r'^(phase_re|phase_count|phase_any|phase_lines)\(\)')
state = re.compile(r'\\\[\[?[ x!~>]')   # a literal \[ opening a phase-state match
bad = []
for i, line in enumerate(lines, 1):
    if 'grep' not in line:
        continue
    if not state.search(line):
        continue
    if helper.match(line.strip()):
        continue
    bad.append('%d: %s' % (i, line.strip()))
sys.stdout.write('\n'.join(bad))
PYG
)"
[ -z "$GUARD_OUT" ] || echo "  offending: $GUARD_OUT"
assert "S18: no phase-state grep bypasses the helpers" '[ -z "$GUARD_OUT" ]'

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
S21_SKILLS="$TESTDIR/../../plugins/phased-workflow/skills"
S21_REFS="$TESTDIR/../../plugins/phased-workflow/refs"
HOME_OUT="$(python3 - "$S21_SKILLS" "$S21_REFS" <<'PYH'
import os, sys
bad = []
for root in sys.argv[1:]:
    for dirpath, _, names in os.walk(root):
        for name in names:
            p = os.path.join(dirpath, name)
            for i, line in enumerate(open(p, encoding='utf-8').read().splitlines(), 1):
                if '~/.claude/' not in line and '$HOME/.claude/' not in line:
                    continue
                # documented exemption: the settings.json auto-mode mention
                if line.count('~/.claude/') == 1 and '~/.claude/settings.json' in line \
                        and '$HOME/.claude/' not in line:
                    continue
                bad.append('%s:%d: %s' % (p, i, line.strip()))
sys.stdout.write('\n'.join(bad))
PYH
)"
[ -z "$HOME_OUT" ] || echo "  offending: $HOME_OUT"
assert "S21: no skill or ref addresses ~/.claude/ or \$HOME/.claude/" '[ -z "$HOME_OUT" ]'
# The guard is only worth having if it fails on the defect it describes.
S21_MUT="$(mktemp -d)"; cp -R "$S21_SKILLS" "$S21_MUT/skills"
printf '\nSee `python3 ~/.claude/scripts/next-phase.py --resolve` for the plan.\n' \
  >> "$S21_MUT/skills/auto-phase/SKILL.md"
S21_MUT_OUT="$(python3 - "$S21_MUT/skills" <<'PYH'
import os, sys
bad = []
for dirpath, _, names in os.walk(sys.argv[1]):
    for name in names:
        p = os.path.join(dirpath, name)
        for i, line in enumerate(open(p, encoding='utf-8').read().splitlines(), 1):
            if '~/.claude/' not in line and '$HOME/.claude/' not in line:
                continue
            if line.count('~/.claude/') == 1 and '~/.claude/settings.json' in line \
                    and '$HOME/.claude/' not in line:
                continue
            bad.append('%s:%d' % (p, i))
sys.stdout.write('\n'.join(bad))
PYH
)"
rm -rf "$S21_MUT"
assert "S21: the guard fails when a ~/.claude/ path is reintroduced" '[ -n "$S21_MUT_OUT" ]'

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

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
