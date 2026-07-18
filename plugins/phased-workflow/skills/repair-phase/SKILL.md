# Repair Phase

Fresh-eyes repair session for a phase that `/auto-phase` left as `[!]`. It runs in a new context on purpose: the previous session's diagnosis may itself be the problem — question it, don't continue it.

**Designed for unattended execution**: diagnose, fix, verify, update MEMORY.md, exit. No commits, no questions. Launched automatically by `/run-all-phases` (at most once per phase, on fable with opus fallback), or manually: `claude -p '/repair-phase' --model fable`.

Repair deserves the strongest model available: it is by definition the case where the phase's own model already failed once.

**Language rule:** all persisted content (MEMORY.md notes, code, comments) in English.

## Execution flow

### Step 1: Locate the failed phase

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
```

Read `$REPO_ROOT/.claude/MEMORY.md`. Find the **first** `[!]` phase.

- No `[!]` phase → print "No failed phases to repair." and exit.
- The phase already has a `> Repair attempted:` note → print "Repair already attempted for Phase N — human review required." and exit. Never loop repairs.

### Step 2: Read the failure record

From the phase notes, read:
- `> Issue:` — the previous session's symptom and diagnosis
- `> Attempted:` — every fix already tried, with its error signature
- `> Files:` — what was touched

**Hard rule: do NOT repeat an attempt listed in `> Attempted:`.** If your diagnosis leads to a fix that is essentially one of those, the diagnosis is wrong — dig deeper.

### Step 3: Fresh diagnosis

Start from scratch, not from the previous session's conclusion:
1. Re-read the phase's objective, `Details:`, `Done:` and its `Pattern:`/`Pattern reference:` example.
2. Reproduce the failure yourself (run the failing test/check) — confirm the error signature is still the one recorded.
3. Root-cause first: grep the callers of the touched functions, compare the implementation against the pattern reference, and ask whether the previous fixes were aimed at a symptom.
4. Apply the phase's execution config (Effort/Sourcerer) from MEMORY.md, as in `/auto-phase` Step 0.5.

### Step 4: Fix and converge

Apply the same convergence rules as `/auto-phase` Steps 5–5.8:
- Green signal = project test suite + linter scoped to the touched files.
- Up to **3 fix attempts**, with the no-progress detector (same failure signature twice in a row → stop early).
- After green: independent verification — one read-only reviewer subagent scoped to this phase's touched files; mechanical findings fixed within the same budget, judgment-level findings recorded as `> Review:`.
- Done-criterion gate: literally re-check every item in the phase's `Done:` field before declaring success.

### Step 5: Update MEMORY.md

**Repaired:**
```
- [x] **Phase N**: title
  > Done: brief description
  > Repaired: <the actual root cause, and why the previous attempts missed it>
  > Files: <complete list — previous session's files plus yours>
  > Review: judgment-level findings flagged for finalize (omit if none)
```

**Still failing:**
Keep `[!]`, keep the existing `> Issue:` / `> Attempted:` / `> Files:` notes (extend them with your own attempts), and append:
```
  > Repair attempted: <ISO timestamp> — <updated diagnosis: what you ruled out, what the human should look at first>
```

### Step 6: Exit

Print a one-line summary:
```
✓ Phase N repaired: <root cause>
```
or
```
✗ Phase N repair failed: <brief reason> — human review required
```

Then stop.

## Rules

- ONE phase per invocation — the first `[!]` only
- NEVER commit — changes stay in the working tree
- NEVER ask questions — decide and document in MEMORY.md
- NEVER repeat an attempt listed in `> Attempted:`
- NEVER modify files outside the phase's scope
- The convergence loop is BOUNDED: 3 fix attempts max, early stop on no progress
- Always leave a machine-readable outcome: `[x]` + `> Repaired:`, or `[!]` + `> Repair attempted:`
