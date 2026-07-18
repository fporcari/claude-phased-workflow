# Run All Phases

Launches `/auto-phase` in a loop, one new Claude session per phase. Each session gets:

- A **fresh context window** (low token cost, high quality)
- **Model defaults to opus**; the execution config table can override per phase: `sonnet` when the pre-flight review marks the phase as mechanical, well-specified and trivial; `fable` when it marks the phase as genuinely hard (architecture, hairy debugging, multi-file consistency, novel design) — subject to credit availability. If in doubt → opus.
- **`auto` permission mode**: each sub-session uses Claude Code's auto-mode classifier, which decides per-action what's safe. It auto-concedes routine local operations in project scope (git status/log/diff/show, edits in the working directory, push to the working branch, manifest-driven installs like `pip install -r requirements.txt`) and **blocks the dangerous categories**: force-push, push to default branch, irreversible destruction of pre-existing files, install of agent-chosen packages (typosquat risk), production deploys, data exfiltration, `curl | bash`, self-modification of agent config. No manual allowlist to maintain; if the classifier blocks something, the session reports it cleanly.

Before launching the loop, this skill performs a **pre-flight review of MEMORY.md** to make sure every remaining phase is concrete enough for autonomous execution. If a phase looks exploratory or vague, the skill stops and asks you targeted questions to make it precise — only after you confirm the refined plan does the loop start.

**Model tip:** invoke `/run-all-phases` itself from a chat on the strongest model available (fable if you have credits). The bash loop consumes no model — but the pre-flight review is pure judgment work, and a mistake there wastes an entire autonomous run.

**Usage:** `/run-all-phases`

**Budget control:** The `--max-budget-usd` flag is a runaway-loop safety net, NOT a real spend cap when on a subscription plan (Pro / Max / Team). On subscription plans, you don't pay per token — quota is the 5-hour rolling message window, not dollars. The flag computes a notional cost as if API-priced and stops the session if exceeded; that protects against bugged loops, but with values too low it triggers spuriously on legitimate large phases.

The script reads the cap-per-phase from the effort level in the config table:
- low effort → $50 max per phase
- medium effort → $100 max per phase
- high effort → $200 max per phase
- max effort → $300 max per phase

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

# NOTE: grep -c prints 0 itself on no match (exit 1) — do NOT add "|| echo 0", it would double the output
REMAINING=$(grep -c '^\- \[ \]' "$MEMORY" 2>/dev/null || true)
REMAINING=${REMAINING:-0}   # unreadable file → empty var → treat as 0

if [ "$REMAINING" -eq 0 ]; then
  echo "No phases remaining. Run /finalize-workflow."
  exit 0
fi

echo "Found $REMAINING phases to execute."
echo ""

for i in $(seq 1 $REMAINING); do
  # Re-read MEMORY to get current state
  if ! grep -q '^\- \[ \]' "$MEMORY" 2>/dev/null; then
    echo ""
    echo "All phases completed!"
    break
  fi

  # Find the next [ ] phase number
  NEXT_PHASE=$(grep -n '^\- \[ \] \*\*Phase' "$MEMORY" | head -1 | sed 's/.*Phase \([0-9]*\).*/\1/')

  if [ -z "$NEXT_PHASE" ]; then
    echo "All phases completed!"
    break
  fi

  # Snapshot completed-phase count BEFORE the run (progress guard)
  BEFORE_DONE=$(grep -c '^\- \[x\]' "$MEMORY" 2>/dev/null || true)
  BEFORE_DONE=${BEFORE_DONE:-0}

  # Look up model and effort from execution config table.
  # Default = opus. Sonnet only if explicitly marked (mechanical, trivial phases);
  # fable only if explicitly marked (genuinely hard phases, credits permitting).
  # Exact row match: "Phase 1" must not match "Phase 10".
  MODEL_LINE=$(grep -E "^\|[[:space:]]*Phase $NEXT_PHASE[^0-9]" "$MEMORY" | head -1)

  if echo "$MODEL_LINE" | grep -qi 'fable'; then
    MODEL="fable"
  elif echo "$MODEL_LINE" | grep -qi 'sonnet'; then
    MODEL="sonnet"
  else
    MODEL="opus"
  fi

  # Cap per phase (runaway-loop safety net, NOT a real spend limit on subscription plans).
  # Generous defaults so normal phases never trip the cap; trips signal a bug, not a budget issue.
  if echo "$MODEL_LINE" | grep -qi 'max'; then
    BUDGET=300
  elif echo "$MODEL_LINE" | grep -qi 'high'; then
    BUDGET=200
  elif echo "$MODEL_LINE" | grep -qi 'medium'; then
    BUDGET=100
  else
    BUDGET=50
  fi

  # Fable burns more notional dollars per token — double the cap so the
  # safety net keeps the same "only trips on a real bug" semantics.
  if [ "$MODEL" = "fable" ]; then
    BUDGET=$((BUDGET * 2))
  fi

  echo "========================================="
  if [ -n "$RUN_ALL_PHASES_NO_BUDGET" ]; then
    echo "Phase $NEXT_PHASE — model: $MODEL, cap: none (RUN_ALL_PHASES_NO_BUDGET=1)"
    echo "========================================="
    claude -p '/auto-phase' \
      --model "$MODEL" \
      --permission-mode auto
  else
    echo "Phase $NEXT_PHASE — model: $MODEL, runaway-cap: \$$BUDGET"
    echo "========================================="
    claude -p '/auto-phase' \
      --model "$MODEL" \
      --permission-mode auto \
      --max-budget-usd "$BUDGET"
  fi

  CLAUDE_EXIT=$?
  if [ "$CLAUDE_EXIT" -ne 0 ]; then
    echo ""
    echo "claude exited with code $CLAUDE_EXIT. Stopping."
    echo "Check .claude/MEMORY.md — reset any stale [>] phase to [ ] before relaunching."
    break
  fi

  # Check for issues — one fresh-eyes repair attempt before stopping
  if grep -q '^\- \[!\]' "$MEMORY" 2>/dev/null; then
    if grep -A6 '^\- \[!\]' "$MEMORY" | grep -q 'Repair attempted:'; then
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
    if [ -n "$RUN_ALL_PHASES_NO_BUDGET" ]; then
      claude -p '/repair-phase' \
        --model fable \
        --permission-mode auto
    else
      claude -p '/repair-phase' \
        --model fable \
        --permission-mode auto \
        --max-budget-usd 300
    fi
    REPAIR_EXIT=$?

    if [ "$REPAIR_EXIT" -ne 0 ] && ! grep -A6 '^\- \[!\]' "$MEMORY" 2>/dev/null | grep -q 'Repair attempted:'; then
      echo "Fable repair session did not run (exit $REPAIR_EXIT) — retrying with opus..."
      if [ -n "$RUN_ALL_PHASES_NO_BUDGET" ]; then
        claude -p '/repair-phase' \
          --model opus \
          --permission-mode auto
      else
        claude -p '/repair-phase' \
          --model opus \
          --permission-mode auto \
          --max-budget-usd 200
      fi
    fi

    if grep -q '^\- \[!\]' "$MEMORY" 2>/dev/null; then
      echo ""
      echo "Repair failed. Stopping for review — see the 'Repair attempted:' note in MEMORY.md."
      break
    fi
    echo "Repair succeeded — continuing with next phase."
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
  if [ "$AFTER_DONE" -le "$BEFORE_DONE" ]; then
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
```

## What happens

For each phase:

1. Reads MEMORY.md to find the next `[ ]` phase
2. Looks up the model: opus by default, sonnet or fable only if the execution config table explicitly says so for that phase
3. Launches `claude -p '/auto-phase' --model <model> --permission-mode auto` — auto mode's classifier handles per-action permission decisions
4. That session: explores, implements, then iterates its internal convergence loop (up to 3 fix attempts against tests + lint, no-progress detector, independent review, Done-criterion gate), updates MEMORY.md, exits
5. If the phase exits `[!]`, ONE fresh-eyes repair session (`/repair-phase`, fable — opus fallback if the fable session cannot start) is launched; the run continues only if the repair turns the phase `[x]`
6. Loop continues to next phase

**Stop conditions:**

- All phases `[x]` — done
- A phase marked `[!]` after one failed repair attempt — stops for review (marker: the `> Repair attempted:` note; delete it to grant another repair round after manual intervention)
- A phase marked `[~]` — stops (blocked)
- `claude` exits non-zero — stops (session crashed)
- No progress (phase left `[>]` by a dead session, no WIP note) — stops instead of looping uselessly
- Ctrl+C between phases — safe (no commits to lose, changes in working tree)

## After completion

When you come back:

- `grep '^\- \[' .claude/MEMORY.md` — phase status at a glance
- `pytest tests/ -v` — run all tests
- `git diff --stat` — see all changes
- Fix any `[!]` phases, then run `/run-all-phases` again
- When all `[x]` — run `/finalize-workflow`
