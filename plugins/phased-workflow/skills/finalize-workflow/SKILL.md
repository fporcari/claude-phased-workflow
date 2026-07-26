---
description: Finalize the workflow - verify all phases, prepare final commit
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cd:*), Bash(head:*), Bash(sed:*), Read, Grep, Glob, Write, AskUserQuestion, Skill
---

# Finalize Workflow

Verify the work plan is complete and turn the working tree into one clean commit. **Never edit source code here** — findings get reported and delegated.

**Shared conventions:** read `~/.claude/workflow-refs/common.md` once at start — language, AskUserQuestion style, MEMORY.md path resolution.

## Step 1: Find the plan

```bash
git rev-parse --show-toplevel
git worktree list --porcelain
```

Set `IN_WORKTREE` from whether the cwd is in the worktree list. In a worktree → `<repo_root>/.claude/MEMORY.md`. In the main repo → also check `memory_*.md` and `.claude/worktrees/*/`; one plan with active phases → use it, several → AskUserQuestion. If a worktree plan is chosen from the main repo, tell the user to run from there.

Read it for branch, `Parent:`, issue number and phase states (also `.claude/parent-branch` if present). **Resolve the base ref**: `origin/<parent>` if `git rev-parse --verify` finds it, otherwise the local `<parent>` — use it everywhere below.

## Step 2: Verify completion

All phases `[x]` → proceed. Otherwise report the incomplete ones (warn specifically that a `[>]` may be a dead session) and ask whether to finalize anyway (default: no).

Collect any `> Verify:` lines — manual UI checks `/execute-phase` recorded — and ask whether the user has done them.

## Step 3: Stage the work

**In a worktree**, everything belongs to this workflow: `git diff --name-only <base>...HEAD` + `git status --short`, present it, then stage.

**In the main repo** (parallel workflows without worktrees), scope by the `> Files:` notes of the `[x]` phases: cross-reference against `git status --short`, flag files changed but listed in no phase (ask whether to include), flag files listed but unchanged (warn), and stage only the confirmed set.

Then consolidate WIP commits. Inspect `git log <base>..HEAD --oneline`:

- All commits in range are WIP → `git reset --soft <base>`
- WIP plus real commits → soft-reset only to the parent of the oldest commit in the contiguous WIP streak at HEAD (`git reset --soft <oldest-wip>^`)
- WIP and real commits interleaved → **STOP and ask the user**

Then `git add -A` (worktree) or `git reset HEAD . && git add <files>` (selective), and say how many WIP commits are being consolidated. In selective mode, files from *other* workflows inside those WIP commits become uncommitted again — expected.

## Step 4: Pre-commit review

Run the built-in `code-review` skill (Skill tool) on the staged diff — never with `--fix`. Effort `high` when the plan is `Mode: autonomous` or any phase carries a `> Review:` note (nobody read that code as it landed); `medium` otherwise.

Pass every `> Review:` note as an explicit focus point — each must come out confirmed or explicitly dismissed, never silently dropped. And instruct the review to hunt **cross-phase** issues specifically: each phase ran in a fresh session and was verified in isolation, so nothing has yet seen the whole diff at once — one phase breaking another's assumption, helpers duplicated by sessions unaware of each other, naming or pattern drift between phases.

**Large autonomous diffs:** offer the user a reviewer panel instead of the single pass — 4 dimensions (correctness, cross-phase coherence, pattern conformance, test coverage) in parallel, each finding then verified by 3 independent skeptics prompted to *refute* it, keeping only what survives a majority. Read-only, under ~15 agents, never edits source.

Findings → present them in Italian and ask: *"La review pre-commit ha trovato N problemi. Li sistemiamo prima o procedo col commit?"* (recommended: fix first). Fixing is delegated, not done here; then re-run `/finalize-workflow`.

This step is the only whole-diff review on the "Merge sul parent" and "Solo commit" paths — `/pull-request` adds a maintainer-grade one only on the PR path.

## Step 5: Commit

Build the message from the objective, the completed phases, the actual diff and the issue (`fixes #N`):

```
<type>: <concise summary>

<detailed description, grouped logically>

[Fixes #N]
```

Present it, get approval (default: yes), allow edits, then `git commit`.

## Step 6: Capture durable lessons

This is the last moment the whole run is visible and the memory file still exists — after cleanup it goes with the worktree. Without this the loop learns nothing across runs.

Scan the memory file for: `> Repaired:` notes (a root cause *plus why earlier attempts missed it* — the highest-value kind, it encodes a trap); `new-pattern` phases that landed cleanly (now there IS a reference); `> Review:` findings that revealed a convention rather than a one-off; and pattern references that proved **wrong**.

One bar: **would this have saved a future session real work, in a way the repo and git history don't already say?** Framework quirks, non-obvious API behaviour, "we do it like X here" → yes. Bugs specific to this diff, anything visible by opening the file → no.

Nothing clears it → say so in one line and move on; this step is silent by default. Something does → propose it via AskUserQuestion with a draft title and a two-line summary, and on approval write it wherever this project keeps durable know-how, following whatever your global rules say about that. Prefer correcting an existing entry over adding a near-duplicate. Never publish without approval.

## Step 7: Close out

```
Workflow completato e committato. Come vuoi procedere?

[ ] Pull request — push branch e crea PR verso <parent-branch> (consigliato)
[ ] Merge sul parent — merge diretto su <parent-branch> e push
[ ] Solo commit — lascia tutto com'è, decido dopo
```

**Pull request** → `git push -u origin <branch>`, then: *"Branch pushato. Lancia `/pull-request` per creare la PR verso `<parent>`."*

**Merge sul parent** → push the branch, then from the main repo (`git worktree list --porcelain | head -1 | sed 's/worktree //'`): switch to the parent, pull, merge, push. Then ask whether to remove the worktree (default: yes) — `git worktree remove .claude/worktrees/<name>` + `git branch -d <branch>`.

**Solo commit** → the work is committed locally, decide later.

Leave MEMORY.md as-is (all `[x]`; it goes with the worktree if that is removed). If it has a `## Roadmap` with further macro-phases, remind the user: *"La roadmap ha altre macrofasi. Prossimo passo: nuova chat e `/write-workflow` per dettagliare la prossima — col senno di poi di quella appena committata."* If `IN_WORKTREE`, mention `/clean-contexts` for old worktrees.

## Rules

- **NO source code editing** — report findings, delegate fixes
- Show what will happen before any git operation; be especially careful with resets
