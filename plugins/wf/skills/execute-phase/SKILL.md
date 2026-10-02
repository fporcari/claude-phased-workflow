---
description: Execute the next phase from the active work plan, built here in the worker chat with you in it, after one approval gate
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion, Skill, SendMessage, ListAgents, SendUserFile, ToolSearch, mcp__ccd_session_mgmt__set_session_title, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions, mcp__ccd_session_mgmt__get_session
---

# Execute Phase

Execute the next uncompleted phase. **This is the heart of the attended mode**, not a lesser `/run-workflow`: ONE approval gate up front (plan + all questions batched), then the build (`${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` → *Where decisions travel*). `Mode: manual` — and `interactive`, `assisted` and a plan carrying no `Mode:`, which read as manual — **the build happens here, in this chat, with the user in it.** This chat is the **worker**: one conversation per phase, the same chat cleared between phases (the ▶ button of `wf-bar`, or `/clear`); a change of mind, a study, a browser pass that reshapes the design are ordinary work here, not a failed gate. A plan ambiguity goes UP first, as `clarify?` to the foreman (`refs/phase-execution.md` → *Routing a decision*). An `autonomous` plan is not this skill's: `/run-workflow` owns it.

Two kinds of interruption, and only one is legitimate: a question that needs a **decision** — ask it, take the answer, go on. Asking the user to **try something trivial** mid-phase is not a question, it is the symptom of a phase that was cut too small; the cure is sizing, and manual checks belong in `Verify:` at the end. Execution stays on a strong model — `opus` floor; `sonnet` is not in this plugin's palette.

**The phase's `Run: <model> / <effort>` line** is the plan's advice, decided during planning. The effort governs how wide *this* chat looks before the gate — the scale is in Step 3. Both values are this session's: read them, do not reconsider them. Missing line → treat as `opus` / `high`.

- **`fable`** means the phase kept inventive work of its own. Read this file as a contract on the *output* — the approval gate, one phase, one commit, the outcome format — not as a procedure to walk step by step, since a prescriptive step list is exactly what degrades that model. The settled `Decisions:` are input, not something to re-derive.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md`, `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` once at start — core conventions and the contract layer (Done:/Verify:, contract tests). The relay layer is not read at start: the road and the protocol behind it are reached through the shared core's *Routing a decision* when a decision has to travel. **Shared mechanics:** `${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md` — selection, implementation discipline, the outcome formats, the phase commit.

## Step 1: Find the plan and the phase

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
```

No active plan → stop and say so: `/write-workflow` creates one, `/import-workflow` adapts an older one. The plan lives on the workflow branch, so being on the wrong branch is the usual reason it is missing — check `git branch --show-current` before concluding there is no work. If the plan lives in another checkout (or the user means a different workflow), resolve via `--plans` and anchor every command to that plan's root — `common.md` → *Plan location*.

**Title this chat** before acting on the recommendation, with `set_session_title` on `session_id: "self"` — every road out of it runs in this chat, the awaiting-checks gate included. `wf:<slug>:phase-N — <phase title>`: a resuming chat finds the phase's chat by it (`refs/phase-execution.md` → *Resuming a `[>]` phase*). Best-effort: no tool, no title, no consequence.

**Check this chat against the `Run:` line** before taking `next: N` or a resume: `get_session` on `session_id: "self"` gives the chat's `model` and `effort`. A model id that does not name the `Run:` model, or another effort → ONE `AskUserQuestion` before the phase is marked: *switch from the model menu and relaunch `/execute-phase` here* (Recommended) or *proceed on <model> / <effort>*. The switch is the user's: `set_session_model` refuses `self`, a session never re-prices its own turns. A chat cleared after the previous phase keeps that phase's model, which is why this check exists. No tool → skip, nothing asked. An invocation ending in a `wf-bar:` line was launched by the button, which already runs this chat on the phase's model and effort: skip the check.

Act on `recommendation:` — `next: N` → proceed to the gate (mark the phase `[>]` with `> In execution since <ISO timestamp>` first); `resume-candidate: N` → a `[>]` phase another session left with a `> WIP:` note: ask whether to resume it — on yes, skip the gate (it was passed): look for the chat that had it and take the phase over here (`refs/phase-execution.md` → *Resuming a `[>]` phase*); a `[>]` with no `> WIP:` note, no `partial` commit and nobody alive on it is a dead session: reset it per the Rules and take it as `next`; `attention: ...` → surface the `[!]`/`[~]` phases, they block what follows — `/repair-phase` here for a `[!]`; `done` → suggest `/quality-check`, then `/finalize-workflow`; `blocked: ...` → report and stop — except a `blocked:` naming a phase that awaits the human's checks, which is this skill's own gate coming back: go straight to Step 6 (`refs/phase-execution.md` → *Awaiting the human's checks*).

## Step 2: `vast` phases only — read-only fan-out

Skip unless the phase is tagged `vast`. Partition its `Files:` list — or, where the phase carries a discovery rule instead of a file list, run that rule and partition what it returns — into **at most 4 slices**, and dispatch one Explore subagent per slice. Each returns that and nothing else: one line per site the phase must touch, as `<path>:<line> — <what changes there> — <the pattern it follows>`, or exactly `NO SITES` for a slice with none. Build the Step 3 gate from those lines instead of reading the whole surface yourself, and the build from them after it — they must not be rediscovered. A slice answering `NO SITES` for a path the plan's `Files:` names is not an empty result but a plan ambiguity, asked at the gate per *Routing a decision*.

## Step 3: The approval gate (the only planned interruption)

Read the phase's `Pattern:` example first — don't re-explore what planning already recorded.

**Scale the exploration to the phase's `Run:` effort** (missing → `high`): `low` only the listed `Files:`; `medium` + their immediate references; `high` up to 2 read-only Explore subagents and the surrounding package; `xhigh`/`max` up to 3 plus a cross-package consistency pass. Same scale as `/execute-phase-agent` Step 2 — what differs is only that here it ends in a question instead of a decision.

**The gate carries a compatibility line.** Before presenting, read the
pending phases — their `Files:`, `Details:`, and contract tests where the
plan carries them (`contracts.md` → *Contract tests*) — plus the plan's
`Must not break:` header and, when `.phased/roadmap.md` exists, its
remaining macro-phases (`contracts.md` → *Must not break:*): premises of the
same rank. State in ONE line what this phase's approach leaves standing for
them: the data shape a later phase builds on, the file a later `Files:`
names, the behaviour a later test asserts. A conflict found here is a plan
ambiguity: ask it at this gate per *Routing a decision*, before any approval
is asked — approving an approach nobody checked against the plan's own
future is how a phase betrays it.

**Plan ambiguities are settled before the approval**, per `refs/phase-execution.md` → *Routing a decision*: an open question about the plan itself — what the objective means, what `Done:` covers, a `Files:`/`Pattern:` that doesn't match the code. Whoever wrote the plan holds the reasons it is shaped that way, and the user is never made to reconstruct them:

It goes to the foreman first, as `clarify?`, and its answer joins the gate by its form (*Clarify*, in the relay protocol *Routing a decision* reaches): an answer the foreman cites from the plan or `notes.md` is a settled decision, shown in one line; a decision it proposes is put to the user for confirmation in the batch; an `ask-user` joins the batch as a question, and its answer goes back as `clarify: noted`. No foreman reachable → the batch, as a plain question. The answer is recorded in `notes.md` under `## Phase N`.

Present in ONE message: what the phase will do, the files to create/modify/delete with their key changes, and **every open question batched** (anything `Decisions:`/`Details:` leave unsettled). Then ONE AskUserQuestion carrying approval plus those questions.

**`ui` phases — the mockup gate.** Before asking for approval, build a
throwaway **static HTML mockup** of what the phase will produce — look and
layout only, plausible fake data, no framework — and show it rendered
(SendUserFile with `display: render`, or the Browser pane). This gate may
loop: mockup → feedback → mockup, as long as it takes — aesthetics is all
decision, and this is the one interruption that is legitimate by design. A
text description of a UI is never a substitute: the stated purpose of the
tag is judging the *look*. The authored `Verify:` checks stay as planned —
the mockup loop refines the look, never the checklist: a check that no
longer fits is asked here per *Routing a decision*, never edited by the build (`contracts.md` → *Verification*, authored checks are owned by a position). Approval of the phase IS approval of the mockup:
save the approved version as `.phased/active/<slug>/mockups/phase-N.html` —
the phase's visual contract (`contracts.md` → *Verification*), the reference
the build follows and the judge compares against.

**No file may be edited before approval.** After approval, **record the gate**: every answer that settled something goes to `notes.md` under `## Phase N` (a decision the build will read, and the covering decision the close will look for); the mockup is saved. Then go straight on to Step 4: the tree is this chat's, and the record is committed with the phase.

## Step 4: Build the phase here

Implement only this phase, per the shared core (`refs/phase-execution.md` → *Implement*). When a coherent, demonstrable sub-result lands and substantial work remains, checkpoint it (*WIP checkpoints*) — the cost is a `partial` commit the squash will drop, the payoff is that a dying session loses minutes, not the phase. A phase carrying `> Batches:` commits each batch as it lands and **carries straight on** (*Planned batches*): a batch is not a checkpoint.

**The user is in the build**, and that is the point of this mode: what they see as the phase takes shape — the real page, a browser pass, a failed probe — may change their mind, and a new design decision mid-phase is ordinary work, not a failed gate. Take it, record it in `notes.md` under `## Phase N`, go on. If something the plan does not cover comes up and a wrong default would be costly, ask ONE batched question; otherwise take the conservative option and note it. A blocker that is a plan ambiguity takes the gate's road — `clarify?` first, its answer by its form (*Clarify*).

**The stop-loss.** Struggle is itself a routing signal: the second failed attempt at one obstacle, or an exchange with the user that has turned from deciding into diagnosing why the approach does not work, stops the work — checkpoint (*WIP checkpoints*), then send the premise the attempts leaned on as `clarify?` (*assuming X — does it hold?*); never a third attempt, never another diagnostic message here. The answer decides between the two known exits: the premise holds → what remains is a defect, and it leaves this chat (`refs/phase-execution.md` → *Handing a defect to repair*); it was false → the plan is wrong there, and the foreman's answer carries the edit.

**When an answer changes the plan itself** — a phase reshaped, a decision reversed, scope moved — the plan edit gets committed as usual and the foreman chat is told: one `plan changed at phase N` message per the relay protocol the shared core reaches (*Routing a decision*), best-effort. The foreman must not discover a deviation at finalize.

## Step 5: Verify

- Phases with contract tests start from them: copied verbatim and green per the shared core (*Implement*); an edit to their contract only ever arrives as a `clarify?` answer, never taken here.
- Testable logic → write/update tests in the repo's existing style, run the suite. A failure that doesn't touch this phase's `Files:` is probably pre-existing: check before absorbing it, and tell the user instead. Fix and re-run, ONE retry; still red → the stop-loss above.
- Purely UI/declarative → what a browser agent can assert still belongs to the machine: the `ui-test` skill (Skill tool), where installed, drives a real browser (the flow works, the record persists, the grid reloads). Run it, or say why you didn't — and when it is not installed, apply the declared fallback in `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` → *Verification*: those checks go to the human as `Verify: now` steps, said out loud. **Login-gated target → the human performs the login, always** — first establish whether there is one, then hand over (`contracts.md` → *Verification*).
- `ui`-tagged → the browser pass above takes `mockups/phase-N.html` as its reference and must return **screenshots of the key states** (saved next to the mockup). Then ONE `wf:ui-judge` subagent (Agent tool — this plugin's agents register namespaced, and a bare `ui-judge` finds either nothing or an un-namespaced copy installed outside the plugin: the first falls through to the fallback below, the second answers with a prompt this plugin does not ship, and neither says so; fallback: a general-purpose subagent told to stay read-only), given the mockup path, the screenshot paths, and a one-line phase brief naming what the phase built and which states the screenshots cover. Findings: **MECHANICAL** (element missing or plainly wrong vs the mockup) → a correction with no decision open: apply it here, commit as `wf(phase N): partial — <fix>`, re-run the check; **JUDGMENT** (a deviation that may be legitimate, an aesthetic call) → record as `> Review:`, never block. No browser surface available → the judge is skipped too; say so and hand the comparison to the human as a `Verify: now` step with both paths.
- `vast` → optionally re-run the read-only fan-out to confirm no site was missed.

What is left after that — aesthetics, "is this interaction right?", UX ambiguity — is the human's, and only that. Record it as `> Verify:` notes, each with its *when*, **starting from the phase's own authored `Verify:` fields** and adding what the build surfaced, per `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` → *Verification*: `now` steps go in the phase summary, `deferred: needs Phase M` steps are **also appended to `verify.md`** in the plan directory, under a `## Phase N` heading, so `/quality-check` can present them as one QA pass. Never use `Verify:` to offload a check the tests could have made.

## Step 6: Hand over for testing, then close

**A `Verify: now` step left to the human holds the phase open**: commit the work and write the `> Testing:` note (`refs/phase-execution.md` → *Awaiting the human's checks*), present the checks — each with what to do and what should happen — and **stop there**: no `close-phase`, no message, nothing has closed. What the checks turn up is ordinary work on the open phase, on three roads: a correction with no decision open (a label, a default, a wrong term) → apply it, `partial` commit, present again; a defect that reproduces → `/repair-phase` here (`refs/phase-execution.md` → *Handing a defect to repair*), which hands the phase back `[>]` with `> Repaired:` and this gate resumes; the result wrong at the root → not this phase's to repair and never `[!]`: the shared core's third exit applies (`common.md` → *Failure and repair notes*), and the re-planning is the foreman's. The user's ok runs the close; a new chat resuming here gets the same gate back from `next-phase.py`, as `blocked:` (Step 1). **Nothing left for the human** — the suite covered it — closes straight away, but **never before Step 5's browser pass**: on a phase that touches a page, it has run or its skip was said out loud with the reason, before `close-phase` is proposed.

A phase that reached its `Done:` closes through the `close-phase` skill (Skill tool) — naming review, the Done gate re-run, the `[x]` record with the Step 5 `> Verify:` notes, the ONE phase commit, the foreman's message — handed the outcome material (touched files, `> Review:`/`> Verify:` notes); its closing line names the next step, and beside it goes what it does not carry — what was done, test results, the manual checks left to the user; a phase ending `[!]` or `[~]` never routes through it — record and commit it here per the shared core, and send the outcome message (*Notify the foreman*), best-effort.

## Handing over

A long phase outlives its chat. **Ask first whether it has a seam** (`refs/phase-execution.md` → *When the phase outgrows its chat or its executor*): a coherent green sub-result **closes short** — the phase ends properly and the foreman grows a phase for the remainder — while work in mid-air hands over. The handover is also a move the user can call at any time — *"pass the baton"*, no reason needed — and one to offer when the context is filling: *"⚠️ The context is filling up. Close this phase on what is done, or hand over to a new chat?"*

Handing over is three things, in order: **checkpoint** (*WIP checkpoints* — `partial` commit and `> WIP:` note together); **write down what four keys cannot hold** — decisions taken and why, roads tried that do not work — into `notes.md` under `## Phase N`, committed with the checkpoint; **stop**, and say to open a new chat on `/wf:execute-phase`. From here the working tree belongs to whoever picks the phase up; answering the arriving chat's handover message is the last thing this chat does.

## Rules

- NEVER edit before the Step 3 approval; the `vast` fan-out never bypasses it
- ONE phase per invocation; no out-of-scope refactoring
- ONE phase commit per phase, at the close — checkpoints and planned batches (shared core) are `partial` commits, not phase commits
- This chat builds and does not supervise — no `/resume-workflow`, no re-planning of other phases here; those are the foreman's
- If this session dies with the plan still writable and NO checkpoint exists, reset `[>]` to `[ ]` with `> Execution interrupted, phase available for retry` — and commit that reset as `wf: reset phase N` (the plan is tracked). With a checkpoint, leave `[>]` and its `> WIP:` note in place: they are the resume brief
