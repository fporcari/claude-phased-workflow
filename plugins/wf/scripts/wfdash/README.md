# wfdash — the dashboard of a phased workflow

A local page, opened at the side: the plan as a tree on top, and below it one
pane holding the detail of whatever row is selected — which agents ran the
phase, what they are doing right now, what they produced, what it cost.

`/wf:dashboard` opens it: the skill starts the server on the current
repository, reads the port from its first line and opens the page in the
session's Browser pane. By hand:

```bash
python3 plugins/wf/scripts/wfdash/server.py -C /path/to/repo
```

The port is the first free one from 8787 up, printed on the first line, so
several repositories are watched at once. `-P` binds exactly that port and
never walks up — which is what `.claude/launch.json` needs, since it declares
the port its preview pane opens: it carries the `wfdash-thin` and
`wfdash-dense` configurations, with the repo to watch in their `runtimeArgs`.

A repository with no plan is not an error: the page shows a no-plan state
carrying the `/wf:write-workflow` command to copy out.

## An agent is a chat or a subagent

They carry the same fields, because the question asked of both is the same. On
the dense test repo: 32 chats and 28 subagents, the subagents nested under the
chat that spawned them.

| field | source |
|---|---|
| name | the title the chat gave itself (`custom-title`), or the subagent's `agentType` |
| task | the first prompt, or the subagent's `description` |
| start ts, duration | first and last `timestamp` of the `assistant` rows |
| active | transcript touched in the last 120 seconds |
| doing now | last `tool_use`: name, argument, seconds elapsed |
| trail | the last 8 tool calls, newest first |
| produced | last `text` block, plus the count of writes and bash calls |
| cost | turns, output, reread, reread/output, $ equivalent |
| thermometer | reread/output against the median of the plan's phases |

## The tree

The root is `.phased/roadmap.md` where there is one: below it the
macro-phases, below each of those the phases of its own plan. A repo with no
roadmap has the active plan as its root and its phases directly under it.

The state of a macro-phase comes from where its plan directory sits — `done/`
closed, `active/` in progress, neither one not started — never from a judgment
this tool makes. A finalized workflow leaves no directory behind at all:
`/wf:finalize-workflow` drops `.phased/` from the squash that reaches the
parent, so `.phased/done/<slug>/` survives only on the `wf/` branch that
produced it, and the tree reads it there with `git ls-tree` and `git show`.
The scan is cached against the branch tips.

A plan whose slug names no macro-phase is not dropped: it lands at the foot of
the tree as a node of its own.

Per phase, the icon is derived from the plan's own facts:

| icon | meaning |
|---|---|
| `○` | not started |
| `✓` | closed |
| `✓!` | closed, carrying a `> Review:` |
| `✕` | failed `[!]` |
| `⊘` | blocked `[~]` |
| `◐` | in execution |
| `👤` | `[>]` with a `Testing:` note — awaiting the human's checks |
| `⚠` | an active agent of the phase has API errors |

Closed rows are dimmed; their icon is not, so a `✓!` still catches the eye.

## The pane

- **Phase** — the detail of the selected row, with three sub-tabs: Overview
  (the agents of the phase and their trail, then what needs attention, then
  the checks to verify), Log, Notes. A phase of a plan read from a branch has
  no agents and no log: its notes are what there is to read.
- **Foreman** — the supervision chat as the dashboard sees it: whether it
  is running, the exchange read back out of its transcript, and a box that
  queues a message for the chat to deliver.
- **Active** — only agents touched in the last 120 seconds.
- **Alerts** — checkable facts only: `[!]`, `[~]`, `[>]` phases, the `[>]` ones
  awaiting the human's checks, the API errors of an **active** agent, and an
  active agent whose reread/output passes twice the median.

**Off plan**, above the grid, holds the agents belonging to no phase.

## The Verify: steps

The `Verify:` steps a plan carries are shown as text, with their `when`, and
nothing is recorded: the ok on a step is given in the conversation, to
`/wf:close-phase`. A tick persisted where no skill reads it would be a second
source of truth for that gate.

Where a phase carries `> Verify:` notes written by execution, those are the
list; otherwise the `- Verify:` fields written by planning. Never both, or
every closed phase would show its checks twice.

## Attribution to phases

Chats title themselves `wf:<slug>:phase-N`. The slug is part of the key:
without comparing it, the phases of another workflow in the same repo end up
attributed by number. The dense test repo has four plans
(`macro2-replica-convergence`, `macro1-legacy-data-collection`,
`bridge-rebase-new-core`, `wf4-core-bridge`) and the median computed without
the check was wrong: 262.4 instead of 272.2.

Phases run in an unattended run have no titled chat: the row stays at `—`,
never at zero.

## The steps an agent declares

`~/.claude/tasks/<sessionId>/N.json` is the session's own todo list, one file
per item. The dashboard reads it as-is and shows it as an estimate, always:
the list belongs to the agent, it is written at the agent's grain, and nothing
in it is certified. Three consequences, all deliberate:

- a session that never wrote a todo reads as **no declaration**, never as 0% —
  an empty bar would say the opposite of what is true;
- an item going back from `completed` to `in_progress` moves the bar
  **backwards**: a retreat is a thing to see;
- several chats on one phase are **not summed** — two lists are written at two
  grains, and their sum measures nothing. The most recently active chat that
  declares is the one working now.

The bar shows where a phase is the subject: the running phase's grid row and
its pane head. The card shows the agent's own words — the `activeForm` of the
item in progress — and the list itself.

## The lifecycle strip

Four stages in the header, each lit only by the artifact that proves it:

| stage | artifact |
|---|---|
| `plan` | the `wf: plan for <slug>` commit |
| `exec` | every phase marked `[x]` |
| `quality` | the `> Quality check:` stamp under `## Quality check` |
| `final` | the plan directory under `.phased/done/` |

Nothing is predicted and no stage is inferred from another. Scoping has no
stage: it leaves no artifact on disk. The stamp counts only under its own
heading — the same words inside a phase note are a phase talking about the
check, not the check having run.

## Security

Listening on `127.0.0.1` and nothing else, and every request carries the token
this process mints — reads included, so the page is the only client. It starts
nothing and writes into no session: the launch button and the foreman box queue
a request that the chat watching the repository serves, so the authority over
the work stays with the skills that own it. The only write is that queue,
under `${TMPDIR:-/tmp}/phased-workflow-<uid>/` — never the working tree, and
nothing durable under `~/.claude/`.

## Incremental reading

Transcripts are append-only and reach a few MB. `Scan.update()` reads only the
bytes added since the last call and keeps its state between requests, so
polling every 5 seconds costs the tail of the file, not the file.

## Tests

```bash
bash tests/orchestration/run_tests.sh
```

Bare asserts, no framework: every `tests/wfdash/test_*.py` is a script that
exits 0 clean, and scenario S51 of the plugin's own harness runs the whole
directory under bash and zsh, plus flake8. Add a file, it runs.
