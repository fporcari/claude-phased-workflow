---
description: Finalize the workflow - verify all phases, prepare final commit
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob, Write, AskUserQuestion
---

# Finalize Workflow

Verify the entire work plan is complete and prepare the final state for commit/PR.

**IMPORTANT: This command is for FINALIZATION ONLY. Do NOT edit source code. If issues are found, report them to the user for delegation.**

**Language rule:** All written content must be in English. Conversation with the user remains in Italian.

**UI rule:** Use `AskUserQuestion` for all questions. Provide `default_answer` when a sensible default exists. For multiple-choice questions, list each option on its own line with a checkbox-style format.

## Step 1: Select and read the plan

Look in the current project's memory directory for `MEMORY.md` and any `memory_*.md` files.

1. **If only one memory file has active phases** → use it directly
2. **If multiple memory files have active phases** → use AskUserQuestion with checkbox-style options:
   ```
   Ci sono più piani attivi. Quale vuoi finalizzare?

   [ ] MEMORY.md — <context name from first line>
   [ ] memory_<name>.md — <context name from first line>
   ```
   - Default: `MEMORY.md`
3. Store the chosen file path — all reads/writes in this session target that file.

Read the selected memory file and extract:
- Branch name and base branch
- Issue number (if any)
- All phases and their status

## Step 2: Verify phase completion

Check that ALL phases are marked as completed (`[x]`).

If any phases are `[ ]`, `[!]`, or `[~]`:
- Report the incomplete/problematic phases to the user
- Use AskUserQuestion: "Ci sono fasi non completate. Vuoi procedere comunque con la finalizzazione?" (default: "no")
- If "no", stop and suggest running `/execute-phase` or `/check-phase-context`

## Step 3: Analyze git state

Run in parallel:

1. **All commits on branch**:
   ```bash
   git log origin/<base>..HEAD --oneline --no-decorate
   ```

2. **Uncommitted changes**:
   ```bash
   git status --short
   ```

3. **Full diff from base** (committed + uncommitted):
   ```bash
   git diff origin/<base>...HEAD --stat
   ```

4. **Staged changes**:
   ```bash
   git diff --cached --stat
   ```

## Step 4: Handle uncommitted work

If there are uncommitted changes:
- Show which files are modified/added/deleted
- Use AskUserQuestion: "Ci sono modifiche non committate. Vuoi includerle nel commit finale?" (default: "si")
- If yes, stage them:
  ```bash
  git add -A
  ```

## Step 5: Evaluate commit strategy

Analyze the commit history:

**Case A — No intermediate commits (all work is uncommitted or staged):**
- Prepare a single commit with a comprehensive message

**Case B — One or more intermediate commits exist:**
- Show the user the list of intermediate commits
- Use AskUserQuestion: "Ci sono commit intermedi. Come vuoi procedere?" (default: "squash")
  - **squash**: squash all into a single commit with a comprehensive message
  - **keep**: keep intermediate commits, only commit remaining uncommitted work
  - **reword**: keep commits but let the user review/edit the final message

For squash:
```bash
git reset --soft origin/<base>
git add -A
```

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

## Step 8: Clean up memory file

Clear the selected memory file by writing an empty content to it. The work is now captured in the git history. If the file is a parallel context (`memory_<name>.md`), delete it entirely instead of clearing it.

## Step 9: Next steps

Use AskUserQuestion: "Workflow completato. Vuoi procedere con la pull request?" (default: "si")
- If yes, suggest running `/pull-request`
- If no, inform that the work is committed and ready

## Rules

- **NO source code editing** from this command
- If issues are found during verification, report to user — do not fix them directly
- Always show the user what will happen before executing git operations
- Be extra careful with squash/reset operations — always confirm first
