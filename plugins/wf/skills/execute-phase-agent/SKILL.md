---
description: Execute the next phase unattended — the executor of both modes, launched as a subagent by /execute-phase after its gate or headless by /run-workflow; no questions, baseline attribution, convergence loop, one commit
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, SendMessage, ListAgents, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions
---

# Execute Phase — Agent

Execute ONE phase of the active plan unattended: implement, test, record the outcome, commit, exit.

**Base skill: execute-phase** — the gate; this is the executor of both modes. `/execute-phase` launches it as a subagent once its gate is passed — fresh context, the plan and `notes.md` as its whole memory — and `/run-workflow` launches it as a headless session; the work is the same, and nobody can answer a question in either. This file states only the unattended constraints; the mechanics (phase selection, implementation discipline, outcome formats, the phase commit, the WIP checkpoints) live in `${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md` and are not restated here.

**Usage:** as the Agent-tool subagent `/execute-phase` launches (*Launched from the workflow chat*, below); `claude -p '/execute-phase-agent'` by hand; or `/run-workflow` for the whole plan.

**Non-negotiables:**
- **No questions.** Never AskUserQuestion — there is nobody here who can answer. Decide, and document the decision in the plan.
- **Output is a log.** Nobody reads this session live; every word of narration is token spend with no reader. Silence between tool calls — one short line only on a load-bearing finding, a change of direction, or a blocker — and a closing report of the ✓/⚠ line plus at most three sentences. Never restate the plan or the phase text.
- **The outcome in the plan is the exit condition**, not bookkeeping — under `/run-workflow` an independent evaluator re-checks it every turn.
- One phase, one commit at the end, everything written in English — per the shared core.

**Shared conventions:** `${CLAUDE_PLUGIN_ROOT}/refs/common.md` and `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md`. The foreman layer is NOT read at start: only its message formats matter here, at the notify step, per the shared core — and only under `/run-workflow`.

## Launched from the workflow chat

When the brief says you were launched from `/execute-phase`, three things change and nothing else:

- **The gate is passed.** The decisions it took are in `notes.md` under `## Phase N`, the mockup of a `ui` phase under `mockups/phase-N.html`; read them with the plan, and treat them as `Decisions:`. A question the gate did not settle is not yours to answer: stop with a `> WIP:` checkpoint (`refs/phase-execution.md` → *WIP checkpoints*) and report `blocked — <the question, one line>`; the gate asks it and relaunches you. Never a guess, never a default: a wrong default here costs the human a repair.
- **You do not close.** Step 6 ends with the `Done:` green and the phase still `[>]`: write the `> Testing:` note and its `partial` commit exactly as `refs/phase-execution.md` → *Awaiting the human's checks* specifies — `wf(phase N): partial — built, awaiting the gate` — markers left in place, `[x]` never written. The naming review, the browser pass on a `ui` phase, the human's own checks and the phase commit belong to the gate, where somebody can answer. `[!]` and `[~]` are recorded and committed here as always.
- **Nothing is notified.** An interactive plan has no foreman: skip Step 6's message without looking for one.

Everything else — the baseline check, the restore point, the convergence loop, the Done gate, the verifier rule — is unchanged: the gate trusts none of it to have happened because a summary says so, it re-reads the plan and `git log` when you return.

## Step 0: Read the plan

Resolve the active plan (`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve`, see `common.md`; from outside the plan's root, `--plans` + `git -C` per `common.md` → *Plan location*) and read it. No `[ ]` phases left → print "All phases completed. Run /quality-check, then /finalize-workflow." and exit.

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

*Case B — nobody owns it* (pre-dates the run). Mark your phase `[~]` with a `> Blocked:` note naming the failure signature, and exit.

Ambiguous attribution → prefer Case B. A wrong reopen burns the culprit's only repair on the wrong bug.

## Step 0.4: Restore point

`HEAD` is the restore point: every earlier phase committed its own work, so the tree is clean when you start. A **dirty tree means something is wrong** — a previous session died mid-phase, or someone edited by hand. Do not commit it as if it were yours: report what is uncommitted, mark your phase `[~]` with a `> Blocked:` note naming the stray files, and exit.

## Step 1: Select the phase

Per the shared core. The mode-specific outcomes, decided here instead of asked: `resume-candidate: N` → resume it if `wip: yes` (always the case when the brief names a resume), else take it over if older than 2h, else exit reporting it busy; `attention: ...` → mark the pending phase `[~] Blocked` and exit.

## Step 2: Implement

Use the shared core's reconnaissance for the assigned role. Low effort starts
with listed files, but inspect callers and dependencies whenever evidence requires
it. High effort does not automatically launch exploration agents. Escalate an
unknown premise before implementing a guessed design.

## Step 3: Write tests

Phases with contract tests start from them: copy `tests/phase-N/` verbatim and make them green — a skeleton's body is yours, the rest is read-only, and a test that cannot pass as written closes the phase `[!]` with `> Issue: plan-defect claim — …` (`contracts.md` → *Contract tests*: the exact wording, and why it is a claim the launcher routes upstream, never your verdict); never edit a contract into passing. The same claim format applies when the blocker is the plan itself — a `Done:` premise that turns out false, a pre-made decision that cannot be implemented. Then test the phase's remaining logic following the repo's existing test patterns. Purely UI/declarative phases with no testable logic → skip.

## Step 4: Convergence loop

Green signal = test suite + linter scoped to the touched files. Both must pass.

- **Green** → Step 5.
- **Failure** → up to **two fix attempts** (the stop-loss: never a third). Each: find the root cause before patching (grep the callers — one fix in the shared function beats a patch in the failing path), fix, re-run.
- **No-progress detector**: identical failure signature twice in a row → stop early.
- **Revert, don't stack**: an attempt that leaves the signal worse gets undone (`git checkout -- <files it touched>` returns to `HEAD`, the Step 0.4 restore point) before re-diagnosing. Patch-on-patch also poisons what `/repair-phase` receives.
- **Budget exhausted or stuck** → `[!]` with the shared core's notes. Leave the failing code **in place** — repair needs to see it. **Struggle is a symptom before it is a defect.** Two attempts lost against the same obstacle usually mean a premise nobody named. Before writing the `> Issue:`, name the one the attempts leaned on — a `Done:`, `Pattern:`, `Files:` or pre-made decision the code contradicts. When there is one, the `> Issue:` is a `plan-defect claim` (Step 3's format) written as that premise — *assuming X — it does not hold because <the code, file:line>* — with the before-text → after-text edit when you know it: the claim goes to the plan's author before any repair. No premise in doubt → an ordinary `[!]`.

## Step 5: Verify and gate

**The Done gate always runs.** Re-check the phase's `Done:` field literally, criterion by criterion — run the named test, the named lint, verify the named output. "Tests pass" is not enough if `Done:` says more. An unmet criterion is a failure: back to Step 4 if attempts remain, else `[!]` naming it in `> Issue:`. This is a contract check against a criterion you did not write — not a re-read of your own work.

**An independent verifier runs only where it earns its keep**: the phase's `Pattern:` is `new-pattern`, or the phase is marked `sonnet` (legacy plans only — sonnet left the palette). Otherwise skip it — you already check your own work as you go, and a second review pass on a well-specified phase mostly re-litigates settled decisions.

When it does run: ONE `wf:phase-verifier` subagent (Agent tool — namespaced: a bare `phase-verifier` may resolve to an older un-namespaced copy of this agent installed outside the plugin and silently skip its marker, necessity and contract-test checks; fallback: a general-purpose subagent told to stay read-only), given the phase objective and `Done:`, its `Pattern:` example, **only this phase's touched files**, and — where the plan carries them — the phase's contract-test paths, plan copy and in-tree copy. Findings: **MECHANICAL** (real bug, wrong API, divergence from the pattern) → fix, re-run the signal, same 3-attempt budget. **JUDGMENT** (design trade-off, human call) → do not fix; record as `> Review:`. Never blocks `[x]`.

## Step 6: Record, commit, stop

Record the outcome and make the phase commit exactly as the shared core specifies. The `wf:phase-N:new` markers on new callables stay in place — nobody here can answer a naming question; `/quality-check` runs the whole-workflow naming review (`contracts.md` → *New-method markers and minimality*). **Thin `Verify:` pass — thin, never absent** (`${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` → *Verification*): the phase's authored `Verify:` fields, plus anything only human eyes can judge, become `> Verify:` notes with their *when*; deferred ones are appended to `verify.md` under a `## Phase N` heading. No browser skill runs here, and `Verify:` never carries what the tests already cover — most phases end with none. A `ui`-tagged phase reaching this skill lost its mockup gate and browser pass by construction (the tag belongs to interactive plans): note it, and hand the visual check to the human as a `Verify: now` step.

Then, under `/run-workflow` only, the shared core's *Notify the foreman* — one outcome message, best-effort, no retry: in a `-p` sub-session the messaging tool may simply not exist, and that is the silent-skip case, not a failure.

Print `✓ Phase N completed: <title>` — `✓ Phase N built: <title> — awaiting the gate` when launched from the workflow chat — or `⚠ Phase N has issues: <reason>`, and stop.
