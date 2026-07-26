---
description: Close the current worktree context and return to the main repo
allowed-tools: Bash(git:*), Bash(cd:*), Bash(du:*), Bash(command:*), Bash(cat:*), Bash(grep:*), Bash(head:*), Bash(sed:*), AskUserQuestion
---

# Close Context

Remove the current worktree directory and return to the main repo. **The git branch is NOT deleted** — it stays available for PRs, merges, or future work. Branch cleanup happens after merge/PR, or via `/clean-contexts`.

Must run from inside a worktree.

## Step 1: Gather the state

```bash
git rev-parse --show-toplevel
git worktree list --porcelain
```

Not in a worktree → stop: *"Non sei in un worktree. Questo comando va lanciato dall'interno del worktree di un workflow."* Otherwise extract the worktree name and path, the branch, and the main repo path (first entry of the list).

Then collect, in parallel: `git status --porcelain` (uncommitted), `git log origin/<branch>..HEAD --oneline` (unpushed), the completed/total phase count from `.phased/active/*/plan.md`, disk usage, and whether the branch is merged into its parent (the plan's `Parent:` line, fallback `develop`, then `git branch --merged origin/<parent>`).

## Step 2: Present and choose

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

Recommend "Chiudi e rimuovi" when nothing is pending, "Chiudi e mantieni" otherwise.

## Step 3: Execute

**Chiudi e rimuovi** — never without confirming data loss first:

- Uncommitted changes → *"Ci sono modifiche non committate che verranno perse. Sei sicuro?"*
- Unpushed commits → offer to push first (`git push -u origin <branch>`); on no, require explicit confirmation that they will be lost.

Then remove the worktree from the main repo (the `code` CLI cannot close a window — remind the user to close the worktree's VS Code manually):

```bash
MAIN_REPO=$(git worktree list --porcelain | head -1 | sed 's/worktree //')
cd "$MAIN_REPO"
git worktree remove .claude/worktrees/<name> --force
```

Inform: *"Worktree rimosso. Il branch `<branch>` resta disponibile. Sei tornato su `$MAIN_REPO`."* — and that their terminal is still sitting in the deleted directory.

**Chiudi e mantieni** — *"Il worktree resta in `.claude/worktrees/<name>/`. Puoi riaprirlo con `cd .claude/worktrees/<name> && claude`."* Suggest `/clean-contexts` for later cleanup.

**Annulla** — do nothing.
