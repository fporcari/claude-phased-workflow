---
description: Open the dashboard of this repository's phased workflows — the plan as a tree, the agents that ran each phase, what they are doing right now and what it cost. Use when the user asks to see, open or watch the dashboard, or wants the plan on screen instead of in chat.
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(python3:*), Bash(kill:*), Bash(open:*), Bash(ps:*), Bash(tr:*), Read, mcp__Claude_Browser__preview_start, mcp__Claude_Browser__navigate
---

# Dashboard

Start `wfdash` on this repository and open its page. **Read-only on the
repository**: the server serves a page and writes nothing — never in
`.phased/`, never in the working tree.

The page PROPOSES and this chat acts. Its buttons queue a request; nothing is
spawned and no session is written from that process, so a run still goes
through `/wf:run-workflow` and a message to the foreman still through
`refs/foreman.md`. Step 5 is where this chat serves what the page asked for.

The server outlives this turn: a dashboard is watched while the work goes on,
so it is started detached and left running. The user closes it by killing the
process, and this skill says how.

## Step 1: The repository to watch

```bash
git rev-parse --show-toplevel
```

Not a git repository → stop and say so: the dashboard reads `.phased/` and the
transcripts of the sessions that worked in that root, and both are anchored to
it.

A repository with no plan is a normal case, not an error — the page shows its
own no-plan state carrying the `/wf:write-workflow` command. Never refuse to
open on that account.

## Step 2: Reuse a server, or start one

A second server on the same repository is a second page saying the same thing,
so look first:

A live server leaves a registry entry beside its queue (an owner-only file
under `${TMPDIR:-/tmp}/phased-workflow/`), and `--probe` reads it, confirms
over the authenticated endpoints that the server still answers for THIS
repository, and mints a fresh one-shot — every read requires the token, so
asking the ports blind cannot recognise anything:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/wfdash/server.py" --probe -C "<repo root>"
```

A `wfdash on http://…?k=…` line is a dashboard already on this repository:
reuse it — take the whole URL from that line exactly as in Step 3, skip the
start, and say it was already running (the line carries the pid to stop it).
`no wfdash on …` means a stale or absent entry — the probe removes a stale one
itself, so just start a server.

To start one: no `-P` — the server takes the first free port from 8787
up, which is what lets several repositories be watched at once.

`-O` tells the server which chat opened it — **this one**. On a repository with
no workflow the page offers to create one, and the command it sends goes back
here, to the chat the user is already talking to: without this flag the page has
to ask them to pick a recipient instead. `$$` is the skill's own Bash and its
parent is the session, so the pid is read, never guessed.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/wfdash/server.py" -C "<repo root>" \
  -O "$(ps -o ppid= -p $$ | tr -d ' ')"
```

Run it with `run_in_background`. Its first line is
`wfdash on http://127.0.0.1:<port>/?k=<one-shot>  repo: <root>` — **read the
whole URL from that line**, never assume 8787 and never drop the `?k=`: the
port is not known in advance, and the one-shot is the only way the page is
ever let in. No line after a few seconds → report the process output as it
stands and stop.

The one-shot is spent on the first request and exchanged for an `HttpOnly`
cookie, so it authenticates exactly one navigation. A server reused from
Step 2 is no exception: the probe's line carries a freshly minted one-shot,
so its URL opens one new pane the same way.

## Step 3: Open the page

`preview_start` with `{url: "<the URL the server printed, `?k=` included>"}` —
the Browser pane at the side of the session, which is where the user asked for
it. Pane unavailable → `open "<that URL>"` on darwin, `xdg-open` elsewhere, and
say which one was used. From the second load on the address bar carries no
`k=`: the cookie has replaced it.

## Step 4: Report

One message, three facts: the port, the repository, and how to stop it
(`kill <pid>`). Then, from `/api/state`, the one line the page opens on —
how many phases are closed of how many, and which phase is next or what
blocks it. A repository with no plan reports that instead, and says the page can create
one — the command comes back to this chat. Say that the page's buttons come
back here as requests, so the user knows where the work is decided.

## Step 5: Serve what the page asks for

The page queues; this chat carries out. Read the queue whenever the user says
they pressed something, and at the end of any turn spent on this workflow:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/wfdash/outbox.py" -C "<repo root>" --drain
```

`--drain` empties it, so read once and act on everything it returned. Each
request carries a `kind`:

- `run-workflow` → invoke `/wf:run-workflow`; that skill owns the pre-flight,
  the Monitor, the push policy and the foreman relay, and none of it can be
  short-circuited by starting the launcher directly.
- `foreman` → deliver the `text` to the foreman by `refs/foreman.md`, which is
  the plugin's only channel to it.
- `write-workflow` → run the `command` it carries.

Several requests of the same kind are one intent pressed twice, not two jobs:
serve it once and say so. A queue this chat never drains is a queue the user
is waiting on, so never leave one behind unread.

## Rules

- NEVER edit a file of the repository, the plan included: this skill opens a
  view, it does not touch the work — what the page asks for is carried out by
  the skill that owns it, never by this one
- ONE server per repository — reuse before starting
- Never hardcode the port: it is read from the server's own first line
