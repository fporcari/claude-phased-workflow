---
description: Execute the next phase autonomously — no confirmations, auto-test, no commit
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, mcp__sourcerer__kb_*, mcp__sourcerer__sem_*, mcp__sourcerer__code_*
---

# Auto Phase

Execute the next uncompleted phase from the work plan autonomously. This is a wrapper around the `/execute-phase` workflow with all confirmation steps removed.

**Designed for unattended execution**: implement, test, update MEMORY.md, exit. No commits of your own work — the only commit allowed is the baseline WIP restore point of Step 0.4; `/finalize-workflow` consolidates it at the end.

**Usage:**
- Single phase: `claude -p '/auto-phase'`
- All phases: use `/run-all-phases` which handles model selection and looping

**Language rule:** All written content (MEMORY.md, code comments) in English.

**Goal guard:** when launched by `/run-all-phases`, this session runs under a native `/goal` condition — an independent evaluator re-checks after every turn that MEMORY.md shows the phase outcome (`[x]` with demonstrated Done, or `[!]` with Issue+Attempted notes). Recording the outcome in MEMORY.md is therefore not just bookkeeping: it is the session's exit condition. Never end a turn "done" without it.

## Autonomous mode overrides

These rules REPLACE the corresponding steps in the standard execute-phase workflow:

1. **NO user confirmations** — do NOT use AskUserQuestion at any point. Do not ask for plan approval, do not wait for verification. Just implement.
2. **NO commits of your own work** — the phase's changes stay uncommitted in the working tree. The single exception is the Step 0.4 baseline WIP commit, which snapshots what was *already* there before this phase began. The user runs `/finalize-workflow` at the end, which soft-resets the WIP streak and commits everything cleanly.
3. **AUTO-TEST with convergence loop** — write pytest tests for the phase, then iterate the Step 5 loop: up to 3 fix attempts against tests + lint, with a no-progress detector. If it doesn't converge, mark the phase `[!]` with structured notes and exit.
4. **EXIT when done** — after completing one phase (or determining no phases remain), exit cleanly.

## Execution flow

### Step 0: Detect environment and read plan

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
```

Read `$REPO_ROOT/.claude/MEMORY.md`. Extract branch, parent, phases.

If no `[ ]` phases remain → print "All phases completed. Run /finalize-workflow." and exit.

### Step 0.2: Baseline check (before touching anything)

A previous phase may have left the tree broken — a session that died without a WIP note, or an `[x]` phase whose breakage only shows now. Starting on a red baseline makes this phase attribute someone else's failure to itself, and burn its whole fix budget (and a repair session) on a bug it did not cause.

Run the project's green signal **before** any edit: the test suite plus the linter (for pytest/flake8 projects: `python -m pytest tests/ -q` and `flake8` on the tree). Then:

- **Green** → proceed.
- **Red** → the failure is **not yours**. Do NOT fix it inline and do NOT start the phase. Attribute it first, then take one of the two exits below.
- **Signal unavailable** (no test suite, no linter configured) → note it and proceed; there is nothing to compare against.

**Attribution.** Compare the failing test/check against the `> Files:` notes of the phases already marked `[x]` in this plan.

*Case A — an earlier phase owns it.* The failure touches files a completed phase claimed: that phase introduced a regression and was closed `[x]` wrongly (its `Done:` criterion was too weak, or its tests passed while it broke something outside its own scope). Do not stop the run for a human — this is exactly what the repair path is for. **Reopen the culprit** and exit without touching the phase you were going to take:

```
- [!] **Phase M**: title
  > Issue: regression detected at the baseline check of Phase N: <failure signature>. Closed [x] but broke <file>, which its own Done criterion did not cover.
  > Attempted: (none — reopened by a later phase's baseline check, not by a failed fix loop)
  > Files: <the culprit phase's original Files: list, preserved>
```

Keep its `> Done:`/`> Repaired:` history in place — the repair session needs to know what was already claimed. `/run-all-phases` sees the `[!]`, launches ONE fresh-eyes `/repair-phase` on it, and continues if the repair lands. The one-repair-per-phase guard (`> Repair attempted:`) still applies, so this cannot loop.

*Case B — nobody owns it.* The failure touches nothing any phase claimed: it pre-dates the run (base branch, an unrelated local edit, the repo itself). The chain has no mandate to fix code no phase in the plan touched. Mark the phase you were about to take and exit:

```
- [~] **Phase N**: title
  > Blocked: pre-existing failure on the baseline, attributable to no phase in this plan: <failure signature>
```

*If attribution is genuinely ambiguous* — the failing area is shared, or `> Files:` notes are missing — prefer Case B. A wrong reopen sends a repair session after the wrong bug and burns that phase's only repair.

Record the signature of a green baseline briefly — you will compare against it in Step 5, so you can tell your own regressions from noise.

### Step 0.4: Baseline restore point

If the working tree is dirty (earlier phases of this run left uncommitted changes), create ONE baseline commit so the convergence loop has somewhere to return to:

```bash
git add -A && git commit -q -m "WIP: baseline before Phase N"
```

This is the same WIP-commit mechanism `/execute-phase` uses and `/finalize-workflow` consolidates (its soft-reset collapses the whole WIP streak into the final clean commit), so it costs nothing in history. If the tree is already clean, skip it — `HEAD` is already the restore point.

### Step 1: Select next phase

Compute it deterministically:

```bash
python3 ~/.claude/scripts/next-phase.py "$REPO_ROOT/.claude/MEMORY.md"
```

Act on its `recommendation:` line:
- `next: N` → take Phase N. (Autonomous plans should not contain `group:N` — if a `unit:` appears anyway, execute only Phase N and note it in MEMORY.md.)
- `resume-candidate: N` → if it has `wip: yes`, RESUME it (a previous invocation exited early to preserve context — refresh the timestamp and continue from the WIP state). Otherwise: age > 2h → assume stale and take it over (refresh timestamp); newer → exit cleanly reporting the phase is busy.
- `attention: ...` → if the next pending phase depends on a `[!]` phase, mark it `[~] Blocked` and exit.
- `done` → print "All phases completed. Run /finalize-workflow." and exit.
- `blocked: ...` → exit reporting the reason.

If the script is unavailable or errors, apply the selection semantics manually from `~/.claude/workflow-refs/common.md` (Phase selection).

Mark selected phase as `[>]` in MEMORY.md immediately.

### Step 1.5: Read execution config for the selected phase

Now that the phase is known, look up its row in the "Suggested execution config" table in MEMORY.md and extract:
- **Effort** (`low` / `medium` / `high` / `xhigh` / `max`) — governs how much exploration to do before implementing
- **Sourcerer** (yes/no) — whether to search Sourcerer KB for GenroPy patterns before coding

`/run-all-phases` also passes this Effort to the session as `--effort`, so the model's own reasoning depth is already set when you start; the scale below is the *exploration* budget on top of it. If the table has no row for this phase, or no table exists, treat Effort as `high` and Sourcerer as `yes` for non-trivial code.

Apply these settings:
- **Effort=low**: Read only the files directly listed in the phase. Minimal exploration. (Under `/run-all-phases`, `low` phases normally run in light mode without this skill — if you are reading this at `low`, you were launched directly.)
- **Effort=medium**: Read listed files + their immediate references. Use 1 Explore agent if patterns are unclear.
- **Effort=high**: Thorough exploration. Use up to 2 Explore agents. Read all related files in the same package. Check existing patterns in other packages for consistency.
- **Effort=xhigh / max**: As `high`, plus up to 3 Explore agents and a cross-package consistency pass — reserved for architectural or multi-file-consistency phases.
- **Sourcerer=yes**: Before implementing, search Sourcerer skills for relevant GenroPy patterns:
  - Use `kb_find_skills` for the main pattern involved (e.g., "GenroPy package creation", "TH handler with buttons", "formulaColumn")
  - Use `sem_ask_codebase` if the pattern spans multiple files
  - Apply findings to the implementation — do NOT invent GenroPy APIs

### Step 2: Explore and understand

Before writing any code:
1. Read ALL files listed in the phase's "Files:" section (if they exist)
2. Read the phase's `Pattern:` / `Pattern reference:` example first — it is the model to copy-adapt — then any other reference files mentioned in the details
3. Scale exploration depth based on **Effort** level (see Step 1.5)
4. Search Sourcerer if **Sourcerer=yes** (see Step 1.5)

This step is critical — understand before implementing.

### Step 3: Implement

Write the code for this phase. Follow the phase details precisely.

**Conventions:**
- Follow the patterns of existing code in the project (never invent framework APIs)
- Before non-trivial code, locate 1–2 existing examples of the same pattern in the repo and copy-adapt
- Imports at top of file, never inside functions
- No `print()` or leftover debug output in committed code
- Match the style of existing files in the same package
- Apply any framework conventions from the global and project CLAUDE.md (e.g. GenroPy logging via `pkglog`)

### Step 4: Write tests

Create or update test files in the project's test directory. For each phase:
- Test the core logic (engines, importers, utility functions)
- Follow the patterns of existing tests in the repo (fixtures, mocks, naming); if the project has no tests yet, use the standard idioms of its test framework
- Test edge cases (empty input, missing fields, etc.)

If the phase is purely UI/declarative (e.g. TH resources, menu entries) and has no testable logic, skip this step.

### Step 5: Convergence loop (tests + lint)

The green signal is the project's test suite (for pytest projects: `python -m pytest tests/ -v`) **plus** the project linter scoped to the touched files (for flake8 projects: `flake8 <touched files>`). Both must pass.

Run the signal, then loop:

- **Green** → proceed to Step 5.5.
- **Failure** → up to **3 fix attempts**. Each attempt: read the failure, identify the ROOT CAUSE before patching (grep the callers of the touched function — one fix in the shared function beats a patch in the one failing path), fix, re-run the signal.
- **No-progress detector**: if the failure signature (same failing test + same exception) is identical two runs in a row, STOP the loop early — you are hitting a wall; more attempts only burn budget.
- **Revert instead of stacking** — if an attempt leaves the signal *worse* than before it (new failures, or a different and larger failure set), undo that attempt rather than patching on top of it: `git checkout -- <the files that attempt touched>` returns them to the Step 0.4 restore point. Then re-diagnose from the known state. Patch-on-patch is how a recoverable phase becomes an unrecoverable one, and it also poisons the input `/repair-phase` gets.
- **Budget exhausted or no progress** → mark the phase `[!]` with the structured notes of Step 6. Fill `> Attempted:` with every attempt and its error signature — the repair session (`/repair-phase`) depends on it. Leave the last attempt's code **in place** (do not revert before exiting): repair needs to see the failing state. Reverting is for mid-loop course correction, not for cleaning up on the way out.

### Step 5.5: Independent verification

Once green, launch ONE **`phase-verifier`** subagent (Agent tool, subagent type `phase-verifier` — a native read-only agent defined in `~/.claude/agents/phase-verifier.md`; if the type is unavailable, fall back to a general-purpose subagent instructed to be read-only). The verifier runs in its own context window, so the review costs this session almost nothing. Pass it:
- the phase objective and its `Done:` criterion
- the `Pattern:`/`Pattern reference:` example
- the list of files touched by THIS phase only (never the whole working tree — earlier phases' uncommitted changes are not up for re-review)

It returns findings classified as:
- **MECHANICAL** — real bug, wrong API usage, unused import, clear divergence from the pattern reference with an obvious fix → apply the fix and re-run the Step 5 signal. These fixes share the same 3-attempt budget.
- **JUDGMENT** — design trade-off, missing edge case needing a human decision → do NOT fix. Record as a `> Review:` note on the phase (Step 6). Judgment findings never block `[x]`.

### Step 5.8: Done-criterion gate

Before marking `[x]`, re-read the phase's `Done:` field and literally re-check each criterion: run the named test, run the named lint, verify the named output exists/matches. "Tests pass" is not enough if `Done:` says more.

- All criteria met → Step 6, phase is `[x]`.
- A criterion unmet → treat it as a failure: loop back to Step 5 if attempts remain, otherwise `[!]` naming the unmet criterion in `> Issue:`.

### Step 6: Update MEMORY.md

**If the phase converged (green signal + Done criteria met):**
```
- [x] **Phase N**: title
  > Done: brief description
  > Files: path/to/file1.py, path/to/file2.py, ...
  > Review: judgment-level findings flagged for finalize (omit if none)
```

**If the loop did not converge:**
```
- [!] **Phase N**: title
  > Issue: root symptom and current diagnosis
  > Attempted: 1) <fix tried> → <error signature>  2) <fix tried> → <error signature>
  > Files: path/to/file1.py, path/to/file2.py, ...
```

The `> Attempted:` line is mandatory on `[!]` — it is the input for the fresh-eyes repair session (`/repair-phase`), which must not repeat those attempts.

### Step 7: Exit

Print a one-line summary:
```
✓ Phase N completed: <title> (N files, N tests)
```
or
```
⚠ Phase N has issues: <brief reason>
```

Then stop. Do not proceed to the next phase — let the next invocation handle it.

## Context window management

Since each invocation handles ONE phase in a fresh context, compaction should not be an issue. However, if a phase is very large:
- If you've used more than ~60% of context and still have substantial work ahead:
- Update MEMORY.md with WIP note (keep `[>]` status):
  ```
  - [>] **Phase N**: title
    > In execution since <original timestamp>
    > WIP: description of what was done so far and what remains
  ```
- Exit. The next invocation will resume.

## Rules

- ONE phase per invocation, always
- NEVER commit your own work — only the Step 0.4 baseline WIP commit, and only when the tree was already dirty
- NEVER start on a red baseline (Step 0.2): a pre-existing failure is `[~]`, not yours to fix
- NEVER ask questions — make reasonable decisions and document them in MEMORY.md
- ALWAYS write tests when there is testable logic
- The convergence loop is BOUNDED: 3 fix attempts max, early stop on no progress — never iterate blindly against the same error
- NEVER modify files outside the current phase's scope
- If a phase depends on a previous `[!]` phase, skip it and mark as `[~]` Blocked
- Respect the `parallel:N` dependency system from MEMORY.md
