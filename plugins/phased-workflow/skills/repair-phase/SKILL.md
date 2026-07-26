---
description: Repair the first failed [!] phase with fresh eyes — autonomous
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent
---

# Repair Phase

Fresh-eyes repair of a phase `/auto-phase` left `[!]`. It runs in a new context on purpose: **the previous session's diagnosis may itself be the problem — question it, don't continue it.**

**Usage:** launched by `/run-all-phases` (at most once per phase), or `claude -p '/repair-phase'`.

**Non-negotiables:** no questions, ONE commit at the end (Step 4), one phase per invocation, everything written in English, and always leave a machine-readable outcome — `[x]` + `> Repaired:`, or `[!]` + `> Repair attempted:`. Under `/run-all-phases` that outcome is the session's exit condition, checked by an independent evaluator.

## Step 1: Locate and read the failure

Resolve the active plan (`python3 ~/.claude/scripts/next-phase.py --resolve`, see `common.md`) and take the **first** `[!]` phase.

- No `[!]` → print "No failed phases to repair." and exit.
- It already has `> Repair attempted:` → print "Repair already attempted for Phase N — human review required." and exit. Never loop repairs.

Read its `> Issue:`, `> Attempted:` and `> Files:`. **Hard rule: never repeat an attempt listed in `> Attempted:`.** If your diagnosis leads to essentially one of those fixes, the diagnosis is wrong — dig deeper.

Under `/run-all-phases` there is one more source, and it is the richest: `log/phase-N.txt` next to the plan holds the failing session's actual transcript. The `> Attempted:` notes are that session's summary of itself — the log is what it really did.

## Step 2: Diagnose from scratch

1. Re-read the phase objective, `Details:`, `Done:` and its `Pattern:` example.
2. Reproduce the failure and confirm the recorded error signature still holds.
3. **Establish whose failure it is.** The failed phase committed its own work as `wf(phase N): FAILED — <title>`, so its boundaries are exact: `git show --stat HEAD` is everything it changed, and `HEAD^` is the tree before it started. Re-run the green signal at `HEAD^` — a failure that reproduces there is **not this phase's**. Don't patch it here: keep the phase `[!]` with a `> Repair attempted:` note naming the real culprit, so the human fixes the right thing.

   `HEAD` is that commit only if nothing landed after it, which is the normal case (a `[!]` phase stops the run). Otherwise find it by message rather than assuming: `git log --format='%H %s' | grep "phase N"`.
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

Either way, commit — the plan is tracked, and leaving the tree dirty would block the next phase's baseline:

```bash
git add -A && git commit -q -m "wf(phase N): repaired — <root cause>"
```

or, on a failed repair, `wf(phase N): repair attempted — <diagnosis>`.

Print `✓ Phase N repaired: <root cause>` or `✗ Phase N repair failed: <reason> — human review required`, then stop.
