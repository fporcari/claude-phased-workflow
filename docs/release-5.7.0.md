# 5.7.0 — the board becomes a working view, shared by planning and supervision

5.6.0 introduced a board and 5.6.1 made its controls mandatory. Using it for real
showed that most of what it did was wrong for the medium it lives in. This release
takes out the two controls that promised what a chat cannot deliver, replaces the
double bookkeeping with one hand-kept state, adds the two things the work actually
needed — notes and an export — and moves the whole specification into a shared ref,
because `/write-workflow` now draws it too.

## What came out

**The `spawn_task` chip.** It was the only mechanism that opens a session of its own,
which is why 5.6.0 reached for it — but it also decides *how* on its own. Its
suggestion popup offers **"Inizia con worktree"**, so a plan that already has a branch
and a checkout gets its phase forked into a new tree, and the session's first move is
to offer to re-anchor it. `spawn_task` exposes no parameter to prevent that (`title`,
`prompt`, `tldr`, `cwd` — that is all), so 5.6.1's fix of passing the plan's root was
treating a symptom. A popup that forks the tree is worse than a copied command.

**The refresh button.** It was a promise the medium cannot keep: nothing inside a
conversation updates itself, so pressing it re-ran the whole skill and printed a
second report below — a full recomputation dressed as a redraw, paid in tokens every
time. The board is now what it can honestly be: an accurate snapshot of the moment it
was asked for.

**Any button that runs a phase.** A widget's only channel is `sendPrompt`, which writes
into the chat you are in, so such a button could only execute the phase in the chat
holding the board. A phase belongs in a chat of its own; copying its command into a new
one is the whole gesture — two actions instead of one, and the honest price of the two
removals above.

## One state per phase, kept by hand

Every card now carries a single select — `da fare` / `in esecuzione` / `fatta` /
`problema` — and the drawing skill seeds them all. From then on the board is the user's
working view: the selects move as the phases go, without waiting for a report to agree.

The first attempt showed two badges per card, the plan's state and the user's marker,
on the reasoning that a note must never masquerade as a state. It was correct and
unreadable — every card asked to be parsed twice. The resolution is not two channels
but a short-lived one: the plan in the repository remains the only thing that is *true*
(a widget cannot write to `plan.md` — verified by putting a server on `127.0.0.1` and
watching the request never arrive), and the board simply does not argue about it, being
**re-seeded from the plan every time it is drawn**. A wrong marker survives exactly
until the next board.

**The selects are order-guided**, which is what makes a single state safe: `fatta` is
offered only when every earlier phase is `fatta`, so Phase 4 cannot be closed while
Phase 2 is open — and moving a phase back off `fatta` returns every later `fatta` to
`da fare`, since the alternative is a state the chain cannot reach.

**`copia comando` is gated the same way.** Every unfinished phase still *shows* its
command — reading it is how you see what is coming — but the button appears only where
every earlier phase is `fatta`. Not because copying early could start something out of
turn (it cannot: `next-phase.py` chooses the phase, and the argument is only a
chat-title label) but because it produces a chat *titled* `Phase 4` that runs Phase 2,
and that title is what the user scrolls their session list for a day later.

## Notes per phase, and an export that gets them out

Each card gains an `annotazioni e problemi` textarea: interactive phases run in chats
the board cannot see, and what they surfaced belongs next to the phase it came from.

At the foot of the board, `esporta prompt correzioni` copies one prompt assembled from
the cards that carry notes — the slug, branch and plan path, then a block per annotated
phase with its state and note, then the closing instruction to diagnose before editing
and to treat a fix on a closed phase as new work rather than a reopened phase. Phases
without notes are omitted: an export listing everything says nothing about what needs
attention.

That export is also the **only** way the notes leave the widget. Like the selects, the
textareas live in one message and die with it.

## Drawn by two commands, specified once

`/write-workflow` now closes an interactive plan with the same board, so its shape
lives in `refs/board.md` and both skills cite it — the rule `common.md` already carries
for the `Done:`/`Verify:` contract. Two boards described in two files is how they start
drifting apart.

| | `/write-workflow` | `/resume-workflow` |
|---|---|---|
| State selects | all `da fare` — the plan was just written | seeded from the plan: `[x]`→`fatta`, `[>]`→`in esecuzione`, `[!]`→`problema` |
| Notes and export | absent: nothing has run yet, and an empty export is furniture | present |
| When | after the plan's commit, never during the presentation — a command for a branch that does not exist yet is a trap | with the report |

**Interactive plans only, in both.** On a `Mode: autonomous` plan neither command draws
anything: there the next step is `/run-workflow`, one launcher that owns every remaining
phase, so a per-phase control invites the hand-driving that mode exists to remove — and
an autonomous plan's model and effort live in the config table, not on the phases, so
two of the board's columns would have nothing to show.

## Still missing

The board's clauses have no mutation-proven assert. Every load-bearing invariant in
this plugin has one (S24, S27 are the models), and 5.6.1 exists precisely because a
clause nobody guarded was quietly not followed. The candidates: no run button, no
refresh, copy gated by order, `fatta` gated by order, notes and export absent in
`/write-workflow`, nothing rendered on an autonomous plan.
