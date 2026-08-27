---
description: Run all remaining phases autonomously — launches a new claude session per phase with correct model
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Monitor, PushNotification, AskUserQuestion, Agent, SendUserFile, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions
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

   **Model** — default `opus`; `fable` is the one exception:
   - `fable` — architectural change, hairy debugging, multi-file consistency, novel design with no pattern reference (subject to credits; ask once if unsure).
   - `sonnet` is **not in the palette** — field experience regretted every sonnet phase, and a failed one costs a fable repair. Mechanical work is `opus` at `low` effort (light mode). Legacy plans that carry it still run, with the launcher's sonnet steering — accepted is not recommended.
   - In doubt → `opus`.
   - The launcher steers each session for its model via `--append-system-prompt` (log-style silent output for all; opus: no scope creep or extra verification; fable: act, don't re-derive settled decisions) — neither the plan nor the phases need to restate style or verbosity rules.

   **Effort** — **start low and climb only for a reason.** A phase that passed the check above is well-specified by construction, and that is where high effort buys least: it gets spent re-exploring and re-verifying decisions the plan already settled. `low` mechanical, `medium` the standard well-specified phase, `high` only where real design judgment survives inside the phase, `xhigh` wide multi-file agentic work, `max` practically never (overthinking, diminishing returns). Effort levels copied from an older plan rarely transfer — re-decide them here.

   It sets `--effort`, the runaway cap, and light mode: `low` phases run a slim `/goal` contract *without* the execute-phase-agent skill, so their `Details:`/`Done:` must be fully self-contained.

6. **Rewrite the plan** with the refined phases and the table, committing the edit as `wf: refine plan for autonomous run` (the plan is tracked), then show the user the final phase list with the model chosen for each and close with the gate line (`common.md` → *The gate line*): *"**Launch?** On your ok the run starts in the background over all \<N\> phases; keep the app open."* The line is the gate — AskUserQuestion exists in this skill solely for the stop-work question below, never for the launch.

## Execution

After confirmation, launch the run in the **background** and watch it while it runs — the run stays attached to this session. Tee the launcher's output to a log **outside the repo** (`<slug>` = the active plan's directory name under `.phased/active/`); a file inside `.phased/` would dirty the tree at the next phase's start and land in that phase's commit, which is exactly why the launcher itself writes no file:

```bash
mkdir -p "${TMPDIR:-/tmp}/phased-workflow-$(id -u)"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-workflow.sh" 2>&1 \
  | tee "${TMPDIR:-/tmp}/phased-workflow-$(id -u)/<slug>-run.log"
```

The script owns the loop; do not reimplement it.

**Watch it with the Monitor tool** — one persistent monitor on that log, filtered to the `EVENT:` lines the launcher emits (`phase-done`, `phase-failed`, `phase-needs-foreman`, `phase-blocked`, `run-end`). The launcher emits `run-end` on **every** exit path, so the loop below always terminates — never `tail -f | awk '… exit'` here: when the log goes quiet after `run-end` (it always does — `run-end` is the launcher's last word), `tail` never gets its SIGPIPE and the pipeline hangs forever:

```bash
LOG="${TMPDIR:-/tmp}/phased-workflow-$(id -u)/<slug>-run.log"; SEEN=0
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

**Push policy** (see `${CLAUDE_PLUGIN_ROOT}/refs/foreman.md` → *Notifications*): send a **PushNotification** on the **first** `phase-failed` of the run, on **any** `phase-needs-foreman` (the run holds for the consult window — the one push the user can still act on), on **any** `phase-blocked`, and once when the run ends — the end push comes from the background command's own completion, not from the `run-end` event, so there is exactly one source per notification and no duplicate. At most one failure push per run. Nothing else is pushed: routine per-phase progress is not worth an interruption. Each message leads with what the user would act on, one line under 200 characters with no markdown — e.g. `run stopped: phase 4 [!] after repair, 3/7 done — see its > Issue: note`.

**Relay to the foreman — this session is the run's site inspector.** On the first wake-up, one line names the channel this relay rides (desktop session tools, CLI `SendMessage`, or neither — `foreman.md` → *Channel floors*), so a run whose relays cannot arrive says so up front. The `-p` sub-sessions cannot reach desktop chats, but this chat can: on each Monitor wake-up, relay every new `EVENT:` line to the foreman in the corresponding message format of `foreman.md` → *The foreman* (`phase-done` → the done line, `phase-failed` → the FAILED line with the phase's `> Issue:` in one line, `phase-needs-foreman` → the `plan-defect?` question with the claim from the phase's `> Issue:`, `phase-blocked` → the blocked line, `run-end` → the run outcome). Best-effort as always — and when this chat IS the foreman the title lookup finds nothing and the relay skips itself. Unlike the push, the relay carries routine progress: the foreman is a board, not a pager.

**Plan-defect consult.** `phase-needs-foreman` is the one event with a return leg: the launcher is HOLDING the repair, polling `${TMPDIR:-/tmp}/phased-workflow-$(id -u)/<slug>-foreman-answer` for up to `RUN_WORKFLOW_CONSULT_TIMEOUT` seconds (default 600). Relay the `plan-defect?` question (with the phase's `> Issue:` claim) to the foreman; when its reply arrives — `plan-defect: repair`, `plan-defect: apply` or `plan-defect: stop` (`foreman.md` → *Plan-defect claims*) — write exactly that verb, alone, into the answer file. The file lives outside the repo, so writing it breaks no invariant. On `apply`, the applying is THIS session's work, per the protocol's apply road: apply exactly the claim's before-text → after-text edit to both contract copies (byte-identical), re-run the phase's `Done:`, on green flip the phase `[x]` (`> Done:` re-stated, `> Applied:` note, `> Issue:` kept) and commit `wf: plan defect phase N — applied — <one line>`, then write `green` into `${TMPDIR:-/tmp}/phased-workflow-$(id -u)/<slug>-apply-outcome` — the launcher resumes with the next phase, no repair and no relaunch. The window (`RUN_WORKFLOW_APPLY_TIMEOUT`, default 900s) is a hard deadline: red Done or no time left → reset what was touched, write `red`, and let the repair judge the claim. When this chat IS the foreman, put the question's options to the user here (AskUserQuestion — *Authorize repair (Recommended)* / *Apply the declared edit*, only when the `> Issue:` carries the edit as before-text → after-text / *Stop the run*) and write the file from the answer. No reply in time → the launcher proceeds to repair on its own; say so, never write a guess.

**Stop-work.** The inspector's judgment, not a checklist: when what it sees makes *continuing* look like wasted tokens — a repair cascade (a reopen after a repair, a second `phase-failed`), a budget cap tripped, phases closing suspiciously instantly, log content that contradicts the plan, or a completed phase's outcome that undermines a phase still to run — send the foreman the `stop-work?` question per `foreman.md` → *The foreman* and keep watching. On each `phase-done`, one cheap coherence look is part of the watch: this session holds the whole plan from the pre-flight, so check the phase's log (and `git show` on its commit if the log is ambiguous) against what the remaining phases assume — a file a later `Files:` names that was renamed or moved, a data shape a later phase builds on that came out different, a `Pattern:` example a later phase cites that this phase just refactored away — and against the plan's `Must not break:` header plus the roadmap's remaining macro-phases, premises of the same rank (`contracts.md` → *Must not break:*). On a plan carrying contract tests, a phase that closed on a bent decision — its `> Done:` or `notes.md` entry records a deviation from what the plan's `Decisions:` assumed — gets one check more: re-read the pending phases' contract tests (`tests/phase-M/` in the plan directory) against the bend, every negative assertion first — a prohibition the bend now forces is tomorrow's plan-defect consult, surfaced while stopping is still cheap. Reading logs and diffs breaks no invariant — only *writes* are forbidden mid-run. The run is NOT paused by the question. On `stop-work: granted` (the reply path): kill the background run now (TaskStop / kill the launcher's process group), accept that a phase may die `[>]` mid-flight — the WIP evidence and the stale-`[>]` reset exist for exactly this — write the *Run inspection* notes immediately (the run no longer owns the tree), and close telling the user the resume path: correct the plan (talk it through + `/resume-workflow`), then a fresh `/run-workflow` restarts the work. On `stop-work: denied` or no reply, the run's own stop conditions govern. When this chat IS the foreman there is nobody to ask upward: put the same *Stop workflow / Go on* question to the user here, directly — reason phrased per `foreman.md` → *The reporting register*.

**Graceful stop — finish the phase in flight, then stop.** When the user wants the run ended without killing the phase mid-flight (credits running low, end of day), write anything into `${TMPDIR:-/tmp}/phased-workflow-$(id -u)/<slug>-stop-request`: the launcher checks the file between sessions, consumes it, and ends the run as `EVENT: run-end stopped-by-request N/M` without launching another phase — no `[>]` left behind, unlike the stop-work kill, so the relaunch needs no reset. To bound the run before it starts, `RUN_WORKFLOW_MAX_PHASES=N` on the launch command runs at most N more phases and stops the same clean way — how "run only phase 8, hold phase 9" is said.

**While the run is in the background, this session does NOT write to the repository.** The run owns the working tree; a parent-side edit breaks the clean-tree invariant every phase session checks at its start. The one exception is the apply leg of the plan-defect consult above: from the `apply` answer to the outcome file the launcher holds, and the tree is this session's for the declared edit (`foreman.md` → *Plan-defect claims*).

**Degradation is declared, not silent.** Without the Monitor tool or PushNotification available, run the script in the foreground exactly as before and report once at the end — and say that the early `[!]` notification needs the background path.

Report the run's outcome to the user per `foreman.md` → *The reporting register*: the short form (verdict line, one line per finding — what landed and what it now does, what failed and what the user would see because of it), passed through the `wf:report-judge` comprehension probe before showing, delivered as the register's report page where the session can render one — degraded path: the short form in chat, closed with the register's single detail question. The launcher's raw summary is the record, not the report.

**Runaway cap:** `--max-budget-usd` is a bugged-loop safety net, not a spend limit — on a subscription plan quota is the 5-hour window, not dollars. Caps come from effort ($50 low → $300 max, doubled for fable). A phase that actually trips its cap is a signal to investigate, not to raise it. `RUN_WORKFLOW_NO_BUDGET=1` removes the flag entirely.

**Stop conditions:** all phases `[x]`; a `[!]` phase after its one repair attempt (marker `> Repair attempted:` — delete it to grant another round); a foreman answering `stop` on a plan-defect consult (the plan fix and any repair are then the foreman's, per `foreman.md` → *Plan-defect claims*); a `[~]` blocked phase (unattributable red baseline); a stop request or an exhausted `RUN_WORKFLOW_MAX_PHASES` budget (clean stops between sessions, above); `claude` exiting non-zero; no progress. An *attributable* red baseline does not stop the run — the culprit phase is reopened `[x] → [!]` and repaired.

## After completion

**Inspection notes — only now, never mid-run** (the run owned the tree until `run-end`; writing earlier breaks the clean-tree invariant). Append to the plan's `notes.md` a `## Run inspection` section: one bullet per noteworthy fact of the run, read from the EVENT stream and the phase logs — which phase failed and was repaired, which came back blocked, anomalies (a phase that tripped its budget cap, a no-progress stop, a session that died), and nothing when the run was uneventful (write `- uneventful run, N/N phases` and stop there). Commit it as `wf: run inspection notes`. This is what the closing skills read: `/quality-check`'s pre-commit review takes these bullets as focus points, and `/finalize-workflow`'s lessons pass scans the same file.

Then:

- `grep '^\- \[' "$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve)"` — phase status
- all `[x]` → `/quality-check`, then `/finalize-workflow`; any `[!]` → read its `> Issue:`/`> Attempted:` notes first
