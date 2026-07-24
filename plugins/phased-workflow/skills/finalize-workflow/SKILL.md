# Finalize Workflow

Verify the entire work plan is complete and prepare the final state for commit/PR.

**IMPORTANT: This command is for FINALIZATION ONLY. Do NOT edit source code. If issues are found, report them to the user for delegation.**

**Model tip:** run this from a chat on **opus at `xhigh` effort**. Most of this command is git plumbing (worktree detection, staging, soft-reset, commit message) where a premium model buys nothing; the judgment is concentrated in Step 5.5, and opus is high-precision *and* high-recall on diff review. Reach for fable only in the one case where the premium actually pays: an autonomous plan (`Mode: autonomous`) with a large diff no human has read. Better than either, when the diff is big: the reviewer panel described in Step 5.5.

**Shared conventions:** read `~/.claude/workflow-refs/common.md` once at start — language, AskUserQuestion style, MEMORY.md path resolution.

## Step 1: Detect environment and select the plan

### Worktree detection

```bash
git rev-parse --show-toplevel
git worktree list --porcelain
```

Compare the current working directory with the worktree list to determine if we are in a worktree.
Set `IN_WORKTREE=true/false` for use in subsequent steps.

### Memory file selection

**If in a worktree** → read the work plan from `<repo_root>/.claude/MEMORY.md` (where `<repo_root>` is `$(git rev-parse --show-toplevel)`). Use it directly.

**If in the main repo:**

Also check for `<repo_root>/.claude/memory_*.md` files and scan `<repo_root>/.claude/worktrees/*/` for active plans.

1. **If only one memory file has active phases** → use it directly
2. **If multiple memory files have active phases** → use AskUserQuestion with checkbox-style options:
   ```
   Ci sono più piani attivi. Quale vuoi finalizzare?

   [ ] MEMORY.md — <context name from first line>
   [ ] memory_<name>.md — <context name from first line>
   [ ] worktree: <name> — <context from worktree MEMORY.md>
   ```
   - Default: `MEMORY.md`
   - If a worktree plan is selected from the main repo, inform the user: "Questo workflow è in un worktree. Esegui `/finalize-workflow` da: `cd .claude/worktrees/<name> && claude`"
3. Store the chosen file path — all reads/writes in this session target that file.

Read the selected memory file and extract:
- Branch name and **parent branch** (from `Parent:` line)
- Issue number (if any)
- All phases and their status

Also read `.claude/parent-branch` file if it exists (written by `/create-context`).

**Resolve the base ref.** Check `git rev-parse --verify origin/<parent>`: if it exists, the base ref is `origin/<parent>`; otherwise the parent is a local-only branch and the base ref is the local `<parent>`. Use this resolved ref wherever the steps below mention `origin/<base>`.

## Step 2: Verify phase completion

Check that ALL phases are marked as completed (`[x]`).

Also collect any `> Verify:` lines on `[x]` phases (manual UI checks recorded by `/execute-phase`). If present, ask the user: *"Queste fasi hanno verifiche manuali UI in sospeso: <list>. Le hai verificate?"* — if not, suggest verifying before committing.

If any phases are `[ ]`, `[>]`, `[!]`, or `[~]`:
- Report the incomplete/problematic phases to the user
- For `[>]` phases specifically, warn: "La fase N risulta ancora in esecuzione da un'altra chat. Potrebbe essere una sessione terminata."
- Use AskUserQuestion: "Ci sono fasi non completate. Vuoi procedere comunque con la finalizzazione?" (default: "no")
- If "no", stop and suggest running `/execute-phase` or `/check-phase-context`

## Step 3: Build the workflow file list

### If IN_WORKTREE=true (simplified)

All changes in the worktree belong to this workflow. No selective filtering needed:
```bash
git diff --name-only origin/<base>...HEAD
git status --short
```
Collect all modified/untracked files as the workflow file set. Present to user for confirmation.

### If IN_WORKTREE=false (selective — legacy mode)

Extract the list of files belonging to THIS workflow:

1. Parse the completed phases (`[x]`) in the memory file — each has a `> Files:` line listing modified files
2. Also parse any `> In progress:` notes from partially completed phases
3. Collect all file paths mentioned into a **workflow file set**
4. Cross-reference with actual git state:
   ```bash
   git status --short
   git diff --name-only origin/<base>...HEAD
   ```
5. Present the file list to the user for confirmation:
   - Show which files from the workflow are modified (uncommitted or in WIP commits)
   - Flag any files that appear changed but are NOT listed in any phase note — ask the user whether to include them
   - Flag any files listed in phase notes that are NOT actually changed — warn the user

This step is critical when parallel workflows exist without worktrees — it ensures only files belonging to the current workflow are committed.

## Step 4: Analyze git state

Run in parallel:

1. **All commits on branch** (look for WIP commits from this workflow):
   ```bash
   git log origin/<base>..HEAD --oneline --no-decorate
   ```

2. **Uncommitted changes** (filter by workflow file set):
   ```bash
   git status --short
   ```

## Step 5: Consolidate and stage work

### If IN_WORKTREE=true (simplified)

All changes belong to this workflow. Staging is straightforward:

**Case A — No WIP commits:**
```bash
git add -A
```

**Case B — WIP commits exist:**

First inspect `git log origin/<base>..HEAD --oneline`:
- If ALL commits in the range are WIP commits → `git reset --soft origin/<base>`
- If there are also non-WIP commits (manual commits, previously finalized work not yet pushed), do NOT reset past them: soft-reset only to the parent of the oldest commit in the contiguous WIP streak at HEAD (`git reset --soft <oldest-wip>^`). If WIP and non-WIP commits are interleaved, STOP and ask the user how to consolidate.

Then:
```bash
git add -A
```
Inform the user that N WIP commits will be consolidated into a single clean commit.

**Case C — No changes:**
Inform the user there is nothing to commit.

### If IN_WORKTREE=false (selective staging — legacy mode)

Using the confirmed workflow file set from Step 3:

**Case A — No WIP commits, only uncommitted changes:**
- Stage only the workflow files:
  ```bash
  git add <file1> <file2> ...
  ```

**Case B — WIP commits from execute-phase exist:**
- Same guard as the worktree case: inspect `git log origin/<base>..HEAD --oneline` first. Reset to `origin/<base>` only if ALL commits in the range are WIP; otherwise soft-reset to the parent of the oldest contiguous WIP commit at HEAD, or STOP and ask the user if WIP and real commits are interleaved.
- Reset WIP commits to unstage them, then selectively re-stage only workflow files:
  ```bash
  git reset --soft <reset-target>
  git reset HEAD .
  git add <file1> <file2> ...
  ```
- Inform the user that N WIP commits will be consolidated into a single clean commit
- **WARNING**: If WIP commits contain files from OTHER workflows, those files will become uncommitted changes again — this is expected and correct

**Case C — No changes for this workflow:**
- All workflow files are already clean — inform the user there is nothing to commit

## Step 5.5: Pre-commit review

With the workflow files staged, run the built-in `code-review` skill (Skill tool) on the staged diff. Do NOT use `--fix` — this command never edits source.

**Effort is dynamic:**
- `high` — when the plan is autonomous (`Mode: autonomous` in the memory file) or any phase carries a `> Review:` note. No human looked at those phases while they ran: this is the first deep pass with the whole diff in one context.
- `medium` — otherwise (interactive plans, phases already seen by the user).

**Feed the review the phase-level context.** Collect every `> Review:` note from the memory file (judgment-level findings flagged by the per-phase verification) and pass them to the review as explicit focus points. Each note must come out either confirmed (a real finding to present) or explicitly dismissed — never silently dropped.

**Cross-phase coherence focus.** Each phase ran in a fresh session and was verified in isolation; no phase-level check ever saw the whole diff at once. Instruct the review to look specifically for cross-phase issues: one phase breaking an assumption another relies on, helpers duplicated by sessions unaware of each other, naming or pattern drift between phases.

**Reviewer panel (optional — large autonomous diffs).** When the plan is `Mode: autonomous` AND the diff spans many phases, a single review pass is the weak link: it is one perspective on code no human has read. If the user opts in, run the review as a fan-out instead — 4 dimensions (correctness, cross-phase coherence, pattern conformance, test coverage) reviewed in parallel, then each surviving finding verified by 3 independent skeptics prompted to *refute* it, keeping only findings that survive a majority. Findings arrive with the reasoning that justifies them, which is what you need to triage them here. This is worth more than upgrading the single pass to fable, and it is read-only like the rest of Step 5.5. Keep the agent count under ~15 (verify findings, not dimensions) and never let the panel edit source.

- No findings → proceed to Step 6.
- Findings → present them (in Italian) and ask via AskUserQuestion: "La review pre-commit ha trovato N problemi. Li sistemiamo prima o procedo col commit?" (recommended: fix first). Fixing is not this command's job — delegate (a quick fix session or a new phase via `/write-workflow`), then re-run `/finalize-workflow`.

Role split with `/pull-request`: this step = whole-diff coherence + phase `> Review:` notes; `/pull-request` Step 4 = maintainer-grade review. The PR path gets both; the "Merge sul parent" / "Solo commit" paths get only this one — another reason not to skimp here.

## Step 6: Prepare commit message

Generate a commit message based on:
- The objective from the selected memory file
- The phases completed
- The actual changes in the diff
- The issue number (if present, use "fixes #N" or "closes #N")

Format:
```
<type>: <concise summary>

<detailed description of changes, organized by logical groups>

[Fixes #N]
```

Present the commit message to the user for review.
Use AskUserQuestion: "Ecco il messaggio di commit proposto. Va bene?" (default: "si")

Allow the user to edit/adjust before proceeding.

## Step 7: Commit

After user approval:
```bash
git commit -m "<approved message>"
```

## Step 7.5: Capture durable lessons (Sourcerer)

This is the only moment where the whole run is visible at once and the memory file still exists — after cleanup it is gone with the worktree. Without this step the loop learns nothing across runs: the same wrong pattern reference gets chosen again next time.

Scan the memory file for the few things worth outliving this workflow:

- `> Repaired:` notes — a root cause plus *why the earlier attempts missed it*. The highest-value kind: it encodes a trap.
- Phases whose `Pattern:` was `new-pattern` and that landed cleanly — now there IS a reference for next time.
- `> Review:` findings that turned out to reveal a convention rather than a one-off bug.
- A pattern reference that proved **wrong** — worth recording as much as a right one.

Judge each against one bar: **would this have saved a future session real work, in a way the repo and the git history don't already say?** Framework quirks, non-obvious API behaviour, "we do it like X here" conventions → yes. Bugs specific to this diff, anything a reader would find by opening the file → no.

If nothing clears the bar, say so in one line and move on — this step is silent by default.

If something does, propose it via AskUserQuestion with the draft skill title and a two-line summary, then on approval write it with `kb_add_skill` (or `kb_update_skill` when it corrects an existing one — check with `kb_find_skills` first, an updated skill beats a near-duplicate). Never push without approval.

## Step 8: Clean up

The work is now captured in the git history.

Use AskUserQuestion:
```
Workflow completato e committato. Come vuoi procedere?

[ ] Pull request — push branch e crea PR verso <parent-branch> (consigliato)
[ ] Merge sul parent — merge diretto su <parent-branch> e push
[ ] Solo commit — lascia tutto com'è, decido dopo
```
Default: "Pull request"

### Pull request
Push the branch and suggest running `/pull-request`:
```bash
git push -u origin <feature-branch>
```
Then inform: *"Branch pushato. Lancia `/pull-request` per creare la PR verso `<parent-branch>`."*

### Merge sul parent
Push the feature branch, then merge on the parent:
```bash
git push -u origin <feature-branch>
```

Then get the main repo path and merge:
```bash
MAIN_REPO=$(git worktree list --porcelain | head -1 | sed 's/worktree //')
cd "$MAIN_REPO"
git switch <parent-branch>
git pull origin <parent-branch>
git merge <feature-branch>
git push
```

After successful merge, ask: *"Merge completato su `<parent-branch>`. Vuoi rimuovere il worktree?"* (default: "si")

If yes:
```bash
cd "$MAIN_REPO"
git worktree remove .claude/worktrees/<name>
git branch -d <feature-branch>
```

### Solo commit
Inform the user the work is committed locally and they can decide later.

### Memory cleanup
After any option, leave MEMORY.md as-is — all phases are `[x]`. If the worktree is removed, the MEMORY.md goes with it.

**Roadmap check (rolling wave):** if MEMORY.md contains a `## Roadmap` section with macro-phases beyond the one just completed, remind the user (in Italian): *"La roadmap ha altre macrofasi. Prossimo passo: nuova chat e `/write-workflow` per dettagliare la prossima — col senno di poi di quella appena committata."*

### Suggest cleanup
After completing any option, if IN_WORKTREE=true, inform the user:
*"Per rimuovere questo e altri worktree vecchi, lancia `/clean-contexts` dal repo principale."*

## Rules

- **NO source code editing** from this command
- If issues are found during verification, report to user — do not fix them directly
- Always show the user what will happen before executing git operations
- Be extra careful with reset operations — always confirm first
