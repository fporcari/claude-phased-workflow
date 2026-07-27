---
description: Run all remaining phases autonomously — launches a new claude session per phase with correct model
allowed-tools: Bash, Read
---

# Run All Phases

Runs `${CLAUDE_PLUGIN_ROOT}/scripts/run-all-phases.sh`, which launches one fresh `claude` session per remaining phase (`/auto-phase` under a `/goal` contract, `--permission-mode auto`, model and effort from the plan's execution config table). Your job before that: the pre-flight review below.

**Usage:** `/run-all-phases`

## Pre-flight review (MANDATORY — before running the script)

1. **Read** the active plan (`python3 ${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py --resolve`).

2. For every remaining `[ ]` phase, check it is **autonomous-ready**:
   - **Concrete and verifiable**, not exploratory ("explore", "investigate", "decide", "evaluate options" → not ready).
   - **Bounded scope**: named files, or an explicit discovery rule.
   - **Measurable `Done:`**: a test passes, a check returns true, a named output appears. Not "looks good".
   - **Decisions pre-made**: no library / API / naming choice left to the run.
   - **`Pattern:` cited** for non-trivial code (1–2 existing examples to copy-adapt), or `library-standard`.

   **Macro-split check**: more than ~10 phases, or a phase unspecifiable because it depends on an *earlier phase's outcome* → don't refine blindly, propose macro-phases (see `${CLAUDE_PLUGIN_ROOT}/refs/write-workflow-autonomous.md`): detail the first macro as the Work Plan, the rest as `## Roadmap` bullets (inert for the script).

3. Any phase failing the check → **stop and refine interactively**, one targeted question at a time, confirming each rewritten phase before the next. When the gap is a missing `Pattern:`, ask the user for an example; if they don't have one, propose 2–3 candidates from the repo to confirm.

4. **Permission scope**: sub-sessions run `--permission-mode auto`; `${CLAUDE_PLUGIN_ROOT}/refs/common.md` lists the categories its classifier is expected to deny, together with this plugin's own convention for writing phases. For each phase needing one, report it and let the user choose: rephrase to stop before it, drop the phase, or run it by hand. Never silently rewrite a phase to hide a blocked operation.

5. **Fill the execution config table** (create it if the plan has none — it drives model, effort and cap per phase).

   **Model** — default `opus`; the other two are exceptions:
   - `sonnet` — mechanical work only: renames, extractions, moves, header updates, and implementations that merely follow a cited `Pattern:` with a test-enforced `Done:`. **Never for UI or declarative output — opus is the floor there.** Marking a phase `sonnet` is a commitment about the *plan*, not about the model: that phase's `Details:` and `Done:` must be spelled out until nothing is left to infer. If they aren't, write them out now or leave it `opus`.
   - `fable` — architectural change, hairy debugging, multi-file consistency, novel design with no pattern reference (subject to credits; ask once if unsure).
   - In doubt → `opus`. A failed sonnet phase costs a fable repair.

   **Effort** — **start low and climb only for a reason.** A phase that passed the check above is well-specified by construction, and that is where high effort buys least: it gets spent re-exploring and re-verifying decisions the plan already settled. `low` mechanical, `medium` the standard well-specified phase, `high` only where real design judgment survives inside the phase, `xhigh` wide multi-file agentic work, `max` practically never (overthinking, diminishing returns). Effort levels copied from an older plan rarely transfer — re-decide them here.

   It sets `--effort`, the runaway cap, and light mode: `low` phases run a slim `/goal` contract *without* the auto-phase skill, so their `Details:`/`Done:` must be fully self-contained.

6. **Rewrite the plan** with the refined phases and the table, committing the edit as `wf: refine plan for autonomous run` (the plan is tracked), show the user the final phase list with the model chosen for each, and get explicit confirmation before launching.

## Execution

After confirmation:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-all-phases.sh"
```

The script owns the loop; do not reimplement it. Report its output to the user.

**Runaway cap:** `--max-budget-usd` is a bugged-loop safety net, not a spend limit — on a subscription plan quota is the 5-hour window, not dollars. Caps come from effort ($50 low → $300 max, doubled for fable). A phase that actually trips its cap is a signal to investigate, not to raise it. `RUN_ALL_PHASES_NO_BUDGET=1` removes the flag entirely.

**Stop conditions:** all phases `[x]`; a `[!]` phase after its one repair attempt (marker `> Repair attempted:` — delete it to grant another round); a `[~]` blocked phase (unattributable red baseline); `claude` exiting non-zero; no progress. An *attributable* red baseline does not stop the run — the culprit phase is reopened `[x] → [!]` and repaired.

## After completion

- `grep '^\- \[' "$(python3 ${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py --resolve)"` — phase status
- all `[x]` → `/finalize-workflow`; any `[!]` → read its `> Issue:`/`> Attempted:` notes first
