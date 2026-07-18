#!/bin/bash
# Benchmark the phase-execution path on a fixed, well-specified phase.
# Each run: fresh copy of the fixture project -> one real claude -p session
# -> external verification of the Done criterion (pytest + flake8 + MEMORY state).
# Metrics from --output-format json: num_turns, total_cost_usd, duration_ms.
#
# Usage: bench.sh [runs_per_config] [config ...]
#   config format: label|model|mode      mode: plain | goal
#   default: 1 run each of sonnet-plain|sonnet|plain and sonnet-goal|sonnet|goal
set -u
TESTDIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE="$TESTDIR/fixture"
RUNS="${1:-1}"; shift 2>/dev/null || true
if [ "$#" -gt 0 ]; then CONFIGS=("$@"); else
  CONFIGS=("sonnet-plain|sonnet|plain" "sonnet-goal|sonnet|goal")
fi

GOAL_CONTRACT='Use the auto-phase skill to execute exactly ONE phase of .claude/MEMORY.md. Condition: MEMORY.md gains exactly one phase marked [x] with its Done criterion demonstrated in this conversation (tests and lint actually run), or one phase marked [!] with Issue and Attempted notes after the bounded fix attempts are exhausted, or no pending phase exists. No other phase may change state. Stop after 25 turns.'

WORK="$(mktemp -d)"
CSV="$WORK/results.csv"
echo "config,run,success,turns,cost_usd,duration_s" > "$CSV"

for CFG in "${CONFIGS[@]}"; do
  LABEL="${CFG%%|*}"; REST="${CFG#*|}"; MODEL="${REST%%|*}"; MODE="${REST#*|}"
  for i in $(seq 1 "$RUNS"); do
    DIR="$WORK/$LABEL-$i"
    mkdir -p "$DIR"; cp -R "$FIXTURE"/. "$DIR"
    ( cd "$DIR" && git init -q && git add -A && git commit -qm init ) || exit 1
    if [ "$MODE" = "goal" ]; then PROMPT="/goal $GOAL_CONTRACT"; else PROMPT='/auto-phase'; fi

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
    OK=yes
    ( cd "$DIR" && python3 -m pytest tests/ -q >/dev/null 2>&1 ) || OK=no
    ( cd "$DIR" && python3 -m flake8 textutils/truncate.py tests/test_truncate.py >/dev/null 2>&1 ) || OK=no
    grep -q '^- \[x\]' "$DIR/.claude/MEMORY.md" || OK=no

    DUR=$((END - START))
    echo "$LABEL,$i,$OK,$TURNS,$COST,$DUR" >> "$CSV"
    echo "    success=$OK turns=$TURNS cost=\$$COST duration=${DUR}s"
  done
done

echo ""
echo "=== Results ($CSV) ==="
column -s, -t < "$CSV"
