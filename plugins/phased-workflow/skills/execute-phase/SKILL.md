---
description: Execute the next phase from the active work plan
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion, Skill, SendMessage, ListAgents, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions
---

# Execute Phase

Execute the next uncompleted phase. **This is the heart of interactive mode**, not a lesser `/run-workflow`: ONE approval gate up front (plan + all questions batched), then execution — and a real doubt is asked **live, in this chat**, because here there is somebody who can answer.

Two kinds of interruption, and only one is legitimate: a question that needs a **decision** — ask it, take the answer, resume. Asking the user to **try something trivial** mid-phase is not a question, it is the symptom of a phase that was cut too small; the cure is sizing, and manual checks belong in `Verify:` at the end. Execution stays on a strong model — `opus` floor, never `sonnet`, which is also the standing rule for UI and declarative work.

**The phase's `Run: <model> / <effort>` line** is the plan's advice for this session, decided during planning. Neither value can be changed from inside the session, so read it rather than reconsider it:

- **Effort** governs how wide you look before the gate — the scale is in Step 3. Missing line → treat as `high`.
- **`fable`** means the phase kept inventive work of its own. Read this file as a contract on the *output* — the approval gate, one phase, one commit, the outcome format — not as a procedure to walk step by step, since a prescriptive step list is exactly what degrades that model. The settled `Decisions:` are input, not something to re-derive.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start — language, AskUserQuestion style, plan directory, workflow branch, phase-selection semantics. **Shared mechanics:** `${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md` — selection, implementation discipline, outcome formats, the phase commit; `/execute-phase-agent` is this same skill with the gate replaced by unattended constraints.

## Step 1: Find the plan and the phase

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
```

No active plan → stop and say so: `/write-workflow` creates one, `/import-workflow` adapts an older one. The plan lives on the workflow branch, so being on the wrong branch is the usual reason it is missing — check `git branch --show-current` before concluding there is no work. If the plan lives in another checkout (or the user means a different workflow), resolve via `--plans` and anchor every command to that plan's root — `common.md` → *Plan location*.

Act on `recommendation:` — `next: N` → proceed; `resume-candidate: N` → ask whether to take over a phase another chat left `[>]` — on yes, resume per the shared core (`refs/phase-execution.md` → *WIP checkpoints*): the `> WIP:` note and its `commit:` are the evidence, the diff decides what is already done; `attention: ...` → surface the `[!]`/`[~]` phases, they block what follows; `done` → suggest `/finalize-workflow`; `blocked: ...` → report and stop.

Mark the phase `[>]` with `> In execution since <ISO timestamp>`.

## Step 2: `vast` phases only — read-only fan-out

Skip unless the phase is tagged `vast`. Partition its `Files:` list (or run its discovery rule) into slices, dispatch one read-only Explore subagent per slice, and build the Step 3 gate from their summaries instead of reading the whole surface yourself. **This fan-out writes nothing.**

## Step 3: The approval gate (the only planned interruption)

Read the phase's `Pattern:` example first — don't re-explore what planning already recorded.

**Scale the exploration to the phase's `Run:` effort** (missing → `high`): `low` only the listed `Files:`; `medium` + their immediate references; `high` up to 2 read-only Explore subagents and the surrounding package; `xhigh`/`max` up to 3 plus a cross-package consistency pass. Same scale as `/execute-phase-agent` Step 2 — what differs is only that here it ends in a question instead of a decision.

Present in ONE message: what the phase will do, the files to create/modify/delete with their key changes, and **every open question batched** (anything `Decisions:`/`Details:` leave unsettled). Then ONE AskUserQuestion carrying approval plus those questions.

**No file may be edited before approval. After approval, run to completion.**

## Step 4: Execute

Implement only this phase. When a coherent, demonstrable sub-result lands and substantial work remains, checkpoint it per the shared core (*WIP checkpoints*) — the cost is a `partial` commit the squash will drop, the payoff is that a dying session loses minutes, not the phase. If something the plan doesn't cover comes up and a wrong default would be costly, ask ONE batched question and record the answer in Notes; otherwise take the conservative option and note it.

**When an answer changes the plan itself** — a phase reshaped, a decision reversed, scope moved — the plan edit gets committed as usual, and the foreman chat is told: one `plan changed at phase N` message per the protocol in `common.md` → *The foreman*, best-effort. The father must not discover a deviation at finalize.

## Step 5: Verify

- Testable logic → write/update tests in the repo's existing style, run the suite. A failure that doesn't touch this phase's `Files:` is probably pre-existing: check before absorbing it, and tell the user instead. Fix and re-run, ONE retry; still red → `[!]`.
- Purely UI/declarative → what a browser agent can assert still belongs to the machine: the `ui-test` skill (Skill tool), where installed, drives a real browser (the flow works, the record persists, the grid reloads). Run it, or say why you didn't — and when it is not installed, apply the declared fallback in `${CLAUDE_PLUGIN_ROOT}/refs/common.md` → *Verification*: those checks go to the human as `Verify: now` steps, said out loud.
- `vast` → optionally re-run the read-only fan-out to confirm no site was missed, then test as usual.

What is left after that — aesthetics, "is this interaction right?", UX ambiguity — is the human's, and only that. Record it as `> Verify:` notes, each with its *when*, **starting from the phase's own authored `Verify:` fields** and adding what execution surfaced, per `${CLAUDE_PLUGIN_ROOT}/refs/common.md` → *Verification*: `now` steps go in the phase summary, `deferred: needs Phase M` steps are **also appended to `verify.md`** in the plan directory, under a `## Phase N` heading, so `/finalize-workflow` can present them as one QA pass. Never use `Verify:` to offload a check the tests could have made.

## Step 6: Record and notify

Record the outcome and make the phase commit exactly as the shared core (`refs/phase-execution.md`) specifies — the Step 5 `> Verify:` notes included, surfaced in the notification and the summary. Then the shared core's *Notify the foreman*: one outcome message to the foreman chat, best-effort.

```bash
osascript -e 'display notification "Phase N: <short outcome>" with title "Claude — <repo>/<branch>" sound name "Glass"'
```

Then summarise in Italian: what was done, test results, the manual checks left to the user — **and the next step, always**: the next phase with its `Run:` hint quoted (*"prossima: Phase N+1 — nuova chat, `/execute-phase` (suggerito: \<model\> / \<effort\>)"*), or `/finalize-workflow` when this was the last. The user must never need to know the flow by heart to keep moving.

## Context window

The user strongly dislikes compaction — act before it happens. When the phase isn't done and the context is filling (or it already compacted once), offer: *"⚠️ Il contesto si sta riempiendo. Apri una nuova chat e rilancia /execute-phase. Salvo il lavoro parziale in un commit prima?"* On yes: checkpoint exactly as the shared core (`refs/phase-execution.md` → *WIP checkpoints*) specifies — `partial` commit and structured `> WIP:` note together, never one without the other.

## Rules

- NEVER edit before the Step 3 approval; the `vast` fan-out never bypasses it
- ONE phase per invocation; no out-of-scope refactoring
- After approval, no further questions except the Step 4 blocker policy
- ONE phase commit per phase, at Step 6 — WIP checkpoints (shared core) are `partial` commits, not phase commits
- If the session dies with the plan still writable and NO checkpoint exists, reset `[>]` to `[ ]` with `> Execution interrupted, phase available for retry` — and commit that reset as `wf: reset phase N` (the plan is tracked). With a checkpoint, leave `[>]` and its `> WIP:` note in place: they are the handoff
