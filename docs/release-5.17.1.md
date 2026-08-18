# 5.17.1 — the foreman commands and does not execute

A defect found by reading, not by running: `/resume-workflow`'s skill table told
the chat that had just taken command of the workflow to run the next phase
*itself*.

> `/execute-phase` | run the next phase **in this chat**, with an approval gate

The chat reading that line is, per Step 1b of the same skill, the foreman. So the
skill that supervises the plan advised the one thing the hierarchy is built to
avoid — and it contradicted itself twenty lines below, where model and effort
*"are chosen when that chat is opened"*, presupposing a chat about to be opened.

## Why it matters

The foreman's context has to hold the whole plan. That is what lets it answer for
any phase, keep the board coherent while children come and go, and — from
`/run-workflow` — judge whether continuing is worth the tokens. Spend that context
on one phase's implementation and the workflow loses the only session that sees
all of it. A foreman that executes also has nobody to report to and nobody to ask,
so the whole messaging protocol falls back to its degenerate *"when this chat IS
the foreman"* branches, which exist as a safety net and were never meant as the
normal path.

## What changed

- `refs/common.md` → *The foreman* states the rule once: the foreman commands and
  does not execute; a *Next step* naming `/execute-phase` is always worded as a
  fresh chat; launching an unattended run (`/run-workflow`) from the foreman is
  the exception and the intended one — it supervises there, it does not implement.
- `/resume-workflow`'s table now reads *run the next phase in a new chat*.
- `/write-workflow`'s closing message said *"better in a new session, for a clean
  context"* — a tepid suggestion resting on the wrong reason. It now reads *launch
  /execute-phase in a new chat — this one stays the board*.
- `/import-workflow`'s closing message said only *"launch /execute-phase"*, and
  that chat takes command too. Same wording as above.

**Nothing is enforced.** A user who runs a phase in the foreman chat anyway gets
the degenerate branches, which keep working. The rule is about what the plugin
*advises*, and it never advises that.

## The guard

S30 already owned the foreman protocol; it grew two checks — the rule present in
common.md's section, and no shipped skill pairing `/execute-phase` with *in this
chat* — each proven by a mutation that puts the 5.17.0 defect back and watches the
guard fire. 204 assertions, one shape of drift fewer.
