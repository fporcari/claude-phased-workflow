---
description: Execute the next phase from the work plan (MEMORY.md or parallel context)
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion
---

# Execute Phase

Execute the next uncompleted phase from the work plan. Supports both `MEMORY.md` and parallel context files (`memory_<name>.md`).

**Language rule:** All written content (MEMORY.md updates, phase notes) must be in English. Conversation with the user remains in Italian as per global settings.

**UI rule:** Use `AskUserQuestion` tool for ALL questions to the user. Always provide a `default_answer` when a sensible default exists. For multiple-choice questions, list each option on its own line with a checkbox-style format.

## Step 0: Select the workflow

As the VERY FIRST interaction, look in the current project's memory directory (the path indicated by the system as "persistent auto memory directory").

1. Check for `MEMORY.md` and any `memory_*.md` files that contain active uncompleted phases (`- [ ]`)
2. **If no memory files have active phases** → inform the user there are no active plans
3. **If only one memory file has active phases** → use it directly, no question needed, inform the user which plan was selected
4. **If multiple memory files have active uncompleted phases** → use AskUserQuestion with checkbox-style options listing each active plan:
   ```
   Quale workflow vuoi eseguire?

   [ ] MEMORY.md — <context name from first line>
   [ ] memory_<name>.md — <context name from first line>
   ...
   ```
   - Default: the file with the most uncompleted phases
5. Store the chosen file path — all subsequent reads/writes in this session target that file.
6. As the VERY FIRST thing in your first response, include this line at the top:
   **→ Rinomina questa chat: `<context-name>`**
   where `<context-name>` is the context name from the selected plan (e.g. the value after `# Context:` in the memory file). This is a statement, not a question. Do NOT use AskUserQuestion for this.

**Only ask this on the first invocation in a conversation — skip if already asked.**

## Step 1: Read the plan and apply config

Read the selected memory file (chosen in Step 0). Identify the first phase marked `- [ ]` (uncompleted).

If no phases remain, inform the user the plan is complete.

## Step 2: Execute the phase

Execute ONLY the identified phase. Do not touch other phases.

## Step 3: Wait for user verification

After completing the phase implementation, use AskUserQuestion to ask (in Italian):
- Question: "Ho completato l'implementazione della fase. Puoi verificare e dirmi se funziona tutto?"
- No default

**Do NOT proceed to update MEMORY.md until the user confirms the result of their test.** The user may report issues that need fixing before the phase can be marked as done.

## Step 4: Update the memory file

After the user confirms, update the selected memory file (chosen in Step 0):

**If completed successfully**:
```
- [x] **Phase N**: title
  > Done: brief description of what was done / modified files
```

**If completed with issues or doubts**:
```
- [!] **Phase N**: title
  > Issue: description of the problem and what was partially done
```

**If unable to complete**:
```
- [~] **Phase N**: title
  > Blocked: reason for the block and what is needed to unblock
```

## Context window management (CRITICAL)

The user strongly dislikes context compaction. You MUST proactively monitor context usage and act BEFORE compaction happens.

### When to suggest continuing in a new chat

Suggest opening a new chat to continue when ANY of these conditions apply:
- You notice the conversation is getting long and the phase is not yet complete
- You're about to start a complex sub-task that will require many tool calls
- You've already done significant exploration/reading and still have substantial implementation ahead
- The system has already compacted once — immediately recommend switching

### How to suggest it

Use AskUserQuestion:
```
⚠️ Il contesto si sta riempiendo. Ti consiglio di aprire una nuova chat e lanciare di nuovo /execute-phase per continuare con qualità ottimale.

Vuoi che prima faccia commit del lavoro fatto finora?
```
- Default: "si"

### Before switching: save progress

If the phase is partially done when context gets tight:
1. **Commit** any working changes (ask confirmation)
2. **Update the memory file** with a progress note on the current phase:
   ```
   - [ ] **Phase N**: title
     > In progress: description of what was done so far and what remains
   ```
3. This way the next chat can pick up exactly where this one left off.

## Rules

- Execute ONE phase per invocation only
- Do not modify other phases in the plan
- Do not refactor or improve outside of scope
- If the phase requires non-obvious architectural decisions, ask the user
- Al termine di ogni fase completata con successo ([x]), esegui sempre un commit. Chiedi conferma del messaggio di commit, ma il commit è obbligatorio — non opzionale. Questo garantisce che check-phase-context e finalize-workflow possano sempre usare git log per ricostruire lo stato stabile del lavoro.
