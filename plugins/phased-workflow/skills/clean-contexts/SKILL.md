---
description: List and clean up old worktree contexts
allowed-tools: Bash(git:*), Bash(du:*), Bash(rm:*), Bash(ls:*), AskUserQuestion
---

# Clean Contexts

List every worktree context and remove the stale ones.

## Step 1: Inventory

```bash
git worktree list --porcelain
ls -d .claude/worktrees/*/ 2>/dev/null
```

The second command catches **orphans** — directories left behind after a worktree was deregistered.

For each entry collect: branch name, last commit date (`git -C <path> log -1 --format='%ar'`), merged status (parent from `cat <path>/.claude/parent-branch`, fallback `develop` if `origin/develop` exists else `main`, then `git branch --merged origin/<parent>`), disk usage (`du -sh`), plan state from `.claude/MEMORY.md`, and whether the branch is pushed (`git ls-remote --heads origin <branch>`).

## Step 2: Report and choose

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

Then AskUserQuestion with `multiSelect` to pick which to remove.

## Step 3: Remove the selected

For each, warn before acting and require an explicit yes:

1. Dirty (`git -C <path> status --porcelain`) → *"Il worktree <name> ha modifiche non committate. Confermi la rimozione?"*
2. Unpushed (`git -C <path> log origin/<branch>..HEAD --oneline`) → *"Il worktree <name> ha N commit non pushati. Confermi?"*
3. `git worktree remove .claude/worktrees/<name> --force`
4. Branch: merged → `git branch -d <branch>`; not merged → ask, and only on yes `git branch -D <branch>`
5. **Remote branch — its own separate confirmation**, since deleting it is irreversible for the whole team: *"Vuoi eliminare anche il branch remoto `origin/<branch>`?"* (default: no). Only on explicit yes: `git push origin --delete <branch>`
6. Orphaned directories → `rm -rf .claude/worktrees/<name>`

## Step 4: Summary

```
Rimossi: 2 contesti, liberati 90MB
- feat-export-pdf (branch eliminato, rimosso da remote)
- refactor-auth (directory orfana rimossa)

Contesti attivi rimanenti: 1
- fix-login-timeout (2/4 fasi)
```
