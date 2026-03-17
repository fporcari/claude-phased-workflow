---
description: Check the current status of the work plan phases
allowed-tools: Bash(git:*), Read, Edit, Grep, Glob, AskUserQuestion
---

# Check Phase Context

Verify the current state of the work plan from the supervisor chat.

**IMPORTANT: This command is for SUPERVISION ONLY. Do NOT edit any source code.**

**Language rule:** All written content must be in English. Conversation with the user remains in Italian.

**UI rule:** Use `AskUserQuestion` tool for ALL questions to the user.

## Step 0: Chat title

As the VERY FIRST thing in your first response, include this line at the top:

**→ Rinomina questa chat: `<context-name>`**

where `<context-name>` is the context name from the first line of the selected memory file (e.g. the value after `# Context:` in MEMORY.md). If multiple plans exist and the user must choose, output this line after the selection is made.

This is a statement, not a question. Do NOT use AskUserQuestion for this. **Only output this on the first invocation in a conversation — skip if already done.**

## Step 1: Select and read current state

Look in the current project's memory directory for `MEMORY.md` and any `memory_*.md` files.

1. **If only one memory file has active phases (`- [ ]`)** → use it directly
2. **If multiple memory files have active phases** → use AskUserQuestion with checkbox-style options:
   ```
   Ci sono più piani attivi. Quale vuoi verificare?

   [ ] MEMORY.md — <context name from first line>
   [ ] memory_<name>.md — <context name from first line>
   ```
   - Default: `MEMORY.md`
3. Store the chosen file path — all reads/writes in this session target that file.

Read the selected memory file.

## Step 2: Get uncommitted changes

Run in parallel:

1. **Uncommitted files**:
   ```bash
   git status --short
   ```

2. **Detailed diff** (unstaged + staged):
   ```bash
   git diff HEAD --stat
   ```

3. **Full diff content** (to understand what changed):
   ```bash
   git diff HEAD
   ```

If the diff is too large, focus on `git diff HEAD --stat` and read the most relevant changed files individually.

## Step 3: Cross-reference uncommitted changes with the plan

For each phase in the Work Plan:
- Analyze the uncommitted changes and determine which phase they belong to
- Mark phases as **fully covered**, **partially covered**, or **not started** based on the diff
- Identify any uncommitted changes that don't match any planned phase (drift)

## Step 4: Detect oversized phases

A phase is considered **oversized** when uncommitted changes tied to it are too large or span too many concerns. Indicators:
- More than ~10 files changed for a single phase
- Changes cover multiple unrelated areas (e.g. model + UI + tests for different features)
- The diff is so large it's hard to review as a single commit

When an oversized phase is detected:
1. Identify which parts of the work are **complete and coherent** (committable as-is)
2. Identify what remains to be done
3. Propose a **re-phasing**: split the current phase into smaller sub-phases, suggesting:
   - What to commit now (with a proposed commit message)
   - New phases to add to the plan for the remaining work
   - Updated phase ordering

## Step 5: Present status report

Present to the user (in Italian) a clear summary:

1. **Stato del piano**: list each phase with its status from the selected memory file (`[x]`, `[ ]`, `[!]`, `[~]`)
2. **Modifiche non committate**: list changed files grouped by the phase they belong to
3. **Copertura fasi**: for each `[ ]` or `[!]` phase, indicate if uncommitted changes already address it (fully/partially/not at all)
4. **Drift**: any uncommitted changes that don't match any planned phase
5. **Fasi sovradimensionate**: if any phase is oversized, present the re-phasing proposal with:
   - Which changes to commit now
   - Proposed new sub-phases
   - Ask the user (via `AskUserQuestion`) if they want to apply the re-phasing
6. **Prossimo passo**: suggest whether to commit, continue working, re-phase, or update the plan

## Step 6: Apply re-phasing (if approved)

If the user approves the re-phasing proposal:
1. Update the selected memory file with the new sub-phases (replace the oversized phase with the split phases)
2. Mark completed sub-phases as `[x]`
3. Leave remaining sub-phases as `[ ]`

**Note:** This is the ONLY case where this command modifies a file — and only the memory file, never source code.

## Rules

- **NO source code editing** from this command
- Read-only analysis of git state and MEMORY.md
- The only file that can be modified is the selected memory file, and only when the user approves a re-phasing
- If no memory files exist or all are empty, inform the user to run `/setup-context` first
