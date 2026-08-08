# 5.11.0 — the run inspector, and the stop-work question

The foreman protocol (5.10.x) gave interactive phase chats a father to report
to, but left the autonomous run mute: its `claude -p` children cannot reach
desktop chats at all (field-tested — headless `ListAgents` sees no desktop
sessions), so during a `/run-workflow` the foreman's board learned nothing
until the run ended.

The observation that closes the gap: **the chat that launches `/run-workflow`
is already watching the run** — it holds a Monitor on the launcher's log,
filtered to the stable `EVENT:` lines. That chat is a desktop chat, so it can
message the foreman. It was already the site inspector; now the role is
explicit.

## Per-phase progress events

The launcher gains one event: `EVENT: phase-done <N> <done>/<total>`, emitted
when the `[x]` count grows after a phase session. Failures and blocks already
had their events; now routine progress has one too. The inspector relays
every event to the foreman in the protocol's message formats — `phase 3 done
— 3/7`, the FAILED line with the phase's `> Issue:`, the run outcome —
best-effort as always, and self-skipping when the inspector IS the foreman
(the `list_sessions` self-exclusion property, again). Unlike the
PushNotification policy (first failure, blocks, run end — what is worth an
interruption), the relay carries everything: the foreman is a board, not a
pager.

## Stop-work — fermo lavori

The inspector holds one power beyond reporting: when what it sees makes
continuing look like wasted tokens — a repair cascade, a tripped budget cap,
phases closing suspiciously instantly, log content contradicting the plan —
it sends the foreman the protocol's one *question* message:

```
[wf:<slug>] stop-work? — <what looks wrong, one line; the run keeps burning until answered>.
```

The foreman does not judge on its own: it puts ONE AskUserQuestion to its
user (*Fermo lavori* / *Continua*) and answers on the message's reply path —
`stop-work: granted` or `stop-work: denied — continue`. On granted, the
inspector kills the background run immediately, accepts that a phase may die
`[>]` mid-flight (the WIP evidence and the stale-`[>]` reset exist for
exactly this), and writes its inspection notes. What follows is human by
design: chiacchierata, plan correction, and a fresh `/run-workflow` as the
ripresa lavori. On denied — or no reply at all — the run's own stop
conditions govern, as if nothing was asked. When the inspector IS the
foreman, the same question goes to its own user directly.

## Notes for the final inspector

After `run-end` — never mid-run, the run owns the tree until then — the
inspector appends a `## Run inspection` section to the plan's `notes.md`:
one bullet per noteworthy fact (failures and repairs, blocks, anomalies), or
`- uneventful run, N/N phases`. `/finalize-workflow`'s pre-commit review
takes those bullets as explicit focus points — confirmed or dismissed, never
dropped — and the finalize agent collects them the same way: the run's
inspector briefs the final one.

## Tests

S25 extends to the fourth event: the live half asserts each completed phase
emits its `phase-done` with progress counts, and the two drift guards
(launcher↔skill, both directions) pick the new token up automatically
because they extract tokens from the shipped launcher rather than a list.
S30 gains `run-workflow` among the protocol's citing consumers. 187
assertions over 29 scenarios, green.
