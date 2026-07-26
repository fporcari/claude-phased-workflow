---
description: Create a new work context — branch + worktree + VS Code
argument-hint: <tema del lavoro>
allowed-tools: Bash(git:*), Bash(command:*), Bash(mkdir:*), Bash(echo:*), Bash(cp:*), Bash(code:*), Bash(python3:*), Write
---

# Create Context

Branch + worktree for a new work stream. Infrastructure only — no planning, no MEMORY.md.

**Requires `$ARGUMENTS`** (the topic, e.g. "export PDF fatture", "123 fix login timeout"). Empty → stop: *"Specifica il tema del lavoro. Esempio: `/create-context export PDF fatture`"*

## Step 1: Name the branch

The current branch (`git branch --show-current`) is the **parent** — store it, `/finalize-workflow` needs it.

Derive the branch name from `$ARGUMENTS` in kebab-case: strip accents, lowercase, spaces → hyphens, max 50 chars. A leading number is an issue prefix ("123 fix login" → `123-fix-login`); otherwise prefix by obvious type (`fix-…`, `feat-…`).

Exists already (`git branch --list` / `git ls-remote --heads origin`) → inform and stop.

## Step 2: Create branch + worktree

```bash
git worktree add .claude/worktrees/<name> -b <branch-name> HEAD
mkdir -p .claude/worktrees/<name>/.claude .claude/worktrees/<name>/.vscode
```

One command creates both, and the main repo stays on the parent. Do NOT `git switch -c` first: a branch checked out in the main repo cannot be added as a worktree (`fatal: '<branch>' is already checked out`). Path already exists → inform and stop.

## Step 3: VS Code identity

Hash the branch name to a hue (0-360) and build an HSL colour at 65% saturation / 35% lightness, converted to hex. Merge it into the worktree's `.vscode/settings.json` rather than overwriting — the file is usually already there (tracked via a `!.vscode/settings.json` exception, so worktrees inherit shared pytest/flake8 config):

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

Because that file is tracked, the local colour would show up in `git status` — hide it (reversible with `--no-assume-unchanged`):

```bash
git -C .claude/worktrees/<name> update-index --assume-unchanged .vscode/settings.json
```

## Step 4: Carry over context

```bash
echo "<parent-branch>" > .claude/worktrees/<name>/.claude/parent-branch
[ -f .claude/settings.local.json ] && cp .claude/settings.local.json .claude/worktrees/<name>/.claude/settings.local.json
command -v code >/dev/null 2>&1 && code .claude/worktrees/<name>
```

The parent-branch file is what other commands read. The settings copy and the VS Code launch are best-effort — skip silently if absent.

## Step 5: Inform and end

```
Contesto "<branch-name>" creato.

Worktree: .claude/worktrees/<name>/
Branch: <branch-name> (da <parent-branch>)

Per lavorare, apri una sessione Claude nel worktree:
  cd .claude/worktrees/<name> && claude

Discuti il lavoro con Claude, poi lancia /write-workflow per creare il piano.
```
