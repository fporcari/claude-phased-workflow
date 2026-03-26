
# Write Workflow

Crystallize the current conversation into a phased work plan in MEMORY.md.

**This command assumes you already discussed the work with the user.** Use the conversation context to build the plan — do not start from scratch.

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

If `.claude/parent-branch` does not exist (not in a worktree created by `/create-context`), use the base branch as parent:
```bash
git rev-parse --verify origin/develop 2>/dev/null && echo "develop" || echo "main"
```

If a linked issue exists (branch name starts with a number), fetch it:
```bash
gh issue view <number> --json title,body,labels,state --jq '{title,body,labels: [.labels[].name],state}'
```

## Step 2: Synthesize the plan from conversation

Using the full conversation context, extract:
- **Objective**: what the user wants to achieve (2-3 sentences)
- **Phases**: concrete, self-contained steps to implement
- **Files**: which files are likely involved per phase (if discussed)
- **Notes**: constraints, dependencies, attention points

**Present the plan to the user in Italian** for review. Discuss and iterate until explicit approval.

## Step 3: Write MEMORY.md

Only after user approval, write `.claude/MEMORY.md`:

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
Piano scritto in MEMORY.md (<N> fasi).
Per eseguire, lancia /execute-phase (meglio in una nuova sessione per contesto pulito).
```

## Rules

- **NO source code editing** — this is a planning command
- The plan must come from the conversation, not from scratch exploration
- If the conversation lacks enough detail, ask the user to clarify before writing
