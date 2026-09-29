#!/bin/bash
# Does Sonnet 5.5 earn a place back in the palette for mechanical phases?
# Sonnet left in 6.13.0 on Sonnet 5-era field experience; mechanical work has
# run as opus/low since. This measures the two against each other on the
# shipped /goal contract, on both fixtures: `fixture` (plain, sanity and cost)
# and `fixture-seeded` (a hidden edge case the Done criterion catches).
#
# Decision rule, fixed before the numbers: Sonnet returns for mechanical
# phases only if a sonnet arm matches opus/low on seeded success with no
# false_done, at lower mean cost. Otherwise the exclusion stands, re-measured.
#
# Usage: sonnet55.sh [runs_per_arm]   (default 3 → 24 paid sessions)
set -u
TESTDIR="$(cd "$(dirname "$0")" && pwd)"
RUNS="${1:-3}"
STAMP="$(date +%Y-%m-%d)"
ARMS=(
  "opus55-low|claude-opus-5-5|goal|low"
  "opus55-medium|claude-opus-5-5|goal|medium"
  "sonnet55-medium|claude-sonnet-5-5|goal|medium"
  "sonnet55-high|claude-sonnet-5-5|goal|high"
)
for F in fixture fixture-seeded; do
  BENCH_FIXTURE="$TESTDIR/$F" \
  BENCH_OUT="$TESTDIR/results/run-$STAMP-sonnet55-$F" \
    "$TESTDIR/bench.sh" "$RUNS" "${ARMS[@]}" || exit 1
done
