# Close Context

Close the current worktree context: remove the worktree directory, close VS Code, return to the main repo. The git branch is NOT deleted — it stays available for PRs, merges, or future work.

Must be run from inside a worktree.

## Step 1: Verify we are in a worktree

```bash
git rev-parse --show-toplevel
git worktree list --porcelain
```

Compare current directory with worktree list. If NOT in a worktree, stop: *"Non sei in un worktree. Questo comando va lanciato dall'interno di un contesto creato con `/create-context`."*

Extract:
- **Worktree name** and path
- **Branch name**
- **Main repo path**: first entry in `git worktree list`

## Step 2: Check status

Run in parallel:

1. **Uncommitted changes**:
   ```bash
   git status --porcelain
   ```

2. **Unpushed commits**:
   ```bash
   git log origin/<branch>..HEAD --oneline 2>/dev/null
   ```

3. **MEMORY.md status**: read `.claude/MEMORY.md` — count completed vs total phases

4. **Merge status**: check if branch is merged into parent
   ```bash
   PARENT=$(cat .claude/parent-branch 2>/dev/null || echo "develop")
   git branch --merged origin/$PARENT | grep <branch>
   ```

## Step 3: Present status and options

```
Stato del contesto "<branch-name>":

Piano: 4/4 fasi completate (oppure: 2/4 — incompleto)
Modifiche non committate: 3 file (oppure: nessuna)
Commit non pushati: 2 (oppure: nessuno)
Merged in <parent>: sì/no
Spazio occupato: 45MB

Come vuoi procedere?

[ ] Chiudi e rimuovi — elimina worktree, chiudi VS Code (consigliato)
[ ] Chiudi e mantieni — torna al repo principale, worktree resta su disco
[ ] Annulla — resta nel contesto
```

Default:
- "Chiudi e rimuovi" se nessun cambio pendente
- "Chiudi e mantieni" altrimenti

## Step 4: Execute

### Chiudi e rimuovi

If uncommitted changes exist, warn and require explicit confirmation:
*"Ci sono modifiche non committate che verranno perse. Sei sicuro?"*

If unpushed commits exist, warn:
*"Ci sono N commit non pushati. Vuoi pushare prima di rimuovere?"*
- If yes: `git push -u origin <branch>`, then proceed
- If no: require explicit confirmation that commits will be lost

**VS Code window**: the `code` CLI cannot close an open window programmatically — remind the user to close the worktree's VS Code window manually.

**Remove the worktree** (NOT the branch):
```bash
MAIN_REPO=$(git worktree list --porcelain | head -1 | sed 's/worktree //')
cd "$MAIN_REPO"
git worktree remove .claude/worktrees/<name> --force
```

**The branch is NOT deleted.** Closing a context removes only the worktree directory and the VS Code workspace. The branch remains available for PRs, merges, or future work. Branch cleanup happens separately (after merge/PR, or via `/clean-contexts`).

Inform: *"Worktree rimosso. Il branch `<branch>` resta disponibile. Sei tornato su `$MAIN_REPO`."*

### Chiudi e mantieni

Simply inform: *"Il worktree resta in `.claude/worktrees/<name>/`. Puoi riaprirlo con `cd .claude/worktrees/<name> && claude`."*

Suggest: *"Per pulizia futura, lancia `/clean-contexts` dal repo principale."*

### Annulla

Do nothing.

## Rules

- NEVER remove without user confirmation
- Always warn about data loss (uncommitted changes, unpushed commits)
- Offer to push before removing if there are unpushed commits
- Closing a context does NOT delete the git branch — only the worktree and VS Code workspace
- After removal, the user's terminal will still be in the deleted directory — remind them to `cd` elsewhere
