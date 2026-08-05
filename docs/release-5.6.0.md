# 5.6.0 — the interactive plan says which model and which effort, and shows it on a board

An asymmetry between the two branches of the automation fork, found by reading them
side by side. On an autonomous plan the `## Suggested execution config` table sets
model and effort per phase, the launcher reads them by column position, and
`/execute-phase-agent` scales its exploration to the effort it was given. On an
interactive plan there was nothing: one prose sentence in `/execute-phase`
(*"`opus` floor, never `sonnet`"*), and for effort not a word — not in the plan, not
in the skill, not in the README.

The consequence was not that the interactive path ran at the wrong effort. It is
that nobody was ever told what the right one would be, and how wide `/execute-phase`
explores before its approval gate was governed by nothing at all.

## The `Run:` line

Every phase of an interactive plan now carries one:

```markdown
- [ ] **Phase 2**: table foo with its TH UI (model + webpage)
  - Run: opus / low
  - Files: packages/foo/model/foo.py, packages/foo/webpages/foo.py
```

**It is advice, not enforcement, and it cannot be otherwise.** Model and effort are
chosen when the session starts, before any skill has read the plan — an interactive
phase runs in a chat the user opens by hand. So the line's whole job is to reach a
human *before* that chat exists, which is why it is written into the plan rather
than only said during planning: the chat that needs it is opened days later, when
the planning conversation is gone.

Three points therefore state it, and the order matters:

| Where | When |
|---|---|
| `/write-workflow` — in the presented plan, and again in the closing message for Phase 1 | while planning |
| `/resume-workflow` — quoted in *Prossimo passo* next to `/execute-phase` | before the chat is opened |
| `/execute-phase` — reads it as a given, not as something to reconsider | once it is too late to change |

## Two values, and why `sonnet` is not one of them

`opus` is the floor and the default. `sonnet` never: that is the standing rule for UI
and declarative work, which is most of what interactive mode exists for, and a phase
mechanical enough for `sonnet` belongs on the autonomous side of the fork.

`fable` only where inventive work survives *past* the approval gate — architecture to
invent, an unknown surface, no obvious decomposition. **Half of fable's usual case is
absent here.** The model-tier map earns it two ways: introspective/inventive work,
*and* unattended work where nobody is watching. Interactive work is watched by
construction, so only the first half can pay — and a phase whose ambiguity is "the
user will say whether it looks right" is not inventive work, it is `opus` work with a
human at the gate.

When a phase does say `fable`, `/execute-phase` now declares itself a contract on the
*output* — the approval gate, one phase, one commit, the outcome format — rather than
a procedure to walk step by step. A prescriptive step list is precisely what degrades
that model, and `/execute-phase` is six steps of it. The autonomous chain compensates
for the same problem by injecting a per-model steer through
`--append-system-prompt` (`fable: act, don't re-derive settled decisions`); interactive
mode has no launcher to inject anything, so the skill carries the steer itself.

## Effort now governs something concrete

`/execute-phase` scales its pre-gate exploration to the `Run:` effort, on the same
scale `/execute-phase-agent` already used: `low` only the listed `Files:`, `medium`
plus their immediate references, `high` up to 2 read-only Explore subagents and the
surrounding package, `xhigh`/`max` up to 3 plus a cross-package consistency pass.
A plan with no `Run:` line reads as `opus` / `high`, so older plans keep working
unchanged.

The advice for choosing it is the one the autonomous branch already argues in three
places, and it applies here for the same reason: a phase whose `Decisions:` and
`Pattern:` were settled during planning is exactly where high effort buys least — it
gets spent re-exploring what the plan already decided.

## Not a reversal of the retired `Model hint:`

5.3.0 removed `Model hint: sonnet` from interactive plans for two stated reasons: it
contradicted `/execute-phase`'s `opus` floor, and nothing read it. Both are addressed
rather than forgotten. The permitted values are `opus`|`fable`, so the floor holds by
construction; and two skills read the line — `/execute-phase` to scale exploration
and to switch its own register, `/resume-workflow` to surface it in time.

## The board in `/resume-workflow`

The `Run:` line has a natural place to be read, and it turned out to be the
supervision command. Where the `visualize` MCP server is present, `/resume-workflow`
renders the plan's state as an inline grid — one row per phase with its state, its
`Run:` hint, its files, and the launch command on the eligible one. What stays prose
is everything that is a *judgment*: coverage, drift, oversizing, why a phase is `[!]`.
A grid shows a position well and argues a finding badly.

Two controls, and the distinction between them is the architecture, not decoration:

- **Refresh** re-runs the skill (`sendPrompt('/phased-workflow:resume-workflow')`). It
  does not redraw the widget in place, because nothing can: a widget is the output of
  a message and a printed message is immutable. So the recomputed report prints below,
  and the old grid stays as the snapshot of when you last looked. Press it on returning
  from a phase chat that has just committed.
- **Open the phase** is a `spawn_task` chip, because one click there opens a **session
  of its own** — the whole point of interactive mode. A `sendPrompt` button would run
  the phase in the supervision chat, on top of a context already full of supervision,
  which is precisely the fresh-context guarantee this chain exists to keep. One chip,
  for the eligible phase only: phases run strictly in order, and a chip per pending
  phase would be a row of invitations to break it.

An automatic refresh was considered and dropped. A `Monitor` on `plan.md` would work —
the supervision chat wakes when a phase commits and reprints the grid — but it costs a
chat kept open and a turn per event, to produce the same reprint a button produces on
demand. A published artifact, which *can* update itself, cannot read `plan.md` at all:
it has no view of the local filesystem.

Where the server or the chip tool is absent, the command degrades to today's text
report with the launch command spelled out — the declared-fallback rule `/execute-phase`
already applies to `ui-test`.

## Actualising an older plan

`/resume-workflow` can now write down what an older plan leaves implicit, on pending
phases only — the `Mode:` header when absent, the per-phase `Run:` line on an
interactive plan — as an approved plan edit with its own `wf:` commit, like the
re-phasing and the stale-`[>]` reset it already offered.

The line it does not cross: **defaults, never gaps.** A missing `Run:` is a default
made explicit (`opus` / `high`), so proposing it costs nothing. A missing `Done:`,
`Pattern:` or `Decisions:` is something the author never settled — that gets reported
and left visible, the rule `/import-workflow` Step 3 already states. Filling it in
would make an open question look closed, and nobody checks it twice.

## Nothing changed in the machinery

`Run:` is a plain phase sub-bullet, so it stays outside everything the validator
checks: it is not a `> Note:` field (no unknown-field warning) and not a config table
(which on an interactive plan would draw a warning of its own). `next-phase.py`,
`run-workflow.sh` and the orchestration suite are untouched — 171 assertions still
pass, and `--validate` reports 0 errors and 0 warnings on a plan carrying both
`Run: opus / medium` and `Run: fable / high`.

`marketplace.json` also catches up: it still declared 5.3.0 in both of its version
fields while `plugin.json` had moved twice.
