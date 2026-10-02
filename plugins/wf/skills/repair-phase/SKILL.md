---
description: Repair a broken phase with fresh eyes — you say what is wrong, a repair agent diagnoses and fixes it in a context of its own, you decide when it is fixed
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion, ToolSearch, SendMessage, ListAgents, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions
---

# Repair Phase

Fresh-eyes repair, in this conversation. **The previous session's diagnosis may itself be the problem — question it, don't continue it**, and debugging is the most context-hungry thing a phase does, which is why the repair runs in a **repair agent** — a subagent that starts with nothing but the plan and your account — and not in the chat that holds the workflow.

**Two ways in**, and they differ only at the ends:

- **A phase left `[!]`** — its `Done:` came back red and its executor gave up. The repair closes it: `[x]` + `> Repaired:`.
- **A phase still `[>]`, with a defect you have seen** — the executor handed it back for your checks and something is demonstrably wrong (`refs/phase-execution.md` → *Handing a defect to repair*). The repair **hands it back**: the phase returns `[>]` with a `> Repaired:` note and its gate resumes here.

**Non-negotiables:** no questions between the start and the verdict — that is what keeps this cheap for you; ONE commit at the end; one phase per invocation; everything written in English; and always a machine-readable outcome, never a phase left in a state the plan cannot describe.

`/wf:repair-phase-agent` is this same repair with the human replaced by a contract: unattended, `[!]` only, closing on its own — it reads *The repair body* below and records the verdict itself.

**Shared conventions:** `${CLAUDE_PLUGIN_ROOT}/refs/common.md` and `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` once at start; the outcome mechanics in `${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md`. The relay layer is read only by the unattended variant, at its notify step.

## Step 1: Ask what is wrong

**Always ask, even when the answer seems to be on file.** The plan's `> Issue:`, the executor's account, a log you can read — all of it is a *previous diagnosis*, and this repair exists because those are suspect. Your account of the symptom is the specification; everything else is evidence about it.

One question, plain: what goes wrong, what you expected instead, and — where it can be said — how to make it happen. Nothing else is asked until the verdict.

## Step 2: Locate the phase, and put it under repair

Resolve the active plan (`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve`, see `common.md`; from outside the plan's root, `--plans` + `git -C` per `common.md` → *Plan location*).

- **First `[!]` phase** → that is the one, and it is already marked. Read its `> Issue:`, `> Attempted:` and `> Files:`.
- **No `[!]`, one `[>]`** → the gate case. Write what you said as `> Issue:` and **ask to confirm the phase goes `[!]` while under repair** — one AskUserQuestion, because it is a real state change: while it holds, nothing else in the plan may start, and any chat that looks at the plan sees why. On confirmation, commit that edit alone.
- **Neither** → nothing to repair here: say so and stop.
- It already has `> Repair attempted:` → say "Repair already attempted for Phase N — the next look is yours" and stop. Never loop repairs.

**Then write the marker and commit it**, on the phase:

```
  > Repair started: <ISO timestamp> — chat wf:<slug>
```

`[!]` on its own does not say whether anybody is on the phase, so a chat reopened cold reads it as broken-and-available and can send a second repair into this working tree — two writers, one tree. The note is on disk and committed (`common.md` → *Failure and repair notes*). In the `[>]` case it rides the same commit as the `[!]` transition; in the `[!]` case it is a commit of its own — `wf(phase N): under repair`.

**The tree is the repair agent's while it runs.** Nothing else edits it — not this chat, not another executor: two writers on one working tree is the failure mode the whole protocol is shaped to avoid.

## Step 3: Launch the repair agent

ONE repair agent, through the Agent tool — `subagent_type: general-purpose`, `model` from the plan's `Run:` hint for this phase (`opus` floor; `fable` where the phase named it) — with this brief and nothing else:

- The plan root and the plugin root, as absolute paths.
- *"Phase N of the active plan is under repair. Read `<plugin root>/skills/repair-phase/SKILL.md` → **The repair body** and follow it, with `${CLAUDE_PLUGIN_ROOT}` = `<plugin root>`. The human's account of the symptom is the phase's `> Issue:`; it is the specification. Stop before any verdict: when the signal is green, commit your candidate as `wf(phase N): partial — repair candidate — <root cause, one line>` and report the root cause, what changed, and which signal is green that was red; when it is not green after the budget, commit nothing new beyond your reverts and report what you ruled out and what the human should look at first. Never edit the plan, never write `> Repaired:`."*

The agent's fresh context is the point: it has not read the failed executor's transcript, it has not made its attempts, and the only thing it knows about the previous diagnosis is that `> Attempted:` lists what it must not repeat.

## The repair body

Read by the repair agent, and by `/repair-phase-agent` unattended. Nobody here asks anything.

**Diagnose from scratch:**

1. Re-read the phase objective, `Details:`, `Done:` and its `Pattern:` example, and the decisions in `notes.md` under `## Phase N`.
2. **An `> Issue:` carrying `plan-defect claim` is itself the thing under test.** The executor judged the plan unimplementable, and that judgment reached you unverified — the field count is two claims that dissolved under fresh eyes (the contract was implementable in-dialect both times) and one that was TRUE, which a repair "dissolved" anyway: it built a `lib/resources/__init__.py` `__path__` shim so a test importing a resource by a dotted path could pass, deleted the failed phase's correct component, recorded its own verifier's warning as a `> Review:` and closed `[x]` — undone by hand the next morning. So your first job is trying to satisfy the contract AS WRITTEN, the contract stays read-only either way (`refs/contracts.md` → *Contract tests*), and **satisfying it has a cost bound**: a green that needs surface outside the phase's `Files:` and the failed phase's `> Files:` (a new module, a shim, a loader convention the repo does not have), or that the verifier flags as a JUDGMENT finding against the contract's own premise, does not dissolve the claim — it confirms it at a price the plan never bought. That outcome, like a claim that survives your honest attempt, is *Plan-defect confirmed* below — the plan and its tests are fixed from there by whoever owns the plan, never by you: the confirmed defect travels as an outcome, per `refs/phase-execution.md` → *Routing a decision*, so it reaches the foreman.
3. Reproduce the failure and confirm the recorded error signature still holds.
4. **Establish whose failure it is.** The failed phase committed its own work as `wf(phase N): FAILED — <title>`, so its boundaries are exact: `git show --stat <that commit>` is everything it changed, and its parent is the tree before it started. Re-run the green signal at the parent — a failure that reproduces there is **not this phase's**. Don't patch it here: report the real culprit, so the human fixes the right thing. Find the commit by message, never by assuming it is `HEAD`: `git log --format='%H %s' | grep "phase N"`. Under `/run-workflow` there is one more source, and it is the richest: `log/phase-N.txt` next to the plan holds the failing session's actual transcript. The `> Attempted:` notes are that session's summary of itself — the log is what it really did.
5. Root-cause first: grep the callers of the touched functions, compare against the pattern reference, and ask whether the previous fixes aimed at a symptom. **Hard rule: never repeat an attempt listed in `> Attempted:`.** If your diagnosis leads to essentially one of those fixes, the diagnosis is wrong — dig deeper.
6. Scale exploration to the phase's effort as in `/execute-phase-agent` Step 2.

**Fix and converge**, with the same rules as `/execute-phase-agent` Step 4: green signal = test suite + linter on the touched files; up to **two fix attempts** with the no-progress detector; revert, don't stack; then re-check every item of `Done:` literally.

Then run ONE `wf:phase-verifier` subagent scoped to this phase's files — MECHANICAL findings fixed within the same budget, JUDGMENT recorded for the verdict as `> Review:` material. Unlike a normal phase, here it runs **unconditionally**: this code already failed once and was just patched under a bounded budget, which is the one case where a fresh independent pass reliably pays. On a plan-defect repair the two classes are not symmetric: a JUDGMENT finding against the contract's premise is point 2's cost bound tripping, and it ends the repair as *Plan-defect confirmed* — never `[x]` with a `> Review:` asking a human to ratify a green already committed.

## Step 4: The verdict is yours

When the agent returns, read the tree, not the summary: `git log --oneline -3`, `git diff <the FAILED or Testing commit>..HEAD`, and re-run the signal it says is green. Then show what it turned out to be, what changed, and which signal is green that was red — and **stop and ask**. You decide it is repaired; a repair that grades itself is the thing this design exists to avoid.

On your ok, record the outcome for the way in:

- **Came in `[!]`** → the phase closes: `[x]` + `> Repaired:`, as below.
- **Came in `[>]`** → the phase **goes back to `[>]`** carrying `> Repaired:` and its existing `> Testing:` note, and its work resumes here: `/execute-phase` again in this chat — the worker — presents the checks anew. The phase is not finished by the repair, and finishing it is the gate's job.

**One agent is one attempt.** If the repair agent returns without a green signal, the problem is not a bug: leave `[!]` + `> Repair attempted:` — the record, owed in every mode — and report `blocked` per `refs/phase-execution.md` → *Routing a decision*: the line to the foreman (the relay protocol that table reaches, best-effort); say plainly that this belongs in a re-planning conversation, not in another repair, and let that re-planning take the road the same table gives it.

## The outcome formats

**Repaired:**
```
- [x] **Phase N**: title
  > Done: brief description
  > Repaired: <the actual root cause, and why the previous attempts missed it>
  > Files: <complete list — previous session's plus yours>
  > Review: judgment-level findings flagged for the quality check (omit if none)
```

**Still failing** — keep `[!]` and the existing `> Issue:` / `> Attempted:` / `> Files:` notes (extend `> Attempted:` with the agent's), and append:
```
  > Repair attempted: <ISO timestamp> — <updated diagnosis: what was ruled out, what the human should look at first>
```

**Plan-defect confirmed** — the same `[!]` record, its note reading `> Repair attempted: <ISO timestamp> — plan-defect confirmed — <what was tried; why the contract cannot hold as written, or what making it hold would cost>`, and the code goes back to the FAILED commit's before the note is written — `git checkout <FAILED commit> -- .` on everything outside the plan directory — so the workaround lives in the note and nowhere in the tree. What lands is the plan alone, as `wf(phase N): plan defect confirmed — <one line>`.

**The `> Repair started:` marker goes, whatever the outcome** — it described a repair in progress, and the outcome supersedes it: remove it in the same edit that records the result, on a phase handed back `[>]` too. A marker left behind describes a repair that no longer exists.

Either way, commit — the plan is tracked, and leaving the tree dirty would block the next phase's baseline:

```bash
git add -A && git commit -q -m "wf(phase N): repaired — <root cause>"
```

or, on a failed repair, `wf(phase N): repair attempted — <diagnosis>`.

Print `✓ Phase N repaired: <root cause>`, `✗ Phase N repair failed: <reason> — human review required` or `✗ Phase N plan defect confirmed: <one line> — the plan's author decides`, then stop. A phase handed back `[>]` prints the same first line plus where to go: *"back to the gate — `/execute-phase` here presents the checks again."*
