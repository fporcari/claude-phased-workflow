---
description: Initialize work context - analyze existing branch or create new branch with work plan
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob, Write, AskUserQuestion
---

# Setup Context

Initialize the work context for the current project. This command prepares the work plan in MEMORY.md (or in a `memory_<context>.md` file if MEMORY.md is already occupied by another active plan).

**IMPORTANT: This command is for PLANNING ONLY. Do NOT edit any source code. The user will supervise execution from this chat and delegate coding to other sessions using /execute-phase.**

**Language rule:** All written content (memory files, phase notes, plan) must be in English. Conversation with the user remains in Italian as per global settings.

**UI rule:** Use `AskUserQuestion` tool for ALL questions to the user. Always provide a `default_answer` when a sensible default exists. For multiple-choice questions, list each option on its own line with a checkbox-style format so the user can pick easily.

## Step 0: Chat title

As the VERY FIRST thing in your first response, include this line at the top:

**→ Rinomina questa chat: `<branch-name>`**

where `<branch-name>` is the current branch (if already on a feature branch) or the branch that will be created in Step 3B. If the branch is not yet known at the start, output this line as soon as the branch is determined.

This is a statement, not a question. Do NOT use AskUserQuestion for this. **Only output this on the first invocation in a conversation — skip if already done.**

## Step 1: Identify current branch and base

```bash
git branch --show-current
```

Determine base branch:
1. Try `origin/develop` — if it exists, propose `develop` as default
2. Otherwise propose `origin/main`

```bash
git rev-parse --verify origin/develop 2>/dev/null && echo "develop" || echo "main"
```

Use AskUserQuestion:
- Question: "Qual e' il branch di riferimento?"
- Default: the detected base branch

## Step 2: Determine mode

Compare current branch with reference branch:

**Case A — On a feature branch different from reference:**
Proceed with change analysis (Step 3A).

**Case B — On the same branch as reference:**
Ask the user for a subject for the new branch, create it and proceed (Step 3B).

## Step 3A: Existing branch analysis (feature branch)

Run in parallel:

1. **Commit history**:
   ```bash
   git log origin/<base>..HEAD --oneline --no-decorate
   ```

2. **Changed files**:
   ```bash
   git diff --stat origin/<base>...HEAD
   ```

3. **Full diff**:
   ```bash
   git diff origin/<base>...HEAD
   ```

4. **Linked issue** (if branch name starts with a number):
   ```bash
   gh issue view <number> --json title,body,labels,state --jq '{title,body,labels: [.labels[].name],state}'
   ```

Analyze changes:
- Understand the role of each modified file
- Identify touched functions/classes
- Note dependencies between modified files

Then go to Step 4.

## Step 3B: New branch

Use AskUserQuestion:
- Question: "Descrivi brevemente cosa vuoi fare (subject del branch)"
- No default

Create the branch:
```bash
git checkout -b <branch-name-from-subject> origin/<base>
```

Branch name must be kebab-case, derived from subject (e.g. "fix login timeout" -> `fix-login-timeout`).
If a linked issue exists, prefix with the number (e.g. `123-fix-login-timeout`).

Then go to Step 4.

## Step 4: Propose the work plan

Use AskUserQuestion:
- Question: "Come vuoi impostare il lavoro? Descrivimi cosa vuoi fare."
- No default

The user will provide a work description. Integrate this with:
- Information from the diff (if Case A)
- Information from the issue (if present)
- Your understanding of the project structure

**Present the plan to the user in Italian for review before writing MEMORY.md.** Discuss and iterate until the user approves the plan.

## Step 5: Choose memory file and write plan

Only after user approval, determine which memory file to write.

### Memory file selection

1. Read the existing `MEMORY.md` in the project's memory directory
2. **If `MEMORY.md` does not exist or is empty** → write to `MEMORY.md`
3. **If `MEMORY.md` already contains an active work plan** (has unchecked `- [ ]` phases):
   - Inform the user: "MEMORY.md è già occupato dal piano: `<context name from existing MEMORY.md>`"
   - Use AskUserQuestion:
     - Question: "Nome per il contesto di questo piano parallelo? (verrà salvato come `memory_<nome>.md`)"
     - Default: derive from branch name in kebab-case (e.g. branch `fix-login-timeout` → default `login-timeout`)
   - Write to `memory_<nome>.md` in the same memory directory
   - Add to the top of the file a note: `<!-- Parallel context — primary plan in MEMORY.md -->`
4. **If `MEMORY.md` contains a plan but all phases are completed** (all `- [x]`) → overwrite `MEMORY.md`

### Write the plan

Completely overwrite the chosen memory file with the plan.

Memory file format:

```
# Context: <branch-name>
Base: <base-branch> | Issue: #<number> (if present)

## Objective
[2-3 sentences describing the overall goal]

## Work Plan
- [ ] **Phase 1**: <concise title>
  - Details: <what to do concretely>
  - Files: <involved files, if known>
- [ ] **Phase 2**: <concise title>
  - Details: <what to do concretely>
  - Files: <involved files, if known>
[... more phases ...]

## Notes
[Any attention points, dependencies, breaking changes]

## Suggested execution config
| Phase | Effort | Model | Sourcerer |
|-------|--------|-------|-----------|
| Phase 1 | ... | ... | ... |
| Phase 2 | ... | ... | ... |
```

Rules for filling "Suggested execution config":
- **Effort**: `low` for mechanical/repetitive tasks, `medium` for standard implementations, `high` for phases touching architecture or complex logic, `max` for unbounded analysis
- **Model**: `haiku` for simple/fast tasks, `sonnet` for standard development, `opus` for deep reasoning or complex multi-file phases
- **Sourcerer**: `yes` if the phase touches architectural patterns, framework conventions, or code that may have precedents in internal repos; `no` otherwise

Principles for phases:
- Each phase must be **self-contained and independently testable**
- Right granularity: not too large (risks losing focus) nor too small (unnecessary overhead)
- Logical order: dependencies first, tests after
- If a phase depends on another, state it explicitly

## Rules

- **NO code editing** from this command. This is a planning-only session.
- The user supervises from this chat and delegates execution to other sessions via `/execute-phase`.
- Focus on understanding the problem, structuring the plan, and writing the memory file.
- If you need to read code to understand the project structure, that is fine. But do NOT modify any source files.
- When writing to a `memory_<context>.md` file, inform the user clearly which file was written so they can reference it when running `/execute-phase`.
