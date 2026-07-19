---
description: Create a new work context — branch + worktree + VS Code
argument-hint: <tema del lavoro>
allowed-tools: Bash(git:*), Bash(command:*), Bash(mkdir:*), Bash(echo:*), Write
---

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

## Step 3: Create branch + worktree (one step)

```bash
git worktree add .claude/worktrees/<name> -b <branch-name> HEAD
```
Where `<name>` = branch name.

This creates the branch AND its worktree in a single command, while the main repo stays on the parent branch. Do NOT `git switch -c` in the main repo first: a branch checked out in the main repo cannot be added as a worktree (`fatal: '<branch>' is already checked out`), and the main repo must remain on the parent.

If the worktree path already exists, inform user and stop.

Set up directories:
```bash
mkdir -p .claude/worktrees/<name>/.claude
mkdir -p .claude/worktrees/<name>/.vscode
```

## Step 4: VS Code workspace identity

Write `.vscode/settings.json` in the worktree with a distinctive title bar color.

Generate the color deterministically: hash the branch name to a hue value (0-360), then use HSL with saturation 65% and lightness 35% for a dark, readable background. Convert to hex.

**Preserve existing settings.** If `.vscode/settings.json` already exists in the worktree (it usually does — `.vscode/settings.json` is tracked in this repo via a `!.vscode/settings.json` exception, so worktrees inherit shared pytest/flake8 config), merge the `workbench.colorCustomizations` key into the existing JSON instead of overwriting the file. If the file doesn't exist, create it with just the color customization.

Use python to do the merge safely (avoids quoting headaches and preserves the rest of the JSON):

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path(".claude/worktrees/<name>/.vscode/settings.json")
p.parent.mkdir(parents=True, exist_ok=True)
data = json.loads(p.read_text()) if p.exists() else {}
data["workbench.colorCustomizations"] = {
    "titleBar.activeBackground": "<color>",
    "titleBar.activeForeground": "#ffffff",
}
p.write_text(json.dumps(data, indent=4) + "\n")
PY
```

**Hide the local color override from git.** The repo's root `.gitignore` has `!.vscode/settings.json`, so the file is tracked and any local edit would show up as a modification in `git status`. Mark it `assume-unchanged` in the worktree so git ignores the per-context color customization:

```bash
git -C .claude/worktrees/<name> update-index --assume-unchanged .vscode/settings.json
```

This is reversible with `--no-assume-unchanged` if you ever need to pick up upstream changes to that file.

## Step 5: Save parent branch info

Write a minimal `.claude/parent-branch` file in the worktree so other commands know the origin:
```bash
echo "<parent-branch>" > .claude/worktrees/<name>/.claude/parent-branch
```

## Step 6: Inherit local permissions

If the parent repo has a `.claude/settings.local.json`, copy it into the worktree so
Claude Code starts with the same permissions baseline (auto-accept toggles, pre-approved
Bash commands, etc.):

```bash
[ -f .claude/settings.local.json ] && cp .claude/settings.local.json .claude/worktrees/<name>/.claude/settings.local.json
```

If the source file does not exist, skip silently — the worktree will start with
default permissions, which is fine.

## Step 7: Open VS Code (optional)

```bash
command -v code >/dev/null 2>&1 && code .claude/worktrees/<name>
```

If `code` is not available, skip silently.

## Step 8: Inform and end

```
Contesto "<branch-name>" creato.

Worktree: .claude/worktrees/<name>/
Branch: <branch-name> (da <parent-branch>)

Per lavorare, apri una sessione Claude nel worktree:
  cd .claude/worktrees/<name> && claude

Discuti il lavoro con Claude, poi lancia /write-workflow per creare il piano.
```

**This command ends here. No planning, no MEMORY.md.**
