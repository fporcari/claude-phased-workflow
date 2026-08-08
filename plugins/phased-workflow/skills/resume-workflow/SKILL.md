---
description: Locate the active phased workflow and report where it stands, then name the skill that takes it forward. The entry point of the phased-workflow plugin, and the only skill in it the agent may reach on its own. Use when the user asks where the work stands, what the next phase is, whether a workflow is running, why a phase is stuck or failed, how to resume after an interrupted session, or mentions `.phased/` or a `wf/` branch.
allowed-tools: Bash(git:*), Bash(python3:*), Read, Edit, Write, Grep, Glob, AskUserQuestion, SendMessage, ListAgents, mcp__visualize__read_me, mcp__visualize__show_widget, mcp__ccd_session_mgmt__set_session_title, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions
---

# Resume Workflow

Supervision and resume view of the work plan. **Read-only on source code** — the only files this command may modify are the plan, `notes.md` and `foreman.json`; plan and notes only on an approved edit; each edit gets its own `wf:` commit.

A healthy workflow is a valid reason to run this: when nothing is broken it early-exits with the state report and nothing to resume.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start — language, AskUserQuestion style, plan directory, workflow branch.

## The map

Every other skill in this plugin is **user-invoked**: only the user typing its name reaches it. Naming the right one is part of this skill's job — in Step 3's *Prossimo passo*, and whenever the user asks what to run.

| Skill | Reach for it when |
|---|---|
| `/scope-workflow` | the work is still vague — settle the decisions before planning |
| `/write-workflow` | there is no plan yet, and the work was just discussed |
| `/import-workflow` | a plan or handoff document already exists outside `.phased/` |
| `/issue` | the work starts from a GitHub issue (analysis only) |
| `/execute-phase` | run the next phase in this chat, with an approval gate |
| `/run-workflow` | run every remaining phase unattended (`Mode: autonomous` plans) |
| `/repair-phase` | a phase is `[!]` and needs fresh eyes |
| `/finalize-workflow` | every phase is `[x]` — consolidate into one commit |
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

Read `.phased/active/<slug>/foreman.json` (protocol, file format and
take-command mechanics live once in `common.md` → *The foreman*):

- **Absent** → **assume command, without asking**: the normal state of every
  workflow that predates the protocol, and a workflow being resumed wants a
  foreman. Take command per `common.md` — write the file, ONE `wf: foreman —
  takes command` commit, suggest the chat title to the user.
- **Present, and no other session bears the title** (`list_sessions`) → the
  title is unclaimed: either it is this very chat (fine) or the old foreman
  is dead or renamed. Either way, claim it — same take-command step, which is
  **idempotent by content** (`common.md`): the file already carries this
  exact title, so nothing is rewritten and no commit is made; at most,
  repeat the rename suggestion if the user never applied it.
- **Present, another session bears the title** → do not depose on a status
  query. Report it (Step 3 gets a *Capocantiere* line: who, since when).
  Offer the takeover through the Step 3 AskUserQuestion only when something
  actually needs action here, or the user says they want this chat in
  charge. On yes: depose per `common.md` — best-effort farewell message and
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

Flag a phase as **oversized** when its commit spans more than ~10 files, covers unrelated areas (model + UI + tests for different features), or is too large to review as one commit. **Exception:** a `vast` phase is intentionally whole — that size is by design, never propose re-phasing it for size alone. For a pending phase the same judgment is a projection from its `Files:`, not a measurement; say which one you are making.

## Step 3: Report (in Italian)

1. **Stato del piano** — every phase with its marker. For `[>]`, show the timestamp and flag anything older than 2h: *"in esecuzione da oltre 2 ore — la chat precedente potrebbe essere terminata"*. One **Capocantiere** line closes the point: who commands (this chat, another session with its `since`, or just assumed per Step 1b).
2. **Commit del workflow** — `git log --oneline $BASE..HEAD`, one line per phase, with the files each touched.
3. **Copertura** — per `[x]` phase: does its commit match its `> Files:`? Per pending phase: still to do.
4. **Drift** — the two kinds above, kept apart.
5. **Fasi sovradimensionate** — for each, what its commit already contains, what remains, and a proposed split into sub-phases.
6. **Prossimo passo** — continue (`/execute-phase` or `/run-workflow`), repair (`/repair-phase` on a `[!]`), re-phase, add phases for work that surfaced (Step 4 — the answer when a phase passed and is still wrong), finalize, or clean up drift. When it is `/execute-phase`, quote the next phase's `Run: <model> / <effort>` hint alongside it (older plan without one → `opus` / `high`): both are chosen when that chat is opened, so the hint is only useful before it is.

**The board.** On a `Mode: interactive` plan, render points 1 and 6 as the inline widget specified in `${CLAUDE_PLUGIN_ROOT}/refs/board.md` — read it there rather than inferring the layout; it is the single source of the board's shape, shared with `/write-workflow`. Points 3, 4 and 5 stay prose in the reply: they are judgments, and a grid argues badly.

What is this skill's own, on top of that file:

- **Seed every state select from the plan**, since here the plan has a history: `[x]` → `fatta`, `[>]` → `in esecuzione`, `[!]` → `problema`, the rest → `da fare`. The board is then the user's working view, re-seeded on the next run.
- **Notes and export are on**, per the ref's *supervision only* section: this is the command that runs over work already done, so there is something to annotate and something to export.
- On an autonomous plan, no board at all — the report stays text, as the ref says.

**No `spawn_task` chip.** A chip does open a session of its own, which is why 5.6.0 reached for it, but its own UI decides how — including starting a *new worktree* for a plan that already has a branch and a checkout — and `spawn_task` exposes no parameter to prevent it. A suggestion popup that forks the tree is worse than a button that is honest about running here.

No `visualize` server → the plain text report of today, with the launch command spelled out to copy. Declare the fallback, never fail silently; same rule as `ui-test` in `/execute-phase`.

**Healthy plan → stop here.** No `[!]`/`[~]`, no stale `[>]`, no drift: the report ends with the next step and nothing to resume — no questions asked.

Something needs action → propose it via AskUserQuestion: reset a stale `[>]` to `[ ]`, apply a re-phasing, or hand the `[!]` to `/repair-phase`.

## Step 4: Apply approved plan edits (only if approved)

- **Stale `[>]` reset** — back to `[ ]` with `> Execution interrupted, phase available for retry`.
- **Re-phasing** — replace the oversized phase with the split sub-phases, marking the completed ones `[x]` and leaving the rest `[ ]`.
- **Adding phases for work that surfaced** — the answer to *"this phase passed and is still wrong"*. A phase whose `Done:` went green cannot be repaired into a different design: `/repair-phase` only takes a `[!]`, and its job is to make a `Done:` green again, not to reopen a decomposition. What the plan needs is one or more **new phases**, written from the user's own account of the problem (typically the board's `annotazioni e problemi`, or its export).

  **In the tail, never in the middle**, even when the work logically belongs at Phase 2. Phase numbers must be contiguous ascending from 1, so an insertion renumbers everything after it — while the commits already made say `wf(phase 3)`, `wf(phase 4)` with the old numbers, and the correspondence between the plan and the history breaks silently. Execution order stays the numeric order; the new phase's text says what it remedies.

  **A closed phase is not reopened.** Its `[x]` and its `> Files:` are the record of what happened and stay as they are; what it lacks becomes new work with its own phase and its own commit. Write the new phases to the same bar as `/write-workflow` — `Files:`, `Details:`, a re-runnable `Done:`, a `Pattern:` where the code is non-trivial, and a `Run:` line — and present them for approval before writing.

- **Actualising an older plan** — a plan written before a format existed keeps running on defaults, and defaults are invisible. Offer to write them down, on pending phases only (a `[x]` phase is a record of what happened; leave it alone): the `Mode:` header when absent, and on an interactive plan the per-phase `Run: <model> / <effort>` line. Decide each one with `/write-workflow`'s own criteria — that skill is the single source, do not restate them here — and present the values before writing them.

  **Fill in defaults, never gaps.** A missing `Run:` is a default made explicit (`opus` / `high`), which is why proposing it is legitimate. A missing `Done:`, `Pattern:` or `Decisions:` is something its author never settled: report it and stop there, exactly as `/import-workflow` Step 3 does. Inventing a plausible `Done:` makes an open question look closed, and nobody checks it twice.

The plan is a tracked file, so each edit needs its own commit — it belongs to no phase:

```bash
git add .phased && git commit -q -m "wf: <what changed>"
```

Leaving it uncommitted would break the clean-tree invariant the next phase's baseline check relies on.

After any such commit, send the foreman one `plan changed` message per `common.md` → *The foreman* — best-effort, and naturally skipped when this chat is the foreman (`list_sessions` excludes it). A plan reshaped from a supervision chat must not surface for the first time at finalize.
