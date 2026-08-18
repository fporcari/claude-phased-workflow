# 6.1.0 — a phase with checks left to you does not close itself

Two field findings from the same interactive run, both about weight: work
closing before anyone had looked at it, and a foreman answering a one-line
event with a full redraw.

## The phase waits for the human's checks

Step 5 of `/execute-phase` already splits verification by who can do it: what
an agent can assert, an agent asserts; what is left — aesthetics, "is this
interaction right?" — goes to the human as `Verify: now`. Step 6 then closed
the phase anyway and let those checks travel to `/finalize-workflow`. On a
`ui` phase whose browser pass could not run (no instance up, a login wall),
*everything* was in that list: the phase closed `[x]` on a result nobody had
seen.

Now a `now` step left to the human holds the phase open:

1. The work is committed — the checkpoint mechanic that already existed, a
   `partial` commit — and the phase stays `[>]` with a new note:
   `> Testing: awaiting the human's Verify: now checks | commit: <hash>`.
2. The checks are presented, and the skill stops. No `close-phase`, no
   foreman message: nothing has closed.
3. What the checks turn up is ordinary work on the open phase — fix, commit,
   present again.
4. The human's ok runs `/close-phase`, which drops the note and closes as
   before.

`next-phase.py` reports such a phase as `blocked:`, naming the command that
clears it — so a fresh chat lands back on the same gate instead of
re-implementing a finished phase, and an unattended `/run-workflow` stops and
says why rather than closing on the human's behalf. `/resume-workflow` reads
the note too: a `[>]` older than 2h that carries it is not a suspect dead
session, it is waiting for you.

Nothing changes where the suite covered everything: that phase closes
straight away, as before. Autonomous mode is untouched — it has nobody to
wait for.

## The foreman answers with the delta

The protocol told a foreman receiving a message to re-read `.phased/` and
**redraw its board**. The board is a 150-line widget spec; a phase closing is
one marker moving. Every child report cost a full recomputation plus a prose
essay under it.

So the two are separated: an incoming message is answered with the delta —
what changed, what it blocks, what to launch next, in the reporting register.
The board is what answers a human asking where the work stands, or a change
in the plan's *shape* (a re-phasing, a `[!]` that wants a decision).

## The launch command lost its argument

The board's cards read `/wf:execute-phase Phase N — <title>`, and `board.md`
admitted what the argument was for: nothing but the chat's title —
`next-phase.py` picks the phase from the plan. Since 6.0.3 the phase chat
titles itself, so the argument is gone and copying a command out of turn no
longer mislabels a session.

## The guards

New S34: the selector reports a waiting phase as `blocked:` and the same
phase without the note as a resume candidate (run for real, not greped),
`Testing` is a known note field, the mechanic lives once in
`phase-execution.md`, and no skill respells the note's format — two mutations
prove both halves. S30 gains the delta rule, the board's new
*not on an incoming message* case, and the absence of the chat-title
argument.
