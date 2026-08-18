# 6.3.0 — a rejected result travels up, and re-plans what has not run

The field sequence this closes, in order: the phase chat marked the phase done
and told the foreman **before** the human had run the UI check; the human then
ran it, found bugs, and behind the bugs found that the *design* was wrong; the
plan had to be re-discussed, and the only place the state could be corrected
was by hand.

6.1.0 fixed the first half — a phase with checks left to the human stays open.
This release finishes the other three.

## Nothing is closed and nobody is told before you answer

Stated where the gate is, not three sections away: the `[x]`, the phase commit
and the foreman message all belong on the far side of the human's answer. A
phase reported done while its checks are still unrun is the failure the gate
exists to prevent, and the report is half of that failure — the foreman
redraws its board on a result nobody has seen.

## The rejection has a line of its own

The protocol's message list gains one:

```
[wf:<slug>] phase N closed, result rejected — <what the person judged wrong, one line>. The pending phases need re-planning.
```

It is the one report that is not routine: the plan the foreman authored is
about to change, and it holds the reasons the plan was shaped that way. The
answer is the delta, as for any message — **a rejection is the moment a board
is most tempting and least useful**, since the shape is about to change and
drawing the old one shows a position nobody will act on. `board.md` now says
*never* on an incoming message, whatever it carries; the board comes back when
the person asks, or once after a re-planning is committed.

## Re-planning is not only an append

6.2.1 said a rejected result becomes new phases. Field use says that is half
of it: **the phases that have not run were written for the design just
rejected**, so `/resume-workflow` re-plans them too — rewriting what no longer
fits, dropping what no longer applies — from the person's own account of what
went wrong. The closed phase keeps its `[x]` and its `> Review:` verdict: its
work stands, its design did not, and the board's strip shows that row as
closed-with-a-problem.

`/close-phase` closes such a phase the same way it closes any other, with two
differences: the message is the rejected one, and its closing line names
`/resume-workflow` rather than the next phase.

## The guards

S34 gains four checks — the gate holds the `[x]`, the commit and the message;
`common.md` carries the rejection line; `/close-phase` uses it; and
`/resume-workflow` owns the re-planning path — plus two mutations: a gate that
reports early, and a rejection flattened into a plain `done`.
