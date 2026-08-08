# 5.10.0 — the foreman: one chat commands, the others report to it

Claude Code 2.1.224 gave sessions a way to talk to each other (`SendMessage` +
`ListAgents` in the CLI, the session-management tools in the desktop app). This
release puts that transport under the metaphor the workflow always implied:
**one engineer/foreman chat per workflow, N executor chats** — in both modes,
interactive and autonomous. The children report to the father; the father's
board redraws itself instead of being polled.

The design decision everything else hangs on: **the foreman's identity lives in
a file, never in any chat's memory.**

## `foreman.json` — the anagraphics on disk

`.phased/active/<slug>/foreman.json`, tracked and committed like the plan:

```json
{
  "session": "wf:<slug>:foreman",
  "since": "<ISO timestamp>",
  "status": "active",
  "history": [
    {"session": "<previous session name>", "deposed": "<ISO timestamp>"}
  ]
}
```

Whoever wants to talk to the foreman reads the file — no session discovery, no
guessing which chat has the dashboard open. The whole protocol (file format,
take-command mechanics, deposition, message formats) lives once in
`refs/common.md` → *The foreman*; every skill cites it.

## Taking command

- **`/write-workflow`** and **`/import-workflow`** take command at plan
  creation: the session renames itself `wf:<slug>:foreman`, writes the file,
  and the file rides the plan/import commit. Importing IS assuming command —
  an imported workflow is born with a foreman like a written one.
- **`/resume-workflow`** owns the migration and the succession:
  - **No `foreman.json`** — the normal state of every pre-5.10 workflow — →
    assume command, without asking; the first `/resume-workflow` on an old
    workflow dotes it with a foreman, no manual step.
  - **Another session on file** → never depose on a status query. The report
    gains a *Capocantiere* line (who, since when); the takeover is offered only
    when something needs action or the user wants this chat in charge. On yes:
    best-effort farewell message and retitle of the old chat to
    `wf:<slug>:deposed`, read `handover.md` if present, take command.

`handover.md` is the outgoing foreman's note to the incoming one — the context
that lives only in chat. Optional by design: a takeover from a dead chat must
work with the plan and `notes.md` alone.

## Reporting up

The shared core (`refs/phase-execution.md`) gains one step both execute modes
cite — *Notify the foreman*: after the phase commit, one plain-text message in
a fixed format:

```
[wf:<slug>] phase N done — <title>. Commit <hash>. Verify: <n now, m deferred>.
[wf:<slug>] phase N FAILED — <title>. Issue: <one line>.
[wf:<slug>] phase N blocked — <one line>.
[wf:<slug>] plan changed at phase N — <summary of the approved deviation>.
[wf:<slug>] workflow finalized — <consolidation outcome>.
```

`/execute-phase` additionally messages the foreman when a live answer reshapes
the plan — the father must not discover a deviation at finalize. A foreman
receiving any of these re-reads `.phased/` and redraws its board: the plan on
disk, not the message text, is the state.

**Best-effort, always, in both directions.** No `foreman.json`, no messaging
tool (a `claude -p` sub-session may simply not have one), dead target,
delivery refused → silent skip. A notification never fails a phase, never asks
the user anything, never becomes a retry loop.

## Rationale outlives the executor

Executor chats are ephemeral — by finalize time there is nobody left to ask
why a choice was made. So the mechanism is a file, the message the extra: a
phase that makes a non-obvious choice appends it to `notes.md` under a
`## Phase N` heading, and `/finalize-workflow`'s lessons pass reads the file.
Interactive children still alive may additionally be queried by message.

## Tests

S30, proven by mutation: the protocol is single-source in `common.md`'s
`## The foreman`, the shared core carries the one *Notify the foreman* step,
every taking/deposing/notifying skill cites the section, `/resume-workflow`
keeps the assume-command migration, and nobody restates the `foreman.json`
body. 185 assertions over 29 scenarios, all green.

## Requirements

Cross-session messaging needs Claude Code ≥ 2.1.224 on both ends and
`crossSessionInbound: accept` on the foreman's side (otherwise every incoming
outcome asks for approval). Everything else — the file, the migration, the
rationale notes — works on any version: the protocol degrades to files, which
is where the truth lives anyway.
