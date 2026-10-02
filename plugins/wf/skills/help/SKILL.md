---
description: The map of the wf commands — where the work stands decides which command comes next, plus one line per command. Pure orientation, reads no state, changes nothing.
disable-model-invocation: true
allowed-tools: Read
---

# Help — the map of the plugin

A router, not a manual: from where the user says they are, name the command
that takes the work forward. This skill reads no state and runs nothing — the
state of a real workflow is `/wf:resume-workflow`'s to report — in the
foreman chat or a fresh one. Answer in the user's language,
adapted to what they asked; the routes and the table below are the canon of
what to say, not a page to paste.

## Where are you?

- **No workflow yet — an idea, an issue, a discussion.** Talk the work
  through in a chat, then `/wf:write-workflow` turns the conversation into a
  branch, a plan and its first commit. Decisions still open →
  `/wf:scope-workflow` first, one question at a time. Starting from a GitHub
  issue → `/wf:issue` for the analysis. A plan or handoff that already
  exists → `/wf:import-workflow`.
- **A plan exists, building it with you inside (`Mode: manual`).**
  `/wf:execute-phase` in the worker — one chat for every phase, cleared between
  them by the ▶ button of `wf-bar`, which also sets the phase's model and
  effort (without it: `/clear` and the model menu): one approval gate up front
  (a rendered mockup on `ui` phases), then the build right there, with you
  changing your mind, studying and trying it in the browser as it takes shape;
  plan questions go to the foreman first, and you answer only what it does not
  know. The phase closes through `/wf:close-phase` on your ok, and the foreman
  is told.
- **A plan exists, run it unattended.** `/wf:run-workflow` from the foreman
  chat: one sub-session per phase, one automatic repair on failure, stop
  conditions. The `-agent` variants (`/wf:execute-phase-agent`,
  `/wf:repair-phase-agent`, `/wf:quality-check-agent`) are its workers.
- **Something is demonstrably broken** — a red `Done:`, a defect that
  reproduces → `/wf:repair-phase`, here: you say what is wrong, a repair
  agent diagnoses and fixes it in a context of its own, you decide when it
  is fixed.
- **The work is done but it was the wrong thing** — everything green, result
  rejected: the phase closes `[x]` carrying the verdict, and the phases that
  have not run are re-planned: the foreman chat is told and
  `/wf:resume-workflow` runs there or in a fresh one.
- **Lost, or resuming after days** — `/wf:resume-workflow`: it needs the
  branch, nothing else, and it names the next command — in the foreman chat
  or a fresh one: the disk holds the whole state.
- **The phases feel incompatible with each other** — or the plan predates
  contract tests and you want the verdict instead of the suspicion →
  `/wf:doctor`: coherence audit, contract-test integrity, and a blind
  retro-fit of the missing tests, verified phase by phase.
- **Every phase is `[x]`** — `/wf:quality-check` first: the QA pass of the
  deferred human checks, the naming review, the whole-diff review at the
  depth you choose — it stamps the plan. Then `/wf:finalize-workflow`:
  lessons, archive, one consolidated commit on the parent — then PR, merge,
  or leave it.

## The commands, one line each

| Command | What it does |
|---|---|
| `/wf:scope-workflow` | settle the open decisions before the plan exists, one question at a time |
| `/wf:issue` | load and analyze a GitHub issue — analysis only |
| `/wf:write-workflow` | turn the conversation into branch + plan + first commit |
| `/wf:import-workflow` | adopt an existing plan or handoff document into `.phased/` |
| `/wf:execute-phase` | execute the next phase — the gate here, the build in a fresh executor, the verdict here |
| `/wf:close-phase` | close a finished phase: naming review, Done gate, `[x]`, one phase commit |
| `/wf:repair-phase` | fresh-eyes repair in an agent of its own; you say what is wrong and when it is fixed |
| `/wf:run-workflow` | run all remaining phases unattended, one sub-session per phase |
| `/wf:execute-phase-agent` | one phase, unattended — the executor of both modes |
| `/wf:repair-phase-agent` | repair the first `[!]` phase, unattended |
| `/wf:resume-workflow` | where the work stands, and which command takes it forward |
| `/wf:doctor` | is the work still coherent with the plan — audit, test integrity, blind retro-fit |
| `/wf:quality-check` | QA pass, naming review, whole-diff review — stamps the plan |
| `/wf:quality-check-agent` | the read-only quality verification, in a clean sub-session |
| `/wf:finalize-workflow` | quality gate, lessons, archive, consolidate into one commit |
| `/wf:pull-request` | open the PR after a maintainer-grade review |
| `/wf:help` | this map |

Close with one line: the full narrative is the plugin's README; for the state
of an actual workflow, `/wf:resume-workflow` — in the foreman chat or a fresh one.
