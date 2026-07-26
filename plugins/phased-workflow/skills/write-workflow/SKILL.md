---
description: Write a phased work plan (MEMORY.md) from the current conversation
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Read, Grep, Glob, Write, AskUserQuestion, Agent, mcp__sourcerer__kb_*, mcp__sourcerer__sem_*, mcp__sourcerer__code_*
---

# Write Workflow

Plan a work session and write the phased plan to a memory file. That plan is the **only** deliverable.

1. **NEVER edit source code.** Read anything; write nothing outside the memory file.
2. **Do not implement.** The user runs `/execute-phase` afterwards.

**Shared conventions:** read `~/.claude/workflow-refs/common.md` once at start — language, AskUserQuestion style, MEMORY.md path resolution.

**Mode:** plans are **interactive** by default; don't ask. Only if the user explicitly asks for an autonomous/robottino plan (for `/run-all-phases`), read `~/.claude/workflow-refs/write-workflow-autonomous.md` and apply its stricter format on top of this.

## Step 1: Where are we

```bash
git branch --show-current
git rev-parse --show-toplevel
cat .claude/parent-branch 2>/dev/null || git rev-parse --verify origin/develop >/dev/null 2>&1 && echo develop || echo main
```

**On a feature branch** — read what is already there (`git log origin/<base>..HEAD --oneline`, `git diff --stat origin/<base>...HEAD`, the full diff, and `gh issue view <number>` if the branch starts with one), summarise it, then ask: *"Cosa vuoi pianificare su questo branch?"*

**On the base branch** — no exploration. Ask straight away: *"Sei su `<branch>`. Cosa vuoi fare?"*

The user's answer is the primary input. Read code only in service of the plan.

## Step 2: Build the plan

Extract from the conversation: objective, phases, files per phase, pattern references, decisions, parallel groups, sizing, notes.

**Pattern references.** Every `/execute-phase` runs in a fresh chat: whatever isn't in the plan gets re-discovered there, phase after phase. While the code is in front of you, find 1–2 existing examples to copy-adapt for each phase that writes non-trivial code, and record concrete paths in `Pattern:`. Library-standard work → `library-standard`; nothing comparable → `new-pattern`. From ~3 such phases up, dispatch one read-only Explore subagent per phase instead of searching serially, and reason over what they return.

**Decisions.** `/execute-phase` has a single approval gate, so every choice needing the user's judgment — naming, signatures, library, API shape, trade-offs — is settled *here*, batched into AskUserQuestion, and recorded in `Decisions:`. A phase containing "decide later" is not ready. On a real architectural fork, give a recommendation with its trade-off; say if it is the kind of choice a judge panel would decide better, and let the user ask for one.

**Parallel groups.** Rare bonus, not the default. `parallel:N` only when the phases touch **completely different files**, exchange no data, share no state, and live in different areas of the codebase. Any doubt → sequential (a wrong tag causes git conflicts between chats). Propose it to the user unless they already said the phases are independent.

**Sizing.** Size each phase:
1. **Standard** (no tag) — one concern, ~6-8 files, testable alone. The common case.
2. **`group:N`** — too small to test alone (a model half, a migration, a schema): consecutive phases run together in one chat, verified by a single end-to-end test written in the **last** one's `Details:`. Combined they must still fit one chat.
3. **Split** — two concerns in one phase: just write more phases, no tag.
4. **`vast`** — one indivisible concern with a genuinely large surface (>~10 files). At execution a read-only fan-out maps it, so the ~6-8 file ceiling is lifted for it only.

A phase carries at most one of `group:N` / `parallel:N`. Only the split-vs-`vast` call materially changes execution — batch it into the Decisions questions; grouping just gets shown in the plan review.

**Present the plan in Italian** and iterate until the user approves.

## Step 3: Write it

Only after approval. Target `<repo_root>/.claude/MEMORY.md`, unless it already holds a plan with unchecked `- [ ]` phases → write `memory_<branch-in-kebab>.md` next to it, headed `<!-- Parallel context — primary plan in MEMORY.md -->`, and say so. All phases `[x]` → overwrite.

```
# Context: <branch-name>
Parent: <parent-branch> | Issue: #<number> (if present)

## Objective
[2-3 sentences]

## Work Plan
- [ ] **Phase 1**: <concise title>
  - Pattern: `path/to/example.py:func` (or `library-standard` / `new-pattern`)
  - Files: <involved files, if known>
  - Decisions: <choices already settled — omit if none>
  - Details: <what to do concretely>
- [ ] **Phase 2**: <concise title>  `parallel:1`
  - Pattern: ...
  - Files: ...
  - Details: ...
- [ ] **Phase 3**: create table foo (model)  `group:1`
  - Files: packages/foo/model/foo.py
  - Details: table + columns + relations. No standalone test (tested with Phase 4).
- [ ] **Phase 4**: TH UI to manage foo  `group:1`
  - Files: packages/foo/webpages/foo.py
  - Details: TableHandler view + form on foo. Group end-to-end test: create a row via the form, assert it persists and reloads in the grid.
- [ ] **Phase 5**: rename legacyAmount → amount across the web layer  `vast`
  - Files: discovery rule — all references to `legacyAmount` under packages/foo/ and gnr/web/
  - Details: rename + deprecated alias.

## Notes
[Attention points, dependencies, breaking changes]
```

Phases sharing a `parallel:N` can run from separate chats; a phase without the tag is a **synchronization barrier** — every phase above it must be `[x]` first.

No "Suggested execution config" table on interactive plans: nothing reads it. The one useful per-phase hint is `Model hint: sonnet`, and it is deliberately rare — mechanical work only (renames, extractions, moves), **never on UI or declarative phases**, and only when that phase's `Details:` is spelled out to the point where nothing is left to infer. If you can't write it that way, leave the hint off. No hint means opus.

## Step 4: Close

```
Piano scritto in <file> (<N> fasi).
Per eseguire, lancia /execute-phase (meglio in una nuova sessione per contesto pulito).
```

(Autonomous plans use the closing message in the autonomous reference file.)
