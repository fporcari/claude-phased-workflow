# 6.0.2 — the clarify decision survives a dead reply path

Issue #14, from the second half of the `clarify?` field test. 6.0.1 fixed the
first failure (a permission prompt killing the reply in the unattended foreman
chat) by ordering the reply before the plan edit. The very next round proved
that ordering solves the wrong layer: the reply path itself broke — the
foreman tried the incoming message's `from` id, its `name`, and the
`ListAgents` roster, and none resolved — while **the plan commit, the channel
6.0.1 had demoted to second place, was the only thing that delivered the
decision**. The child got its answer by re-reading the plan from disk.

The conclusion is the repo's own motto applied to the reply path: *every arrow
into a chat can die; every arrow into disk survives.* The message is the
notification; the disk is the state.

## The design (settled in #14)

1. **The decision lands on disk before the reply.** The foreman records it in
   `notes.md` under the phase's `## Phase N` heading and commits — its own
   file, never contended with the child's working tree.
2. **The plan edit travels in the reply.** `clarify: <decision, one line>`,
   plus — when the decision changes the plan — the exact edit as before-text →
   after-text pairs (never a literal patch: the child's plan carries a `[>]`
   marker the foreman never saw). The foreman does not touch the plan any
   more: one writer per working tree, and mid-phase that writer is the child.
   6.0.1's `— plan edit follows` is gone.
3. **The child applies on acceptance.** It shows the human the decision and,
   accepted, applies the foreman's edit verbatim — the hands, not the author —
   committing `.phased/` alone as `wf: clarify phase N — <one line>`. Nobody
   asks permission for that commit: the workflow branch is unpushed, the edit
   touches the plan directory only, and the human gate was the acceptance
   itself.
4. **The timeout re-reads the disk before bothering the human.** A committed
   decision found in `.phased/` — notes included — IS the reply: the child
   presents it for confirmation, noting the message never arrived. Only a
   silent disk hands the question to the human as the foreman's failure to
   answer.
5. **The reply tool is named.** On the desktop the reply travels by
   `send_message` (session-management) with the incoming message's `from` as
   `session_id`. `SendMessage` does not resolve desktop sessions or their
   titles — field-tested: three addresses tried, none reachable — and its
   "copy the from as your to" advice belongs to the agent world.

This also removes a failure class the test exposed incidentally: the foreman
committing the plan from another directory while the child held uncommitted
edits on the same file — two writers on one working tree.

## The guard

S30 swapped the 6.0.1 reply-order check for four: decision-on-disk before the
reply, child-applies-on-acceptance, the timeout's disk re-read, and the named
reply tool — the first and third proven by mutations that restore the dead
behaviour on a copy and watch the guard fire. Closes #14.
