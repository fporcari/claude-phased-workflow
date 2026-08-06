---
description: Run all remaining phases autonomously — launches a new claude session per phase with correct model
disable-model-invocation: true
allowed-tools: Bash, Read, Monitor, PushNotification
---

# Run Workflow

Runs `${CLAUDE_PLUGIN_ROOT}/scripts/run-workflow.sh`, which launches one fresh `claude` session per remaining phase (`/execute-phase-agent` under a `/goal` contract, `--permission-mode auto`, model and effort from the plan's execution config table). Your job before that: the pre-flight review below.

**Usage:** `/run-workflow`

## Pre-flight review (MANDATORY — before running the script)

1. **Read** the active plan (`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve`; from outside the plan's root, `--plans` per `common.md` → *Plan location* — the launcher itself attaches or creates the plan's workspace), and read its `Mode:` header first:
   - **`Mode: autonomous`** → the plan was written for this; proceed with the check below.
   - **`Mode: interactive`** → say so plainly: this plan was written for `/execute-phase`, one chat per phase. Offer the conversion — refine every phase to the autonomous-ready bar, add the `## Suggested execution config` table, flip the header to `Mode: autonomous`, and commit the rewrite as `wf: refine plan for autonomous run` (step 6) — or stop and leave it interactive. **Never convert silently.**
   - **No header** → a legacy plan (pre-Mode). Treat it as today, with no accusation, and let the check below decide whether it is ready.

2. For every remaining `[ ]` phase, check it is **autonomous-ready**:
   - **Concrete and verifiable**, not exploratory ("explore", "investigate", "decide", "evaluate options" → not ready).
   - **Bounded scope**: named files, or an explicit discovery rule.
   - **Measurable `Done:`**: a test passes, a check returns true, a named output appears. Not "looks good".
   - **Decisions pre-made**: no library / API / naming choice left to the run.
   - **`Pattern:` cited** for non-trivial code (1–2 existing examples to copy-adapt), or `library-standard`.

   **Macro-split check**: more than ~10 phases, or a phase unspecifiable because it depends on an *earlier phase's outcome* → don't refine blindly, propose macro-phases (see `${CLAUDE_PLUGIN_ROOT}/refs/write-workflow-autonomous.md`): detail the first macro as the Work Plan, the rest as `## Roadmap` bullets (inert for the script).

3. Any phase failing the check → **stop and refine interactively**, one targeted question at a time, confirming each rewritten phase before the next. When the gap is a missing `Pattern:`, ask the user for an example; if they don't have one, propose 2–3 candidates from the repo to confirm.

4. **Permission scope**: sub-sessions run `--permission-mode auto`; `${CLAUDE_PLUGIN_ROOT}/refs/auto-mode-scope.md` lists the categories its classifier is expected to deny, together with this plugin's own convention for writing phases. For each phase needing one, report it and let the user choose: rephrase to stop before it, drop the phase, or run it by hand. Never silently rewrite a phase to hide a blocked operation.

5. **Fill the execution config table** (create it if the plan has none — it drives model, effort and cap per phase).

   **Model** — default `opus`; the other two are exceptions:
   - `sonnet` — mechanical work only: renames, extractions, moves, header updates, and implementations that merely follow a cited `Pattern:` with a test-enforced `Done:`. **Never for UI or declarative output — opus is the floor there.** Marking a phase `sonnet` is a commitment about the *plan*, not about the model: that phase's `Details:` and `Done:` must be spelled out until nothing is left to infer. If they aren't, write them out now or leave it `opus`.
   - `fable` — architectural change, hairy debugging, multi-file consistency, novel design with no pattern reference (subject to credits; ask once if unsure).
   - In doubt → `opus`. A failed sonnet phase costs a fable repair.
   - The launcher steers each session for its model via `--append-system-prompt` (log-style silent output for all; opus: no scope creep or extra verification; sonnet: literal execution, a real spec gap closes the phase `[!]`; fable: act, don't re-derive settled decisions) — neither the plan nor the phases need to restate style or verbosity rules.

   **Effort** — **start low and climb only for a reason.** A phase that passed the check above is well-specified by construction, and that is where high effort buys least: it gets spent re-exploring and re-verifying decisions the plan already settled. `low` mechanical, `medium` the standard well-specified phase, `high` only where real design judgment survives inside the phase, `xhigh` wide multi-file agentic work, `max` practically never (overthinking, diminishing returns). Effort levels copied from an older plan rarely transfer — re-decide them here.

   It sets `--effort`, the runaway cap, and light mode: `low` phases run a slim `/goal` contract *without* the execute-phase-agent skill, so their `Details:`/`Done:` must be fully self-contained.

6. **Rewrite the plan** with the refined phases and the table, committing the edit as `wf: refine plan for autonomous run` (the plan is tracked), then show the user the final phase list with the model chosen for each and close with the gate line (`common.md` → *The gate line*): *"**Lancio?** Al tuo ok parte il run in background su tutte le \<N\> fasi; tieni l'app aperta."* This skill carries no AskUserQuestion — the line is the gate.

## Execution

After confirmation, launch the run in the **background** and watch it while it runs — the run stays attached to this session. Tee the launcher's output to a log **outside the repo** (`<slug>` = the active plan's directory name under `.phased/active/`); a file inside `.phased/` would dirty the tree at the next phase's start and land in that phase's commit, which is exactly why the launcher itself writes no file:

```bash
mkdir -p "${TMPDIR:-/tmp}/phased-workflow"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-workflow.sh" 2>&1 \
  | tee "${TMPDIR:-/tmp}/phased-workflow/<slug>-run.log"
```

The script owns the loop; do not reimplement it.

**Watch it with the Monitor tool** — one persistent monitor on that log, filtered to the `EVENT:` lines the launcher emits (`phase-failed`, `phase-blocked`, `run-end`). The launcher emits `run-end` on **every** exit path, so the loop below always terminates — never `tail -f | awk '… exit'` here: when the log goes quiet after `run-end` (it always does — `run-end` is the launcher's last word), `tail` never gets its SIGPIPE and the pipeline hangs forever:

```bash
LOG="${TMPDIR:-/tmp}/phased-workflow/<slug>-run.log"; SEEN=0
while :; do
  COUNT=$(grep -c '^EVENT: ' "$LOG" 2>/dev/null); COUNT=${COUNT:-0}
  if [ "$COUNT" -gt "$SEEN" ]; then
    grep '^EVENT: ' "$LOG" | tail -n +"$((SEEN + 1))"
    SEEN=$COUNT
  fi
  grep -q '^EVENT: run-end' "$LOG" 2>/dev/null && exit 0
  sleep 5
done
```

If the launcher is killed outright (`kill -9`, machine shutdown) even `run-end` cannot arrive: the background command's own completion still notifies, and this monitor is then stopped by hand (TaskStop) — say so instead of leaving it armed.

**Push policy** (see `${CLAUDE_PLUGIN_ROOT}/refs/common.md` → *Notifications*): send a **PushNotification** on the **first** `phase-failed` of the run, on **any** `phase-blocked`, and once when the run ends — the end push comes from the background command's own completion, not from the `run-end` event, so there is exactly one source per notification and no duplicate. At most one failure push per run. Nothing else is pushed: routine per-phase progress is not worth an interruption. Each message leads with what the user would act on, one line under 200 characters with no markdown — e.g. `run stopped: phase 4 [!] after repair, 3/7 done — see its > Issue: note`.

**While the run is in the background, this session does NOT write to the repository.** The run owns the working tree; a parent-side edit breaks the clean-tree invariant every phase session checks at its start.

**Degradation is declared, not silent.** Without the Monitor tool or PushNotification available, run the script in the foreground exactly as before and report once at the end — and say that the early `[!]` notification needs the background path.

Report the launcher's output to the user.

**Runaway cap:** `--max-budget-usd` is a bugged-loop safety net, not a spend limit — on a subscription plan quota is the 5-hour window, not dollars. Caps come from effort ($50 low → $300 max, doubled for fable). A phase that actually trips its cap is a signal to investigate, not to raise it. `RUN_WORKFLOW_NO_BUDGET=1` removes the flag entirely.

**Stop conditions:** all phases `[x]`; a `[!]` phase after its one repair attempt (marker `> Repair attempted:` — delete it to grant another round); a `[~]` blocked phase (unattributable red baseline); `claude` exiting non-zero; no progress. An *attributable* red baseline does not stop the run — the culprit phase is reopened `[x] → [!]` and repaired.

## After completion

- `grep '^\- \[' "$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve)"` — phase status
- all `[x]` → `/finalize-workflow`; any `[!]` → read its `> Issue:`/`> Attempted:` notes first
