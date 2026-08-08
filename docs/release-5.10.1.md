# 5.10.1 — the foreman field-tested: the title is the address

5.10.0 shipped the foreman protocol designed on paper; this release is what a
live test against the desktop app's session tools taught, the same day. Three
hard limits surfaced, and each one simplified the design instead of
complicating it.

## What the field test found

1. **A session cannot rename itself.** The desktop session-management tools
   (`set_session_title`, `get_session`) refuse the *current* session.
   Retitling *another* session works — which is exactly what deposition
   needs, and it turned out to be the only rename the protocol requires.
2. **A session cannot read its own id.** Not in the environment, not via
   `get_session`, not via transcript search (all exclude the current
   session). So `foreman.json` cannot record "my id" — the 5.10.0 format was
   recording something no session can know about itself.
3. **Unattended sessions have no messaging at all** — `claude -p`
   sub-sessions, scheduled runs: they can neither send nor receive
   (documented platform behavior, confirmed by the tool contract). The
   best-effort rule was designed for exactly this and survives unchanged.

## The simplification

**The foreman's address is its chat TITLE.** A session cannot know its own
id — but every *other* session sees both title and id in `list_sessions`.
So the file records a title, children look it up and message the id they
find, and the one manual step in the whole protocol is the user renaming
the foreman chat — which the skills now suggest verbatim at take-command:

> Rinomina questa chat in `wf:<slug>:foreman` — è l'indirizzo a cui le chat
> di fase mandano gli esiti.

`foreman.json` slims down accordingly — `foreman` (the title), `since`,
`history`; the `status` field is gone (an active file IS active) — and
`handover.md` is dropped entirely: a takeover from a dead chat must work
from the plan and `notes.md` alone, so the extra file was a promise the
protocol could not keep.

Two elegant consequences of title addressing:

- `/resume-workflow`'s foreman check needs no identity test: no other
  session bears the title → claim it (idempotent when this chat already had
  it); another session bears it → report, and depose only on the user's
  word.
- `/finalize-workflow`'s closing message needs no "am I the foreman?"
  guard: `list_sessions` excludes the current session, so when the
  finalizing chat IS the foreman the lookup finds nothing and the skip is
  automatic.

What the deposition test exercised for real: farewell message delivered to
a live session (it woke and acted on it), retitle of the old foreman to
`wf:<slug>:deposed`, `foreman.json` rewritten with the deposed entry in
`history` — each primitive verified against the actual desktop tools.

S30 updated to the simplified contract (title lookup defined in `common.md`,
no `handover.md`, nobody restates the JSON body or the message formats, the
rename suggestion pinned verbatim across its three files — the restatement
clause proven by mutation). An independent inspector agent reviewed the whole
protocol before release; its two mechanical findings (a dead tool grant from
the abandoned self-rename design, a take-command that was not idempotent for
the foreman's own status queries) are fixed in this same release. 186
assertions over 29 scenarios, green.
