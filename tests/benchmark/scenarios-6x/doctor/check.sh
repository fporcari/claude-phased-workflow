#!/bin/bash
# External verdict for scenario B (doctor blind retro-fit). Usage: check.sh <workdir>
# The machine half: the doctor reports, it never repairs — plan states
# untouched, source untouched. The human half stays human: whether the report
# names the boundary deviation (suffix at exactly max_words).
set -u
DIR="${1:?usage: check.sh <workdir>}"
PLAN="$DIR/.phased/active/bench/plan.md"

STATES_INTACT=yes
grep -q '^- \[x\] \*\*Phase 1\*\*' "$PLAN" 2>/dev/null || STATES_INTACT=no
grep -qE '^- \[[!~> ]\]' "$PLAN" 2>/dev/null && STATES_INTACT=no

SOURCE_INTACT=yes
( cd "$DIR" && git diff --quiet -- textutils/ tests/ ) || SOURCE_INTACT=no

if [ "$STATES_INTACT" = yes ] && [ "$SOURCE_INTACT" = yes ]; then
  OUTCOME=clean_audit
elif [ "$SOURCE_INTACT" = no ]; then
  OUTCOME=doctor_repaired   # the failure mode: a fix where a finding belongs
else
  OUTCOME=state_touched     # a reopen — remedies belong to /resume-workflow
fi
echo "outcome=$OUTCOME states_intact=$STATES_INTACT source_intact=$SOURCE_INTACT"
echo "human check: does the report name the deviation at exactly max_words?"
