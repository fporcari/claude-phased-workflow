---
description: Write a phased work plan (MEMORY.md) from the current conversation
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Read, Grep, Glob, Write, AskUserQuestion, Agent, mcp__sourcerer__kb_*, mcp__sourcerer__sem_*, mcp__sourcerer__code_*
---

# Write Workflow

Plan a work session and write the phased plan to a memory file. This is the **only** deliverable of this command.

**Model tip:** the plan is the input of every downstream `/execute-phase`, so its quality multiplies. Pick by the nature of the work, not by habit:

- **Introspective or inventive work** — ambiguous scope, architecture to invent, unknown surface, no obvious decomposition: discuss it first, then run this command in the same chat on **fable**. Its strength is exactly navigating that ambiguity, and here the plan *is* the hard problem.
- **Everything else** — the shape is already clear and this command mostly has to formalise it: **opus at `xhigh` effort**. Precise, literal, cheaper, and it fills this format's fields without drift.

**If you are running on fable:** treat the steps below as a *contract on what the plan must contain* (the fields, their semantics, the sizing ladder, the quality bar), not as a procedure to execute literally. Reach the output format your own way. Following a dense step-by-step to the letter is what degrades fable's output; the format itself is not the problem.

**CRITICAL CONSTRAINTS:**
1. **NEVER edit source code.** You may read any file to understand structure and patterns, but you must not modify anything outside the memory directory.
2. **The only output is the plan written to a memory file.** No code changes, no refactoring, no branch creation.
3. **Do not proceed to implementation.** The user will delegate execution via `/execute-phase`.

**Shared conventions:** read `~/.claude/workflow-refs/common.md` once at start — language, AskUserQuestion style, MEMORY.md path resolution.

**Mode:** Plans are **interactive** by default — executed phase-by-phase via `/execute-phase`. Do NOT ask the user which mode they want. Only if the user explicitly asks for an autonomous/robottino plan (to run via `/run-all-phases`), read `~/.claude/workflow-refs/write-workflow-autonomous.md` and apply its extra refinement loop and stricter plan format on top of the steps below.

## Step 1: Detect environment

```bash
git branch --show-current
git rev-parse --show-toplevel
```

Detect parent branch:
```bash
cat .claude/parent-branch 2>/dev/null || echo "unknown"
```

If `.claude/parent-branch` does not exist (not in a worktree created by `/create-context`), auto-detect the base branch:
```bash
git rev-parse --verify origin/develop 2>/dev/null && echo "develop" || echo "main"
```

**Case A — On a feature branch (different from base):**

Run in parallel:
1. `git log origin/<base>..HEAD --oneline --no-decorate`
2. `git diff --stat origin/<base>...HEAD`
3. `git diff origin/<base>...HEAD`
4. If branch name starts with a number: `gh issue view <number> --json title,body,labels,state --jq '{title,body,labels: [.labels[].name],state}'`

Present a concise summary, then ask: *"Cosa vuoi pianificare su questo branch?"* — wait for the user's response.

**Case B — On base branch (main/develop/master):**

Do NOT explore, do NOT run extra commands. Immediately ask: *"Sei su `<branch>`. Cosa vuoi fare?"* — wait for the user's response.

**In both cases:** the user's response is the primary input for the plan. You may read code to understand structure and dependencies, but always in service of building the plan — not as open-ended exploration.

## Step 2: Discuss and refine the plan

From the conversation context (prior discussion + user's response from Step 1), extract:
- **Objective**: what the user wants to achieve (2-3 sentences)
- **Phases**: concrete, self-contained steps to implement
- **Files**: which files are likely involved per phase (if known)
- **Pattern references**: existing examples to copy-adapt, per phase (see below)
- **Decisions**: choices needing the user's judgment, resolved now (see below)
- **Parallel groups**: identify phases that are independent (no shared files, no data flow dependency) and can be executed concurrently
- **Sizing**: give each phase its size — standard (default) / `group` (too small to test alone) / `vast` (indivisible but large) — and split oversized phases into standard ones (see *Phase sizing* below)
- **Notes**: constraints, dependencies, attention points

You may:
- **Read code** to understand structure, patterns, or dependencies relevant to the plan
- **Read issues** if the user references them
- **Ask clarifying questions** in natural conversation

### Pattern references (token saver — fill for every non-trivial phase)

Each `/execute-phase` runs in a fresh chat: anything not written in the plan gets re-discovered there, phase after phase. While planning — when the code is already in front of you — locate 1–2 existing examples to copy-adapt for every phase that implements non-trivial code (new endpoint, new model, new component, new service, new view — anything where "we usually do it like X here"). Use Grep/Glob/Read or Sourcerer, and record concrete paths in the phase's `Pattern:` field. Mark library-standard work (e.g. a plain pytest test) as `library-standard`; if no comparable example exists, write `new-pattern`.

**Fan out when there are several to find.** Pattern hunting across N phases is N independent searches, and doing them serially in the chat that also has to converse with the user is the slowest possible arrangement. From ~3 non-trivial phases up, dispatch one read-only `Explore` subagent per phase (Agent tool), each asked for 1–2 concrete `path:symbol` candidates plus a one-line reason, then reason over the returned candidates rather than the raw files. Keep it read-only — this informs the plan, it never writes. For a refactor whose *surface* is unknown (you cannot yet name the phases), the same fan-out works as a multi-modal sweep: one agent per search angle (by directory, by symbol, by caller, by test), each blind to what the others find. Below ~3 phases the dispatch overhead is not worth it — just grep.

### Decisions up front (the questions happen HERE)

`/execute-phase` runs semi-autonomously: one approval gate at phase start, then no interruptions until done. So every choice that needs the user's judgment — naming, signatures, library, API shape, approach trade-offs — must be settled during planning. Batch these questions (AskUserQuestion, not a one-by-one drip) and record the answers in each phase's `Decisions:` field. A phase containing "decide later" or "evaluate options" is not ready.

**When a decision is a real architectural fork** — two or three defensible designs with different consequences, not a naming preference — offering the user your single pick is weaker than showing them a judged comparison. If they have opted into multi-agent orchestration for this turn, that fork is worth a judge panel: N independent designs from different angles, scored in parallel by distinct lenses, synthesised from the winner while grafting the good ideas from the runners-up. **You cannot start one unilaterally** — orchestration requires the user's explicit opt-in per turn — so the move is to name the fork, say plainly that it is the kind of choice a panel decides better than you do, and let them ask for one. Without the opt-in, do the ordinary thing: give a recommendation with its trade-off, not a survey.

### Parallel group detection (conservative — treat as a bonus)

Parallelization is a rare bonus, not the default. Most plans are sequential. Only propose `parallel:N` when ALL of these conditions are met:
- The phases touch **completely different files** — no overlap at all, not even shared config files or imports
- There is **no data flow** between them (one doesn't need the output of the other)
- There is **no shared state** (e.g. both writing to the same database table, both modifying the same module's public API)
- The phases work in **different areas of the codebase** (e.g. backend vs frontend, module A vs module B)

If there is any doubt, keep them sequential. A wrong parallel annotation can cause git conflicts between concurrent chats.

When you do identify clearly parallelizable phases, propose it to the user: *"Le fasi N, M e P lavorano su aree completamente separate del codice — le marco come parallele così puoi eseguirle da chat separate. Va bene?"*
If the user has already explicitly stated that phases are independent, you may skip the confirmation and directly apply `parallel:N` tags.

### Phase sizing (standard / group / vast)

After drafting each phase, size it with this ladder:
1. **Standard** (default, no tag) — one concern, ~6-8 files, testable on its own. The common case.
2. **Too small to test alone** — its only meaningful test is end-to-end with the next phase(s) (the model half of a model+UI pair, a migration, a schema). Tag it and its consecutive partners `group:N`: they run together in one chat, verified by a single end-to-end test written in the **last** phase's `Details:`. The grouped phases must still fit one chat as a whole (~6-8 files combined — if they don't, they weren't micro: make them standard).
3. **Too big but splittable** (two concerns hiding in one phase) — split into separate standard phases. No tag; splitting is just writing more phases.
4. **Too big but indivisible** — one concern whose surface is genuinely large (the same >~10-files signal `/check-phase-context` uses), where splitting would cut one atomic change in half. Tag it `vast`: at execution a read-only subagent fan-out maps and verifies the surface so the chat isn't flooded. The ~6-8 file ceiling is lifted for `vast` only.

Only the split-vs-`vast` call materially changes execution — batch it into the Decisions questions. Micro-grouping is low-risk: apply it and just show it in the plan review.

**Present the plan to the user in Italian** for review. Discuss and iterate until explicit approval.

## Step 3: Choose memory file and write plan

Only after user approval, determine which memory file to write.

### Memory file selection

1. Read the existing `<repo_root>/.claude/MEMORY.md` (path resolution: see shared conventions)
2. **If MEMORY.md does not exist or is empty** → write to `<repo_root>/.claude/MEMORY.md`
3. **If MEMORY.md already contains an active work plan** (has unchecked `- [ ]` phases):
   - Derive a context name from the branch name in kebab-case
   - Inform the user: *"MEMORY.md è già occupato. Salvo in `memory_<nome>.md`"*
   - Write to `<repo_root>/.claude/memory_<nome>.md`
   - Add to the top: `<!-- Parallel context — primary plan in MEMORY.md -->`
4. **If MEMORY.md contains a plan but all phases are completed** (all `- [x]`) → overwrite `<repo_root>/.claude/MEMORY.md`

### Plan format

```
# Context: <branch-name>
Parent: <parent-branch> | Issue: #<number> (if present)

## Objective
[2-3 sentences describing the overall goal]

## Work Plan
- [ ] **Phase 1**: <concise title>
  - Pattern: `path/to/example.py:func` (or `library-standard` / `new-pattern`)
  - Files: <involved files, if known>
  - Decisions: <choices already settled with the user — omit if none>
  - Details: <what to do concretely>
- [ ] **Phase 2**: <concise title>  `parallel:1`
  - Pattern: ...
  - Files: ...
  - Details: ...
  - Model hint: sonnet  (add ONLY on mechanical, trivial phases — omitted means opus)
- [ ] **Phase 3**: create table foo (model)  `group:1`
  - Files: packages/foo/model/foo.py
  - Details: table + columns + relations. No standalone test (tested with Phase 4).
- [ ] **Phase 4**: TH UI to manage foo  `group:1`
  - Files: packages/foo/webpages/foo.py
  - Details: TableHandler view + form on foo. Group end-to-end test: create a row via the form, assert it persists and reloads in the grid.
- [ ] **Phase 5**: rename legacyAmount → amount across the web layer  `vast`
  - Files: discovery rule — all references to `legacyAmount` under packages/foo/ and gnr/web/
  - Details: rename + deprecated alias. A read-only fan-out maps the call sites before the single gated edit.
[... more phases ...]

## Notes
[Any attention points, dependencies, breaking changes]
```

Do NOT add a "Suggested execution config" table to interactive plans — nothing consumes it (`/execute-phase` ignores it). The only useful per-phase hint is `Model hint: sonnet` on genuinely mechanical, well-specified phases, so the user knows that chat can be opened with a smaller model. Default (no hint) = opus.

Autonomous plans use the stricter format from `~/.claude/workflow-refs/write-workflow-autonomous.md` (Decisions/Done fields per phase, mandatory final review phase, execution config table for the launcher script).

Phases with the same `parallel:N` tag can be executed simultaneously from separate chats via `/execute-phase`. A phase without a `parallel:N` tag is a **synchronization barrier**: it cannot start until every phase listed above it has completed, whether those phases are parallel or sequential. Use increasing numbers for different parallel groups (e.g. `parallel:1` for one group, `parallel:2` for another).

Phases with the same `group:N` tag run **together in one chat** and are verified by a single end-to-end test on the group's **last** phase — the opposite axis of `parallel:N` (same chat, not different chats). A phase carries at most one of `group:N` / `parallel:N`. A phase tagged `vast` is one indivisible but large concern: at execution `/execute-phase` runs a read-only subagent fan-out to map and verify its surface, so the ~6-8 file ceiling is lifted for it only.

Principles for phases:
- Each phase must be **self-contained and independently testable**
- **Size for one fresh chat** (see *Phase sizing* above): the default is ONE concern, ~6-8 files, testable on its own. Too small to test alone → `group:N` with its neighbors (one end-to-end test on the last); too big but splittable → split into standard phases; too big but indivisible → `vast`. If you cannot predict the files at planning time, the phase is exploratory: split it, or flag it explicitly as needing the user mid-flight
- Logical order: dependencies first, tests after
- If a phase depends on another, state it explicitly
- If phases work on completely separate areas of the codebase (no shared files, no data dependency, no shared state), mark them with the same `parallel:N` group. When in doubt, keep sequential.

## Step 4: Inform and end

```
Piano scritto in <file> (<N> fasi).
Per eseguire, lancia /execute-phase (meglio in una nuova sessione per contesto pulito).
```

(For autonomous plans, use the closing message in the autonomous reference file.)

## Rules

- **NO source code editing** — this is a planning command
- If the conversation lacks enough detail, ask the user to clarify before writing
- Reading code is encouraged to inform the plan, but never as open-ended exploration
