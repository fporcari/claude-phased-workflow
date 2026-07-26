---
description: Execute the next phase autonomously — no confirmations, auto-test, no commit
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent
---

# Auto Phase

Execute ONE phase of the active plan unattended: implement, test, record the outcome, commit, exit.

**Usage:** `claude -p '/auto-phase'` — or `/run-all-phases` for the whole plan.

**Non-negotiables:**
- **No questions.** Never AskUserQuestion. Decide, and document the decision in the plan.
- **One commit, at the end, for your own phase** (Step 6) — and nothing else. `/finalize-workflow` consolidates them all later.
- **One phase per invocation.** Never start the next one.
- **The outcome in the plan is the exit condition**, not bookkeeping — under `/run-all-phases` an independent evaluator re-checks it every turn.
- All written content in English.

## Step 0: Read the plan

Resolve the active plan (`python3 ~/.claude/scripts/next-phase.py --resolve`, see `common.md`) and read it. No `[ ]` phases left → print "All phases completed. Run /finalize-workflow." and exit.

## Step 0.2: Baseline check (before any edit)

Run the project's green signal — test suite + linter (pytest/flake8 projects: `python -m pytest tests/ -q`, `flake8`). Green → proceed. No signal configured → note it and proceed.

**Red → the failure is not yours.** Do not fix it, do not start the phase. Attribute it against the `> Files:` notes of the `[x]` phases:

*Case A — an earlier phase owns those files.* It was closed `[x]` wrongly. Reopen it and exit without touching your phase:

```
- [!] **Phase M**: title
  > Issue: regression detected at the baseline check of Phase N: <failure signature>. Closed [x] but broke <file>, which its own Done criterion did not cover.
  > Attempted: (none — reopened by a later phase's baseline check, not by a failed fix loop)
  > Files: <the culprit phase's original Files: list, preserved>
```

Keep its `> Done:`/`> Repaired:` history — the repair session needs it.

*Case B — nobody owns it* (pre-dates the run). Mark your phase and exit:

```
- [~] **Phase N**: title
  > Blocked: pre-existing failure on the baseline, attributable to no phase in this plan: <failure signature>
```

Ambiguous attribution → prefer Case B. A wrong reopen burns the culprit's only repair on the wrong bug.

## Step 0.4: Restore point

`HEAD` is the restore point: every earlier phase committed its own work, so the tree is clean when you start. Nothing to do here.

A **dirty tree means something is wrong** — a previous session died mid-phase, or someone edited by hand. Do not commit it as if it were yours: report what is uncommitted, mark your phase `[~]` with a `> Blocked:` note naming the stray files, and exit.

## Step 1: Select the phase

```bash
python3 ~/.claude/scripts/next-phase.py
```

Act on `recommendation:` — `next: N` → take it; `resume-candidate: N` → resume if it has `wip: yes`, else take over if older than 2h, else exit reporting it busy; `attention: ...` → mark the pending phase `[~] Blocked` and exit; `done` → exit; `blocked: ...` → exit with the reason. Script unavailable → apply the semantics in `~/.claude/workflow-refs/common.md`.

Mark the selected phase `[>]` immediately.

## Step 2: Implement

Read the phase's `Pattern:` example first — it is the model to copy-adapt — then its `Files:`. Scale exploration to the **Effort** column of the execution config table (missing table → `high`): `low` only the listed files; `medium` + immediate references; `high` up to 2 Explore subagents and the surrounding package; `xhigh`/`max` up to 3 plus a cross-package consistency pass.

Then write the code the phase describes, and nothing else. Never invent framework APIs.

## Step 3: Write tests

Test the phase's logic following the repo's existing test patterns. Purely UI/declarative phases with no testable logic → skip.

## Step 4: Convergence loop

Green signal = test suite + linter scoped to the touched files. Both must pass.

- **Green** → Step 5.
- **Failure** → up to **3 fix attempts**. Each: find the root cause before patching (grep the callers — one fix in the shared function beats a patch in the failing path), fix, re-run.
- **No-progress detector**: identical failure signature twice in a row → stop early.
- **Revert, don't stack**: an attempt that leaves the signal worse gets undone (`git checkout -- <files it touched>` returns to `HEAD`, the Step 0.4 restore point) before re-diagnosing. Patch-on-patch also poisons what `/repair-phase` receives.
- **Budget exhausted or stuck** → `[!]` with the Step 6 notes. Leave the failing code **in place** — repair needs to see it.

## Step 5: Verify and gate

**The Done gate always runs.** Re-check the phase's `Done:` field literally, criterion by criterion — run the named test, the named lint, verify the named output. "Tests pass" is not enough if `Done:` says more. An unmet criterion is a failure: back to Step 4 if attempts remain, else `[!]` naming it in `> Issue:`. This is a contract check against a criterion you did not write — not a re-read of your own work.

**An independent verifier runs only where it earns its keep**: the phase is marked `sonnet`, or its `Pattern:` is `new-pattern`. Otherwise skip it — you already check your own work as you go, and a second review pass on a well-specified phase mostly re-litigates settled decisions.

When it does run: ONE `phase-verifier` subagent (Agent tool; fallback: a general-purpose subagent told to stay read-only), given the phase objective and `Done:`, its `Pattern:` example, and **only this phase's touched files**. Findings:

- **MECHANICAL** (real bug, wrong API, divergence from the pattern) → fix, re-run the signal, same 3-attempt budget.
- **JUDGMENT** (design trade-off, human call) → do not fix; record as `> Review:`. Never blocks `[x]`.

## Step 6: Record the outcome

```
- [x] **Phase N**: title
  > Done: brief description
  > Files: path/a.py, path/b.py, ...
  > Review: judgment-level findings flagged for finalize (omit if none)
```

```
- [!] **Phase N**: title
  > Issue: root symptom and current diagnosis
  > Attempted: 1) <fix tried> → <error signature>  2) <fix tried> → <error signature>
  > Files: path/a.py, path/b.py, ...
```

`> Attempted:` is mandatory on `[!]`: it is the input of `/repair-phase`, which must not repeat those attempts.

Then commit — the phase's code and its own status update, together, so the next phase starts from a clean tree:

```bash
git add -A && git commit -q -m "wf(phase N): <title>"
```

A phase closing `[!]` commits too, as `wf(phase N): FAILED — <title>`. **Leave the failing code in place**: repair has to see it, and it needs a clean tree to work from.

Print `✓ Phase N completed: <title>` or `⚠ Phase N has issues: <reason>` and stop.

**Context running out mid-phase** (past ~60% with substantial work left): commit what exists as `wf(phase N): partial — <title>`, keep `[>]`, add `> WIP: <what is done, what remains>`, and exit — the next invocation resumes from a clean tree.
