---
description: Create a Pull Request after thorough review as a meticulous maintainer
argument-hint: [issue-number]
allowed-tools: Bash(gh:*), Bash(git:*), Read, Grep, Glob, TodoWrite, AskUserQuestion
---

# Pull Request Review & Creation

**Language rule:** All written content (PR title, body, review reports) must be in English. Conversation with the user remains in Italian as per global settings.

## Parameters

- Optional argument: `$1` (issue number, overrides branch default)

## Step 0: Base Branch Selection

Determine the default base branch:
1. If `.claude/parent-branch` exists (written by `/create-context`), use its content as the default
2. Otherwise auto-detect: `git rev-parse --verify origin/develop` → `develop` if it exists, else `main`

Ask the user via AskUserQuestion which branch to use as PR base, with the detected default as the FIRST option marked "(Recommended)".

- Use the chosen branch as `BASE_BRANCH` for all subsequent steps
- Verify the branch exists on remote: `git ls-remote --heads origin <BASE_BRANCH>`
- If the branch doesn't exist, report error and ask again

In all subsequent steps, replace `origin/develop` with `origin/<BASE_BRANCH>`.

## Step 1: Issue Detection and Mode

Determine the linked issue number:

1. If `$1` is specified, use it as issue number
2. Otherwise, check the current branch name with `git branch --show-current`
3. If the branch starts with a number (e.g. `123-fix-login`, `456-feature-x`), extract that number as default issue
4. If no number found, proceed without linked issue

### Mode detection:

- If current branch is `<BASE_BRANCH>` → activate **Auto-Branch Mode** (Step 1B)
- If current branch is already a feature branch → proceed normally from Step 2

## Step 1B: Auto-Branch Mode (only if on BASE_BRANCH)

When starting from `<BASE_BRANCH>` with local changes not yet on a feature branch:

1. Update the base branch:
   ```bash
   git fetch origin <BASE_BRANCH>
   git stash
   git pull origin <BASE_BRANCH>
   git stash pop
   ```
   If there are conflicts during stash pop, STOP and report to the user.

2. Analyze changes to understand context:
   ```bash
   git diff --name-only
   git diff --stat
   git diff
   ```

3. Based on modified files and diff content, generate a descriptive branch name in English:
   - Format: `type/short-description` (e.g. `fix/menu-plugin-ordering`, `feat/add-user-export`)
   - Valid types: `fix/`, `feat/`, `refactor/`, `docs/`, `style/`, `chore/`
   - Use kebab-case, max 50 characters total
   - Name should describe WHAT the changes do, not the files touched

4. Present the proposed branch name and commit message to the user and wait for approval. Then:
   ```bash
   git checkout -b <generated-branch-name>
   git add -A
   git commit -m "<approved message>"
   ```

5. Proceed from Step 3 (Change Analysis)

## Step 2: Update from Base Branch

```bash
git fetch origin <BASE_BRANCH>
git log HEAD..origin/<BASE_BRANCH> --oneline
```

If the base branch has new commits, ask the user via AskUserQuestion before merging: *"Il base branch ha N commit nuovi. Faccio il merge di `origin/<BASE_BRANCH>` nel branch?"* (recommended: yes). Only after approval:

```bash
git merge origin/<BASE_BRANCH>
```

If there are conflicts, STOP and report to the user how to resolve them.

## Step 3: Change Analysis

1. Get list of modified files relative to base branch:
   ```bash
   git diff --name-only origin/<BASE_BRANCH>...HEAD
   ```

2. Get full diff:
   ```bash
   git diff origin/<BASE_BRANCH>...HEAD
   ```

3. If an issue was identified, load it with `gh issue view <number>` to understand expected scope

## Step 4: Meticulous Maintainer Review

Two passes: the heavy machinery first, then the checks only this workflow knows about.

### 4.1 Correctness & quality pass (delegated)

Run the built-in `code-review` skill (Skill tool) on the branch diff, effort `medium` — raise to `high` for large or risky diffs. It hunts correctness bugs, regressions and reuse/simplification/efficiency cleanups, with adversarial verification of findings. Its confirmed findings feed Step 5 like any other problem.

### 4.2 Maintainer checks (this workflow's own)

Act as a demanding maintainer who must approve this PR:

**Issue coherence** — if there's a linked issue:
- Verify ALL changes are relevant to the issue
- Identify any unrelated "drive-by" changes
- Flag any feature creep or scope creep

**Project conventions & over-engineering:**
- Verify the code follows project conventions (GenroPy APIs verified against source, style of the surrounding code)
- Hunt residual over-engineering, one line per finding — `file:line — tag — what to cut, what replaces it`:
  - `delete:` dead code, unused flexibility, speculative features
  - `stdlib:` hand-rolled code the standard library already ships
  - `native:` code or dependency doing what GenroPy / the platform already does
  - `yagni:` abstraction with one implementation, config nobody sets, layer with one caller
  - `shrink:` same logic, fewer lines — show the shorter form
- Verify no TODO/FIXME left in code
- Check for `console.log`, `print`, `debugger` or other debug code

**Comments in English:**
- ALL code comments **added or modified by this PR** MUST be in English
- Flag any new/modified comments in Italian or other languages
- Pre-existing non-English comments on untouched lines are NOT a blocker — do not demand their translation

**Security basics:**
- Verify no hardcoded credentials
- Check error handling and input validation where the diff touches trust boundaries
- If the diff touches auth, permissions or input parsing, recommend a dedicated `/security-review` before merging

## Step 5: Decision

### If problems found:

**BLOCK** PR creation and present a detailed report:

```
## PR Review Failed

### Problems Found:

1. **[Category]**: Problem description
   - File: `path/to/file.py:123`
   - Detail: ...

2. **[Category]**: ...

### Required Actions:
- [ ] Fix problem 1
- [ ] Fix problem 2
- ...

Once problems are resolved, run `/pull-request` again
```

**DO NOT create the PR if there are problems.**

### If everything is ok:

Proceed with PR creation.

## Step 6: PR Creation (only if review passed)

1. Verify the branch is pushed:
   ```bash
   git push -u origin HEAD
   ```

2. Generate summary by analyzing the commits:
   ```bash
   git log origin/<BASE_BRANCH>..HEAD --oneline
   ```

3. Create the PR with this template:

```bash
gh pr create --base <BASE_BRANCH> --title "[DESCRIPTIVE TITLE]" --body "$(cat <<'EOF'
## Summary
- [Main change bullet point 1]
- [Bullet point 2]
- [Bullet point 3 if needed]

## Linked Issue
Closes #ISSUE_NUMBER (if present)

## Test plan
- [ ] Manual tests executed
- [ ] Automated tests pass
- [ ] Expected behavior verified

EOF
)"
```

4. Show the created PR link

## Important Notes

- Be VERY rigorous in review — better to block a problematic PR than to let subpar code through
- Comments added or modified by the PR MUST be in English (pre-existing comments on untouched lines are exempt)
- If the issue is unclear or lacks context, flag it as a problem
- Default base branch comes from `.claude/parent-branch` (or auto-detected develop/main); the user can choose a different branch at Step 0
