# 5.7.1 — `problema` is two things, and only one of them is repairable

The board's `problema` state offered `/repair-phase` on any card carrying it. That is
right for one of the two situations it actually covers, and wrong — unusable, in fact —
for the one interactive mode produces most.

## The two cases

**A phase the plan marks `[!]`** failed its own `Done:`: tests red, `> Issue:` and
`> Attempted:` written by whoever ran it. `/repair-phase` exists precisely for this. It
re-diagnoses in a fresh context on the premise that *the previous diagnosis may itself be
the problem*, refuses to repeat anything listed in `> Attempted:`, checks whose failure it
is by re-running the green signal at `HEAD^`, and closes `[x] + > Repaired:` or
`[!] + > Repair attempted:`.

**A phase that passed and is still wrong** is the other case, and it is the normal one
here: the `Done:` went green, and the human looking at the result judges the phase
mis-scoped — a logical or structural problem whose answer is not to repair that phase but
to add phases to the plan.

On that second case `/repair-phase` does not even start: it takes the *first* `[!]`,
finds none, and prints "No failed phases to repair." And if it did start it would do the
wrong thing — it is built to make a `Done:` green again, not to reopen a decomposition.

So the board now decides by what the plan says, not by the marker alone:

| Card | Command |
|---|---|
| `problema`, plan has that phase `[!]` | `/phased-workflow:repair-phase` |
| `problema`, plan has that phase `[x]` | none — annotate, export, and let the plan grow |

## The export forks on the case

The exported prompt used to say "individua la causa e proponi la correzione", which
quietly assumed every note was a bug. It now asks, per annotated phase, which of two
things it is: a puntual fix, or a problem of design — and in the second case it asks for
the **new phases** that solve it, written in the plan's format (title, `Files:`,
`Details:`, `Done:`, `Run:`) and to be appended by `/resume-workflow`.

That fork is the load-bearing part of the shape. Most of what a human notices in
interactive mode is not a bug inside a phase but a phase cut in the wrong place, and a
prompt that only asks for a fix gets a patch where the plan needed another phase.

## `/resume-workflow` can grow the plan

A third kind of approved plan edit joins the stale-`[>]` reset, the re-phasing and the
actualisation: **appending phases for work that surfaced**, written from the user's own
account of the problem, to the same bar `/write-workflow` applies, and presented before
being written.

**In the tail, never in the middle**, even when the work logically belongs at Phase 2.
Phase numbers must be contiguous ascending from 1 (`next-phase.py --validate` enforces
it), so an insertion renumbers everything after it — while the commits already made say
`wf(phase 3)`, `wf(phase 4)` with the old numbers. The correspondence between the plan
and the history would break silently, and that correspondence is what every later
attribution and repair depends on. Execution order stays the numeric order; the new
phase's text says what it remedies.

**A closed phase is never reopened.** Its `[x]` and its `> Files:` are the record of what
happened; what it lacks becomes new work, with its own phase and its own commit.
