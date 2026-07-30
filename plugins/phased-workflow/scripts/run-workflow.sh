#!/bin/bash
# Phase loop for /run-workflow: one fresh `claude` session per phase.
#
# Resolves the active plan under .phased/, asks next-phase.py which phase is
# next, looks up its model/effort/cap in the execution config table, launches
# the session, and handles repair, blocked and no-progress outcomes. The skill
# runs this file; it is never read into the model's context.
#
# The PHASE_PROMPT / LIGHT_PROMPT / REPAIR_PROMPT assignments below are the
# shipped goal contracts: tests/orchestration/run_tests.sh and
# tests/benchmark/bench.sh extract them from here, so keep them as
# single-quoted one-line assignments.

# The selector ships in the same plugin directory as this launcher, so it can
# never be a different version than we expect. Resolve it relative to our own
# location ($(dirname "$0"), never ${BASH_SOURCE[0]} — this runs under zsh too,
# where BASH_SOURCE does not exist), and there is no need for ${CLAUDE_PLUGIN_ROOT}
# inside a script that can find itself.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
NEXT_PHASE_PY="$SCRIPT_DIR/next-phase.py"

# Sub-session prompts are slash commands. In a headless `claude -p` session a
# bare `/<skill>` resolves only against ~/.claude/commands/; a plugin-shipped
# skill registers as `/<plugin>:<skill>`, so the namespace prefix is REQUIRED or
# the session dies at once with "Unknown command: /<skill>". Derive the plugin
# name from our own plugin.json (found via SCRIPT_DIR), never retyped — with a
# literal fallback so a failed read can never reintroduce a bare slash.
# grep -o, not a greedy sed over the whole line: on a minified single-line
# plugin.json a greedy match would return the LAST "name" (the author's),
# while -o emits matches in order and head -1 keeps the first — the plugin's.
PLUGIN_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' \
  "$SCRIPT_DIR/../.claude-plugin/plugin.json" 2>/dev/null | head -1 \
  | sed 's/.*"\([^"]*\)"$/\1/')
PLUGIN_NAME=${PLUGIN_NAME:-phased-workflow}

# Every run ends with exactly ONE stable `EVENT: run-end` line, whatever the
# exit path. The parent Monitor terminates on this line, so an early exit —
# validation failure, no active plan, nothing left to do — must emit it too,
# not only the happy loop; the EXIT trap is what makes "exactly one per run"
# true by construction, and the flag keeps it single. Status is `ok` only when
# the launcher itself exits 0 AND every phase reached [x] — a validation
# failure on an all-[x] plan is still a stopped run. Before the plan (or the
# helpers) exist, it reports `stopped 0/0`. Counts come from the phase
# helpers, never a fresh grep of the plan.
RUN_END_EMITTED=""
LAUNCHER_RC=0
emit_run_end() {
  [ -n "$RUN_END_EMITTED" ] && return 0
  RUN_END_EMITTED=1
  DONE_COUNT=0; TOTAL_COUNT=0; RUN_STATUS=stopped
  if [ -n "$PLAN" ] && [ -f "$PLAN" ] && type phase_count >/dev/null 2>&1; then
    DONE_COUNT=$(phase_count x); DONE_COUNT=${DONE_COUNT:-0}
    TOTAL_COUNT=$(phase_lines | grep -c .); TOTAL_COUNT=${TOTAL_COUNT:-0}
    if [ "$LAUNCHER_RC" -eq 0 ] && ! phase_any ' ' && ! phase_any '!' \
       && ! phase_any '~' && ! phase_any '>'; then
      RUN_STATUS=ok
    fi
  fi
  echo "EVENT: run-end $RUN_STATUS $DONE_COUNT/$TOTAL_COUNT"
}
trap 'LAUNCHER_RC=$?; emit_run_end' EXIT

REPO_ROOT=$(git rev-parse --show-toplevel)

# Workspace create-or-attach: the launcher runs from anywhere. If the current
# root has no active plan, ask the selector for every reachable one (--plans).
# One plan in another checkout -> operate there; one plan on a branch with no
# checkout -> create its worktree under .claude/worktrees/ (announced: it is
# the one git mechanic worth a line); several plans -> list them and stop.
if ! find "$REPO_ROOT/.phased/active" -mindepth 2 -maxdepth 2 -name plan.md 2>/dev/null | grep -q . \
   && [ -f "$NEXT_PHASE_PY" ]; then
  PLANS=$(python3 "$NEXT_PHASE_PY" --plans 2>/dev/null | grep '^plan|')
  PLANS_COUNT=$(printf '%s' "$PLANS" | grep -c .)
  if [ "$PLANS_COUNT" -gt 1 ]; then
    echo "Several workflows reachable from here — relaunch from the one you mean:"
    printf '%s\n' "$PLANS"
    exit 1
  fi
  if [ "$PLANS_COUNT" -eq 1 ]; then
    PLAN_BRANCH=$(printf '%s' "$PLANS" | awk -F'|' '{print $4}')
    PLAN_CHECKOUT=$(printf '%s' "$PLANS" | awk -F'|' '{print $6}')
    if [ "$PLAN_CHECKOUT" = "-" ]; then
      PLAN_SLUG=$(printf '%s' "$PLANS" | awk -F'|' '{print $2}' \
        | sed 's|.*/\.phased/active/||; s|^[^:]*:\.phased/active/||; s|/plan\.md$||')
      PLAN_CHECKOUT="$REPO_ROOT/.claude/worktrees/$PLAN_SLUG"
      echo "NOTE: branch $PLAN_BRANCH has no checkout — creating its worktree at $PLAN_CHECKOUT."
      git worktree add "$PLAN_CHECKOUT" "$PLAN_BRANCH" || exit 1
      mkdir -p "$PLAN_CHECKOUT/.claude"
      [ -f "$REPO_ROOT/.claude/settings.local.json" ] \
        && cp "$REPO_ROOT/.claude/settings.local.json" "$PLAN_CHECKOUT/.claude/settings.local.json"
    else
      echo "NOTE: the active plan lives in $PLAN_CHECKOUT (branch $PLAN_BRANCH) — operating there."
    fi
    cd "$PLAN_CHECKOUT" || exit 1
    REPO_ROOT="$PLAN_CHECKOUT"
  fi
fi

# Resolve the active plan: exactly one .phased/active/<slug>/plan.md.
# Done with `find` rather than a glob on purpose — an unmatched glob is left
# literal by bash but ABORTS the script under zsh, which is the production
# shell on macOS.
PLAN_LIST=$(find "$REPO_ROOT/.phased/active" -mindepth 2 -maxdepth 2 -name plan.md 2>/dev/null)
PLAN_COUNT=$(printf '%s' "$PLAN_LIST" | grep -c .)

if [ "$PLAN_COUNT" -eq 0 ]; then
  echo "No active plan under $REPO_ROOT/.phased/active/ — run /write-workflow, or /import-workflow on an older plan."
  exit 1
fi
if [ "$PLAN_COUNT" -gt 1 ]; then
  echo "Several active plans under $REPO_ROOT/.phased/active/ — exactly one is expected:"
  printf '%s\n' "$PLAN_LIST"
  exit 1
fi

PLAN="$PLAN_LIST"
PLAN_DIR=$(dirname "$PLAN")
mkdir -p "$PLAN_DIR/log"

# Phase-state matching lives in ONE place. A plain "- [!]" bullet in a
# ## Notes section is prose, not a phase; before this was centralised such a
# bullet launched a real fable repair session at cap $300 and stopped the run.
# Every state match — including the ones already strict — goes through these
# helpers, so the "**Phase" anchor can never drift between call sites.
# phase_re emits ^- \[<state>\] \*\*Phase; the redundant \- escape is dropped.
# Defined BEFORE the validation gate so the run-end trap reports real counts
# even when the gate stops the run.
phase_re()    { printf '^- \\[%s\\] \\*\\*Phase' "$1"; }
phase_count() { grep -c "$(phase_re "$1")" "$PLAN" 2>/dev/null || true; }
phase_any()   { grep -q "$(phase_re "$1")" "$PLAN" 2>/dev/null; }
phase_lines() { grep -E '^- \[[ x!~>]\] \*\*Phase' "$PLAN" 2>/dev/null; }

# Pre-loop validation gate. next-phase.py --validate shares the selector's own
# regexes, so a plan it rejects is one the loop could not drive correctly. Print
# its output verbatim (no re-wording) and stop before spending a single session.
# If the selector is not beside us the install is broken elsewhere, but a missing
# validator must not itself abort the run — skip the gate with a NOTE instead.
if [ -f "$NEXT_PHASE_PY" ]; then
  VALIDATE_OUT=$(python3 "$NEXT_PHASE_PY" --validate "$PLAN" 2>&1)
  VALIDATE_RC=$?
  if [ "$VALIDATE_RC" -ne 0 ]; then
    echo "$VALIDATE_OUT"
    echo "Plan validation failed — fix the plan under .phased/active/ and relaunch."
    exit 1
  fi
  # Warnings never block, but computing them and discarding them would leave
  # the two-severity design half-mute — print every warning line.
  if printf '%s\n' "$VALIDATE_OUT" | grep -q 'warning:'; then
    printf '%s\n' "$VALIDATE_OUT" | grep 'warning:'
    echo "NOTE: plan validation reported warnings (non-blocking) — see above."
  fi
else
  echo "NOTE: next-phase.py not found beside the launcher — skipping plan validation."
fi

# /goal guard (Claude Code >= 2.1.139): each phase session runs under a native
# goal loop — an independent evaluator (small fast model) re-checks the exit
# condition after every turn, so a session cannot declare itself done before
# the plan shows the outcome. Older CLIs fall back to the plain skill prompt.
CLAUDE_VER=$(claude --version 2>/dev/null | awk '{print $1}')
if [ -n "$CLAUDE_VER" ] && [ "$(printf '%s\n' "2.1.139" "$CLAUDE_VER" | sort -V | head -1)" = "2.1.139" ]; then
  PHASE_PROMPT='/goal Use the execute-phase-agent skill to execute exactly ONE phase of the active plan under .phased/active/. Condition: the plan gains exactly one phase marked [x] with its Done criterion demonstrated in this conversation (tests and lint actually run), or one phase marked [!] with Issue and Attempted notes after the bounded fix attempts are exhausted, or -- when the skill baseline check finds tests or lint already red before the phase started -- either one earlier completed phase reopened from [x] to [!] with an Issue note naming the regression it introduced (attribution Case A), or the pending phase marked [~] with a Blocked note (attribution Case B), or no pending phase exists. Apart from a Case A reopen, no other phase may change state. Stop after 25 turns.'
  REPAIR_PROMPT='/goal Use the repair-phase skill on the first [!] phase of the active plan under .phased/active/. Condition: that phase is marked [x] with a Repaired note and its Done criterion demonstrated in this conversation, or it keeps [!] and gains a Repair attempted note, or no [!] phase exists. Stop after 25 turns.'
  # Light mode for Effort=low phases: no skill ritual — the goal contract
  # carries the chain invariants itself (bookkeeping notes included: what the
  # contract omits, the session silently drops). The one invariant it did NOT
  # carry was the per-phase commit: the clause used to forbid committing, so a
  # light phase completed its work but left it uncommitted, and a later full-skill
  # phase, seeing predecessors with no commits, inferred a repo-wide no-commit mode
  # and followed suit. The commit instruction now lives in the contract; S14 guards
  # the clause. Measured on the seeded toy fixture (n=3): ~37% cheaper and ~60% of
  # the wall time. That figure is the `slim` hardcoded control vs `plain`, the two
  # arms whose provenance survived the frozen-copy defect — not this shipped light
  # contract, whose "same external outcomes" was never measured against it. See
  # tests/benchmark/results/README.md. Hard phases keep the full ritual.
  LIGHT_PROMPT='/goal Execute the next pending [ ] phase of the active plan under .phased/active/ exactly as its Details describe. Before your first edit, run the tests and the linter: if they are already red, that failure is not yours -- stop without editing anything and attribute it. If it touches files listed in the > Files: note of a phase already marked [x], reopen THAT phase from [x] to [!] with an > Issue: note naming the regression. Otherwise mark the pending phase [~] with a > Blocked: note naming the failure signature. When in doubt, prefer [~]. Condition: the plan shows the pending phase marked [x] with > Done: and > Files: notes recorded, and its Done criterion demonstrated in this conversation (tests and lint actually run and green); or marked [!] with > Issue: and > Attempted: notes if you cannot complete it; or an earlier completed phase reopened to [!]; or the pending phase marked [~] on an unattributable red baseline; or no pending phase exists. When the phase is done, make exactly one commit for it -- the phase code and its own plan status update together, git add -A && git commit -m "wf(phase N): <title>" -- so the next phase starts from a clean tree. Stop after 25 turns.'
else
  echo "NOTE: claude ${CLAUDE_VER:-unknown} < 2.1.139 — /goal guard unavailable, using plain skill prompts."
  PHASE_PROMPT="/$PLUGIN_NAME:execute-phase-agent"
  REPAIR_PROMPT="/$PLUGIN_NAME:repair-phase"
  LIGHT_PROMPT=''   # light mode needs the goal guard; without it, full skill
fi

# Per-model steering, injected via --append-system-prompt so the goal
# contracts above stay byte-stable (the tests extract those assignments).
# Grounded in Anthropic's model-specific prompting guidance: a headless
# session's output is a log nobody reads live, so narration between tool
# calls is pure token spend; the per-model line damps each model's known
# drift (opus: scope creep, over-verification, eager subagents; sonnet:
# inventing what the spec left open; fable: re-deriving settled decisions).
STEER_COMMON='You run unattended: nobody reads your output live, it is stored as a log. Default to silence between tool calls -- one short line only when you find something load-bearing, change direction, or hit a blocker. Close with the required status line plus at most three sentences; never restate the plan or the phase text.'
STEER_OPUS='Deliver exactly the phase scope -- no extra features, refactors, or abstractions beyond what the phase asks. Do not verify beyond the Done criteria: one pass, no extra review rounds. Work directly; delegate to a subagent only for genuinely wide, independent exploration.'
STEER_SONNET='Execute the Details literally and completely. Make minor calls (naming, formatting) yourself and note them; if the phase leaves a real design decision unspecified, do not invent one -- close the phase [!] with an Issue note naming the gap.'
STEER_FABLE='When you have enough information to act, act -- do not re-derive decisions the plan already settled or survey alternatives you will not pursue. Base every progress or completion claim on a tool result from this session.'

# Notes block of the FIRST [!] phase only, however long it is. Used for the
# idempotency marker: a fixed `grep -A<n>` window is unreliable, because
# /repair-phase extends `> Attempted:` on every round and pushes
# `> Repair attempted:` further down — and a plain grep would also match a
# stale marker belonging to a DIFFERENT [!] phase.
first_bang_block() {
  awk '
    /^- \[[ x!~>]\] \*\*Phase/ { if (seen) exit }
    /^## /  { if (seen) exit }
    /^- \[!\] \*\*Phase/ { seen = 1 }
    seen { print }
  ' "$PLAN" 2>/dev/null
}

# Count only real phase lines: a stray "- [ ]" checkbox in Notes is not a phase.
# NOTE: grep -c prints 0 itself on no match (exit 1) — do NOT add "|| echo 0", it would double the output
REMAINING=$(phase_count ' ')
REMAINING=${REMAINING:-0}   # unreadable file → empty var → treat as 0

if [ "$REMAINING" -eq 0 ]; then
  echo "No phases remaining. Run /finalize-workflow."
  exit 0
fi

echo "Found $REMAINING phases to execute."
echo ""

for i in $(seq 1 $REMAINING); do
  # Re-read the plan to get current state
  if ! phase_any ' '; then
    echo ""
    echo "All phases completed!"
    break
  fi

  # Per-iteration flags. MUST be initialised before the selector below, which
  # can clear RUN_PHASE.
  REPAIRED_THIS_ROUND=0
  RUN_PHASE=1

  # Ask next-phase.py which phase is next — the SAME selector the sub-session
  # uses (it honours the strict phase order and [>] resumes). Using plain
  # file order here would pick a different phase than the one that actually
  # runs, and apply the wrong row's model/effort/cap to it.
  # Keep stderr (2>&1, not 2>/dev/null): if the selector cannot run, the reason
  # (missing file, syntax error, unreadable plan) must be visible in the NOTE
  # the *) fallback arm prints, not swallowed.
  REC_RAW=$(python3 "$NEXT_PHASE_PY" "$PLAN" 2>&1)
  REC=$(printf '%s\n' "$REC_RAW" | sed -n 's/^recommendation: //p')
  case "$REC" in
    next:*)
      NEXT_PHASE=$(printf '%s' "$REC" | sed -n 's/^next: \([0-9]\{1,\}\).*/\1/p') ;;
    resume-candidate:*)
      NEXT_PHASE=$(printf '%s' "$REC" | sed -n 's/^resume-candidate: \([0-9]\{1,\}\).*/\1/p') ;;
    done*)
      echo ""
      echo "All phases completed!"
      break ;;
    attention:*)
      # A [!] or [~] phase blocks the plan. Do NOT start a new phase session --
      # but do not stop here either: this is the relaunch case, where a previous
      # run left a failed phase behind. The [!] / [~] handling further down owns
      # the decision (repair once, or stop citing the existing
      # 'Repair attempted:' marker). Short-circuiting here would make the
      # one-repair-per-phase path unreachable on relaunch.
      echo ""
      echo "next-phase.py reports: $REC — no phase can start; handling it below."
      RUN_PHASE=0 ;;
    blocked:*)
      echo ""
      echo "Stopping — next-phase.py reports: $REC"
      break ;;
    *)
      # Script unavailable or unexpected output: fall back to file order.
      # This is the serious fallback and says so: file order ignores [>]
      # resumes and the attention/blocked handling, so the launcher may apply
      # one phase's model, effort and cap to a different phase than the
      # sub-session actually runs.
      echo "NOTE: next-phase.py returned nothing usable ('$(printf '%s' "$REC_RAW" | head -1)') — falling back to plan file order. This ignores [>] resumes and attention/blocked handling, so the model, effort and cap picked here may belong to a different phase than the sub-session executes."
      NEXT_PHASE=$(grep "$(phase_re ' ')" "$PLAN" | head -1 | sed 's/^- \[.\] \*\*Phase \([0-9]\{1,\}\).*/\1/') ;;
  esac

  if [ "$RUN_PHASE" -eq 1 ] && [ -z "$NEXT_PHASE" ]; then
    echo "Could not determine the next phase. Stopping — check the active plan under .phased/active/."
    break
  fi

  # Snapshot completed-phase count BEFORE the run (progress guard)
  BEFORE_DONE=$(phase_count x)
  BEFORE_DONE=${BEFORE_DONE:-0}

  # Look up model and effort from the execution config table, by COLUMN
  # (| Phase | Effort | Model |) rather than by grepping the whole
  # row for keywords — "xhigh" contains "high", and a keyword grep would also
  # read a value out of the wrong column.
  # Exact row match: "Phase 1" must not match "Phase 10".
  # NOTE: ${NEXT_PHASE} must stay braced — in zsh (the default macOS shell)
  # `$NEXT_PHASE[^0-9]` parses as an array subscript and aborts the command
  # with "bad math expression", leaving MODEL_LINE empty and silently
  # defaulting every phase's model, effort and cap.
  MODEL_LINE=$(grep -E "^\|[[:space:]]*Phase ${NEXT_PHASE}[^0-9]" "$PLAN" | head -1)
  col() { printf '%s\n' "$MODEL_LINE" | awk -F'|' -v n="$1" \
            '{gsub(/^[ \t]+|[ \t]+$/, "", $n); print tolower($n)}'; }

  EFFORT=$(col 3)
  MODEL=$(col 4)

  # Validate against what this launcher actually supports; anything else
  # falls back to the safe default. An empty cell is a validation error as of
  # the --validate gate above, so by the time we reach here the cause is a
  # value this launcher does not support, not a missing table row.
  case "$MODEL" in
    fable|sonnet|opus) ;;
    *) echo "NOTE: unrecognised Model '${MODEL:-<empty>}' from the config table — using 'opus'."; MODEL="opus" ;;
  esac
  case "$EFFORT" in
    low|medium|high|xhigh|max) ;;
    *) echo "NOTE: unrecognised Effort '${EFFORT:-<empty>}' from the config table — using 'high'."; EFFORT="high" ;;
  esac

  # Cap per phase (runaway-loop safety net, NOT a real spend limit on subscription plans).
  # Generous defaults so normal phases never trip the cap; trips signal a bug, not a budget issue.
  case "$EFFORT" in
    low)    BUDGET=50 ;;
    medium) BUDGET=100 ;;
    high)   BUDGET=200 ;;
    xhigh)  BUDGET=250 ;;
    max)    BUDGET=300 ;;
  esac

  # Fable burns more notional dollars per token — double the cap so the
  # safety net keeps the same "only trips on a real bug" semantics.
  if [ "$MODEL" = "fable" ]; then
    BUDGET=$((BUDGET * 2))
  fi

  # Effort=low + goal guard available → light mode (slim contract, no skill)
  RUN_PROMPT="$PHASE_PROMPT"
  MODE_LABEL="full"
  if [ -n "$LIGHT_PROMPT" ] && [ "$EFFORT" = "low" ]; then
    RUN_PROMPT="$LIGHT_PROMPT"
    MODE_LABEL="light"
  fi

  # Steering for the model this phase runs on (see the STEER_* block above).
  case "$MODEL" in
    fable)  STEER="$STEER_COMMON $STEER_FABLE" ;;
    sonnet) STEER="$STEER_COMMON $STEER_SONNET" ;;
    *)      STEER="$STEER_COMMON $STEER_OPUS" ;;
  esac

  # Budget flag assembled once; empty array = no cap (raw subscription mode)
  BUDGET_ARGS=()
  if [ -z "$RUN_WORKFLOW_NO_BUDGET" ]; then
    BUDGET_ARGS=(--max-budget-usd "$BUDGET")
    CAP_LABEL="runaway-cap: \$$BUDGET"
  else
    CAP_LABEL="cap: none (RUN_WORKFLOW_NO_BUDGET=1)"
  fi

  # RUN_PHASE=0 means the selector found no startable phase (a [!]/[~] blocks
  # the plan). Skip the phase session and drop straight to the repair handling.
  if [ "$RUN_PHASE" -eq 1 ]; then
    echo "========================================="
    echo "Phase $NEXT_PHASE — model: $MODEL, effort: $EFFORT, mode: $MODE_LABEL, $CAP_LABEL"
    echo "========================================="
    # Tee the session into the plan's log directory: this transcript is the
    # only record of what a headless sub-session actually did, and
    # /repair-phase reads it when a phase comes back [!].
    # pipefail, NOT ${PIPESTATUS[0]}: zsh does not define PIPESTATUS (it has a
    # 1-indexed $pipestatus instead), and this script is also run under zsh.
    # Without it $? would be tee's status and every non-zero claude exit would
    # be read as success.
    set -o pipefail
    # --append-system-prompt LAST: the orchestration tests assert the
    # model/effort/permission/cap sequence contiguously.
    claude -p "$RUN_PROMPT" \
      --model "$MODEL" \
      --effort "$EFFORT" \
      --permission-mode auto \
      "${BUDGET_ARGS[@]}" \
      --append-system-prompt "$STEER" 2>&1 | tee "$PLAN_DIR/log/phase-$NEXT_PHASE.txt"

    CLAUDE_EXIT=$?
    set +o pipefail
    if [ "$CLAUDE_EXIT" -ne 0 ]; then
      echo ""
      echo "claude exited with code $CLAUDE_EXIT. Stopping."
      echo "Check the active plan under .phased/active/ — reset any stale [>] phase to [ ] before relaunching."
      break
    fi
  fi

  # Check for issues — one fresh-eyes repair attempt before stopping
  if phase_any '!'; then
    # Stable event line: the parent Monitor turns this into a notification.
    # Fires once per loop iteration that finds a [!] phase, before the repair
    # session. The phase number comes from phase_re — the shared state anchor —
    # not a second private regex. The sed is anchored to the phase-line prefix:
    # a greedy `.*Phase` would read a "Phase 10" inside the TITLE as the number.
    FAILED_PHASE=$(grep "$(phase_re '!')" "$PLAN" | head -1 | sed 's/^- \[.\] \*\*Phase \([0-9]\{1,\}\).*/\1/')
    echo "EVENT: phase-failed $FAILED_PHASE"
    if first_bang_block | grep -q 'Repair attempted:'; then
      echo ""
      echo "A phase failed [!] and repair was already attempted. Stopping for review."
      echo "Fix the issue (or delete its 'Repair attempted:' note to grant another repair round), then run /run-workflow again."
      break
    fi

    # Repair runs on the strongest model: it is by definition the case where
    # the phase's model already failed once. Fallback to opus only if the
    # fable session cannot start (e.g. no credits — claude exits non-zero
    # without touching the plan).
    echo ""
    echo "A phase failed [!] — launching one fresh-eyes repair session (fable)..."
    REPAIR_BUDGET_ARGS=()
    [ -z "$RUN_WORKFLOW_NO_BUDGET" ] && REPAIR_BUDGET_ARGS=(--max-budget-usd 300)
    set -o pipefail
    claude -p "$REPAIR_PROMPT" \
      --model fable \
      --effort max \
      --permission-mode auto \
      "${REPAIR_BUDGET_ARGS[@]}" \
      --append-system-prompt "$STEER_COMMON $STEER_FABLE" 2>&1 | tee "$PLAN_DIR/log/repair-fable.txt"
    REPAIR_EXIT=$?
    set +o pipefail

    # Only fall back if the fable session never ran at all (non-zero exit AND no
    # outcome written). If it ran and gave up, it left the marker — do not
    # spend a second repair on the same phase.
    if [ "$REPAIR_EXIT" -ne 0 ] && ! first_bang_block | grep -q 'Repair attempted:'; then
      echo "Fable repair session did not run (exit $REPAIR_EXIT) — retrying with opus..."
      REPAIR_BUDGET_ARGS=()
      [ -z "$RUN_WORKFLOW_NO_BUDGET" ] && REPAIR_BUDGET_ARGS=(--max-budget-usd 200)
      claude -p "$REPAIR_PROMPT" \
        --model opus \
        --effort max \
        --permission-mode auto \
        "${REPAIR_BUDGET_ARGS[@]}" \
        --append-system-prompt "$STEER_COMMON $STEER_OPUS" 2>&1 | tee "$PLAN_DIR/log/repair-opus.txt"
    fi

    if phase_any '!'; then
      echo ""
      echo "Repair failed. Stopping for review — see the 'Repair attempted:' note in the plan."
      break
    fi
    echo "Repair succeeded — continuing with next phase."
    REPAIRED_THIS_ROUND=1
  fi

  if phase_any '~'; then
    # Stable event line (see phase-failed above): phase number via phase_re,
    # sed anchored to the phase-line prefix like phase-failed's.
    BLOCKED_PHASE=$(grep "$(phase_re '~')" "$PLAN" | head -1 | sed 's/^- \[.\] \*\*Phase \([0-9]\{1,\}\).*/\1/')
    echo "EVENT: phase-blocked $BLOCKED_PHASE"
    echo ""
    echo "A phase is blocked [~]. Stopping for review."
    break
  fi

  # Progress guard: a successful run must either complete a phase ([x] count
  # grows) or leave a resumable WIP ([>] + WIP note). Anything else means the
  # session died leaving the phase stuck — looping again would burn runs.
  AFTER_DONE=$(phase_count x)
  AFTER_DONE=${AFTER_DONE:-0}
  # A Case A reopen (a completed phase sent back to [!] by a later phase's
  # baseline check) makes the [x] count DROP, so a successful repair only
  # restores it — real work happened, but the count did not grow. Skip the
  # guard when a repair landed this round, or the run would stop on a
  # misleading "no progress".
  if [ "$AFTER_DONE" -le "$BEFORE_DONE" ] && [ "$REPAIRED_THIS_ROUND" -eq 0 ]; then
    if phase_any '>' && grep -q '^[[:space:]]*> WIP:' "$PLAN" 2>/dev/null; then
      echo "Phase left in WIP state — next session will resume it."
    else
      echo ""
      echo "No progress in the last run (phase stuck as [>]?). Stopping."
      echo "Check the active plan under .phased/active/ — reset stale [>] phases to [ ] and relaunch."
      break
    fi
  fi

  echo ""
done

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo ""
phase_lines | head -20
echo ""
# One commit per phase now, so the run's output is history, not a dirty tree.
# The base is the commit that ADDED the plan — on an adopted branch it is what
# separates this workflow from the work that preceded it.
PLAN_BASE=$(git log -1 --diff-filter=A --format=%H -- "$PLAN" 2>/dev/null)
if [ -n "$PLAN_BASE" ]; then
  echo "Phase commits (consolidate via /finalize-workflow):"
  git log --oneline "$PLAN_BASE"..HEAD | head -15
else
  echo "Working tree changes (uncommitted — consolidate via /finalize-workflow):"
  git diff --stat HEAD | tail -15
fi

# Rolling-wave reminder. The roadmap lives in its own file, one level above
# active/, so it outlives the macro being worked (finalize moves the plan
# directory into done/) and so a roadmap bullet can never be mistaken for a
# phase line.
ROADMAP="$REPO_ROOT/.phased/roadmap.md"
if [ -f "$ROADMAP" ]; then
  echo ""
  echo "Roadmap (pending macro-phases — after /finalize-workflow, detail the next one with /write-workflow):"
  grep '^- ' "$ROADMAP" | head -10
fi

# Stable event line: exactly one per run, after the whole summary — it is
# deliberately the launcher's last word. The emitter and its EXIT trap live at
# the top of this file; the explicit call here keeps the happy path readable,
# the trap covers every early exit, and the flag keeps the line single.
emit_run_end
