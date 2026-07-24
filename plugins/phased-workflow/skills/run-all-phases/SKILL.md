---
description: Run all remaining phases autonomously — launches a new claude session per phase with correct model
allowed-tools: Bash, Read
---

# Run All Phases

Launches `/auto-phase` in a loop, one new Claude session per phase. Each session gets:

- A **fresh context window** (low token cost, high quality)
- **Model defaults to opus**; the execution config table can override per phase: `sonnet` when the pre-flight review marks the phase as mechanical, well-specified and trivial; `fable` when it marks the phase as genuinely hard (architecture, hairy debugging, multi-file consistency, novel design) — subject to credit availability. If in doubt → opus.
- **`auto` permission mode**: each sub-session uses Claude Code's auto-mode classifier, which decides per-action what's safe. It auto-concedes routine local operations in project scope (git status/log/diff/show, edits in the working directory, push to the working branch, manifest-driven installs like `pip install -r requirements.txt`) and **blocks the dangerous categories**: force-push, push to default branch, irreversible destruction of pre-existing files, install of agent-chosen packages (typosquat risk), production deploys, data exfiltration, `curl | bash`, self-modification of agent config. No manual allowlist to maintain; if the classifier blocks something, the session reports it cleanly.

Before launching the loop, this skill performs a **pre-flight review of MEMORY.md** to make sure every remaining phase is concrete enough for autonomous execution. If a phase looks exploratory or vague, the skill stops and asks you targeted questions to make it precise — only after you confirm the refined plan does the loop start.

**Model tip:** invoke `/run-all-phases` itself from a chat on **opus at `xhigh` effort**. The bash loop consumes no model, and the pre-flight review — while pure judgment work — ends in an explicit confirmation from you, so a misjudgement gets caught before the loop starts. Fable's premium belongs on the phases the pre-flight actually marks `fable`, and on repair, where nobody is watching.

**/goal guard (Claude Code ≥ 2.1.139):** each phase and repair session is launched as `claude -p "/goal <contract>"` instead of a bare skill prompt. The native goal loop adds an independent per-turn evaluator: completion is decided by a fresh small model reading the transcript, not by the session that did the work. This turns the skill's bounded-loop instructions into harness-enforced behavior — premature "I'm done" exits and silent give-ups get sent back to work. A 25-turn clause in the contract bounds the loop. Older CLIs fall back automatically to the plain skill prompt.

**Light mode (Effort=low phases):** phases the pre-flight marked `low` run WITHOUT the auto-phase skill — a slim `/goal` contract carries all the chain invariants itself (Done demonstrated with tests+lint green, `> Done:`/`> Files:` notes recorded, `[!]` with notes on failure, no commits). Measured on the seeded benchmark fixture: same external outcomes as the full ritual, ~40% cheaper, half the wall time. The full skill remains the default for `medium`/`high`/`max` phases and, always, on CLIs without the goal guard.

**Usage:** `/run-all-phases`

**Budget control:** The `--max-budget-usd` flag is a runaway-loop safety net, NOT a real spend cap when on a subscription plan (Pro / Max / Team). On subscription plans, you don't pay per token — quota is the 5-hour rolling message window, not dollars. The flag computes a notional cost as if API-priced and stops the session if exceeded; that protects against bugged loops, but with values too low it triggers spuriously on legitimate large phases.

The script reads the cap-per-phase from the effort level in the config table:
- low effort → $50 max per phase
- medium effort → $100 max per phase
- high effort → $200 max per phase
- xhigh effort → $250 max per phase
- max effort → $300 max per phase

**The Effort column drives three things**, not just the cap: it is passed to the sub-session as `--effort` (so it really sets the model's reasoning depth), it selects light mode at `low`, and it sets the cap above. A phase with no row in the table — or a plan with no table — defaults to `high`.

Phases marked `fable` get a **doubled cap** (fable burns more notional dollars per token — same "only trips on a real bug" semantics). The repair session runs capped at $300 (fable) / $200 (opus fallback).

These are intentionally generous so a normal phase never trips them. If a phase actually hits its cap, that's a signal something is wrong (infinite loop, rabbit hole) — investigate before relaunching, don't just bump the cap.

If you want NO cap at all (raw subscription mode), set the env var `RUN_ALL_PHASES_NO_BUDGET=1` before invoking — the script omits `--max-budget-usd` entirely.

**Token optimization:** Each phase runs in an isolated session. Default is opus. Sonnet only kicks in when the pre-flight review has explicitly marked a phase as `sonnet` (mechanical, well-specified, trivial); fable only when it has marked the phase as `fable` (genuinely hard). Fable phases run with a doubled runaway-cap. No wasted context from prior phases.

## Pre-flight review (MANDATORY — do this BEFORE running the script)

Before launching the bash loop, the agent executing this skill MUST:

1. **Read** `.claude/MEMORY.md`.
2. For every remaining `[ ]` phase, evaluate whether it is **autonomous-ready**. A phase is autonomous-ready when ALL of the following hold:
   - The objective is **concrete and verifiable**, not exploratory. Reject phrases like "explore", "investigate", "understand", "figure out", "decide", "evaluate options".
   - The **scope** is bounded: specific files/modules are named, OR a clear discovery rule is given (e.g. "all files matching X that import Y").
   - There is a **measurable done criterion**: a test passes, a specific output appears, a check returns true, a file matches a shape. "Looks good" or "is clean" are not measurable.
   - **External decisions are pre-made**: no choices that require human judgment mid-flight (library selection, API design, naming conventions, tradeoffs).
   - **Pattern reference for non-trivial code**: if the phase asks the agent to write or modify code that follows an established pattern in the repo (new endpoint, new model, new component, new service, new view — anything where "we usually do it like X here"), the phase should cite **1–2 existing examples to copy-adapt from**, with file paths. If the pattern is genuinely standard/library-level (e.g. "add a unit test using pytest"), no reference is needed.

   **Macro-split check**: if the plan has more than ~10 phases, or a phase fails these checks *because its shape depends on an earlier phase's outcome* (not on human judgment), do NOT refine blindly — propose splitting into macro-phases per the autonomous addendum ("Macro-phases"): detail only the first macro as the Work Plan, move the rest to a `## Roadmap` section (plain bullets, inert for this script). One `/run-all-phases` + `/finalize-workflow` per macro; the next `/write-workflow` details the next Roadmap entry with hindsight.
3. If **any** phase fails the check, **stop the script** and refine interactively:
   - Ask the user **one targeted question at a time** (not a wall of questions).
   - Each question should turn one specific vague element into something concrete.
   - **When the missing element is a pattern reference**, ask the user directly: *"Phase X implements <thing>. Do you have an example in the repo I should copy the pattern from? (a file path, a function, a similar feature)"*. If the user doesn't have one or doesn't remember, offer to search: propose 2–3 candidate files based on the phase description so the user can confirm or correct. Only mark the phase as autonomous-ready once the reference is recorded in the phase description (e.g. "...following the pattern in `path/to/example.py:func`").
   - After answers, propose a rewritten phase and confirm it before moving to the next vague phase.
4. **Permission scope check.** Sub-sessions run with `--permission-mode auto`. Auto mode auto-concedes routine local ops in project scope but BLOCKS several categories — the canonical list is in `~/.claude/workflow-refs/common.md` ("Auto-mode blocked categories"). Read it, then for each phase ask whether executing it would need a blocked category.

   For each phase that would need one, **stop and report it to the user clearly**, e.g.:
   > "Phase 3 says 'deploy to prod after tests pass'. Auto mode blocks production deploys. Options: (a) rephrase the phase to stop before the deploy — you deploy manually after, (b) remove the phase from the autonomous run, (c) execute that phase manually outside /run-all-phases. What do you prefer?"

   Apply the user's choice before moving on. Never silently rewrite a phase to drop a forbidden operation — that would just hide the problem.

5. When all phases are autonomous-ready AND scope-safe, **assess complexity** for model selection:
   - Mark a phase as **`sonnet`** when ALL three hold — the self-correction net (convergence loop, independent review, fable repair) makes the cheaper executor safe here:
     - **Well-specified**: `Details:` leaves no design decision open (they were pre-made in the plan);
     - **Solid pattern reference**: a concrete `Pattern:` example to copy-adapt, or genuinely library-standard work;
     - **Testable logic**: the `Done:` criterion is enforced by tests the phase writes and runs — failures get caught by the loop, not by the user.

     Classic fits: mechanical changes (renames, extractions, header updates) AND well-patterned implementations (a new endpoint/model/handler closely following a cited example). The executor doesn't need to be brilliant — the plan carries the intelligence, the loop carries the safety.
   - Is this phase **genuinely hard** — architectural change, hairy debugging, multi-file consistency, novel design with no clean pattern reference? → mark it as **`fable`** (subject to the user having credits for it; if unsure about credits, ask once during the pre-flight summary).
   - Everything else → **`opus`** (or unspecified, which defaults to opus): design judgment left inside the phase, weak or missing pattern reference, poorly testable output (UI/declarative), cross-file consistency concerns.
   - **When in doubt, choose opus.** Economics note: a sonnet phase that fails costs a fable repair — sonnet pays only where first-pass success is likely. The safety net caps the damage; it doesn't make failures free.
6. **Rewrite MEMORY.md** with the refined phases (update phase descriptions, done criteria, AND the execution config table — create the table if the plan doesn't have one, e.g. interactive-format plans, since it drives model and budget per phase).
7. Show the user a short summary of the final phase list (with the model chosen for each, and a note about any allowlist deviations from step 4) and ask explicit confirmation ("vai" / "ok" / "procedi") before launching the bash script.
8. **Do NOT skip this step.** If the user's MEMORY.md is already precise, the review is fast (one pass, one confirmation). If it isn't, this is exactly where the value is — without it, vague phases turn into wasted autonomous runs.

## Execution

Once the pre-flight review is complete and the user has confirmed, read MEMORY.md, count remaining `[ ]` phases, then run this bash script:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
MEMORY="$REPO_ROOT/.claude/MEMORY.md"

if [ ! -f "$MEMORY" ]; then
  echo "No MEMORY.md found at $MEMORY"
  exit 1
fi

# /goal guard (Claude Code >= 2.1.139): each phase session runs under a native
# goal loop — an independent evaluator (small fast model) re-checks the exit
# condition after every turn, so a session cannot declare itself done before
# MEMORY.md shows the outcome. Older CLIs fall back to the plain skill prompt.
CLAUDE_VER=$(claude --version 2>/dev/null | awk '{print $1}')
if [ -n "$CLAUDE_VER" ] && [ "$(printf '%s\n' "2.1.139" "$CLAUDE_VER" | sort -V | head -1)" = "2.1.139" ]; then
  PHASE_PROMPT='/goal Use the auto-phase skill to execute exactly ONE phase of .claude/MEMORY.md. Condition: MEMORY.md gains exactly one phase marked [x] with its Done criterion demonstrated in this conversation (tests and lint actually run), or one phase marked [!] with Issue and Attempted notes after the bounded fix attempts are exhausted, or -- when the skill baseline check finds tests or lint already red before the phase started -- either one earlier completed phase reopened from [x] to [!] with an Issue note naming the regression it introduced (attribution Case A), or the pending phase marked [~] with a Blocked note (attribution Case B), or no pending phase exists. Apart from a Case A reopen, no other phase may change state. Stop after 25 turns.'
  REPAIR_PROMPT='/goal Use the repair-phase skill on the first [!] phase of .claude/MEMORY.md. Condition: that phase is marked [x] with a Repaired note and its Done criterion demonstrated in this conversation, or it keeps [!] and gains a Repair attempted note, or no [!] phase exists. Stop after 25 turns.'
  # Light mode for Effort=low phases: no skill ritual — the goal contract
  # carries every chain invariant itself (bookkeeping notes included: what
  # the contract omits, the session silently drops). Measured on the seeded
  # fixture: same external outcomes as the full skill, ~40% cheaper, half
  # the wall time. Hard phases keep the full ritual.
  LIGHT_PROMPT='/goal Execute the next pending [ ] phase of .claude/MEMORY.md exactly as its Details describe. Before your first edit, run the tests and the linter: if they are already red, that failure is not yours -- stop without editing anything and attribute it. If it touches files listed in the > Files: note of a phase already marked [x], reopen THAT phase from [x] to [!] with an > Issue: note naming the regression. Otherwise mark the pending phase [~] with a > Blocked: note naming the failure signature. When in doubt, prefer [~]. Condition: MEMORY.md shows the pending phase marked [x] with > Done: and > Files: notes recorded, and its Done criterion demonstrated in this conversation (tests and lint actually run and green); or marked [!] with > Issue: and > Attempted: notes if you cannot complete it; or an earlier completed phase reopened to [!]; or the pending phase marked [~] on an unattributable red baseline; or no pending phase exists. Never commit. Stop after 25 turns.'
else
  echo "NOTE: claude ${CLAUDE_VER:-unknown} < 2.1.139 — /goal guard unavailable, using plain skill prompts."
  PHASE_PROMPT='/auto-phase'
  REPAIR_PROMPT='/repair-phase'
  LIGHT_PROMPT=''   # light mode needs the goal guard; without it, full skill
fi

# Notes block of the FIRST [!] phase only, however long it is. Used for the
# idempotency marker: a fixed `grep -A<n>` window is unreliable, because
# /repair-phase extends `> Attempted:` on every round and pushes
# `> Repair attempted:` further down — and a plain grep would also match a
# stale marker belonging to a DIFFERENT [!] phase.
first_bang_block() {
  awk '
    /^- \[/ { if (seen) exit }
    /^## /  { if (seen) exit }
    /^- \[!\]/ { seen = 1 }
    seen { print }
  ' "$MEMORY" 2>/dev/null
}

# Count only real phase lines: a stray "- [ ]" checkbox in Notes is not a phase.
# NOTE: grep -c prints 0 itself on no match (exit 1) — do NOT add "|| echo 0", it would double the output
REMAINING=$(grep -c '^\- \[ \] \*\*Phase' "$MEMORY" 2>/dev/null || true)
REMAINING=${REMAINING:-0}   # unreadable file → empty var → treat as 0

if [ "$REMAINING" -eq 0 ]; then
  echo "No phases remaining. Run /finalize-workflow."
  exit 0
fi

echo "Found $REMAINING phases to execute."
echo ""

for i in $(seq 1 $REMAINING); do
  # Re-read MEMORY to get current state
  if ! grep -q '^\- \[ \] \*\*Phase' "$MEMORY" 2>/dev/null; then
    echo ""
    echo "All phases completed!"
    break
  fi

  # Per-iteration flags. MUST be initialised before the selector below, which
  # can clear RUN_PHASE.
  REPAIRED_THIS_ROUND=0
  RUN_PHASE=1

  # Ask next-phase.py which phase is next — the SAME selector the sub-session
  # uses (it honours parallel:N barriers, group:N units and [>] resumes). Using
  # plain file order here would pick a different phase than the one that
  # actually runs, and apply the wrong row's model/effort/cap to it.
  REC=$(python3 "$HOME/.claude/scripts/next-phase.py" "$MEMORY" 2>/dev/null \
        | sed -n 's/^recommendation: //p')
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
      NEXT_PHASE=$(grep -n '^\- \[ \] \*\*Phase' "$MEMORY" | head -1 | sed 's/.*Phase \([0-9]\{1,\}\).*/\1/') ;;
  esac

  if [ "$RUN_PHASE" -eq 1 ] && [ -z "$NEXT_PHASE" ]; then
    echo "Could not determine the next phase. Stopping — check .claude/MEMORY.md."
    break
  fi

  # Snapshot completed-phase count BEFORE the run (progress guard)
  BEFORE_DONE=$(grep -c '^\- \[x\]' "$MEMORY" 2>/dev/null || true)
  BEFORE_DONE=${BEFORE_DONE:-0}

  # Look up model and effort from the execution config table, by COLUMN
  # (| Phase | Effort | Model | Sourcerer |) rather than by grepping the whole
  # row for keywords — "xhigh" contains "high", and a keyword grep would also
  # read a value out of the wrong column.
  # Exact row match: "Phase 1" must not match "Phase 10".
  # NOTE: ${NEXT_PHASE} must stay braced — in zsh (the default macOS shell)
  # `$NEXT_PHASE[^0-9]` parses as an array subscript and aborts the command
  # with "bad math expression", leaving MODEL_LINE empty and silently
  # defaulting every phase's model, effort and cap.
  MODEL_LINE=$(grep -E "^\|[[:space:]]*Phase ${NEXT_PHASE}[^0-9]" "$MEMORY" | head -1)
  col() { printf '%s\n' "$MODEL_LINE" | awk -F'|' -v n="$1" \
            '{gsub(/^[ \t]+|[ \t]+$/, "", $n); print tolower($n)}'; }

  EFFORT=$(col 3)
  MODEL=$(col 4)

  # Validate against what this launcher actually supports; anything else
  # (empty row, no table, typo) falls back to the safe default.
  case "$MODEL" in
    fable|sonnet|opus) ;;
    *) MODEL="opus" ;;
  esac
  case "$EFFORT" in
    low|medium|high|xhigh|max) ;;
    *) EFFORT="high" ;;
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

  # Budget flag assembled once; empty array = no cap (raw subscription mode)
  BUDGET_ARGS=()
  if [ -z "$RUN_ALL_PHASES_NO_BUDGET" ]; then
    BUDGET_ARGS=(--max-budget-usd "$BUDGET")
    CAP_LABEL="runaway-cap: \$$BUDGET"
  else
    CAP_LABEL="cap: none (RUN_ALL_PHASES_NO_BUDGET=1)"
  fi

  # RUN_PHASE=0 means the selector found no startable phase (a [!]/[~] blocks
  # the plan). Skip the phase session and drop straight to the repair handling.
  if [ "$RUN_PHASE" -eq 1 ]; then
    echo "========================================="
    echo "Phase $NEXT_PHASE — model: $MODEL, effort: $EFFORT, mode: $MODE_LABEL, $CAP_LABEL"
    echo "========================================="
    claude -p "$RUN_PROMPT" \
      --model "$MODEL" \
      --effort "$EFFORT" \
      --permission-mode auto \
      "${BUDGET_ARGS[@]}"

    CLAUDE_EXIT=$?
    if [ "$CLAUDE_EXIT" -ne 0 ]; then
      echo ""
      echo "claude exited with code $CLAUDE_EXIT. Stopping."
      echo "Check .claude/MEMORY.md — reset any stale [>] phase to [ ] before relaunching."
      break
    fi
  fi

  # Check for issues — one fresh-eyes repair attempt before stopping
  if grep -q '^\- \[!\]' "$MEMORY" 2>/dev/null; then
    if first_bang_block | grep -q 'Repair attempted:'; then
      echo ""
      echo "A phase failed [!] and repair was already attempted. Stopping for review."
      echo "Fix the issue (or delete its 'Repair attempted:' note to grant another repair round), then run /run-all-phases again."
      break
    fi

    # Repair runs on the strongest model: it is by definition the case where
    # the phase's model already failed once. Fallback to opus only if the
    # fable session cannot start (e.g. no credits — claude exits non-zero
    # without touching MEMORY.md).
    echo ""
    echo "A phase failed [!] — launching one fresh-eyes repair session (fable)..."
    REPAIR_BUDGET_ARGS=()
    [ -z "$RUN_ALL_PHASES_NO_BUDGET" ] && REPAIR_BUDGET_ARGS=(--max-budget-usd 300)
    claude -p "$REPAIR_PROMPT" \
      --model fable \
      --effort max \
      --permission-mode auto \
      "${REPAIR_BUDGET_ARGS[@]}"
    REPAIR_EXIT=$?

    # Only fall back if the fable session never ran at all (non-zero exit AND no
    # outcome written). If it ran and gave up, it left the marker — do not
    # spend a second repair on the same phase.
    if [ "$REPAIR_EXIT" -ne 0 ] && ! first_bang_block | grep -q 'Repair attempted:'; then
      echo "Fable repair session did not run (exit $REPAIR_EXIT) — retrying with opus..."
      REPAIR_BUDGET_ARGS=()
      [ -z "$RUN_ALL_PHASES_NO_BUDGET" ] && REPAIR_BUDGET_ARGS=(--max-budget-usd 200)
      claude -p "$REPAIR_PROMPT" \
        --model opus \
        --effort max \
        --permission-mode auto \
        "${REPAIR_BUDGET_ARGS[@]}"
    fi

    if grep -q '^\- \[!\]' "$MEMORY" 2>/dev/null; then
      echo ""
      echo "Repair failed. Stopping for review — see the 'Repair attempted:' note in MEMORY.md."
      break
    fi
    echo "Repair succeeded — continuing with next phase."
    REPAIRED_THIS_ROUND=1
  fi

  if grep -q '^\- \[~\]' "$MEMORY" 2>/dev/null; then
    echo ""
    echo "A phase is blocked [~]. Stopping for review."
    break
  fi

  # Progress guard: a successful run must either complete a phase ([x] count
  # grows) or leave a resumable WIP ([>] + WIP note). Anything else means the
  # session died leaving the phase stuck — looping again would burn runs.
  AFTER_DONE=$(grep -c '^\- \[x\]' "$MEMORY" 2>/dev/null || true)
  AFTER_DONE=${AFTER_DONE:-0}
  # A Case A reopen (a completed phase sent back to [!] by a later phase's
  # baseline check) makes the [x] count DROP, so a successful repair only
  # restores it — real work happened, but the count did not grow. Skip the
  # guard when a repair landed this round, or the run would stop on a
  # misleading "no progress".
  if [ "$AFTER_DONE" -le "$BEFORE_DONE" ] && [ "$REPAIRED_THIS_ROUND" -eq 0 ]; then
    if grep -q '^\- \[>\]' "$MEMORY" 2>/dev/null && grep -q 'WIP:' "$MEMORY" 2>/dev/null; then
      echo "Phase left in WIP state — next session will resume it."
    else
      echo ""
      echo "No progress in the last run (phase stuck as [>]?). Stopping."
      echo "Check .claude/MEMORY.md — reset stale [>] phases to [ ] and relaunch."
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
grep '^\- \[' "$MEMORY" | head -20
echo ""
echo "Working tree changes (uncommitted — consolidate via /finalize-workflow):"
git diff --stat HEAD | tail -15

# Rolling-wave reminder: Roadmap entries are inert bullets, not phases —
# the next macro gets detailed by a fresh /write-workflow after finalize.
if grep -q '^## Roadmap' "$MEMORY" 2>/dev/null; then
  echo ""
  echo "Roadmap (pending macro-phases — after /finalize-workflow, detail the next one with /write-workflow):"
  awk '/^## Roadmap/{f=1;next} /^## /{f=0} f && /^- /' "$MEMORY" | head -10
fi
```

## What happens

For each phase:

1. Asks `next-phase.py` which phase is next — the same selector the sub-session uses, so the row looked up in step 2 always belongs to the phase that actually runs (it honours `parallel:N` barriers, `group:N` units and `[>]` resumes). Falls back to file order only if the script is unavailable.
2. Reads the phase's row from the execution config table **by column**: opus by default, sonnet or fable only if explicitly marked; effort defaults to `high`. Effort drives the `--effort` flag, the runaway cap, and light mode at `low` (slim contract, no skill; anything else gets the full auto-phase ritual).
3. Launches `claude -p "/goal <phase contract>" --model <model> --effort <effort> --permission-mode auto` — the goal directive tells the session to run the auto-phase skill; auto mode's classifier handles per-action permission decisions. On CLIs older than 2.1.139 it falls back to `claude -p '/auto-phase'`.
4. That session: explores, implements, then iterates its internal convergence loop (up to 3 fix attempts against tests + lint, no-progress detector, independent review, Done-criterion gate), updates MEMORY.md, exits. Under the `/goal` guard, a **separate evaluator model** re-checks the exit condition after every turn — the session cannot end "convinced it's done" until MEMORY.md actually shows the outcome (or the 25-turn bound trips).
5. If the phase exits `[!]`, ONE fresh-eyes repair session (`/repair-phase`, fable — opus fallback if the fable session cannot start) is launched; the run continues only if the repair turns the phase `[x]`
6. Loop continues to next phase

**Stop conditions:**

- All phases `[x]` — done
- A phase marked `[!]` after one failed repair attempt — stops for review (marker: the `> Repair attempted:` note; delete it to grant another repair round after manual intervention)
- A phase marked `[~]` — stops (blocked). Includes the **unattributable red baseline** (attribution Case B): `/auto-phase` checks tests+lint *before* starting, and if the failure belongs to no phase in the plan it refuses to begin. Stopping is correct there — the chain has no mandate over code no phase touched.
- A **red baseline that IS attributable** (Case A) does **not** stop the run: the culprit phase is reopened `[x] → [!]`, the normal repair path handles it, and the loop continues if the repair lands. Self-repair is preferred over interrupting you whenever the regression has an owner; the one-repair-per-phase guard keeps it bounded.
- `claude` exits non-zero — stops (session crashed)
- No progress (phase left `[>]` by a dead session, no WIP note) — stops instead of looping uselessly
- Ctrl+C between phases — safe (nothing to lose: phase work is in the working tree, and any `WIP: baseline before Phase N` commits get consolidated by `/finalize-workflow`'s soft-reset)

## After completion

When you come back:

- `grep '^\- \[' .claude/MEMORY.md` — phase status at a glance
- `pytest tests/ -v` — run all tests
- `git diff --stat` — see all changes
- Fix any `[!]` phases, then run `/run-all-phases` again
- When all `[x]` — run `/finalize-workflow`
