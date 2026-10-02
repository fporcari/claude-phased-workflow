---
description: Execute the next phase from the active work plan — on a manual plan built here with you in it, on an assisted plan built by a fresh-context executor after the gate and handed back here
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Agent, AskUserQuestion, Skill, SendMessage, ListAgents, SendUserFile, ToolSearch, mcp__ccd_session_mgmt__set_session_title, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions, mcp__ccd_session_mgmt__get_session
---

# Execute Phase

Execute the next uncompleted phase. **This is the heart of the attended modes**, not a lesser `/run-workflow`: ONE approval gate up front (plan + all questions batched), then the build — and the plan's `Mode:` says where the build happens (`${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` → *Where decisions travel*):

- **`Mode: manual`** — and `interactive`, and a plan carrying no `Mode:` — **the build happens here, in this chat, with the user in it.** This conversation is the phase's, one per phase — a new chat, or the previous phase's chat once `/close-phase` has cleared it; a change of mind, a study, a browser pass that reshapes the design are ordinary work here, not a failed gate. A plan ambiguity goes UP first, as `clarify?` to the foreman (`refs/phase-execution.md` → *Routing a decision*, the manual column). Steps 1–3, then *Manual — Steps 4–6*.
- **`Mode: assisted`** — **the build runs in an executor**, a subagent with a fresh context that reads the plan and nothing else, and comes back here for the human's checks and the close. This conversation carries the whole workflow, gate after gate; the code of a phase never enters it. A plan ambiguity is answered **at the gate, here** (the assisted column). Steps 1–3, then Steps 4–6.

Two kinds of interruption, and only one is legitimate: a question that needs a **decision** — ask it, take the answer, go on. Asking the user to **try something trivial** mid-phase is not a question, it is the symptom of a phase that was cut too small; the cure is sizing, and manual checks belong in `Verify:` at the end. An executor cannot ask at all: a doubt the gate did not settle comes back as `blocked`, to this same gate. Execution stays on a strong model — `opus` floor; `sonnet` is not in this plugin's palette.

**The phase's `Run: <model> / <effort>` line** is the plan's advice, decided during planning. The effort governs how wide *this* chat looks before the gate — the scale is in Step 3. On `manual` both values are this session's, chosen when it opened: read them, do not reconsider them. On `assisted` the model goes to the executor's launch. Missing line → treat as `opus` / `high`.

- **`fable`** means the phase kept inventive work of its own. Read this file as a contract on the *output* — the approval gate, one phase, one commit, the outcome format — not as a procedure to walk step by step, since a prescriptive step list is exactly what degrades that model. The settled `Decisions:` are input, not something to re-derive.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md`, `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` once at start — core conventions and the contract layer (Done:/Verify:, contract tests). The relay layer is not read at start: on `manual` the road and the protocol behind it are reached through the shared core's *Routing a decision* when a decision has to travel; on `assisted` it is never read — an assisted workflow has no foreman and sends no message. **Shared mechanics:** `${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md` — selection, implementation discipline, the outcome formats, the hand-back, the phase commit; `/execute-phase-agent` is the executor an assisted plan launches, and the same skill `/run-workflow` launches headless.

## Step 1: Find the plan and the phase

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
```

No active plan → stop and say so: `/write-workflow` creates one, `/import-workflow` adapts an older one. The plan lives on the workflow branch, so being on the wrong branch is the usual reason it is missing — check `git branch --show-current` before concluding there is no work. If the plan lives in another checkout (or the user means a different workflow), resolve via `--plans` and anchor every command to that plan's root — `common.md` → *Plan location*.

**Title this chat** before acting on the recommendation, with `set_session_title` on `session_id: "self"` — every road out of it runs in this chat, the awaiting-checks gate included. On `manual`, `wf:<slug>:phase-N — <phase title>`: a resuming chat finds the phase's chat by it (`refs/phase-execution.md` → *Resuming a `[>]` phase*). On `assisted`, `wf:<slug>`, once: one conversation carries the whole workflow, so a per-phase title would rename the same session at every phase. Best-effort: no tool, no title, no consequence.

**On `manual`, check this chat against the `Run:` line** before taking `next: N` or a resume: `get_session` on `session_id: "self"` gives the chat's `model` and `effort`. A model id that does not name the `Run:` model, or another effort → ONE `AskUserQuestion` before the phase is marked: *switch from the model menu and relaunch `/execute-phase` here* (Recommended) or *proceed on <model> / <effort>*. The switch is the user's: `set_session_model` refuses `self`, a session never re-prices its own turns. A chat cleared after the previous phase keeps that phase's model, which is why this check exists. No tool → skip, nothing asked.

Act on `recommendation:` — `next: N` → proceed to the gate (on `manual`, mark the phase `[>]` with `> In execution since <ISO timestamp>` first); `resume-candidate: N` → a `[>]` phase another session left with a `> WIP:` note: ask whether to resume it — on yes, skip the gate (it was passed): on `manual`, look for the chat that had it and take the phase over here (`refs/phase-execution.md` → *Resuming a `[>]` phase*); on `assisted`, go to Step 4 with a resume brief; a `[>]` with no `> WIP:` note, no `partial` commit and nobody alive on it is a dead session: reset it per the Rules and take it as `next`; `attention: ...` → surface the `[!]`/`[~]` phases, they block what follows — `/repair-phase` here for a `[!]`; `done` → suggest `/quality-check`, then `/finalize-workflow`; `blocked: ...` → report and stop — except a `blocked:` naming a phase that awaits the human's checks, which is this skill's own gate coming back: on `assisted` go straight to Step 5, on `manual` to *Manual — Step 6* (`refs/phase-execution.md` → *Awaiting the human's checks*).

## Step 2: `vast` phases only — read-only fan-out

Skip unless the phase is tagged `vast`. Partition its `Files:` list — or, where the phase carries a discovery rule instead of a file list, run that rule and partition what it returns — into **at most 4 slices**, and dispatch one Explore subagent per slice. Each returns that and nothing else: one line per site the phase must touch, as `<path>:<line> — <what changes there> — <the pattern it follows>`, or exactly `NO SITES` for a slice with none. Build the Step 3 gate from those lines instead of reading the whole surface yourself; on `assisted` hand them to the executor in its brief — it must not rediscover them. A slice answering `NO SITES` for a path the plan's `Files:` names is not an empty result but a plan ambiguity, asked at the gate per *Routing a decision*.

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

- **On `manual`** it goes to the foreman first, as `clarify?`, and its answer joins the gate by its form (*Clarify*, in the relay protocol *Routing a decision* reaches): an answer the foreman cites from the plan or `notes.md` is a settled decision, shown in one line; a decision it proposes is put to the user for confirmation in the batch; an `ask-user` joins the batch as a question, and its answer goes back as `clarify: noted`. No foreman reachable → the batch, as a plain question.
- **On `assisted`** it is answered here: this conversation wrote the plan, so it **proposes the answer with those reasons** and the user confirms or corrects it — a bare question makes the user reconstruct what the author already knows. **Everything the executor could stumble on is settled now**: it cannot ask, so a question left open here is a `blocked` outcome later, paid in a wasted executor.

Either way the answer is recorded in `notes.md` under `## Phase N`.

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
longer fits is asked here per *Routing a decision*, never edited on the
executor's side (`contracts.md` → *Verification*, authored checks are owned by a position). Approval of the phase IS approval of the mockup:
save the approved version as `.phased/active/<slug>/mockups/phase-N.html` —
the phase's visual contract (`contracts.md` → *Verification*), the reference
the build follows and the judge compares against.

**No file may be edited before approval.** After approval, **record the gate**: every answer that settled something goes to `notes.md` under `## Phase N` (a decision the build will read, and the covering decision the close will look for); the mockup is saved. On `manual` go straight on to *Manual — Step 4*: the tree is this chat's, and the record is committed with the phase. On `assisted`, when anything was written, commit it alone — `wf(phase N): partial — gate` — so the executor starts from a clean tree, its own precondition. Nothing written → nothing committed.

## Manual — Step 4: Build the phase here

Implement only this phase, per the shared core (`refs/phase-execution.md` → *Implement*). When a coherent, demonstrable sub-result lands and substantial work remains, checkpoint it (*WIP checkpoints*) — the cost is a `partial` commit the squash will drop, the payoff is that a dying session loses minutes, not the phase. A phase carrying `> Batches:` commits each batch as it lands and **carries straight on** (*Planned batches*): a batch is not a checkpoint.

**The user is in the build**, and that is the point of this mode: what they see as the phase takes shape — the real page, a browser pass, a failed probe — may change their mind, and a new design decision mid-phase is ordinary work, not a failed gate. Take it, record it in `notes.md` under `## Phase N`, go on. If something the plan does not cover comes up and a wrong default would be costly, ask ONE batched question; otherwise take the conservative option and note it. A blocker that is a plan ambiguity takes the gate's road — `clarify?` first, its answer by its form (*Clarify*).

**The stop-loss.** Struggle is itself a routing signal: the second failed attempt at one obstacle, or an exchange with the user that has turned from deciding into diagnosing why the approach does not work, stops the work — checkpoint (*WIP checkpoints*), then send the premise the attempts leaned on as `clarify?` (*assuming X — does it hold?*); never a third attempt, never another diagnostic message here. The answer decides between the two known exits: the premise holds → what remains is a defect, and it leaves this chat (`refs/phase-execution.md` → *Handing a defect to repair*); it was false → the plan is wrong there, and the foreman's answer carries the edit.

**When an answer changes the plan itself** — a phase reshaped, a decision reversed, scope moved — the plan edit gets committed as usual and the foreman chat is told: one `plan changed at phase N` message per the relay protocol the shared core reaches (*Routing a decision*), best-effort. The foreman must not discover a deviation at finalize.

## Manual — Step 5: Verify

- Phases with contract tests start from them: copied verbatim and green per the shared core (*Implement*); an edit to their contract only ever arrives as a `clarify?` answer, never taken here.
- Testable logic → write/update tests in the repo's existing style, run the suite. A failure that doesn't touch this phase's `Files:` is probably pre-existing: check before absorbing it, and tell the user instead. Fix and re-run, ONE retry; still red → the stop-loss above.
- Purely UI/declarative, and `ui`-tagged, and `vast` → the same passes as Step 5 below, run here: the `ui-test` browser pass (or its declared fallback), the screenshots against the mockup and ONE `wf:ui-judge`, the optional fan-out re-run. **Login-gated target → the human performs the login, always.**

What is left after that is the human's, and only that: record it as `> Verify:` notes exactly as Step 5 below says, authored `Verify:` fields first, `deferred` steps appended to `verify.md`.

## Manual — Step 6: Hand over for testing, then close

**A `Verify: now` step left to the human holds the phase open**: commit the work and write the `> Testing:` note (`refs/phase-execution.md` → *Awaiting the human's checks*), present the checks — each with what to do and what should happen — and **stop there**: no `close-phase`, no message, nothing has closed. What the checks turn up is ordinary work on the open phase, on the three roads of Step 6 below: a correction → apply it, `partial` commit, present again; a defect that reproduces → `/repair-phase` here; the result wrong at the root → the shared core's third exit, and the re-planning is the foreman's. The user's ok runs the close. **Nothing left for the human** closes straight away — never before the browser pass, on a phase that touches a page.

A phase that reached its `Done:` closes through the `close-phase` skill (Skill tool), which also sends the foreman its message; a phase ending `[!]` or `[~]` never routes through it — record and commit it here per the shared core, and send the outcome message (*Notify the foreman*), best-effort.

## Manual — Handing over

A long phase outlives its chat. **Ask first whether it has a seam** (`refs/phase-execution.md` → *When the phase outgrows its chat or its executor*): a coherent green sub-result **closes short** — the phase ends properly and the foreman grows a phase for the remainder — while work in mid-air hands over. The handover is also a move the user can call at any time — *"pass the baton"*, no reason needed — and one to offer when the context is filling: *"⚠️ The context is filling up. Close this phase on what is done, or hand over to a new chat?"*

Handing over is three things, in order: **checkpoint** (*WIP checkpoints* — `partial` commit and `> WIP:` note together); **write down what four keys cannot hold** — decisions taken and why, roads tried that do not work — into `notes.md` under `## Phase N`, committed with the checkpoint; **stop**, and say to open a new chat on `/wf:execute-phase`. From here the working tree belongs to whoever picks the phase up; answering the arriving chat's handover message is the last thing this chat does.

## Step 4: Launch the executor (assisted)

ONE executor per launch, through the Agent tool — `subagent_type: general-purpose`, `model` from the phase's `Run:` line (`opus` or `fable`; the effort cannot travel, the executor runs at this session's) — with this brief and nothing else:

- The plan root (absolute path) and the plugin root (`${CLAUDE_PLUGIN_ROOT}`, expanded to its absolute path).
- *"Phase N of the active plan is yours. Invoke the skill `wf:execute-phase-agent` (Skill tool) and follow it; if the Skill tool is unavailable, read `<plugin root>/skills/execute-phase-agent/SKILL.md` and follow it with `${CLAUDE_PLUGIN_ROOT}` = `<plugin root>`. You were launched from `/execute-phase`: its section *Launched from the workflow chat* applies — the gate is passed, nobody can answer a question, hand the phase back with a `> Testing:` note and close nothing."*
- On a `vast` phase, the Step 2 site lines. On a resume, one line: *resume Phase N from its `> WIP:` note.*

**Nothing else travels.** The decisions are in `notes.md`, the mockup is under `mockups/`, the plan says the rest — a brief that restates them is a second copy that drifts. **Never edit source files here**, before or during the launch: the tree belongs to the executor from this moment until it returns.

**When it returns, read the plan, not the prose.** The executor's closing message is a summary of itself; the truth is the plan file and `git log`:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
git log --oneline -5
```

- **`blocked:` — the phase is complete and awaiting the human's checks** → the normal hand-back: Step 5.
- **`[!]`**, no `plan-defect claim` in its `> Issue:` → the executor exhausted its attempts and committed the failing code as `wf(phase N): FAILED`. Report the `> Issue:` and `> Attempted:` in the reporting register, then offer `/repair-phase` — here, in this conversation (`refs/phase-execution.md` → *Handing a defect to repair*).
- **`[!]` whose `> Issue:` carries `plan-defect claim`** → a question for the plan's author, and the author is this conversation: it is answered here BEFORE any repair, which would judge the premise without the reasons behind it. Check the claim against the code it cites — read the files and lines, confirm or refute the premise — then put ONE AskUserQuestion with your verdict and the plan's reasons: *Apply the declared edit* (recommended when the check confirmed the claim and the `> Issue:` carries the edit as before-text → after-text) / *Authorize repair* (recommended when the premise holds: what remains is a defect) / *Re-plan at this gate* (the premise is wrong beyond one edit — *Routing a decision*, the re-planning row). On *Apply*: apply exactly that edit to the plan, and to both contract copies byte-identical when it names a contract test — never a source file — record it in `notes.md` under `## Phase N`, re-run the phase's `Done:`. Green → the phase goes back `[>]` with its `> Testing:` note, `> Applied:` added and `> Issue:` kept, committed as `wf: plan defect phase N — applied — <one line>`, and Step 5 follows; red → commit the edit alone and offer `/repair-phase` on the corrected plan.
- **`[~]`** → a red baseline nobody owns, or a dirty tree. Report the `> Blocked:` note and stop: the human clears it.
- **`[>]` with a `> WIP:` note** → the executor ran out of context and checkpointed (`refs/phase-execution.md` → *WIP checkpoints*). Ask the seam question (*When the phase outgrows its chat or its executor*): close short, or relaunch ONE fresh executor with the resume brief. A second overrun on the same phase is never relaunched: the phase was sized wrong, and the answer is the short close or a re-planning at this gate.
- **`[>]` with nothing** — no `> WIP:`, no `partial` commit, the executor died → reset per the Rules and say so; the gate stands, relaunch on the user's ok.
- **A `blocked` the executor reported on a question** — a plan ambiguity the gate did not settle → answer it now as the gate does, a proposal with the plan's reasons for the user to confirm, record the answer in `notes.md`, commit, relaunch. Count it as the gate's miss, not the executor's.

## Step 5: The hand-back — what only this chat can do (assisted)

The executor ran the tests, the lint, the `Done:` gate criterion by criterion, and the verifier where the plan calls for one; it left the `wf:phase-N:new` markers in place and wrote the thin `> Verify:` pass (`contracts.md` → *Verification*). What remains is what needs a human, or a surface the executor does not have:

- Read the diff since the gate (`git diff <gate or previous phase commit>..HEAD`) — this is the moment this chat sees the code, once, as a reviewer.
- Purely UI/declarative → what a browser agent can assert still belongs to the machine: the `ui-test` skill (Skill tool), where installed, drives a real browser (the flow works, the record persists, the grid reloads). Run it, or say why you didn't — and when it is not installed, apply the declared fallback in `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` → *Verification*: those checks go to the human as `Verify: now` steps, said out loud. **Login-gated target → the human performs the login, always** — first establish whether there is one, then hand over (`contracts.md` → *Verification*).
- `ui`-tagged → the browser pass above takes `mockups/phase-N.html` as its reference and must return **screenshots of the key states** (saved next to the mockup). Then ONE `wf:ui-judge` subagent (Agent tool — this plugin's agents register namespaced, and a bare `ui-judge` finds either nothing or an un-namespaced copy installed outside the plugin: the first falls through to the fallback below, the second answers with a prompt this plugin does not ship, and neither says so; fallback: a general-purpose subagent told to stay read-only), given the mockup path, the screenshot paths, and a one-line phase brief naming what the phase built and which states the screenshots cover. Findings: **MECHANICAL** (element missing or plainly wrong vs the mockup) → a correction with no decision open: apply it here, commit as `wf(phase N): partial — <fix>`, re-run the check; **JUDGMENT** (a deviation that may be legitimate, an aesthetic call) → record as `> Review:`, never block. No browser surface available → the judge is skipped too; say so and hand the comparison to the human as a `Verify: now` step with both paths.
- `vast` → optionally re-run the read-only fan-out to confirm no site was missed.

What is left after that — aesthetics, "is this interaction right?", UX ambiguity — is the human's, and only that. Record it as `> Verify:` notes, each with its *when*, **starting from the phase's own authored `Verify:` fields** and adding what the build surfaced, per `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` → *Verification*: `now` steps go in the phase summary, `deferred: needs Phase M` steps are **also appended to `verify.md`** in the plan directory, under a `## Phase N` heading, so `/quality-check` can present them as one QA pass. Never use `Verify:` to offload a check the tests could have made.

## Step 6: The human's checks, then close (assisted)

**A `Verify: now` step left to the human holds the phase open.** Step 5's split already decided this: what an agent could assert, an agent asserted; what remains is what only you can judge. Closing before you have judged it books a result nobody has looked at — and on a `ui` phase whose browser pass could not run, that is the whole result. So, when at least one `now` check is yours:

1. The executor already committed the work and wrote the `> Testing:` note (`refs/phase-execution.md` → *Awaiting the human's checks*). The phase stays `[>]`.
2. Present what landed — in the reporting register — and the checks, each with what to do and what should happen, and **stop there**. No `close-phase`: nothing has closed.
3. What the checks turn up is ordinary work on the open phase, on three roads: a correction with no decision open (a label, a default, a wrong term) → apply it here, `partial` commit, present again; a defect that reproduces → `/repair-phase` here (`refs/phase-execution.md` → *Handing a defect to repair*), which hands the phase back `[>]` with `> Repaired:` and this gate resumes; the result wrong at the root → not this phase's to repair and never `[!]`: the shared core's third exit applies (`common.md` → *Failure and repair notes*), and the re-planning happens with you, here.
4. The user's ok is the trigger for the close below. A new chat resuming here gets the same gate back from `next-phase.py`, as `blocked:` (Step 1).

**Nothing left for the human** — the suite covered it — closes straight away, but **never before Step 5's browser pass**: on a phase that touches a page, it has run or its skip was said out loud with the reason, before `close-phase` is proposed. The executor's green is not that pass — it never had a browser — and the field saw it skipped on exactly that reading, with the one defect the pass then found shipped inside the "done".

A phase that reached its `Done:` closes through the `close-phase` skill (Skill tool): naming review of the methods this phase marked (`contracts.md` → *New-method markers and minimality* — accept-all is one keypress), the Done gate re-run, the `[x]` record with the Step 5 `> Verify:` notes, the ONE phase commit and the desktop notification — all per the shared cores it cites. Hand it the outcome material (touched files, `> Review:`/`> Verify:` notes); do not restate its mechanics here. Its closing line names the next step; add beside it what it does not carry — what was done, test results, the manual checks left to the user.

A phase ending `[!]` or `[~]` was recorded and committed by the executor, exactly as the shared core (`refs/phase-execution.md`) specifies; here it is reported, never rewritten.

## This conversation does not fill up (assisted)

Each phase costs this chat a gate, a diff read once, and a verdict; the build lives and dies in the executor. So the baton is rarely needed — and when the context does run low after many phases, there is nothing to write down first: every gate is committed before its executor starts and every executor commits before it returns, so the disk already holds the whole state. Say so, and name the move: open a new chat, `/resume-workflow` there, `/execute-phase` again. The arriving chat finds the plan exactly where this one left it.

## Rules

- NEVER edit before the Step 3 approval; the `vast` fan-out never bypasses it
- ONE phase per invocation; no out-of-scope refactoring
- ONE phase commit per phase, at the close — the gate commit, checkpoints and planned batches (shared core) are `partial` commits, not phase commits
- On `manual`: this chat builds and does not supervise — no `/resume-workflow`, no re-planning of other phases here; those are the foreman's
- On `assisted`: NEVER build the phase here: the executor builds, this chat decides, reads once and closes — a fix applied here is a correction with no decision open, never the phase's work. After approval, no further questions until the hand-back — the executor cannot ask, and a question it needed is the gate's miss. Read the plan after the executor returns, never its summary: the plan and `git log` are the record
- If the session building the phase dies with the plan still writable and NO checkpoint exists, reset `[>]` to `[ ]` with `> Execution interrupted, phase available for retry` — and commit that reset as `wf: reset phase N` (the plan is tracked). With a checkpoint, leave `[>]` and its `> WIP:` note in place: they are the resume brief
