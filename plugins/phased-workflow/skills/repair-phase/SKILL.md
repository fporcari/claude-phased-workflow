---
description: Repair the first failed [!] phase with fresh eyes — autonomous, no commit
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent
---

# Repair Phase

Fresh-eyes repair of a phase `/auto-phase` left `[!]`. It runs in a new context on purpose: **the previous session's diagnosis may itself be the problem — question it, don't continue it.**

**Usage:** launched by `/run-all-phases` (at most once per phase), or `claude -p '/repair-phase'`.

**Non-negotiables:** no questions, no commits, one phase per invocation, everything written in English, and always leave a machine-readable outcome — `[x]` + `> Repaired:`, or `[!]` + `> Repair attempted:`. Under `/run-all-phases` that outcome is the session's exit condition, checked by an independent evaluator.

## Step 1: Locate and read the failure

`REPO_ROOT=$(git rev-parse --show-toplevel)` → read `$REPO_ROOT/.claude/MEMORY.md`, take the **first** `[!]` phase.

- No `[!]` → print "No failed phases to repair." and exit.
- It already has `> Repair attempted:` → print "Repair already attempted for Phase N — human review required." and exit. Never loop repairs.

Read its `> Issue:`, `> Attempted:` and `> Files:`. **Hard rule: never repeat an attempt listed in `> Attempted:`.** If your diagnosis leads to essentially one of those fixes, the diagnosis is wrong — dig deeper.

## Step 2: Diagnose from scratch

1. Re-read the phase objective, `Details:`, `Done:` and its `Pattern:` example.
2. Reproduce the failure and confirm the recorded error signature still holds.
3. **Establish whose failure it is.** `/auto-phase` leaves a `WIP: baseline before Phase N` commit marking the tree before the phase began: `git diff <that commit> -- <the phase's Files:>` shows exactly what this phase changed, and re-running the green signal at that commit tells you whether the failure pre-dates it. A failure that reproduces on the baseline is **not this phase's** — don't patch it here; keep the phase `[!]` with a `> Repair attempted:` note naming the real culprit so the human fixes the right thing. No baseline commit → the tree was clean, `HEAD` serves the same purpose.
4. Root-cause first: grep the callers of the touched functions, compare against the pattern reference, and ask whether the previous fixes aimed at a symptom.
5. Scale exploration to the phase's Effort as in `/auto-phase` Step 2.

## Step 3: Fix and converge

Same rules as `/auto-phase` Step 4: green signal = test suite + linter on the touched files; up to **3 fix attempts** with the no-progress detector; then re-check every item of `Done:` literally.

Then run ONE `phase-verifier` subagent scoped to this phase's files — MECHANICAL findings fixed within the same budget, JUDGMENT recorded as `> Review:`. Unlike a normal phase, here it runs **unconditionally**: this code already failed once and was just patched under a bounded budget, which is the one case where a fresh independent pass reliably pays.

## Step 4: Record the outcome

**Repaired:**
```
- [x] **Phase N**: title
  > Done: brief description
  > Repaired: <the actual root cause, and why the previous attempts missed it>
  > Files: <complete list — previous session's plus yours>
  > Review: judgment-level findings flagged for finalize (omit if none)
```

**Still failing** — keep `[!]` and the existing `> Issue:` / `> Attempted:` / `> Files:` notes (extend `> Attempted:` with yours), and append:
```
  > Repair attempted: <ISO timestamp> — <updated diagnosis: what you ruled out, what the human should look at first>
```

Print `✓ Phase N repaired: <root cause>` or `✗ Phase N repair failed: <reason> — human review required`, then stop.
