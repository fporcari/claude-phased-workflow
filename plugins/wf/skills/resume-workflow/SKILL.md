---
description: Locate the active phased workflow and report where it stands, then name the skill that takes it forward. The entry point of the phased-workflow plugin, and the only skill in it the agent may reach on its own. Use when the user asks where the work stands, what the next phase is, whether a workflow is running, why a phase is stuck or failed, how to resume after an interrupted session, or mentions `.phased/` or a `wf/` branch.
allowed-tools: Bash(git:*), Bash(python3:*), Read, Edit, Write, Grep, Glob, AskUserQuestion, SendMessage, ListAgents, mcp__visualize__read_me, mcp__visualize__show_widget, mcp__ccd_session_mgmt__set_session_title, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions
---

# Resume Workflow

Supervision and resume view of the work plan. **Read-only on source code** — the only files this command may modify are the plan, `notes.md` and `foreman.json`; plan and notes only on an approved edit; each edit gets its own `wf:` commit.

A healthy workflow is a valid reason to run this: when nothing is broken it early-exits with the state report and nothing to resume.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start, and `${CLAUDE_PLUGIN_ROOT}/refs/foreman.md` at Step 1b, only once the plan's `Channel:` is known to be `relayed` or absent — an `in-chat` workflow has no relay to take command of and never reads it.

## The map

Every other skill in this plugin is **user-invoked**: only the user typing its name reaches it. Naming the right one is part of this skill's job — in Step 3's *Next step*, and whenever the user asks what to run.

| Skill | Reach for it when |
|---|---|
| `/scope-workflow` | the work is still vague — settle the decisions before planning |
| `/write-workflow` | there is no plan yet, and the work was just discussed |
| `/import-workflow` | a plan or handoff document already exists outside `.phased/` |
| `/issue` | the work starts from a GitHub issue (analysis only) |
| `/execute-phase` | run the next phase with an approval gate — in a new chat on `Channel: relayed` and on a legacy plan, in this same conversation on `Channel: in-chat` |
| `/run-workflow` | run every remaining phase unattended (`Mode: autonomous` plans) |
| `/repair-phase` | a phase is `[!]` and needs fresh eyes |
| `/doctor` | the work and the plan may have drifted apart — coherence audit, contract-test integrity, blind retro-fit of missing tests |
| `/quality-check` | every phase is `[x]` — QA pass, naming review, whole-diff review; stamps the plan |
| `/finalize-workflow` | quality check stamped — lessons, archive, consolidate into one commit |
| `/pull-request` | the branch is ready to open a PR |

## Step 1: Find the plan and the base

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
git log -1 --diff-filter=A --format=%H -- <plan path>
```

No active plan → stop: `/write-workflow` creates one, `/import-workflow` adapts an older one. Since the plan lives on the workflow branch, check `git branch --show-current` before concluding there is no work — and check `--plans` first: the workflow may live in another checkout or on a branch with no checkout at all (`common.md` → *Plan location*); anchor every command to the plan's root with `git -C`.

The third command gives `BASE`, the commit that added the plan. Everything after it is this workflow; everything before it is not — on an adopted branch that distinction is the whole point.

## Step 1b: The foreman

On `Channel: in-chat` there is no relay and nothing to take command of: the
plan's decisions belong to the user in this conversation, so skip to Step 2 and
report the channel instead of a foreman. Everything below is the relayed
channel, which is also every plan carrying no `Channel:`.

On the relayed road, read `.phased/active/<slug>/foreman.json` (protocol, file
format and take-command mechanics live once in `foreman.md` → *The foreman*):

- **Absent** → **assume command, without asking**: the normal state of every
  workflow that predates the protocol, and a workflow being resumed wants a
  foreman. Take command per `foreman.md` — write the file, ONE `wf: foreman —
  takes command` commit, title this chat.
- **Present, and no other session bears the title** (`list_sessions`) → the
  title is unclaimed: either it is this very chat (fine) or the old foreman
  is dead or renamed. Either way, claim it — same take-command step, which is
  **idempotent by content** (`foreman.md`): the file already carries this
  exact title, so nothing is rewritten and no commit is made; at most, the
  chat re-applies the title to itself — the call returns the one it
  replaced, which is also how a chat learns it had drifted off it.
- **Present, another session bears the title** → do not depose on a status
  query. Report it (Step 3 gets a *Foreman* line: who, since when).
  Offer the takeover through the Step 3 AskUserQuestion only when something
  actually needs action here, or the user says they want this chat in
  charge. On yes: depose per `foreman.md` — best-effort farewell message and
  retitle of the old session — then take command (its own commit). The old
  chat may be long dead; nothing in this step is allowed to block on it.

## Step 2: Attribute the work

Each completed phase committed its own work, so attribution is **exact — never infer it**:

```bash
git log --oneline "$BASE"..HEAD
git show --stat <phase commit>
```

For each `[x]` phase, compare its commit's files against its own `> Files:` note. For each pending phase, there is simply no commit yet.

Then look at `git status --short`. **A clean tree is the normal state.** Uncommitted changes are legitimate only while a phase is `[>]` — anything else is a finding, not context: a session that died before committing, or hand edits nobody recorded.

Two distinct kinds of drift, and they mean different things:

1. **Unlisted files** — inside a phase's commit but absent from its `> Files:`. The work landed but the record is wrong, which silently breaks later baseline attribution and `/repair-phase`.
2. **Uncommitted leftovers** — in the tree, in no commit, with no `[>]` phase to explain them.

Flag a phase as **oversized** when its commit spans more than ~10 files, covers unrelated areas (model + UI + tests for different features), or is too large to review as one commit. On a phase carrying `> Batches:` the same judgment applies to each **batch** — its `partial` commit — not to the phase total: batches exist so a large phase stays reviewable, so an oversized *batch* is the finding, and a fat phase made of readable batches is not one. **Exception:** a `vast` phase is intentionally whole — that size is by design, never propose re-phasing it for size alone. For a pending phase the same judgment is a projection from its `Files:`, not a measurement; say which one you are making.

## Step 3: Report

1. **Plan state** — every phase with its marker. For `[>]`, show the timestamp and flag anything older than 2h: *"running for over 2 hours — the previous chat may have ended"* — unless it carries a `> Testing:` note, which means it is not running at all but waiting for the user's own checks (`contracts.md` → *Verification*): report those, and that the phase closes when they pass. A stale `[>]` with a run log at `<transport>-run.log` (`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --transport` names the prefix — uid and repo key included, so it is this checkout's log and not another's) is more than a dead chat: an **unattended run was in flight when everything died** — a host-app restart kills the launcher, its Monitor and the phase session in one blow, and that log is the only channel that survives. Check for it (`T=$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --transport); [ -f "$T-run.log" ] && echo "$T-run.log" || echo "no run log"`); when it exists, say exactly that, read its last `EVENT:` lines to report how far the run got, and make the *Next step* the **reset + relaunch** path: Step 4's stale-`[>]` reset, then a fresh `/run-workflow` over what remains. A `[!]` phase carrying `> Repair started:` is **under repair**, not available: report it as such, with the marker's timestamp and the chat named in it, and do not offer `/repair-phase` on it — a second repair would put two chats in one working tree. Judge staleness rather than applying a threshold: a marker whose chat is nowhere in `list_sessions`, or one old enough that the run it names is plainly over, says the repair died and can be taken up again — say which of the two you are reporting. One **Channel** line closes the point. On `Channel: in-chat`: the channel, and that the work continues in this conversation — there is no foreman to name and no messaging branch to test. On `Channel: relayed` and on a legacy plan it is the **Foreman** line as before: who commands (this chat, another session with its `since`, or just assumed per Step 1b) — and which messaging branch is alive in this installation (desktop session tools, CLI `SendMessage`, or neither), per `foreman.md` → *Channel floors*: a dead channel is declared here, not discovered at the first silent skip.
2. **Workflow commits** — `git log --oneline $BASE..HEAD`, one line per phase, with the files each touched.
3. **Coverage** — per `[x]` phase: does its commit match its `> Files:`? Per pending phase: still to do.
4. **Drift** — the two kinds above, kept apart.
5. **Oversized phases** — for each, what its commit already contains, what remains, and a proposed split into sub-phases.
6. **Next step** — continue (`/execute-phase` or `/run-workflow`), repair (`/repair-phase` on a `[!]`), re-phase, add phases for work that surfaced (Step 4 — the answer when a phase passed and is still wrong), finalize, clean up drift — or, when what smells is incoherence between the landed work and the pending phases' premises rather than record drift, `/doctor` for the verdict instead of the suspicion. When it is `/execute-phase`, quote the next phase's `Run: <model> / <effort>` hint alongside it (older plan without one → `opus` / `high`): both are chosen when that chat is opened, so the hint is only useful before it is.

**The board.** On a `Mode: interactive` plan, render points 1 and 6 as the strip specified in `${CLAUDE_PLUGIN_ROOT}/refs/board.md` — read it there rather than inferring the shape; it is the single source, shared with `/write-workflow`. Points 3, 4 and 5 stay prose in the reply: they are judgments, and a strip argues badly. On an autonomous plan, no board at all. No `visualize` server → the same rows as a plain list, per the ref.

**Healthy plan → stop here.** No `[!]`/`[~]`, no stale `[>]`, no drift: the report ends with the next step and nothing to resume — no questions asked.

Something needs action → propose it via AskUserQuestion: reset a stale `[>]` to `[ ]`, apply a re-phasing, or hand the `[!]` to `/repair-phase` — the last one only when no live repair holds it (point 1). A stale `[>]` that point 1 traced to a killed unattended run gets the reset and the relaunch as **one option** — the reset alone would leave the user without the path back.

## Step 4: Apply approved plan edits (only if approved)

- **Stale `[>]` reset** — back to `[ ]` with `> Execution interrupted, phase available for retry`.
- **Re-phasing** — replace the oversized phase with the split sub-phases, marking the completed ones `[x]` and leaving the rest `[ ]`.
- **A phase for the remainder of one closed short** — announced by the `phase N closed short` message on the relayed road, and said at the gate where there is no relay (the shared core's *Routing a decision*, re-planning row); the reason it is not the child's either way is that the phase which overran is evidence the sizing was wrong, and sizing belongs to whoever owns the plan. Write what remains as its own phase (or phases, if the overrun says the slice was too big), from the remainder recorded in `notes.md` under that phase's heading.
- **Re-planning after a rejected result** — the answer to *"this phase passed and is still wrong"*, and the case the `phase N closed, result rejected` message announces. It is not only an append: the phases that have not run were written for the design just rejected, so they are re-planned too — rewritten where they no longer fit, dropped where they no longer apply — while the closed phase keeps its `[x]` and its `> Review:` verdict. A phase whose `Done:` went green cannot be repaired into a different design: `/repair-phase` only takes a `[!]`, and its job is to make a `Done:` green again, not to reopen a decomposition. What the plan needs is one or more **new phases**, written from the user's own account of the problem (the user's own account of it, here in this chat).

  **In the tail, never in the middle**, even when the work logically belongs at Phase 2. Phase numbers must be contiguous ascending from 1, so an insertion renumbers everything after it — while the commits already made say `wf(phase 3)`, `wf(phase 4)` with the old numbers, and the correspondence between the plan and the history breaks silently. Execution order stays the numeric order; the new phase's text says what it remedies.

  **A closed phase is not reopened.** Its `[x]` and its `> Files:` are the record of what happened and stay as they are; what it lacks becomes new work with its own phase and its own commit. Write the new phases to the same bar as `/write-workflow` — `Files:`, `Details:`, a re-runnable `Done:`, a `Pattern:` where the code is non-trivial, and a `Run:` line — and present them for approval before writing.

- **Actualising an older plan** — a plan written before a format existed keeps running on defaults, and defaults are invisible. Offer to write them down, on pending phases only (a `[x]` phase is a record of what happened; leave it alone): the `Mode:` header when absent, and on an interactive plan the per-phase `Run: <model> / <effort>` line. Decide each one with `/write-workflow`'s own criteria — that skill is the single source, do not restate them here — and present the values before writing them.

  **Fill in defaults, never gaps.** A missing `Run:` is a default made explicit (`opus` / `high`), which is why proposing it is legitimate. A missing `Done:`, `Pattern:` or `Decisions:` is something its author never settled: report it and stop there, exactly as `/import-workflow` Step 3 does. Inventing a plausible `Done:` makes an open question look closed, and nobody checks it twice.

The plan is a tracked file, so each edit needs its own commit — it belongs to no phase:

```bash
git add .phased && git commit -q -m "wf: <what changed>"
```

Leaving it uncommitted would break the clean-tree invariant the next phase's baseline check relies on.

After any such commit, on `Channel: relayed`, send the foreman one `plan changed` message per `foreman.md` → *The foreman* — best-effort, and naturally skipped when this chat is the foreman (`list_sessions` excludes it). Where there is no relay the change is reported to the user here, and the record in the plan commit is the same either way. A plan reshaped from a supervision chat must not surface for the first time at finalize.
