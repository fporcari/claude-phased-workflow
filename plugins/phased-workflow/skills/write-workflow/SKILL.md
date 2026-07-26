---
description: Write a phased work plan from the current conversation — branch, plan directory, first commit
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(mkdir:*), Bash(command:*), Bash(cp:*), Bash(code:*), Bash(python3:*), Read, Grep, Glob, Write, AskUserQuestion, Agent
---

# Write Workflow

Plan a work session, then open the branch and commit the plan. The plan is the **only** deliverable.

1. **NEVER edit source code.** Read anything; write nothing outside `.phased/`.
2. **Do not implement.** The user runs `/execute-phase` afterwards.

**Shared conventions:** read `~/.claude/workflow-refs/common.md` once at start — language, AskUserQuestion style, plan directory, workflow branch.

**Mode:** plans are **interactive** by default; don't ask. Only if the user explicitly asks for an autonomous/robottino plan (for `/run-all-phases`), read `~/.claude/workflow-refs/write-workflow-autonomous.md` and apply its stricter format on top of this.

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

**Close the presentation with the branch line**, pre-filled per Step 3 and flippable — one line, not a separate question:

```
Branch: <what will happen> · Worktree: <sì/no>   (dimmi se preferisci diversamente)
```

## Step 3: Open the branch

Only after approval, and before writing anything.

Derive the slug from the objective: kebab-case, strip accents, ≤50 chars, a leading issue number kept as prefix (`123-fix-login`).

**On the base branch** → `git switch -c wf/<slug>`, no question asked.

**On a feature branch** → the default is to **adopt it** as the workflow branch: `.phased/` goes there, no new branch, and `Parent:` is that branch's own base. You created that branch on purpose; nesting another inside it buys nothing. The alternative, offered in the branch line above, is `wf/<slug>` off it — take it when the workflow is a distinct chunk the user may want to merge or drop on its own; the current branch then becomes the `Parent:`.

Adoption is safe because the workflow's base is the plan commit, not the branch point (see `common.md`): whatever the branch already carried stays outside the workflow.

**Worktree** — only on an autonomous plan (`Mode: autonomous`), where the run grinds elsewhere for a long time and leaves the main repo free. An interactive plan stays here: you drive `/execute-phase` from this session, and a worktree would only cost a `cd`. When it applies, and only when a new branch is being created:

```bash
git worktree add .claude/worktrees/<slug> -b wf/<slug> HEAD
mkdir -p .claude/worktrees/<slug>/.claude .claude/worktrees/<slug>/.vscode
[ -f .claude/settings.local.json ] && cp .claude/settings.local.json .claude/worktrees/<slug>/.claude/settings.local.json
command -v code >/dev/null 2>&1 && code .claude/worktrees/<slug>
```

One command creates branch and worktree together, and the main repo stays put — do NOT `git switch -c` first, a branch checked out in the main repo cannot be added as a worktree. Give the window its own identity by hashing the branch name to a hue (0-360) at 65% saturation / 35% lightness, merged into the worktree's `.vscode/settings.json` (usually already present, so merge rather than overwrite):

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path(".claude/worktrees/<slug>/.vscode/settings.json")
p.parent.mkdir(parents=True, exist_ok=True)
data = json.loads(p.read_text()) if p.exists() else {}
data["workbench.colorCustomizations"] = {
    "titleBar.activeBackground": "<color>",
    "titleBar.activeForeground": "#ffffff",
}
p.write_text(json.dumps(data, indent=4) + "\n")
PY
git -C .claude/worktrees/<slug> update-index --assume-unchanged .vscode/settings.json
```

That file is tracked, so the local colour would otherwise show up in `git status` — the last line hides it, reversibly (`--no-assume-unchanged`).

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

On a worktree, append these two lines to that message — they are for the user to run, not for you:

```
Il worktree è in .claude/worktrees/<slug>. Lavora da lì:
  cd .claude/worktrees/<slug> && claude
```

(Autonomous plans use the closing message in the autonomous reference file.)
