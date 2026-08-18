# 6.0.1 — clarify? field-tested: the reply must survive an unattended chat

5.18.0 shipped the protocol; the first live run of it found the crack. Setup: a
fixture repo with a deliberately contradictory plan (the objective promises a
10% discount, the phase details say 15%, the qualifying threshold defined
nowhere), a real desktop chat retitled `wf:<slug>:foreman`, and a child session
executing the phase.

## What the test proved

The upward half works as designed. The child found the foreman by title,
`clarify?` was delivered, and the foreman applied the policy with no prompting
beyond the protocol text: it spotted the plan contradiction on its own, decided
instead of deferring, and never asked its user anything — correct, since in
this protocol the human sits in the child chat.

Then it died where no test of the prose could have looked: **the reply is a
tool call, and the foreman is an unattended chat.** On default permissions the
plan edit and the cross-session send both queue a permission prompt — and
nobody is in front of that chat to approve it. The child's ~3-minute timeout
fired and correctly handed the question to the human, *saying the foreman did
not answer* — the designed degradation, working — but the human then saw the
stranded prompt in the foreman chat and had to attend two chats: the exact
thing the protocol exists to avoid.

## What changed

Two fixes in `refs/common.md` → *The foreman*, one per failure layer:

- **Take-command grows a step 4**: alongside the rename, one line of advice —
  allow this chat to send cross-session messages and commit under `.phased/`
  without asking, because a `clarify?` arrives while the user is in the other
  chat. Advice like the rename, not a mechanism: ignored, the fallback absorbs
  it.
- **The reply comes FIRST, the plan edit after.** 5.18.0 had the foreman edit
  and commit the plan, then reply appending the commit hash — so a reply that
  needed no permission at all queued behind two writes that did, and died with
  them. Now the decision goes out immediately; when it changes the plan, the
  reply closes with `— plan edit follows` and the foreman edits and commits
  after sending. The child re-reads the plan from disk before acting either
  way — the plan on disk is the state, not the message text.

## The guard

S30 grew two checks — the permissions advice present in take-command, the
reply-before-plan-edit order present in the Clarify paragraph — each proven by
a mutation that restores the 5.18.0 behaviour on a copy and watches the guard
fire.
