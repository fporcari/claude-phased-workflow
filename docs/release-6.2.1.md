# 6.2.1 — a result you reject is not a failed phase

6.1.0 gave the test gate two exits: the checks pass and the phase closes, or
something is off and the phase fixes it. Field use found the third case
immediately — *the result is wrong at the root* — and with no exit written for
it, the session reached for the only marker that reads like "broken" and
reopened the phase `[!]`.

That is the wrong marker, and expensively so. `[!]` is what `/repair-phase`
consumes, and its whole job is making a red `Done:` green again. A phase whose
tests pass has nothing there to repair: `/repair-phase` either finds no `[!]`
to take, or takes one and works on green code to fix a disagreement no test
states — and an unattended `/run-workflow` does it without asking. The phase's
`> Issue:` / `> Attempted:` block, if it has one, is the record of what its own
tests went through; it is not a claim about the design.

So the boundary is now written where the markers are defined: **`[!]` is a
machine verdict, never a human one.** A person judging the result wrong —
including in the words "this phase is broken" — does not move the marker. The
`Done:` passed, so the phase is `[x]`; what they want is a **decomposition**
change, which is new phases written from their own account and appended by
`/resume-workflow`, with the verdict recorded on the phase as `> Review:`,
rejected options included, so nobody proposes them again.

The gate in `phase-execution.md` now states all three exits together, which is
what makes the rule reachable at the moment it is needed rather than three
sections away.

## The guard

S34 gains the two checks and two mutations: strip the machine-verdict boundary
from `common.md`, or the third exit from the gate, and the guard fires.
