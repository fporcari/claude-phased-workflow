
# Create Context

Create a branch and worktree for a new work stream. No planning — just infrastructure.

**Requires `$ARGUMENTS`** — the topic/theme of the work (e.g. "export PDF fatture", "123 fix login timeout").

## Step 1: Detect parent branch

```bash
git branch --show-current
```

The current branch (whatever it is) becomes the **parent branch**. Store it — finalize-workflow will use it for merge/PR.

If `$ARGUMENTS` is empty, stop: *"Specifica il tema del lavoro. Esempio: `/create-context export PDF fatture`"*

## Step 2: Create branch

Derive branch name from `$ARGUMENTS` in kebab-case:
- Strip accented characters, lowercase, replace spaces with hyphens
- If the first word is a number, treat as issue number prefix (e.g. "123 fix login" → `123-fix-login`)
- Otherwise prefix with type if obvious (e.g. "fix ..." → `fix-...`, "add ..." → `feat-...`)
- Max 50 characters

Check if branch exists:
```bash
git branch --list <branch-name>
git ls-remote --heads origin <branch-name>
```
If exists, inform user and stop.

Create:
```bash
git switch -c <branch-name> HEAD
```

## Step 3: Create worktree

```bash
git worktree add .claude/worktrees/<name> <branch-name>
```
Where `<name>` = branch name.

If the worktree path already exists, inform user and stop.

Set up directories:
```bash
mkdir -p .claude/worktrees/<name>/.claude
mkdir -p .claude/worktrees/<name>/.vscode
```

## Step 4: VS Code workspace identity

Write `.vscode/settings.json` in the worktree with a distinctive title bar color:

```json
{
  "workbench.colorCustomizations": {
    "titleBar.activeBackground": "<color>",
    "titleBar.activeForeground": "#ffffff"
  }
}
```

Generate the color deterministically: hash the branch name to a hue value (0-360), then use HSL with saturation 65% and lightness 35% for a dark, readable background. Convert to hex.

Ensure `.vscode/` is gitignored in the worktree:
```bash
git -C .claude/worktrees/<name> check-ignore -q .vscode 2>/dev/null
```
If NOT ignored, append `.vscode/` to the worktree's `.gitignore`:
```bash
echo '.vscode/' >> .claude/worktrees/<name>/.gitignore
```

## Step 5: Save parent branch info

Write a minimal `.claude/parent-branch` file in the worktree so other commands know the origin:
```bash
echo "<parent-branch>" > .claude/worktrees/<name>/.claude/parent-branch
```

## Step 6: Open VS Code (optional)

```bash
command -v code >/dev/null 2>&1 && code .claude/worktrees/<name>
```

If `code` is not available, skip silently.

## Step 7: Inform and end

```
Contesto "<branch-name>" creato.

Worktree: .claude/worktrees/<name>/
Branch: <branch-name> (da <parent-branch>)

Per lavorare, apri una sessione Claude nel worktree:
  cd .claude/worktrees/<name> && claude

Discuti il lavoro con Claude, poi lancia /write-workflow per creare il piano.
```

**This command ends here. No planning, no MEMORY.md.**
