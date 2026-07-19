#!/bin/bash
# Benchmark the phase-execution path on a fixed, well-specified phase.
# Each run: fresh copy of the fixture project -> one real claude -p session
# -> external verification of the Done criterion (pytest + flake8 + MEMORY state).
# Metrics from --output-format json: num_turns, total_cost_usd, duration_ms.
#
# Usage: bench.sh [runs_per_config] [config ...]
#   config format: label|model|mode      mode: plain | goal | slim | slimgoal
#     plain    = full auto-phase skill, no guard
#     goal     = full auto-phase skill under the /goal guard
#     slim     = minimal prompt, NO skill discipline, no guard
#     slimgoal = minimal prompt, discipline carried ONLY by the /goal contract
#   default: 1 run each of sonnet-plain|sonnet|plain and sonnet-goal|sonnet|goal
set -u
TESTDIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE="${BENCH_FIXTURE:-$TESTDIR/fixture}"
RUNS="${1:-1}"; shift 2>/dev/null || true
if [ "$#" -gt 0 ]; then CONFIGS=("$@"); else
  CONFIGS=("sonnet-plain|sonnet|plain" "sonnet-goal|sonnet|goal")
fi

GOAL_CONTRACT='Use the auto-phase skill to execute exactly ONE phase of .claude/MEMORY.md. Condition: MEMORY.md gains exactly one phase marked [x] with its Done criterion demonstrated in this conversation (tests and lint actually run), or one phase marked [!] with Issue and Attempted notes after the bounded fix attempts are exhausted, or no pending phase exists. No other phase may change state. Stop after 25 turns.'

# Slim arms: no skill at all. The plain-slim prompt carries only the task;
# the slim-goal contract carries the discipline the skill would otherwise
# provide (~450 chars vs the ~9.5KB skill body).
SLIM_PROMPT='Execute the next pending [ ] phase in .claude/MEMORY.md: implement what it describes, then update MEMORY.md marking that phase [x] with > Done: and > Files: notes (or [!] with an > Issue: note if you cannot complete it). Do not commit anything.'
SLIM_GOAL_CONTRACT='Execute the next pending [ ] phase of .claude/MEMORY.md exactly as its Details describe. Condition: MEMORY.md shows that phase marked [x] with > Done: and > Files: notes recorded, and its Done criterion demonstrated in this conversation (tests and lint actually run and green); or marked [!] with > Issue: and > Attempted: notes if you cannot complete it; or no pending phase exists. No other phase may change state. Never commit. Stop after 25 turns.'

WORK="$(mktemp -d)"
CSV="$WORK/results.csv"
echo "config,run,outcome,turns,cost_usd,duration_s" > "$CSV"

for CFG in "${CONFIGS[@]}"; do
  LABEL="${CFG%%|*}"; REST="${CFG#*|}"; MODEL="${REST%%|*}"; MODE="${REST#*|}"
  for i in $(seq 1 "$RUNS"); do
    DIR="$WORK/$LABEL-$i"
    mkdir -p "$DIR"; cp -R "$FIXTURE"/. "$DIR"
    ( cd "$DIR" && git init -q && git add -A && git commit -qm init ) || exit 1
    case "$MODE" in
      goal)     PROMPT="/goal $GOAL_CONTRACT" ;;
      slim)     PROMPT="$SLIM_PROMPT" ;;
      slimgoal) PROMPT="/goal $SLIM_GOAL_CONTRACT" ;;
      *)        PROMPT='/auto-phase' ;;
    esac

    echo "=== $LABEL run $i (model=$MODEL, mode=$MODE) ==="
    START=$(date +%s)
    JSON=$(cd "$DIR" && claude -p "$PROMPT" --model "$MODEL" --permission-mode auto \
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
    MARKED_X=no; grep -q '^- \[x\]' "$DIR/.claude/MEMORY.md" && MARKED_X=yes
    # Classify: success = [x] and externally green; false_done = [x] but red
    # (the failure mode the /goal guard targets); honest_fail = anything else
    # (e.g. an honest [!], or no outcome at all).
    if [ "$MARKED_X" = yes ] && [ "$GREEN" = yes ]; then OUTCOME=success
    elif [ "$MARKED_X" = yes ]; then OUTCOME=false_done
    else OUTCOME=honest_fail
    fi

    DUR=$((END - START))
    echo "$LABEL,$i,$OUTCOME,$TURNS,$COST,$DUR" >> "$CSV"
    echo "    outcome=$OUTCOME turns=$TURNS cost=\$$COST duration=${DUR}s"
  done
done

echo ""
echo "=== Results ($CSV) ==="
column -s, -t < "$CSV"
