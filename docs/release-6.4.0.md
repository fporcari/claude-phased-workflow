# 6.4.0 — handing over a phase, and two ways a child got lost

Field session on `ddt-wizard` phase 2, a long one. Three findings, and the
first is a defect in 6.0.3's own fix.

## A tool you have not loaded is not a tool that is absent

6.0.3 was written after a child concluded the foreman was unreachable from an
empty `ListAgents`. The rule it added said: `list_sessions` first, and fall
back to `ListAgents` *only where that tool does not EXIST*.

The same failure happened again, and the wording is why. Inside the desktop
app `mcp__ccd_session_mgmt__list_sessions` is a **deferred** tool: it is not
in the model's tool list until `ToolSearch` loads it. "That tool does not
exist" therefore reads *true*, and the sentence meant to close the wrong
branch licensed it. The child announced that no `wf:<slug>:foreman` existed
while the foreman sat idle in the session list.

So absence now has a proof: **a `ToolSearch` that comes back with nothing.**
Not a tool list that fails to mention it, and not a channel that ran and
returned no match — an empty `ListAgents` says nothing about a desktop
session. The rule is written as an order because the environment pushes the
other way: the branch that fails is already loaded, the branch that works has
to be fetched.

## A phase chat executes; it does not supervise

Believing the foreman dead, the same chat proposed running
`/wf:resume-workflow` — in itself, mid-phase. The hazard is concrete:
`/resume-workflow` **takes command** when no session bears the foreman title,
so a phase chat running it writes `foreman.json` in its own name and becomes a
foreman that also executes. That is what 5.17.1 forbade, reached from the
opposite side, and only the foreman half of it was written down.

Now both halves are: no skill recommends `/resume-workflow`, or any
re-planning of the whole plan, inside a chat executing a phase — a *Next step*
naming it is worded as the foreman chat, or a fresh one if the foreman is
gone. `/close-phase` says it too when it closes a rejected result. What a
phase chat may always do is edit the plan for its own phase, which mid-phase
it is the only writer of. And a child that believes the foreman is dead is
usually a child that looked on the wrong channel: the rule above comes first.

## Handing over is a move, not a reaction

A long phase outlives its chat. The handover existed only as a reaction to a
filling context, and carried only what four keys hold — `done`, `missing`,
`next`, `commit`. Everything the chat had *understood* died with it.

It is now `## Handing over` in `/execute-phase`, callable at any time
(*"pass the baton"*, no reason needed), and it is three things in order:

1. the checkpoint as before — `partial` commit and `> WIP:` note together;
2. **what four keys cannot hold**, into `notes.md` under the phase's
   `## Phase N`: decisions and why, roads tried that do not work, what the
   next chat must not redo — committed with the checkpoint;
3. **stop**: the working tree belongs to whoever picks the phase up.

On the other side, the arriving chat no longer reads the tree as an orphan.
A phase chat titles itself `wf:<slug>:phase-N — <title>` (6.0.3), so it is
findable exactly like the foreman: alive → one message, *commit anything
uncommitted, tell me what is not on disk, and stop working on this phase*.
The answer is a supplement; the note and the diff stay the authority, and a
contradiction is settled by the tree. Unreachable or silent → the disk, as
before.

That message is what makes an uncommitted tree safe. Two chats on one working
tree are not a handover problem, they are two writers: the arriving one must
be able to say *stop* instead of discovering the traces afterwards.

`README` loses its claim about a `handover.md`: nothing wrote or read one.

## The guards

S30 gains five checks — absence bound to `ToolSearch`, the section naming it,
the phase-chat mirror rule, no skill supervising from a phase chat, the named
handover and its stand-down message — and three mutations: restore the
`EXIST` reading, let a phase chat supervise, and have a skill send the user to
`/resume-workflow` in the chat that is running the phase.
