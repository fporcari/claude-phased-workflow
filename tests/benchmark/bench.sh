#!/bin/bash
# Benchmark the phase-execution path on a fixed, well-specified phase.
# Each run: fresh copy of the fixture project -> one real claude -p session
# -> external verification of the Done criterion (pytest + flake8 + plan state).
# Metrics from --output-format json: num_turns, total_cost_usd, duration_ms.
#
# Usage: bench.sh [runs_per_config] [config ...]
#   config format: label|model|mode[|effort]   mode: plain | goal | slim | slimgoal
#     plain    = full execute-phase-agent skill, no guard
#     goal     = full execute-phase-agent skill under the /goal guard   (shipped PHASE_PROMPT)
#     slim     = minimal prompt, NO skill discipline, no guard  (hardcoded control)
#     slimgoal = discipline carried ONLY by the goal contract   (shipped LIGHT_PROMPT)
#   effort defaults to the fixture's own declared Effort for Phase 1, else high.
#   The goal/slimgoal contracts are EXTRACTED LIVE from the shipped
#   run-workflow.sh, so the benchmark cannot silently measure a stale version.
#   default: 1 run each of sonnet-plain|sonnet|plain and sonnet-goal|sonnet|goal
set -u
TESTDIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE="${BENCH_FIXTURE:-$TESTDIR/fixture}"
RUNS="${1:-1}"; shift 2>/dev/null || true
if [ "$#" -gt 0 ]; then CONFIGS=("$@"); else
  CONFIGS=("sonnet-plain|sonnet|plain" "sonnet-goal|sonnet|goal")
fi

# The guarded arms must run the contracts the launcher SHIPS, not a copy of
# them. Frozen copies silently rot: before this was extracted, bench.sh carried
# the pre-2.5.0 text, so the guarded and slim-goal arms measured the previous
# version while the harness reported the current one. Extract live instead —
# there is then no copy that can drift.
SKILL_RAP="$TESTDIR/../../plugins/wf/scripts/run-workflow.sh"
extract_contract() {  # $1 = variable name as assigned in the launcher script
  python3 - "$SKILL_RAP" "$1" <<'PYEOF'
import re, sys
text = open(sys.argv[1], encoding='utf-8').read()
# single-quoted one-line assignments; take the longest (LIGHT_PROMPT is also
# assigned '' in the pre-2.1.139 fallback branch)
vals = re.findall(rf"^\s*{re.escape(sys.argv[2])}='([^']*)'\s*$", text, re.M)
if not vals:
    sys.exit(f'bench.sh: cannot extract {sys.argv[2]} from {sys.argv[1]}')
best = max(vals, key=len)
if not best.strip():
    sys.exit(f'bench.sh: {sys.argv[2]} extracted empty')
sys.stdout.write(best)
PYEOF
}

# Shipped contracts already carry their own leading "/goal " token.
GOAL_PROMPT="$(extract_contract PHASE_PROMPT)" || exit 1
LIGHT_GOAL_PROMPT="$(extract_contract LIGHT_PROMPT)" || exit 1

# The plain-slim arm is NOT a shipped contract: it is a deliberate no-discipline
# control, so it stays hardcoded here on purpose.
SLIM_PROMPT='Execute the next pending [ ] phase in the active plan under .phased/active/: implement what it describes, then update the plan marking that phase [x] with > Done: and > Files: notes (or [!] with an > Issue: note if you cannot complete it). Do not commit anything.'

sha() { printf '%s' "$1" | shasum -a 256 | cut -c1-12; }
echo "contracts: PHASE_PROMPT=$(sha "$GOAL_PROMPT")  LIGHT_PROMPT=$(sha "$LIGHT_GOAL_PROMPT")  (extracted from $SKILL_RAP)"

WORK="$(mktemp -d)"
CSV="$WORK/results.csv"
echo "config,run,outcome,turns,cost_usd,duration_s,effort,contract_sha" > "$CSV"

for CFG in "${CONFIGS[@]}"; do
  IFS='|' read -r LABEL MODEL MODE EFFORT <<< "$CFG"
  # No arm ever passed --effort before, so every archived run sits at the CLI
  # default while the fixture's config table declares Effort=low. Default to
  # the fixture's own declared effort when the config omits it.
  if [ -z "${EFFORT:-}" ]; then
    EFFORT=$(awk -F'|' '/^\|[[:space:]]*Phase 1[^0-9]/{gsub(/^[ \t]+|[ \t]+$/,"",$3); print tolower($3); exit}' \
             "$FIXTURE/.phased/active/bench/plan.md" 2>/dev/null)
    case "$EFFORT" in low|medium|high|xhigh|max) ;; *) EFFORT=high ;; esac
  fi
  for i in $(seq 1 "$RUNS"); do
    DIR="$WORK/$LABEL-$i"
    mkdir -p "$DIR"; cp -R "$FIXTURE"/. "$DIR"
    ( cd "$DIR" && git init -q && git add -A && git commit -qm init ) || exit 1
    case "$MODE" in
      goal)     PROMPT="$GOAL_PROMPT" ;;
      slim)     PROMPT="$SLIM_PROMPT" ;;
      slimgoal) PROMPT="$LIGHT_GOAL_PROMPT" ;;
      *)        PROMPT='/execute-phase-agent' ;;
    esac
    CONTRACT_SHA=$(sha "$PROMPT")

    echo "=== $LABEL run $i (model=$MODEL, mode=$MODE, effort=$EFFORT) ==="
    START=$(date +%s)
    JSON=$(cd "$DIR" && claude -p "$PROMPT" --model "$MODEL" --effort "$EFFORT" \
           --permission-mode auto \
           --max-budget-usd 50 --output-format json 2>"$DIR/stderr.log")
    END=$(date +%s)
    printf '%s' "$JSON" > "$DIR/result.json"

    read -r TURNS COST < <(printf '%s' "$JSON" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("num_turns", "?"), d.get("total_cost_usd", "?"))
except Exception:
    print("?", "?")')

    # External verification — never trust the session self-report
    GREEN=yes
    ( cd "$DIR" && python3 -m pytest tests/ -q >/dev/null 2>&1 ) || GREEN=no
    ( cd "$DIR" && python3 -m flake8 textutils/ tests/ >/dev/null 2>&1 ) || GREEN=no
    MARKED_X=no; grep -q '^- \[x\]' "$DIR/.phased/active/bench/plan.md" && MARKED_X=yes
    # Classify: success = [x] and externally green; false_done = [x] but red
    # (the failure mode the /goal guard targets); honest_fail = anything else
    # (e.g. an honest [!], or no outcome at all).
    if [ "$MARKED_X" = yes ] && [ "$GREEN" = yes ]; then OUTCOME=success
    elif [ "$MARKED_X" = yes ]; then OUTCOME=false_done
    else OUTCOME=honest_fail
    fi

    DUR=$((END - START))
    echo "$LABEL,$i,$OUTCOME,$TURNS,$COST,$DUR,$EFFORT,$CONTRACT_SHA" >> "$CSV"
    echo "    outcome=$OUTCOME turns=$TURNS cost=\$$COST duration=${DUR}s effort=$EFFORT"
  done
done

echo ""
echo "=== Results ($CSV) ==="
column -s, -t < "$CSV"
