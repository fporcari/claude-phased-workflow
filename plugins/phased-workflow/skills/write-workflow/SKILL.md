---
description: Write a phased work plan from the current conversation — branch, plan directory, first commit
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(mkdir:*), Bash(cp:*), Bash(python3:*), Read, Grep, Glob, Write, AskUserQuestion, Agent
---

# Write Workflow

Plan a work session, then open the branch and commit the plan. The plan is the **only** deliverable.

1. **NEVER edit source code.** Read anything; write nothing outside `.phased/`.
2. **Do not implement.** The user runs `/execute-phase` afterwards.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start — language, AskUserQuestion style, plan directory, workflow branch.

**Mode:** plans are **interactive** by default; don't ask. Only if the user explicitly asks for an autonomous/robottino plan (for `/run-workflow`), read `${CLAUDE_PLUGIN_ROOT}/refs/write-workflow-autonomous.md` and apply its stricter format on top of this.

## Step 1: Where are we

```bash
git branch --show-current
git rev-parse --show-toplevel
git rev-parse --verify origin/develop >/dev/null 2>&1 && echo develop || echo main
```

**On a feature branch** — read what is already there (`git log origin/<base>..HEAD --oneline`, `git diff --stat origin/<base>...HEAD`, the full diff, and `gh issue view <number>` if the branch starts with one), summarise it, then ask: *"Cosa vuoi pianificare su questo branch?"*

**On the base branch** — no exploration. Ask straight away: *"Sei su `<branch>`. Cosa vuoi fare?"*

The user's answer is the primary input. Read code only in service of the plan.

This same fork decides the branch in Step 4 — remember which side you are on.

## Step 2: Build the plan

Extract from the conversation: objective, phases, files per phase, pattern references, decisions, sizing, notes.

**Pattern references.** Every `/execute-phase` runs in a fresh chat: whatever isn't in the plan gets re-discovered there, phase after phase. While the code is in front of you, find 1–2 existing examples to copy-adapt for each phase that writes non-trivial code, and record concrete paths in `Pattern:`. Library-standard work → `library-standard`; nothing comparable → `new-pattern`. From ~3 such phases up, dispatch one read-only Explore subagent per phase instead of searching serially, and reason over what they return.

**Decisions.** `/execute-phase` has a single approval gate, so every choice needing the user's judgment — naming, signatures, library, API shape, trade-offs — is settled *here*, batched into AskUserQuestion, and recorded in `Decisions:`. A phase containing "decide later" is not ready. On a real architectural fork, give a recommendation with its trade-off; say if it is the kind of choice a judge panel would decide better, and let the user ask for one.

**Sizing.** Size each phase:
1. **Standard** (no tag) — one concern, ~6-8 files, testable alone. The common case. Too small to test alone (a model half, a migration, a schema)? Merge it into the phase that makes it testable — a phase boundary the user cannot verify is a boundary in the wrong place.
2. **Split** — two concerns in one phase: just write more phases, no tag.
3. **`vast`** — one indivisible concern with a genuinely large surface (>~10 files). At execution a read-only fan-out maps it, so the ~6-8 file ceiling is lifted for it only.

Only the split-vs-`vast` call materially changes execution — batch it into the Decisions questions. Phases always run in order, each in its own chat; there are no parallel or grouped phases.

**Present the plan in Italian** and iterate until the user approves.

**Close the presentation with the branch line**, pre-filled per Step 3 and flippable — one line, not a separate question:

```
Branch: <what will happen>   (dimmi se preferisci diversamente)
```

## Step 3: Open the branch

Only after approval, and before writing anything.

Derive the slug from the objective: kebab-case, strip accents, ≤50 chars, a leading issue number kept as prefix (`123-fix-login`).

**On the base branch** → `git switch -c wf/<slug>`, no question asked.

**On a feature branch** → the default is to **adopt it** as the workflow branch: `.phased/` goes there, no new branch, and `Parent:` is that branch's own base. You created that branch on purpose; nesting another inside it buys nothing. The alternative, offered in the branch line above, is `wf/<slug>` off it — take it when the workflow is a distinct chunk the user may want to merge or drop on its own; the current branch then becomes the `Parent:`.

Adoption is safe because the workflow's base is the plan commit, not the branch point (see `common.md`): whatever the branch already carried stays outside the workflow.

**No worktree here.** Planning creates the branch and the plan, nothing else: the workspace belongs to execution. `/run-workflow` attaches or creates the worktree itself when the run needs one, and `/finalize-workflow` removes it — the user never manages it.

## Step 4: Write it

`.phased/active/` already occupied → stop and say so: one branch, one plan. Otherwise create `.phased/active/<slug>/` holding `plan.md` and an empty `notes.md`.

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
- [ ] **Phase 2**: table foo with its TH UI (model + webpage)
  - Files: packages/foo/model/foo.py, packages/foo/webpages/foo.py
  - Details: table + columns + relations, then TableHandler view + form. End-to-end test: create a row via the form, assert it persists and reloads in the grid.
- [ ] **Phase 3**: rename legacyAmount → amount across the web layer  `vast`
  - Files: discovery rule — all references to `legacyAmount` under packages/foo/ and gnr/web/
  - Details: rename + deprecated alias.

## Notes
[Attention points, dependencies, breaking changes]
```

Phases run strictly in order: a phase starts only when every phase above it is `[x]`.

No "Suggested execution config" table on interactive plans: nothing reads it. The one useful per-phase hint is `Model hint: sonnet`, and it is deliberately rare — mechanical work only (renames, extractions, moves), **never on UI or declarative phases**, and only when that phase's `Details:` is spelled out to the point where nothing is left to infer. If you can't write it that way, leave the hint off. No hint means opus.

## Step 5: Commit and close

The plan is the branch's first commit — everything after it is the workflow:

```bash
git add .phased && git commit -m "wf: plan for <slug>"
```

Verify it is not empty (`git show --stat HEAD`). An empty commit means `.phased/` is excluded by a `.gitignore` — say so and stop rather than working around it; the whole chain depends on the plan being tracked.

```
Piano scritto in .phased/active/<slug>/plan.md (<N> fasi), committato su <branch>.
Per eseguire, lancia /execute-phase (meglio in una nuova sessione per contesto pulito).
```

(Autonomous plans use the closing message in the autonomous reference file.)
