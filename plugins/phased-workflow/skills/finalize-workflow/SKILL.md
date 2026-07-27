---
description: Finalize the workflow - verify all phases, prepare final commit
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cd:*), Bash(head:*), Bash(sed:*), Bash(python3:*), Read, Grep, Glob, Write, AskUserQuestion, Skill
---

# Finalize Workflow

Verify the work plan is complete and turn the working tree into one clean commit. **Never edit source code here** — findings get reported and delegated.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start — language, AskUserQuestion style, plan directory, workflow branch.

## Step 1: Find the plan and the base

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve
git branch --show-current
git worktree list --porcelain
```

Set `IN_WORKTREE` from whether the cwd is in the worktree list. No active plan → stop; the plan lives on the workflow branch, so check `git branch --show-current` before concluding there is nothing to finalize — and check `--plans` first: the workflow may live in another checkout (`common.md` → *Plan location*). When it does, every git command below runs `git -C <plan root>` and every path is anchored there; the consolidation itself (Step 7) must happen on the plan's branch, never on the cwd's.

Read the plan for `Parent:`, the issue number and the phase states. **Resolve the parent ref**: `origin/<parent>` if `git rev-parse --verify` finds it, otherwise the local `<parent>`.

Then resolve the two things every step below depends on:

```bash
BASE=$(git log -1 --diff-filter=A --format=%H -- <plan path>)   # the commit that ADDED the plan
git rev-list --count "$BASE"^..<parent>                         # 0 => BASE is the branch point
```

`BASE` is the workflow's base: everything after it belongs to this run, everything before it does not. That second command tells you which shape you are in — **dedicated branch** (the plan commit *is* the branch point: the branch is the workflow) or **adopted branch** (the branch already carried commits, which must survive untouched). Step 3 and Step 7 differ between the two; nothing else does.

## Step 2: Verify completion

All phases `[x]` → proceed. Otherwise report the incomplete ones (warn specifically that a `[>]` may be a dead session) and ask whether to finalize anyway (default: no).

Collect any `> Verify:` lines — manual UI checks `/execute-phase` recorded — and ask whether the user has done them.

## Step 3: Review the scope

No staging heuristics any more, and no guessing: the workflow is exactly `git log --oneline "$BASE"..HEAD`, one commit per phase plus the plan commit. Show it, with `git diff --stat "$BASE"..HEAD`.

The tree must be clean. If `git status --short` shows anything, a phase closed without committing or someone edited by hand — report it and ask whether to include it before going on; do not sweep it in silently.

Consolidation happens at Step 7, once the review has passed, and its shape depends on Step 1:

- **Dedicated branch** — the branch *is* the workflow, so the parent takes it whole with `git merge --squash`. Nothing to reset here.
- **Adopted branch** — the commits before `BASE` are not yours: `git reset --soft "$BASE"^` collapses only the workflow, leaving them untouched.

## Step 4: Pre-commit review

Run the built-in `code-review` skill (Skill tool) on the staged diff — never with `--fix`. Effort `high` when the plan is `Mode: autonomous` or any phase carries a `> Review:` note (nobody read that code as it landed); `medium` otherwise.

Pass every `> Review:` note as an explicit focus point — each must come out confirmed or explicitly dismissed, never silently dropped. And instruct the review to hunt **cross-phase** issues specifically: each phase ran in a fresh session and was verified in isolation, so nothing has yet seen the whole diff at once — one phase breaking another's assumption, helpers duplicated by sessions unaware of each other, naming or pattern drift between phases.

**Large autonomous diffs:** offer the user a reviewer panel instead of the single pass — 4 dimensions (correctness, cross-phase coherence, pattern conformance, test coverage) in parallel, each finding then verified by 3 independent skeptics prompted to *refute* it, keeping only what survives a majority. Read-only, under ~15 agents, never edits source.

Findings → present them in Italian and ask: *"La review pre-commit ha trovato N problemi. Li sistemiamo prima o procedo col commit?"* (recommended: fix first). Fixing is delegated, not done here; then re-run `/finalize-workflow`.

This step is the only whole-diff review on the "Merge sul parent" and "Solo commit" paths — `/pull-request` adds a maintainer-grade one only on the PR path.

## Step 5: Capture durable lessons

**This step is mandatory and runs before anything is archived or removed.** `.phased/` never reaches the parent, and the workflow branch is deletable at Step 7 — so this is the only path by which anything learned during the run outlives it. Skipping it silently is how the loop stops learning across runs.

Scan the plan and its `notes.md` for: `> Repaired:` notes (a root cause *plus why earlier attempts missed it* — the highest-value kind, it encodes a trap); `new-pattern` phases that landed cleanly (now there IS a reference); `> Review:` findings that revealed a convention rather than a one-off; and pattern references that proved **wrong**.

One bar: **would this have saved a future session real work, in a way the repo and git history don't already say?** Framework quirks, non-obvious API behaviour, "we do it like X here" → yes. Bugs specific to this diff, anything visible by opening the file → no.

Nothing clears the bar → say so explicitly, in one line, naming what you scanned. Something does → propose it via AskUserQuestion with a draft title and a two-line summary, and on approval write it wherever this project keeps durable know-how, following whatever your global rules say about that. Prefer correcting an existing entry over adding a near-duplicate. Never publish without approval.

## Step 6: Archive the plan

The run is over and its lessons are out. Move the plan directory into the archive and commit it on the workflow branch:

```bash
git mv .phased/active/<slug> .phased/done/<slug>
git commit -q -m "wf: archive plan for <slug>"
```

It stays on this branch — logs, notes and phase history included — and never reaches the parent. If `.phased/roadmap.md` exists, leave it in place: the next macro-phase is written against it.

## Step 7: Close out

Build the commit message from the objective, the completed phases, the actual diff and the issue (`fixes #N`):

```
<type>: <concise summary>

<detailed description, grouped logically>

[Fixes #N]
```

Present it, get approval (default: yes), allow edits. Then:

```
Come vuoi procedere?

[ ] Pull request — branch pulito dal parent, squash, PR verso <parent-branch> (consigliato)
[ ] Merge sul parent — squash direttamente su <parent-branch> e push
[ ] Solo commit — lascia il branch com'è, decido dopo
```

**Merge sul parent** → from the main repo (`git worktree list --porcelain | head -1 | sed 's/worktree //'`): switch to the parent, pull, then

```bash
git merge --squash <workflow-branch>
git rm -r -f .phased
git commit    # the message approved above
git push
```

On an **adopted branch** there is nothing to squash onto the parent — the workflow is consolidated in place:

```bash
git tag "wf-archive/<slug>" HEAD     # keep the per-phase history reachable
git reset --soft "$BASE"^
git rm -r -f .phased
git commit                           # the message approved above
```

The commits that preceded `BASE` stay exactly as they were; the branch then reaches the parent by the ordinary merge or PR.

**Say the trade-off out loud before doing it.** Consolidating in place drops the per-phase commits and the archived plan from the branch — unlike the dedicated-branch path, no separate branch is left holding them. The tag is what keeps them reachable (`git log wf-archive/<slug>`), and Step 5 is what carries the lessons out regardless. Delete the tag once the work is merged and the history is no longer wanted.

**Pull request** → branch off the **parent**, not off the workflow branch, so the PR carries one commit and no `.phased/`:

```bash
git switch <parent> && git pull
git switch -c <type>/<slug>
git merge --squash <workflow-branch>
git rm -r -f .phased
git commit
git push -u origin <type>/<slug>
```

Then: *"Branch pushato. Lancia `/pull-request` per creare la PR verso `<parent>`."*

**Solo commit** → nothing else happens; the workflow branch holds everything.

After the first two, offer to delete the workflow branch and its worktree (default: yes) — `git worktree remove .claude/worktrees/<slug>` + `git branch -D <workflow-branch>`. **Unless `.phased/roadmap.md` still lists unstarted macro-phases:** then keep the branch, say why, and remind the user *"La roadmap ha altre macrofasi. Prossimo passo: nuova chat e `/write-workflow` per dettagliare la prossima — col senno di poi di quella appena committata."* If `IN_WORKTREE`, remind the user that the worktree itself is plain git: `git worktree list` shows the stale ones, `git worktree remove <path>` clears them.

## Rules

- **NO source code editing** — report findings, delegate fixes
- Show what will happen before any git operation; be especially careful with resets
- Never delete the workflow branch before Step 5 has run: it is the only thing carrying the run's lessons out
