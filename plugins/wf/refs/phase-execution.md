# Phase execution — shared core

Loaded by `/execute-phase` (the gate of an interactive workflow) and
`/execute-phase-agent` (the executor, in both modes). **The executor is one
skill, whoever launches it**: `/execute-phase` launches it as a subagent
after the approval gate, `/run-workflow` launches it as a headless session.
The two modes differ by *where decisions get made* — live at the gate, or
pre-made in the plan — never by these mechanics. A rule that changes here
changes for both; that is the point (the `Never commit` leftover of 4.1.0 is
what happens when siblings carry their own copies).

## Select the phase

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
```

Act on `recommendation:` — `next: N` → take it; `done` → exit suggesting
`/finalize-workflow`; `blocked: ...` → report the reason and stop;
`resume-candidate: N` and `attention: ...` → mode-specific, see the calling
skill. Script unavailable → apply the semantics in `refs/common.md`.

Mark the selected phase `[>]` with `> In execution since <ISO timestamp>`.

## Implement

Read the phase's `Pattern:` example first — it is the model to copy-adapt —
then its `Files:`. Write the code the phase describes, and nothing else.
Never invent framework APIs. ONE phase per invocation; no out-of-scope
refactoring.

**New callables: minimal, and marked.** Introduce only the methods and
functions the phase's `Done:` requires, and give every one of them the
end-of-line marker on its definition line — `# wf:phase-N:new`, in the
file's own comment token — per `refs/contracts.md` → *New-method markers and
minimality*. The name you choose is a proposal: the naming review
(`refs/naming-review.md`) is where a human accepts or rewords it —
`/close-phase` in interactive runs, `/finalize-workflow` in autonomous
ones — so never spend a question on a name here.

**The plan is context, not just a queue.** Before the first edit, skim the
whole plan once — every phase, not only yours. The `> Done:`/`> Files:`
notes of completed phases say what already exists: reuse it, never
duplicate it. The pending phases say where the work is heading: a
micro-choice this phase leaves open (a name, where a helper lives, a data
shape) is decided in favour of the phases that come after, and a choice
that would force a successor to undo or work around it is the wrong choice
even when it is locally cheaper. Where the plan carries contract tests, the
pending phases' `tests/phase-M/` are the sharpest statement of where the
work is heading — read the ones this phase's choices could touch. The
plan's `Must not break:` header and, on a programme, the roadmap's
remaining macro-phases are successors of the same rank (`refs/contracts.md` →
*Must not break:*): a choice that breaks one is wrong at the same price. Scope is
unchanged: knowing Phase 5 exists never means implementing a piece of it
here.

**Contract tests, where the plan carries them** (`refs/contracts.md` →
*Contract tests*): copy `tests/phase-N/` verbatim into the repo's test tree
before implementing — red is the starting state, green is part of `Done:`.
A skeleton's body is yours to write; everything else is read-only here, and
a test that cannot pass as written goes up, never under the knife —
routed per *Routing a decision* on an interactive plan, `[!]` naming the
test on an autonomous one, per the single source.

## Record the outcome

The `[x]` path has a skill of its own: in interactive runs the executor
hands the phase back `[>]` carrying a `> Testing:` note (*Awaiting the
human's checks*, below) and `/close-phase` performs this section and the
two that follow (naming review included); under `/run-workflow` the
executor performs them inline, markers left in place. The `[!]` and `[~]`
outcomes are always recorded directly by the executor — failure never
routes through `/close-phase`.

```
- [x] **Phase N**: title
  > Done: brief description
  > Files: path/a.py, path/b.py, ...
  > Review: judgment-level findings flagged for the quality check (omit if none)
```

```
- [!] **Phase N**: title
  > Issue: root symptom and current diagnosis
  > Attempted: 1) <fix tried> → <error signature>  2) <fix tried> → <error signature>
  > Files: path/a.py, path/b.py, ...
```

```
- [~] **Phase N**: title
  > Blocked: <what blocks it — e.g. a pre-existing red baseline nobody owns>
```

**Always list ALL touched files in `> Files:`** — later baseline checks
attribute regressions by them, and `/repair-phase` diffs against them.
`> Attempted:` is mandatory on `[!]`: it is the input of `/repair-phase`,
which must not repeat those attempts.

## The phase commit

One commit, at the end, the phase's code and its own plan status update
together — so the next phase starts from a clean tree:

```bash
git add -A && git commit -q -m "wf(phase N): <title>"
```

A phase closing `[!]` commits too, as `wf(phase N): FAILED — <title>`, and
leaves the failing code **in place**: repair has to see it.

A choice the phase made that the plan did not settle — why this way, what was
rejected — goes into `notes.md` under a `## Phase N` heading before the
commit, per `refs/foreman.md` → *The foreman* (per-phase rationale): finalize
reads the file, not the memory of a session that no longer exists.

## Notify the foreman

`Mode: autonomous` only — the outcome's road is the one *Routing a decision*
names. Under `/run-workflow`, send the workflow's foreman chat one message
after the phase commit with the outcome (done, FAILED, or blocked), in the
exact format and by the exact mechanics of `refs/foreman.md` → *Sending to
the foreman*. Read that section when you reach this step, not at start — it
is the only part of the foreman layer an executing session needs.
Best-effort: no `foreman.json`, no messaging tool, delivery refused → skip in
silence. The notification never fails a phase and is never worth a retry
loop. The skip is the message's alone — **the record is written either way**,
in both modes: an interactive plan has no foreman and sends nothing, and its
record is exactly the same.

## Routing a decision

Three things travel out of a phase, and the plan's `Mode:` picks the road for
all three (`contracts.md` → *Where decisions travel*). **This is the single
source of the fork** — the skills and the sections below cite it, they never
restate it.

| what travels | `Mode: interactive`, and a plan carrying no `Mode:` | `Mode: autonomous` |
|---|---|---|
| a **question** the plan's author owns | put to the user at the gate, in this conversation, batched with the rest, before the executor is launched; mid-phase the executor cannot ask, so it stops `blocked` and the question comes back to this same gate | there is no gate: the executor closes `[!]` with a `plan-defect claim` and the launcher holds while the foreman decides (`refs/foreman.md` → *Plan-defect claims*) |
| an **outcome** — done, FAILED, blocked, closed short, result rejected | reported at the gate, in this conversation; no message, and nothing waits for one | one message to the foreman chat, best-effort (*Notify the foreman*) |
| a **re-planning** — the remainder of a short close, the phases after a rejected result | sized with the user at that same gate, and the plan edit committed as usual | the foreman sizes it; the executor never appends phases |

In every row the **record is owed in both modes**: `notes.md` under the phase's
`## Phase N`, and the plan. The message belongs to the autonomous road alone,
and a rule naming the foreman without naming its road is a relay an interactive
workflow cannot escape. **An interactive workflow is one conversation**: the
gate, the verdict and the re-planning all happen where the user is, and the
work between them happens in an executor that returns here. There is no second
chat to command and nothing to relay, and `refs/foreman.md` is never loaded
for it. A plan carrying an old `Channel:` header is read as its `Mode:` says;
the field is ignored, and `next-phase.py --validate` says so.

## WIP checkpoints

A phase big enough to die halfway must leave evidence along the way. Two
triggers, one mechanic:

- **Coherent sub-result** — the phase reaches something demonstrable (the
  schema exists, the logic passes its test) with substantial work still
  ahead: checkpoint it, without asking. In practice this concerns
  interactive phases, sized to "something a human can look at"; an
  autonomous phase rarely lives long enough to need one.
- **Context running out** — the same mechanic, forced: checkpoint what
  exists and exit; the next executor resumes from a clean tree.

Commit and note travel together — never one without the other, so the
note's `commit:` always points at code that exists:

```bash
git add -A && git commit -q -m "wf(phase N): partial — <sub-result>"
```

Keep the phase `[>]` and write (or replace) the structured `> WIP:` note.
**This is the single source of its format** — the skills cite it, they
never restate it:

```
> WIP: done: <demonstrable so far> | missing: <what remains of Done:> | next: <first concrete action> | commit: <short hash>
```

Each key earns its place at resume time: `done:` is what a fresh executor
must not redo, `missing:` is what remains of the phase's own `Done:`,
`next:` is where it starts, `commit:` is the hash it diffs from instead of
trusting the story. Free prose is what made resume unreliable: a fresh
session reading vague prose reinterprets, and reinterpretation is how work
gets redone or contradicted.

## Planned batches

A phase carrying `> Batches:` was sized as one decision whose diff is too large
to read as one unit (`contracts.md` declares the field). **This is the single
source of its format** — the skills cite it, they never restate it:

```
> Batches: 1 <label> | 2 <label> | … | K <label>
```

Numbered from 1, one short label each, pipe-separated — the same shape as
`> WIP:` and for the same reason: a reader and a grep must agree on where one
item ends. `K` is the count the commits below refer to.

**A batch is not a checkpoint**, and that difference is why both exist.

- A **checkpoint** interrupts: partial commit AND the structured `> WIP:` note,
  because something is about to stop — a dying context, an executor returning
  early.
- A **batch** does not interrupt: partial commit, then **straight on in the same
  session, no `> WIP:` note and no handover**. Writing one announces a stop that
  is not happening, and the next reader takes a phase mid-work for an abandoned
  one.

The commit names which batch it is, so the plan's list and the log line up:

```bash
git add -A && git commit -q -m "wf(phase N): partial — batch M/K <label>"
```

If the session does stop after a batch — context out, executor gone — that stop
is an ordinary checkpoint and gets the `> WIP:` note **then**, naming the batch it
stopped after. The note marks the interruption, never the boundary.

## Handing a defect to repair

A defect found at the gate — the executor handed the phase back, the human
exercised it and something is demonstrably wrong — is not the workflow chat's
to chase. Debugging is the most context-hungry thing a phase does, and this
conversation is the one place where that context is expensive: it is carrying
the plan, every gate and everything decided so far. So the defect goes to a
**repair agent** that exists only for it and is thrown away after — fresh eyes
by construction, because a subagent starts with nothing.

The workflow chat's part is two moves and no diagnosis:

1. **Record** — the tree is clean by construction (the executor committed
   before it returned), so nothing needs checkpointing; what the human saw is
   the specification and goes on the phase as `> Issue:`.
2. **Launch `/repair-phase`**, here, in this same conversation: it asks the
   human what is wrong — their account, not the executor's diagnosis —
   records it, marks the phase `[!]` on their confirmation for as long as the
   repair lasts, runs the repair in an agent, and puts the verdict to the
   human. A phase that came in `[>]` goes back `[>]` with a `> Repaired:` note
   and its gate resumes here; one that came in `[!]` closes `[x]`.

**One agent is one attempt**: a repair that eats a whole context without a
green signal is not a bug but a plan problem, and it goes out as `blocked` —
per *Routing a decision*: to the user here on an interactive plan, to the
foreman on an autonomous one — rather than to a second repair.

## When the phase outgrows its executor

A phase that does not fit in one executor's context was sized wrong — the
plan's own doctrine, applied to itself. The executor checkpoints (*WIP
checkpoints*) and returns; the gate sees a `[>]` phase with a `> WIP:` note
and asks **is there a seam here**, and the answer decides between two
mechanics:

- **There is a coherent, demonstrable sub-result, and what exists is
  green** → **close short**, the cleaner of the two. Nothing half-cooked has
  to survive a boundary: the phase ends properly, the tree is clean, the
  markers are reviewed, and the plan grows a phase for the remainder.
- **The work is mid-air** — a refactor half applied, a schema with nothing
  using it yet — → **relaunch**: a fresh executor resumes from the `> WIP:`
  note (*Resuming a `[>]` phase*, below). Once; a second overrun on the same
  phase is the sizing speaking, and the answer is the short close or a
  re-planning, never a third executor.

**Closing short**, in order:

1. **Rewrite the phase's `Done:` to the sub-result actually reached**, and
   its `Files:` to what actually landed, with the user's ok. At the gate the
   workflow chat is the only writer of the plan, so it makes this edit
   itself — on this phase, never on the others. A narrowed `Done:` is not a
   lowered bar: it is the plan being corrected to match what was really
   built, which is the precondition for `[x]` to keep meaning what it says.
2. **Close through `/close-phase`** like any other phase: naming review,
   `Done:` gate re-run — it passes now, honestly — `[x]`, ONE phase commit.
3. **Report that it closed short**, naming what remains in one line, so the
   plan grows the phases that carry it — the outcome row of *Routing a
   decision*: said at the gate on an interactive plan, a message to the
   foreman on an autonomous one. What remains also goes to `notes.md` under
   the phase's `## Phase N` in both modes: a remainder that lives only in a
   message dies with the message.

The remainder is a **re-planning**, and it takes that row's road: sized with
the user at this same gate on an interactive plan, and the plan edit committed
as usual; on an autonomous plan the foreman sizes it and the executor never
appends phases. Either way sizing belongs to whoever owns the plan, not to the
phase that just overran — which is evidence about the sizing, not only about
itself.

**Resuming a `[>]` phase** — the calling skill decides *whether* to take
it over; this is *how*: read the `> WIP:` note, run
`git log --oneline` over the phase's `partial` commits and
`git diff <commit>..HEAD`, and continue from `next:` toward the phase's
own `Done:`. What `done:` claims and the diff confirms is not redone.

**The disk is the whole handover.** An executor is a subagent: it dies with
the turn that launched it, so there is never a live one to reach, and the
`> WIP:` note and the diff are the authority by construction. A `[>]` phase
with no `> WIP:` note and no `partial` commit carries no evidence — reset it
to `[ ]` with `> Execution interrupted, phase available for retry` rather
than guessing what a dead executor did. Uncommitted changes with nothing to
explain them are never guessed at either: report them and ask.

**A planned batch is not an interrupted phase.** On a phase carrying
`> Batches:`, `partial` commits are the expected shape of work in progress, so
the evidence question is which batches the commits cover, not whether the
executor died: a `[>]` phase whose partials stop at a batch boundary and whose
executor is still running is mid-phase, not interrupted. What says
*interrupted* is what always did — no live executor, and no `> WIP:` note to
say where it stopped.

Checkpoints are not phase commits: `/finalize-workflow` squashes them with
everything else, and red-baseline attribution keeps matching against the
`> Files:` of *completed* phases, which a `[>]` phase does not yet have.

## Awaiting the human's checks

Interactive mode only — an unattended phase has nobody to hand a check to.
**This is how every interactive phase comes back from its executor**: the
code is finished, the `Done:` is green, and the phase is not closed. It is
committed and left `[>]`, so nothing closes on a result nobody has looked at
yet — the human's `Verify: now` checks, the browser pass and the judge on a
`ui` phase, and the naming review all happen at the gate, where somebody can
answer.

The mechanic is the checkpoint above — a `partial` commit — plus the note
that says what it waits for. **This is the single source of its format** —
the skills cite it, they never restate it:

```
> Testing: awaiting the human's `Verify: now` checks | commit: <short hash>
```

**Three ways out of the gate**, and only the middle one is more work here:
the checks pass → close; something is off and it can be fixed here →
ordinary work on the open phase — a correction with no decision open the
workflow chat applies itself, a defect that reproduces goes to
`/repair-phase` (*Handing a defect to repair*) — commit, present again; the
result is wrong at the root → the `Done:` passed, so the phase closes `[x]`
carrying the verdict as `> Review:`, the `result rejected` outcome and the
re-planning of the phases that have not run both take their rows in *Routing
a decision* — the user at this gate on an interactive plan, the foreman and
`/resume-workflow` on an autonomous one.
**Never `[!]` on a person's judgment** — `common.md` → *Failure and repair
notes* has both reasons: it aims an automatic repair at green code, and the
work itself is usually sound.

**Nothing is closed and nobody is told before the person has answered.** The
`[x]`, the phase commit and the outcome report all belong on the far side of
this gate: a phase reported done while its checks are still unrun is the
failure the gate exists to prevent.

The checks themselves stay in their own `> Verify: now` notes: one syntax,
not two. `next-phase.py` reports such a phase as `blocked:` — only the human
clears it, so an unattended run stops and says so instead of resuming a
phase with nothing left to implement, and `/execute-phase` reads it as its
own gate coming back. What the checks turn up is ordinary work on the
still-open phase: commit it the same way, replace the note. The human's ok is
what runs `/close-phase`, and closing drops the note.
