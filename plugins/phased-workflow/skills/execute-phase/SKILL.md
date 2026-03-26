
# Execute Phase

Execute the next uncompleted phase from the work plan (`MEMORY.md`). Supports both worktree-based and traditional workflows.

**Language rule:** All written artifacts (MEMORY.md updates, phase notes) must be in English.

**UI rule:** Use `AskUserQuestion` tool for ALL questions to the user. Always provide a `default_answer` when a sensible default exists. For multiple-choice questions, list each option on its own line with a checkbox-style format.

## Step 0: Detect environment and select the workflow

As the VERY FIRST interaction, detect whether we are running inside a worktree or in the main repository.

### Worktree detection

```bash
# Check if current directory is inside a worktree
git rev-parse --show-toplevel
git worktree list --porcelain
```

Compare the current working directory with the worktree list:
- **If inside a worktree** → look for `MEMORY.md` in the local `.claude/` directory. If found with active phases, use it directly — no further selection needed. Inform the user: "Esecuzione nel worktree `<name>`, piano trovato."
- **If in the main repo** → proceed with standard memory file selection below.

### Standard memory file selection (main repo)

Look in the current project's memory directory for `MEMORY.md`. Also scan `.claude/worktrees/*/` for `MEMORY.md` files with active phases.

1. Check local `MEMORY.md` and worktree MEMORY.md files for active uncompleted phases (`- [ ]`)
2. **If no active plans found** → inform the user there are no active plans
3. **If only one plan has active phases** → use it directly, inform the user which plan was selected
4. **If multiple plans have active phases** (local + worktrees) → use AskUserQuestion:
   ```
   Quale workflow vuoi eseguire?

   [ ] MEMORY.md — <context name from first line>
   [ ] worktree: <name> — <context from worktree MEMORY.md>
   ...
   ```
   - If a worktree plan is selected, inform the user: "Questo workflow è in un worktree. Apri una sessione da: `cd .claude/worktrees/<name> && claude`"
5. Store the chosen file path — all subsequent reads/writes in this session target that file.
## Step 1: Read the plan

Read the selected memory file (chosen in Step 0). Extract:
- Branch name and parent branch (from `Parent:` line)
- Issue number (if any)
- All phases and their status

Identify the first phase marked `- [ ]` (uncompleted).

If no phases remain, inform the user the plan is complete and suggest running `/finalize-workflow`.

## Step 2: Execute the phase

Execute ONLY the identified phase. Do not touch other phases.

## Step 3: Wait for user verification

After completing the phase implementation, use AskUserQuestion to ask:
- Question: "Ho completato l'implementazione della fase. Puoi verificare e dirmi se funziona tutto?"
- No default

**Do NOT proceed to update MEMORY.md until the user confirms the result of their test.** The user may report issues that need fixing before the phase can be marked as done.

## Step 4: Update the memory file

After the user confirms, update the selected memory file (chosen in Step 0):

**If completed successfully**:
```
- [x] **Phase N**: title
  > Done: brief description of what was done
  > Files: path/to/file1.py, path/to/file2.py, ...
```
**IMPORTANT:** Always list ALL modified/created/deleted files in the `> Files:` line. This is the source of truth used by `/finalize-workflow` to determine which files belong to this workflow when parallel workflows exist.

**If completed with issues or doubts**:
```
- [!] **Phase N**: title
  > Issue: description of the problem and what was partially done
  > Files: path/to/file1.py, path/to/file2.py, ...
```

**If unable to complete**:
```
- [~] **Phase N**: title
  > Blocked: reason for the block and what is needed to unblock
  > Files: path/to/file1.py, path/to/file2.py, ... (if any were modified)
```

**IMPORTANT: Do NOT commit after completing a phase.** Commits are handled exclusively by `/finalize-workflow`, which has full visibility on the workflow state and produces a single clean commit.

## Context window management (CRITICAL)

The user strongly dislikes context compaction. You MUST proactively monitor context usage and act BEFORE compaction happens.

### When to suggest continuing in a new chat

Suggest opening a new chat to continue when ANY of these conditions apply:
- You notice the conversation is getting long and the phase is not yet complete
- You're about to start a complex sub-task that will require many tool calls
- You've already done significant exploration/reading and still have substantial implementation ahead
- The system has already compacted once — immediately recommend switching

### How to suggest it

Use AskUserQuestion:
```
Il contesto si sta riempiendo. Ti consiglio di aprire una nuova chat e lanciare di nuovo /execute-phase per continuare con qualita' ottimale.

Vuoi che faccia un commit WIP di salvataggio prima di chiudere?
```
- Default: "si"

### Before switching: save progress (WIP commit)

If the phase is partially done when context gets tight:
1. **WIP commit** of working changes (ask confirmation):
   ```bash
   git add <modified files>
   git commit -m "WIP: <phase title> — partial progress"
   ```
   This is the ONLY case where execute-phase is allowed to commit — as a safety net to avoid losing work across chat sessions.
2. **Update the memory file** with a progress note on the current phase:
   ```
   - [ ] **Phase N**: title
     > In progress: description of what was done so far and what remains. WIP commit present.
   ```
3. This way the next chat can pick up exactly where this one left off.
4. `/finalize-workflow` will incorporate WIP commits into the final clean commit.

## Rules

- Execute ONE phase per invocation only
- Do not modify other phases in the plan
- Do not refactor or improve outside of scope
- If the phase requires non-obvious architectural decisions, ask the user
- Do NOT commit after completing a phase — commits are handled by `/finalize-workflow`
- The only exception is the WIP safety commit when context is running out (see above)
