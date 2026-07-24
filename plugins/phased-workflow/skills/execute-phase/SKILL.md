---
description: Execute the next phase from the work plan (MEMORY.md or parallel context)
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion
---

# Execute Phase

Execute the next uncompleted phase from the work plan. **Semi-autonomous**: ONE approval gate up front (plan + batched questions), then run to completion without interruptions, auto-verify with tests, notify the user when done.

**Usage:** `/execute-phase` — selects the next available phase, respecting parallel groups and in-execution markers from other chats.

**Shared conventions:** read `~/.claude/workflow-refs/common.md` once at start — language, AskUserQuestion style, MEMORY.md path resolution, phase-selection semantics.

## Step 0: Detect environment and select the workflow

```bash
git rev-parse --show-toplevel
git worktree list --porcelain
```

- **Inside a worktree** → use `<repo_root>/.claude/MEMORY.md` directly. Inform: "Esecuzione nel worktree `<name>`, piano trovato."
- **Main repo** → select among plans with active `- [ ]` phases.

1. Check `<repo_root>/.claude/MEMORY.md`, `<repo_root>/.claude/memory_*.md` (parallel plans) and `<repo_root>/.claude/worktrees/*/` MEMORY.md files for active phases
2. None → inform the user there are no active plans, stop
3. One → use it, inform which
4. Multiple → AskUserQuestion listing `MEMORY.md — <context>`, `memory_<name>.md — <context>`, `worktree: <name> — <context>`. If a worktree plan is chosen, inform: "Apri una sessione da: `cd .claude/worktrees/<name> && claude`"
5. Store the chosen path — all subsequent reads/writes target it

## Step 1: Read the plan and select the phase

Extract branch, parent (`Parent:` line) and issue from the memory file, then compute the next phase deterministically:

```bash
python3 ~/.claude/scripts/next-phase.py <memory-file>
```

Act on its `recommendation:` line:
- `next: N` → proceed with Phase N. If it reports `unit: N,M,...` (a `group:N` run), the unit executes together in this chat — the only case where one invocation spans multiple phases; only the last member carries the group's single end-to-end test.
- `resume-candidate: N` (a `[>]` phase, nothing else eligible) → ask: "La fase N risulta in esecuzione da un'altra chat (da <timestamp>). Vuoi riprenderla (la chat precedente potrebbe essere terminata)?" If yes, refresh its timestamp and proceed.
- `attention: ...` (`[!]`/`[~]` phases) → surface them to the user; they must be resolved before dependent phases can run.
- `done` → plan complete, suggest `/finalize-workflow`.
- `blocked: ...` → report why and stop.

If the script is unavailable or errors, apply the selection semantics manually from `~/.claude/workflow-refs/common.md` (Phase selection).

## Step 2: Mark phase as in-execution

Immediately update the memory file:
```
- [>] **Phase N**: title  `parallel:1`
  > In execution since <ISO timestamp>
```

For a `group:N` unit, mark every phase in the group `[>]` at start.

## Step 2.6: ultracode assist (`vast` phases only — READ-ONLY)

Only if the phase is tagged `vast`; skip otherwise.

The main session does NOT read the whole surface itself. Partition the `Files:` list (or run its discovery rule) into a few slices and dispatch one read-only Explore subagent per slice (Agent tool). Each returns a short summary (≤10 lines): current structure, the seams relevant to this phase, what a change must preserve, risks.

Build the Step 3 gate by reasoning over the collected summaries — not the raw files. This keeps a large concern inside one context window.

**This fan-out writes nothing.** It only informs the plan presented at the gate; the single writer is still the main session, after approval.

## Step 3: Single approval gate (MANDATORY — the only planned interruption)

If the phase has a `Pattern:` field, read that example FIRST and copy-adapt — do not re-explore what planning already recorded.

Present in ONE message:
1. Concise summary of what the phase will do
2. Files to create/modify/delete, with key changes
3. **All open questions, batched**: anything `Decisions:`/`Details:` don't settle and that needs the user's judgment. Aim for zero; never drip questions later.

Then ONE AskUserQuestion: approval ("Si, procedi (Recommended)" / "No, discutiamone") together with the batched open questions (max 4 per call).

**No file may be edited before approval. After approval, run to completion without further interaction.**

**Inside a `group:N` unit:** repeat this gate once per phase — present phase A, approve, implement; then present phase B, approve, implement; and so on. Each write stays individually approved. **For a `vast` phase:** present the plan built from the Step 2.6 summaries. Neither grouping nor the fan-out ever replaces this approval.

## Step 4: Execute

Implement ONLY this phase. Do not touch other phases, do not refactor out of scope.

Within a `group:N` unit, implement each phase in order; close every non-last phase `[x]` with its `> Files:` and a `> Grouped: tested at Phase <last>` note, and write NO per-phase test — the group's single end-to-end test lives on the last phase (Step 5).

Blocker policy: if something emerges that the plan doesn't cover AND a wrong default would be costly, ask ONE batched question and record the answer in the memory file's Notes. Otherwise pick the conservative option and note it.

## Step 5: Auto-verify

- Testable logic → write/update tests following the repo's existing test patterns, run the project's test suite
- Failures → before fixing, check the failure is **yours**: if it does not touch this phase's `Files:` and looks pre-existing, verify against the tree as it was before you started (`git stash` is not needed — `git diff` against the last WIP commit, or just read the failing test) and tell the user rather than absorbing it. Then fix and re-run. ONE retry; still failing → the phase is `[!]`
- Purely UI/declarative phases → skip tests; **the user is the verifier**: record the manual checks as a `> Verify:` line in the memory file (Step 6) and surface them in the notification and closing summary
- `group:N`, non-last phase → no test here (closed in Step 4 with `> Grouped:`). The **last** phase of the group writes the single end-to-end test for the whole group; if it fails, only that last phase is `[!]` — earlier members stay `[x]` (their code exists; the integration failed)
- `vast` phase → after the edit, optionally re-run a read-only Explore fan-out to confirm no site was missed / conventions held, then write the asserting test as usual

## Step 6: Update the memory file

Replace `[>]` (remove the "In execution since" line) with:

```
- [x] **Phase N**: title
  > Done: brief description
  > Files: path/a.py, path/b.py, ...
  > Verify: <manual UI checks for the user — only for phases without test coverage>
```
or `[!]` with `> Issue: what went wrong, what was done` / `[~]` with `> Blocked: reason and what is needed` (both keep `> Files:` if anything was touched).

**Always list ALL touched files in `> Files:`** — `/finalize-workflow` uses it to scope commits when parallel workflows exist.

Do NOT commit — commits belong to `/finalize-workflow` (only exception: the WIP safety commit below).

## Step 7: Notify and report

Fire a macOS notification:
```bash
osascript -e 'display notification "Phase N: <short outcome>" with title "Claude — <repo>/<branch>" sound name "Glass"'
```
- Success: "Phase N completata — test verdi"
- UI phase: "Phase N implementata — verifica UI a mano"
- Issues/blocked: "Phase N con problemi — vedi [!]"

Then print the closing summary in Italian: what was done, test results, and the manual checks the user should perform (especially for UI work).

## Context window management (CRITICAL)

The user strongly dislikes context compaction. Act BEFORE it happens.

Suggest continuing in a new chat when: the conversation is getting long and the phase isn't complete; a complex sub-task with many tool calls is ahead; heavy exploration is done but substantial implementation remains; the system already compacted once (→ recommend switching immediately).

Ask: "⚠️ Il contesto si sta riempiendo. Apri una nuova chat e rilancia /execute-phase. Faccio un commit WIP di salvataggio prima?" (Recommended: si)

Before switching:
1. WIP commit of working changes: `git add <files> && git commit -m "WIP: <phase title> — partial progress"` — the ONLY commit allowed here, a safety net across sessions
2. Update the memory file keeping `[>]`:
   ```
   - [>] **Phase N**: title
     > In execution since <original timestamp>
     > WIP: what was done, what remains. WIP commit present.
   ```
3. The next chat resumes it; `/finalize-workflow` consolidates WIP commits into the final clean commit

## Rules

- NEVER edit files before the Step 3 approval
- The `vast` assist (Step 2.6) is read-only and never bypasses the Step 3 gate
- ONE phase per invocation — EXCEPT a `group:N` unit, which advances its phases together in one chat (single end-to-end test on the last). Never modify phases outside the current unit; no out-of-scope refactoring
- After approval, no further questions except the Step 4 blocker policy
- Do NOT commit (except the WIP safety commit)
- Always mark `[>]` at start and set the final status when done
- If the session ends unexpectedly and the memory file is still writable, reset `[>]` to `[ ]` with: `> Execution interrupted, phase available for retry`
