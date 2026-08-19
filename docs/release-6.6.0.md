# 6.6.0 — repair splits in two, and a defect leaves the phase chat

Debugging is the most context-hungry thing a phase does, and the chat holding
the phase is the worst place to do it: it is carrying the objective, the
approval gate, the files, every decision so far. Until now the only way out
was for the phase to fail its `Done:` and close `[!]`, which is a heavy price
for *"this button saves twice"*.

## A defect goes to a chat of its own

New in the shared core: **handing a defect to repair**. The phase chat's part
is two moves and no diagnosis — checkpoint (`partial` commit and `> WIP:`
note, so the repair works on committed code), then **stand down**: the working
tree belongs to the repair chat until it hands back. A phase chat that keeps
tinkering "meanwhile" is the two-writers failure the whole protocol is shaped
to avoid.

Everything else happens in the new chat, and it ends where it started: the
phase comes back `[>]` with a `> Repaired:` note, the phase chat is sent the
outcome, and you carry on there. The repair chat is thrown away.

## `/repair-phase` asks, `/repair-phase-agent` does not

The old skill was written for a machine — *no questions*, outcome as the exit
condition an evaluator reads — and was also what a human got when they typed
it. Now the two environments are two skills, and **the method is not
duplicated**: the base holds the whole repair, the variant holds what changes
when nobody is in the room.

**`/wf:repair-phase`** — with you:

1. **Asks what is wrong first**, always, even when the plan carries an
   `> Issue:` and the other chat has an account. Those are *previous
   diagnoses*, and this chat exists because previous diagnoses are suspect.
   Your account of the symptom is the specification.
2. **Asks to confirm `[!]` while the repair lasts** on a phase still `[>]` —
   a real state change: nothing else in the plan may start, and any chat
   looking at the plan sees why.
3. Diagnoses from scratch and repairs, **with no questions in between** —
   that is what keeps it cheap for you.
4. **The verdict is yours.** It shows what it was, what changed, which signal
   went green, and stops. A repair that grades itself is what this chat was
   opened to avoid. On your ok it closes an `[!]` phase, or hands a `[>]` one
   back and tells you to return to the chat that owns it.

**`/wf:repair-phase-agent`** — `[!]` only, no questions at either end, never
hands back, outcome as the run's exit condition. `/run-workflow` reaches this
one; both of its call sites moved.

**One chat is one attempt.** A repair that eats a whole context without a green
signal is not a bug but a plan problem: `[!]` stays with `> Repair attempted:`,
the foreman gets the `blocked` line, and the next conversation is a
re-planning, not a second repair.

## `[!]` re-read

6.2.1 said `[!]` is a machine verdict, never a human one, and that stands —
but the reason is sharper now. What the marker asserts is that **something is
demonstrably broken**: a red signal, or a defect that reproduces. A person is
usually the one who saw it, and confirming `[!]` for the duration of a repair
is not a human verdict — it is a human pointing at a machine-checkable fact.
The verdict a person cannot make is still the other one: a phase whose result
they judge wrong with everything green.

## The guards

S30 gains four checks — the base's two ways in, its opening question, the
shared core's hand-off section, and the existence of the unattended variant —
plus two mutations: delete `repair-phase-agent` (the launcher would reach the
interactive one and hang on its first question), and take away the opening
question. S23 already covers the new variant: it cites its base and stays
thin. The launcher's test assertions moved with its prompts.
