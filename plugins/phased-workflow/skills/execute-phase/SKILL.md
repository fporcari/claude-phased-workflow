---
description: Execute the next phase from the active work plan
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion
---

# Execute Phase

Execute the next uncompleted phase. **Semi-autonomous**: ONE approval gate up front (plan + all questions batched), then run to completion without interruptions.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start — language, AskUserQuestion style, plan directory, workflow branch, phase-selection semantics.

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
- Purely UI/declarative → no tests; **the user is the verifier**. Record the manual checks as `> Verify:` and surface them in the notification and the summary.
- `vast` → optionally re-run the read-only fan-out to confirm no site was missed, then test as usual.

## Step 6: Record and notify

Replace `[>]` with `[x]` + `> Done:` + `> Files:` (+ `> Verify:` for untested UI work), or `[!]` + `> Issue:`, or `[~]` + `> Blocked:`. **Always list ALL touched files** — the baseline check of later phases attributes regressions by them, and `/repair-phase` diffs against them.

Then commit the phase's code together with its status update, so the next one starts from a clean tree:

```bash
git add -A && git commit -q -m "wf(phase N): <title>"
```

A phase closing `[!]` commits too, as `wf(phase N): FAILED — <title>` — repair needs to see the failing code.

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
