---
description: Execute the next phase from the active work plan
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion, Skill
---

# Execute Phase

Execute the next uncompleted phase. **This is the heart of interactive mode**, not a lesser `/run-workflow`: ONE approval gate up front (plan + all questions batched), then execution — and a real doubt is asked **live, in this chat**, because here there is somebody who can answer.

Two kinds of interruption, and only one is legitimate: a question that needs a **decision** — ask it, take the answer, resume. Asking the user to **try something trivial** mid-phase is not a question, it is the symptom of a phase that was cut too small; the cure is sizing, and manual checks belong in `Verify:` at the end. Execution stays on a strong model — `opus` floor, never `sonnet`, which is also the standing rule for UI and declarative work.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start — language, AskUserQuestion style, plan directory, workflow branch, phase-selection semantics. **Shared mechanics:** `${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md` — selection, implementation discipline, outcome formats, the phase commit; `/execute-phase-agent` is this same skill with the gate replaced by unattended constraints.

## Step 1: Find the plan and the phase

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
```

No active plan → stop and say so: `/write-workflow` creates one, `/import-workflow` adapts an older one. The plan lives on the workflow branch, so being on the wrong branch is the usual reason it is missing — check `git branch --show-current` before concluding there is no work. If the plan lives in another checkout (or the user means a different workflow), resolve via `--plans` and anchor every command to that plan's root — `common.md` → *Plan location*.

Act on `recommendation:` — `next: N` → proceed; `resume-candidate: N` → ask whether to take over a phase another chat left `[>]`; `attention: ...` → surface the `[!]`/`[~]` phases, they block what follows; `done` → suggest `/finalize-workflow`; `blocked: ...` → report and stop.

Mark the phase `[>]` with `> In execution since <ISO timestamp>`.

## Step 2: `vast` phases only — read-only fan-out

Skip unless the phase is tagged `vast`. Partition its `Files:` list (or run its discovery rule) into slices, dispatch one read-only Explore subagent per slice, and build the Step 3 gate from their summaries instead of reading the whole surface yourself. **This fan-out writes nothing.**

## Step 3: The approval gate (the only planned interruption)

Read the phase's `Pattern:` example first — don't re-explore what planning already recorded.

Present in ONE message: what the phase will do, the files to create/modify/delete with their key changes, and **every open question batched** (anything `Decisions:`/`Details:` leave unsettled). Then ONE AskUserQuestion carrying approval plus those questions.

**No file may be edited before approval. After approval, run to completion.**

## Step 4: Execute

Implement only this phase. If something the plan doesn't cover comes up and a wrong default would be costly, ask ONE batched question and record the answer in Notes; otherwise take the conservative option and note it.

## Step 5: Verify

- Testable logic → write/update tests in the repo's existing style, run the suite. A failure that doesn't touch this phase's `Files:` is probably pre-existing: check before absorbing it, and tell the user instead. Fix and re-run, ONE retry; still red → `[!]`.
- Purely UI/declarative → what a browser agent can assert still belongs to the machine: the `ui-test` skill (Skill tool) drives a real browser (the flow works, the record persists, the grid reloads). Run it, or say why you didn't.
- `vast` → optionally re-run the read-only fan-out to confirm no site was missed, then test as usual.

What is left after that — aesthetics, "is this interaction right?", UX ambiguity — is the human's, and only that. Record it as `> Verify:` notes, each with its *when*, per `${CLAUDE_PLUGIN_ROOT}/refs/common.md` → *Verification*: `now` steps go in the phase summary, `deferred: needs Phase M` steps are **also appended to `verify.md`** in the plan directory, under a `## Phase N` heading, so `/finalize-workflow` can present them as one QA pass. Never use `Verify:` to offload a check the tests could have made.

## Step 6: Record and notify

Record the outcome and make the phase commit exactly as the shared core (`refs/phase-execution.md`) specifies — plus, for untested UI work, a `> Verify:` note with the manual checks, surfaced in the notification and the summary.

```bash
osascript -e 'display notification "Phase N: <short outcome>" with title "Claude — <repo>/<branch>" sound name "Glass"'
```

Then summarise in Italian: what was done, test results, and the manual checks left to the user.

## Context window

The user strongly dislikes compaction — act before it happens. When the phase isn't done and the context is filling (or it already compacted once), offer: *"⚠️ Il contesto si sta riempiendo. Apri una nuova chat e rilancia /execute-phase. Salvo il lavoro parziale in un commit prima?"* On yes: `git add -A && git commit -m "wf(phase N): partial — <title>"`, then keep `[>]` and add `> WIP: <what is done, what remains>`.

## Rules

- NEVER edit before the Step 3 approval; the `vast` fan-out never bypasses it
- ONE phase per invocation; no out-of-scope refactoring
- After approval, no further questions except the Step 4 blocker policy
- ONE commit per phase, at Step 6 and nowhere else
- If the session dies with the plan still writable, reset `[>]` to `[ ]` with `> Execution interrupted, phase available for retry` — and commit that reset as `wf: reset phase N` (the plan is tracked)
