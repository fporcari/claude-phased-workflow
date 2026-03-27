---
description: Write a phased work plan (MEMORY.md) from the current conversation
allowed-tools: Bash(git:*), Bash(cat:*), Read, Grep, Glob, Write, AskUserQuestion
---

# Write Workflow

Plan a work session and write the phased plan to a memory file. This is the **only** deliverable of this command.

**CRITICAL CONSTRAINTS:**
1. **NEVER edit source code.** You may read any file to understand structure and patterns, but you must not modify anything outside the memory directory.
2. **The only output is the plan written to a memory file.** No code changes, no refactoring, no branch creation.
3. **Do not proceed to implementation.** The user will delegate execution via `/execute-phase`.

**Language rule:** All written content (memory files, phase notes) must be in English. Conversation with the user remains in Italian.

## Step 1: Detect environment

```bash
git branch --show-current
git rev-parse --show-toplevel
```

Detect parent branch:
```bash
cat .claude/parent-branch 2>/dev/null || echo "unknown"
```

If `.claude/parent-branch` does not exist (not in a worktree created by `/create-context`), auto-detect the base branch:
```bash
git rev-parse --verify origin/develop 2>/dev/null && echo "develop" || echo "main"
```

**Case A — On a feature branch (different from base):**

Run in parallel:
1. `git log origin/<base>..HEAD --oneline --no-decorate`
2. `git diff --stat origin/<base>...HEAD`
3. `git diff origin/<base>...HEAD`
4. If branch name starts with a number: `gh issue view <number> --json title,body,labels,state --jq '{title,body,labels: [.labels[].name],state}'`

Present a concise summary, then ask: *"Cosa vuoi pianificare su questo branch?"* — wait for the user's response.

**Case B — On base branch (main/develop/master):**

Do NOT explore, do NOT run extra commands. Immediately ask: *"Sei su `<branch>`. Cosa vuoi fare?"* — wait for the user's response.

**In both cases:** the user's response is the primary input for the plan. You may read code to understand structure and dependencies, but always in service of building the plan — not as open-ended exploration.

## Step 2: Discuss and refine the plan

From the conversation context (prior discussion + user's response from Step 1), extract:
- **Objective**: what the user wants to achieve (2-3 sentences)
- **Phases**: concrete, self-contained steps to implement
- **Files**: which files are likely involved per phase (if known)
- **Notes**: constraints, dependencies, attention points

You may:
- **Read code** to understand structure, patterns, or dependencies relevant to the plan
- **Read issues** if the user references them
- **Ask clarifying questions** in natural conversation

**Present the plan to the user in Italian** for review. Discuss and iterate until explicit approval.

## Step 3: Choose memory file and write plan

Only after user approval, determine which memory file to write.

### Memory file selection

1. Read the existing `.claude/MEMORY.md`
2. **If MEMORY.md does not exist or is empty** → write to `.claude/MEMORY.md`
3. **If MEMORY.md already contains an active work plan** (has unchecked `- [ ]` phases):
   - Derive a context name from the branch name in kebab-case
   - Inform the user: *"MEMORY.md è già occupato. Salvo in `memory_<nome>.md`"*
   - Write to `.claude/memory_<nome>.md`
   - Add to the top: `<!-- Parallel context — primary plan in MEMORY.md -->`
4. **If MEMORY.md contains a plan but all phases are completed** (all `- [x]`) → overwrite `.claude/MEMORY.md`

### Plan format

```
# Context: <branch-name>
Parent: <parent-branch> | Issue: #<number> (if present)

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

Rules for "Suggested execution config":
- **Effort**: `low` for mechanical/repetitive, `medium` for standard, `high` for architecture/complex, `max` for unbounded analysis
- **Model**: `haiku` for simple, `sonnet` for standard, `opus` for deep reasoning
- **Sourcerer**: `yes` if touches architectural patterns or framework conventions; `no` otherwise

Principles for phases:
- Each phase must be **self-contained and independently testable**
- Right granularity: not too large nor too small
- Logical order: dependencies first, tests after
- If a phase depends on another, state it explicitly

## Step 4: Inform and end

```
Piano scritto in <file> (<N> fasi).
Per eseguire, lancia /execute-phase (meglio in una nuova sessione per contesto pulito).
```

## Rules

- **NO source code editing** — this is a planning command
- If the conversation lacks enough detail, ask the user to clarify before writing
- Reading code is encouraged to inform the plan, but never as open-ended exploration
