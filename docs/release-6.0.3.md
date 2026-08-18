# 6.0.3 — the chat titles itself, and the channel is tried in the right order

Two field findings from the same interactive run, both on the messaging
channel, both of the same shape: **the protocol described an environment that
had moved on.**

## The channel is tried in the right order

The section named two worlds — desktop (`list_sessions` + `send_message`) and
CLI (`ListAgents` + `SendMessage`) — and never said how a session decides which
one it is in. Claude Code inside the desktop app is neither: it carries both
toolsets. The environment then tilts the choice the wrong way, because
`ListAgents` is always loaded while the session-management tools sit behind
`ToolSearch` — the branch that works is the one you have to go and fetch, the
one that fails is already there. The run read an empty `ListAgents`, concluded
the foreman was unreachable, and fell back to asking the human. That is the
worst failure this protocol has: it degrades in silence into attending two
chats, the exact thing the foreman exists to avoid.

So: **`list_sessions` first, always.** Fall back to `ListAgents` only where
that tool does not EXIST — never because it came back without the title. And
the inference that licensed the fallback is now bounded to the channel that
can draw it: an empty `ListAgents` is no evidence about a desktop foreman.

## The chat titles itself

`set_session_title` accepts the literal `"self"` (verified on 2.1.234) and
returns the title it replaced. The 5.10.1 note — the tool refuses the current
session — was true when it was written and is now stale, and it had cost the
protocol its only manual step: the user renaming the foreman chat by hand.

- **Take command titles its own chat.** `/write-workflow`, `/import-workflow`
  and `/resume-workflow` set `wf:<slug>:foreman` themselves. The ask survives
  as the fallback where the tool is absent (CLI, unattended runs), in the same
  canonical wording, so nothing regresses there.
- **Phase chats title themselves too**, `wf:<slug>:phase-N — <phase title>`,
  at the start of `/execute-phase`. Nothing addresses a child — only the
  foreman's title is an address — so this is legibility, not protocol: the
  session list stops being a wall of auto-generated summaries.
- **The return value is useful on its own**: a session cannot read its own
  title, but it can learn the one it just replaced, which is how a re-claiming
  foreman notices the chat had drifted off its name.

## The guard

S30 gains three checks — the section names the self-rename, it no longer
claims a chat cannot rename itself, and every skill that titles a chat
declares the tool — plus two mutations: restoring the stale claim on a copy,
and stripping `set_session_title` from `/execute-phase`. Both fire.
