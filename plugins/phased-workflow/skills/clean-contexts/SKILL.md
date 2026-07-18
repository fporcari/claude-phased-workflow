# Clean Contexts

List all worktree contexts and let the user remove stale ones.

## Step 1: List worktrees

```bash
git worktree list --porcelain
```

Also check for orphaned directories (worktree removed but directory left behind):
```bash
ls -d .claude/worktrees/*/ 2>/dev/null
```

## Step 2: Gather info for each worktree

For each worktree found, collect:

1. **Branch name**: from worktree list
2. **Last commit date**: `git -C <path> log -1 --format='%ar'`
3. **Merged status**: read the worktree's parent (`cat <path>/.claude/parent-branch`; fallback: `develop` if `origin/develop` exists, else `main`), then `git branch --merged origin/<parent> | grep <branch>`
4. **Disk usage**: `du -sh <path>`
5. **MEMORY.md status**: check if `.claude/MEMORY.md` exists and if all phases are `[x]`
6. **Remote branch**: `git ls-remote --heads origin <branch>` (pushed or local only)

## Step 3: Present report

Show a table for each worktree:

```
Worktree contexts trovati:

1. feat-export-pdf
   Branch: feat-export-pdf | Ultimo commit: 3 giorni fa
   Stato piano: completato (5/5 fasi) | Merged: sì | Size: 45MB

2. fix-login-timeout
   Branch: fix-login-timeout | Ultimo commit: 2 settimane fa
   Stato piano: incompleto (2/4 fasi) | Merged: no | Size: 45MB

3. [orphan] refactor-auth
   Directory presente ma worktree non registrato | Size: 45MB
```

## Step 4: Let user choose

Use AskUserQuestion with multiselect:

```
Quali contesti vuoi rimuovere?

[ ] 1. feat-export-pdf (completato, merged)
[ ] 2. fix-login-timeout (incompleto, non merged)
[ ] 3. [orphan] refactor-auth
```

## Step 5: Remove selected

For each selected worktree:

1. **Check for uncommitted changes**:
   ```bash
   git -C <path> status --porcelain
   ```
   If dirty, warn: "Il worktree <name> ha modifiche non committate. Confermi la rimozione?" — require explicit yes.

2. **Check for unpushed commits**:
   ```bash
   git -C <path> log origin/<branch>..HEAD --oneline 2>/dev/null
   ```
   If unpushed, warn: "Il worktree <name> ha N commit non pushati. Confermi?"

3. **Remove worktree**:
   ```bash
   git worktree remove .claude/worktrees/<name> --force
   ```

4. **Remove branch** (only if merged or user confirms):
   - If merged: `git branch -d <branch>`
   - If not merged, ask: "Il branch <name> non è merged. Vuoi eliminarlo comunque?"
   - If yes: `git branch -D <branch>`

5. **Remote branch** — deleting a remote branch is irreversible for the whole team, so it requires its OWN explicit confirmation. If the branch is pushed, ask: "Vuoi eliminare anche il branch remoto `origin/<branch>`?" (default: no). Only on explicit yes: `git push origin --delete <branch>`

6. **Orphaned directories** (not registered as worktree):
   ```bash
   rm -rf .claude/worktrees/<name>
   ```

## Step 6: Summary

```
Rimossi: 2 contesti, liberati 90MB
- feat-export-pdf (branch eliminato, rimosso da remote)
- refactor-auth (directory orfana rimossa)

Contesti attivi rimanenti: 1
- fix-login-timeout (2/4 fasi)
```

## Rules

- NEVER remove a worktree without user confirmation
- Always warn about uncommitted changes and unpushed commits BEFORE removing
- Orphaned directories get a separate, explicit warning
- Show disk space freed at the end
