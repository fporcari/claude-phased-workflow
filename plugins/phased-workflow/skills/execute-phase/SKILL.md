---
description: Execute the next phase from the work plan (MEMORY.md or parallel context)
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion
---

# Execute Phase

Execute the next uncompleted phase. **Semi-autonomous**: ONE approval gate up front (plan + all questions batched), then run to completion without interruptions.

**Shared conventions:** read `~/.claude/workflow-refs/common.md` once at start — language, AskUserQuestion style, MEMORY.md path resolution, phase-selection semantics.

## Step 1: Find the plan and the phase

```bash
git rev-parse --show-toplevel
git worktree list --porcelain
```

In a worktree → `<repo_root>/.claude/MEMORY.md`. In the main repo → look for active `- [ ]` phases in `MEMORY.md`, `memory_*.md` and `.claude/worktrees/*/`; none → stop; one → use it; several → AskUserQuestion. If a worktree plan is chosen from the main repo, tell the user to run from there: `cd .claude/worktrees/<name> && claude`.

```bash
python3 ~/.claude/scripts/next-phase.py <memory-file>
```

Act on `recommendation:` — `next: N` → proceed (a `unit: N,M,...` means a `group:N` runs together in this chat, the only case where one invocation spans several phases); `resume-candidate: N` → ask whether to take over a phase another chat left `[>]`; `attention: ...` → surface the `[!]`/`[~]` phases, they block what follows; `done` → suggest `/finalize-workflow`; `blocked: ...` → report and stop.

Mark the phase (every phase of a `group:N` unit) `[>]` with `> In execution since <ISO timestamp>`.

## Step 2: `vast` phases only — read-only fan-out

Skip unless the phase is tagged `vast`. Partition its `Files:` list (or run its discovery rule) into slices, dispatch one read-only Explore subagent per slice, and build the Step 3 gate from their summaries instead of reading the whole surface yourself. **This fan-out writes nothing.**

## Step 3: The approval gate (the only planned interruption)

Read the phase's `Pattern:` example first — don't re-explore what planning already recorded.

Present in ONE message: what the phase will do, the files to create/modify/delete with their key changes, and **every open question batched** (anything `Decisions:`/`Details:` leave unsettled). Then ONE AskUserQuestion carrying approval plus those questions.

**No file may be edited before approval. After approval, run to completion.** Inside a `group:N` unit, repeat the gate once per phase — each write stays individually approved.

## Step 4: Execute

Implement only this phase. If something the plan doesn't cover comes up and a wrong default would be costly, ask ONE batched question and record the answer in Notes; otherwise take the conservative option and note it.

In a `group:N` unit, implement in order and close every non-last phase `[x]` with its `> Files:` and `> Grouped: tested at Phase <last>` — no per-phase test.

## Step 5: Verify

- Testable logic → write/update tests in the repo's existing style, run the suite. A failure that doesn't touch this phase's `Files:` is probably pre-existing: check before absorbing it, and tell the user instead. Fix and re-run, ONE retry; still red → `[!]`.
- Purely UI/declarative → no tests; **the user is the verifier**. Record the manual checks as `> Verify:` and surface them in the notification and the summary.
- `group:N` → the single end-to-end test lives on the **last** phase; if it fails only that phase is `[!]`, the earlier members stay `[x]`.
- `vast` → optionally re-run the read-only fan-out to confirm no site was missed, then test as usual.

## Step 6: Record and notify

Replace `[>]` with `[x]` + `> Done:` + `> Files:` (+ `> Verify:` for untested UI work), or `[!]` + `> Issue:`, or `[~]` + `> Blocked:`. **Always list ALL touched files** — `/finalize-workflow` scopes commits by them. Do NOT commit.

```bash
osascript -e 'display notification "Phase N: <short outcome>" with title "Claude — <repo>/<branch>" sound name "Glass"'
```

Then summarise in Italian: what was done, test results, and the manual checks left to the user.

## Context window

The user strongly dislikes compaction — act before it happens. When the phase isn't done and the context is filling (or it already compacted once), offer: *"⚠️ Il contesto si sta riempiendo. Apri una nuova chat e rilancia /execute-phase. Faccio un commit WIP di salvataggio prima?"* On yes: `git add <files> && git commit -m "WIP: <phase title> — partial progress"` (the only commit allowed here), then keep `[>]` and add `> WIP: <what is done, what remains. WIP commit present.>`.

## Rules

- NEVER edit before the Step 3 approval; the `vast` fan-out never bypasses it
- ONE phase per invocation, except a `group:N` unit; no out-of-scope refactoring
- After approval, no further questions except the Step 4 blocker policy
- Do NOT commit (except the WIP safety commit)
- If the session dies with the memory file still writable, reset `[>]` to `[ ]` with `> Execution interrupted, phase available for retry`
