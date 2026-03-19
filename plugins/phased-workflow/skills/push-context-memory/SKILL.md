---
description: Push the current MEMORY.md work plan to Sourcerer as a shared context
allowed-tools: Read, Bash(git:*), AskUserQuestion, mcp__sourcerer__ctx_*
---

# Push Context Memory to Sourcerer

Syncs the current project's MEMORY.md work plan to Sourcerer's context system, making it accessible to other tools, bots, and team members.

**Language rule:** All written content must be in English. Conversation with the user remains in Italian.

**UI rule:** Use `AskUserQuestion` for all questions. Provide `default_answer` when a sensible default exists.

## Step 1: Read MEMORY.md

Read `MEMORY.md` from the current project's memory directory (the path indicated by the system as "persistent auto memory directory").

If MEMORY.md is empty or missing, inform the user to run `/setup-context` first and stop.

Parse the MEMORY.md structure:
- **Context name**: from the `# Context: <name>` header
- **Base branch and issue**: from the `Base: ... | Issue: ...` line
- **Objective**: the content under `## Objective`
- **Phases**: each `- [x]/[ ]/[!]/[~] **Phase N**: ...` with details and status
- **Notes**: content under `## Notes`

## Step 2: Detect branch info

```bash
git branch --show-current
git log origin/<base>..HEAD --oneline --no-decorate 2>/dev/null | head -20
```

## Step 3: Check existing context on Sourcerer

Use `ctx_list_contexts` to check if a context with the same name already exists.

- If it exists, use `ctx_list_memories` to see current memories
- Ask the user: "Esiste gia' un contesto '<name>' su Sourcerer. Vuoi aggiornarlo o crearne uno nuovo?" (default: "aggiorna")
  - **aggiorna**: delete existing memories and recreate them
  - **nuovo**: append a suffix (e.g. `-v2`) to the context name

- If it doesn't exist, proceed to create it

## Step 4: Create/update context on Sourcerer

### 4a. Create context (if new)

Use `ctx_create_context`:
- name: the context name from MEMORY.md (e.g. `style-modernization`)
- context_type: `project`
- description: the Objective text from MEMORY.md

### 4b. Create memories

Create one memory per logical section:

**Memory 1 — Objective**
- title: `Objective`
- memory_type: `note`
- body: the objective text
- visibility: `shared`

**Memory 2 — Work Plan**
- title: `Work Plan`
- memory_type: `note`
- body: summary of all phases with their status markers
- visibility: `shared`

Then add one `memory_line` per phase:
- `line_type`: `done` for `[x]`, `todo` for `[ ]`, `warning` for `[!]` or `[~]`
- `content`: `Phase N: <title> — <status/details summary>`
- `position`: phase number (for ordering)

**Memory 3 — Notes** (if Notes section exists and is non-empty)
- title: `Notes`
- memory_type: `constraint`
- body: the notes content
- visibility: `shared`

**Memory 4 — Git State** (snapshot)
- title: `Git State`
- memory_type: `reference`
- body: branch name, base branch, commit count, last commit summary
- visibility: `shared`

## Step 5: Confirm

Show the user a summary of what was pushed:
- Context name
- Number of memories created
- Number of phases (done/total)
- Visibility level

## Rules

- NO source code editing
- Always parse MEMORY.md structure — do not push raw text as a single blob
- Use `shared` visibility so the context is accessible to team/bots
- If MEMORY.md has extra sections (e.g. "Key files", "Previous Work"), create additional memories for them
- Idempotent: running twice should update, not duplicate
