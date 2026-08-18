# 5.18.0 — plan questions go to the foreman first

Reported by Giovanni, from the flow the plugin itself recommends: the whole plan
authored with the foreman chat (`/write-workflow`), then each phase executed by
hand in a fresh chat (`/execute-phase`). Mid-phase the executing chat hits an
ambiguity in the plan and asks *him*. He should not be the first responder: the
foreman authored the plan and holds the reasons it is shaped that way, so it
answers better than the human, who would have to reconstruct them.

## What existed

Child → foreman was **report-only**: `phase N done` / `FAILED` / `blocked` /
`plan changed` — none of them expects a reply. The one question on the channel,
`stop-work?`, flows from `/run-workflow`'s inspector and carries the *opposite*
decision policy: the foreman is forbidden from judging and must put the question
to its user immediately. So *"a phase chat needs the plan clarified"* had no
channel at all; its nearest neighbour, `blocked`, informs the foreman after the
fact.

## The flow

1. the child hits the ambiguity and does **not** ask the human: it sends
   `clarify?` to the foreman;
2. the foreman answers — editing and committing the plan itself when the answer
   changes it (`— plan changed, commit <short hash>` on the reply); the child
   re-reads the plan from disk and shows the human *what the foreman decided*,
   asking confirmation;
3. a foreman in doubt does not guess: it replies `clarify: ask-user — <the
   question, rephrased better than the child put it>`, and the child asks the
   human.

The human lives **only in the child chat**; the foreman never speaks to the
person directly. Same upward channel as `stop-work?`, opposite decision policy —
`stop-work?` forbids the foreman from deciding, `clarify?` imposes deciding as
its first attempt — and the human sits at opposite ends: at the foreman for
`stop-work?` (its children are `claude -p`, with nobody in front of them), at
the child here.

## The boundaries

- **Scope** — plan ambiguities only: objective, `Done:`, `Files:`, `Pattern:`.
  Local technical choices and the phase's own approval gates stay with the human
  in the child chat, or interactive mode loses its point.
- **Who edits the plan** — the foreman, committing the edit itself (already its
  prerogative). The child never touches the plan: the plan on disk is the state,
  not the message text.
- **The human rejects** — the rejection and its reason travel back up exactly
  ONCE; no convergence → the question is the human's, as it is today. In an
  interactive phase the human is watching; a ping-pong between two chats is
  worse than asking directly.
- **Precondition, for free** — the child sends only when the foreman is another
  session, and the title lookup already answers this: `list_sessions` excludes
  the current session, so finding nothing means this chat is the foreman or the
  foreman is dead — both land on asking the human directly, today's behaviour.
- **Foreman unreachable** — the report channel's silent skip does not apply to a
  question: no reply within ~3 minutes (the foreman is an idle chat the message
  has to wake) → the child asks the human, saying the foreman did not answer.

## What changed

- `refs/common.md` → *The foreman* owns the whole protocol, as for every other
  message: the `clarify?` format line, the two-questions paragraph (same
  channel, opposite policies, the human at opposite ends), the *Clarify*
  paragraph (scope, reply paths, one-round cap, precondition, timeout), and the
  best-effort rule gaining its one exception — an unanswered question falls back
  instead of skipping in silence.
- `/execute-phase` routes plan ambiguities upward at both interruption points —
  before the Step 3 gate (the answers fold into the gate as settled decisions
  presented for confirmation) and on a Step 4 mid-phase blocker — citing the
  section, restating nothing.
- README: the *Stop-work* section loses "the protocol's only question", and a
  *Clarify* section tells the story from the user's side.

Depends on #12 (5.17.1): a foreman that executes phases itself is not a distinct
addressee for any of this. Closes #13.

## The guard

S30 owns the foreman protocol; it grew three checks — `clarify?` defined in
common.md's section, the `ask-user` reply path present, `/execute-phase` citing
the routing — each proven by a mutation that removes the 5.18.0 behaviour from a
copy and watches the guard fire. The existing restatement check already forbids
any skill from carrying the message format itself.
