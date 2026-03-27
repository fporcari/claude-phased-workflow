---
description: Finalize the workflow - verify all phases, prepare final commit
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob, Write, AskUserQuestion
---

# Finalize Workflow

Verify the entire work plan is complete and prepare the final state for commit/PR.

**IMPORTANT: This command is for FINALIZATION ONLY. Do NOT edit source code. If issues are found, report them to the user for delegation.**

**Language rule:** All written content must be in English. Conversation with the user remains in Italian.

**UI rule:** Use `AskUserQuestion` for all questions. Provide `default_answer` when a sensible default exists. For multiple-choice questions, list each option on its own line with a checkbox-style format.

## Step 1: Detect environment and select the plan

### Worktree detection

```bash
git rev-parse --show-toplevel
git worktree list --porcelain
```

Compare the current working directory with the worktree list to determine if we are in a worktree.
Set `IN_WORKTREE=true/false` for use in subsequent steps.

### Memory file selection

**If in a worktree** → look for `MEMORY.md` in the local `.claude/` directory. Use it directly.

**If in the main repo** → look in the project's memory directory for `MEMORY.md` and any `memory_*.md` files. Also scan `.claude/worktrees/*/` for active plans.

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

## Step 2: Verify phase completion

Check that ALL phases are marked as completed (`[x]`).

If any phases are `[ ]`, `[!]`, or `[~]`:
- Report the incomplete/problematic phases to the user
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
```bash
git reset --soft origin/<base>
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
- Reset WIP commits to unstage them, then selectively re-stage only workflow files:
  ```bash
  git reset --soft origin/<base>
  git reset HEAD .
  git add <file1> <file2> ...
  ```
- Inform the user that N WIP commits will be consolidated into a single clean commit
- **WARNING**: If WIP commits contain files from OTHER workflows, those files will become uncommitted changes again — this is expected and correct

**Case C — No changes for this workflow:**
- All workflow files are already clean — inform the user there is nothing to commit

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

### Suggest cleanup
After completing any option, if IN_WORKTREE=true, inform the user:
*"Per rimuovere questo e altri worktree vecchi, lancia `/clean-contexts` dal repo principale."*

## Rules

- **NO source code editing** from this command
- If issues are found during verification, report to user — do not fix them directly
- Always show the user what will happen before executing git operations
- Be extra careful with reset operations — always confirm first
