# The board — the interactive plan, rendered

The inline widget that `/write-workflow` and `/resume-workflow` draw for a
`Mode: interactive` plan. **This file is the single source of its shape** — the
skills cite it and add only what is theirs, they never restate it.

## When it is drawn, and when it is not

- **`Mode: interactive` only.** On an autonomous plan, render nothing: the report
  stays text. There the next step is `/run-workflow`, a single launcher that owns
  every remaining phase, so a per-phase control would invite exactly the
  hand-driving that mode exists to remove — and its model and effort live in the
  config table, not on the phases.
- **Only where the `visualize` MCP server is available.** Absent → the plain text
  report, with the launch command spelled out to copy. Declare the fallback, never
  fail silently; same rule as `ui-test` in `/execute-phase`.
- **Judgments stay prose.** Coverage, drift, oversizing, why a phase failed — those
  go in the reply where they can be read. A grid shows a position well and argues a
  finding badly.
- **Not on an incoming message.** A foreman told that a phase closed answers with the
  delta — `common.md` → *The foreman*. The board answers the human's question about
  where the work stands, or a change in the plan's *shape* (a re-phasing, a `[!]`
  that wants a decision); one marker moving is not either.

## The shape

**The board is the grid plus its controls — a grid without them is not the board,
it is a text report set in a table.** The layout is fixed rather than left to the
renderer, because a free hand drops the controls: a bare table has no natural cell
for a button.

- **Header** — three metric cards: `phases done N / M`, `branch`, `mode`.
- **One card per phase**, in order: state icon, `Phase N: <title>`, and one muted
  meta line — `<model> / <effort> · <n> file · <commit, or manual checks>`. The card
  of the first unfinished phase carries the accent border; finished ones are muted.
- **Every unfinished card shows its command in full, in mono.**

**No refresh button.** Nothing inside a conversation can update itself, so a refresh
could only re-run the whole skill and print a second report below — a recomputation
dressed as a redraw, paid in tokens each time. The board is an accurate snapshot of
the moment it was asked for.

**No button that runs a phase.** `sendPrompt` is a widget's only channel and it
writes into the chat you are in, so such a button would run the phase in the chat
holding the board. A phase belongs in a chat of its own; copying into a new one is
the whole gesture.

**No `spawn_task` chip.** A chip does open a session of its own, but its own UI
decides how — including starting a *new worktree* for a plan that already has a
branch and a checkout — and `spawn_task` exposes no parameter to prevent it. A
suggestion popup that forks the tree is worse than a copied command.

## Which command, per state

| State | Command on the card |
|---|---|
| unfinished (`to do` / `running`) | `/wf:execute-phase` |
| `problem`, **and the plan has that phase `[!]`** | `/wf:repair-phase` |
| `problem` on a phase the plan has `[x]` | **none** — annotate and export |
| a `[~]` phase | none: a red baseline nobody owns is the human's |

**`problem` means two different things, and only one of them is repairable.** A phase
the plan marks `[!]` failed its own `Done:` — tests red, with `> Issue:` and
`> Attempted:` written by whoever ran it — and `/repair-phase` exists precisely for that:
it re-diagnoses from scratch and pushes that code back to green.

The other case is the one interactive mode produces most: the phase passed, and *you*
looking at the result judge it wrong — a logical or structural problem whose answer is
not to repair that phase but to **add phases to the plan**. `/repair-phase` would not
even start there (it takes the first `[!]`, finds none, and says so), and if it did it
would do the wrong thing: it is built to make a `Done:` green again, not to reopen a
decomposition. So the card offers no command; the note and the export are the path, and
the plan grows through `/resume-workflow`.

Every unfinished phase shows its command, not just the one whose turn it is —
reading it is how you see what is coming.

**The command carries no argument.** It used to repeat `Phase N — <title>`, which
`next-phase.py` ignored: the phase is chosen from the plan, and the text was only
there to name the chat. Since 6.1.0 the phase chat titles itself
(`common.md` → *The foreman*), so the argument has nothing left to do and copying
one out of turn no longer mislabels a session — every unfinished card can carry the
same bare command, with `due after phase M` saying only what it says: order.

## One state per phase

**Each card carries a single state select — `to do` / `running` / `done` /
`problem` — and the skill seeds them all when it draws the board.** From that
moment the board is the user's working view: they move the selects as the phases go,
without waiting for a report to agree.

**One state, not two.** An earlier draft showed the plan's state and the user's
marker as separate badges: correct, and unreadable — every card asked to be parsed
twice. The plan in the repository remains the only thing that is *true* (a select
cannot write to `plan.md`: no network leaves the widget sandbox) but the board does
not argue about it. It is re-seeded from the plan every time a skill draws it, so a
wrong marker survives exactly until the next board.

**The selects are order-guided.** `done` is offered only when every earlier phase
is already `done`; while one is not, the option stays disabled on the later cards.
And moving a phase back off `done` returns every later `done` to `to do`, since
the alternative is a state the chain cannot reach. It is the ordering rule the whole
chain runs on, enforced where the user is clicking rather than explained afterwards.

## Notes and export — supervision only

Present when a board is drawn over work that has run (`/resume-workflow`), omitted
on a plan that has just been written (`/write-workflow`): there is nothing to
annotate before the first phase starts, and an export with nothing in it is furniture.

- **A `notes and problems` textarea on every card.** Interactive phases run in
  chats the board cannot see: what you noticed, what came out wrong, what to
  revisit, goes next to the phase it came from.
- **An `export fix prompt` button at the foot of the board**, copying one
  prompt built from the cards that carry notes. **It is also the only thing that
  saves them** — like the selects, the textareas live in that message and die with
  it. Say so once, under the board.

The exported prompt has a fixed shape, so it can be pasted into a fresh chat and
acted on:

```
Post-phase review — <slug> (branch <branch>, plan .phased/active/<slug>/plan.md)

Phase 2 — table foo with its TH UI  [done]
  the form saves but the grid does not reload afterwards

Phase 4 — pdf export endpoint  [problem]
  the discount is computed in the page: it belongs in the model, and one
  single point must apply it to the export too

For each one, decide which of the two cases it is and say so before touching
anything:

1. targeted fix — find the cause and propose the change;
2. design problem — not repairable inside the phase: propose the NEW phases
   that solve it, in the plan's format (title, Files:, Details:, Done:, Run:),
   to be appended AT THE END. /resume-workflow writes them, with its own commit.

A closed phase is not reopened: what it lacks becomes new work.
```

The scaffold is fixed text the widget builds, so it ships in English like every
other written artifact; the notes it carries are the user's own words, in
whatever language they typed them.

Phases with no note are left out — an export listing every phase says nothing about
which ones need attention.

**The two-case fork is the load-bearing part of the shape.** Most of what a human
notices in interactive mode is not a bug in a phase but a phase cut in the wrong place,
and a prompt that only asks for a fix gets a patch where the plan needed another phase.
The closing lines matter for the same reason: without them the prompt is a list of
complaints, and whoever receives it starts editing before diagnosing.
