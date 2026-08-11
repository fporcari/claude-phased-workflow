# 5.13.0 — cross-phase awareness, and the reporting register

Two field reports from teams running the autonomous mode, one release. First:
a phase-3 worker would make choices that complicated life for phases 4 and 5
— and the fresh-session design is exactly why. Second: the reports the chain
hands back — the finalize presentation above all — read as if the human had
watched every phase land, when the whole point of the autonomous mode is that
nobody did.

## The plan is context, not just a queue

The diagnosis behind the first report is sharper than "workers can't see the
plan": they always could. `/execute-phase-agent` reads the whole plan at Step
0 — and then every instruction after that narrows the view to one phase:
*"write the code the phase describes, and nothing else"*, with the opus steer
adding *"deliver exactly the phase scope"*. The knowledge was in context and
deliberately unused. Three changes, one per layer:

- **The shared core** (`refs/phase-execution.md`, both execute modes) now
  says it outright: before the first edit, skim the whole plan — the
  `> Done:`/`> Files:` notes of completed phases say what already exists
  (reuse it, never duplicate it), the pending phases say where the work is
  heading, and a micro-choice the phase leaves open (a name, where a helper
  lives, a data shape) is decided in favour of the successors. Scope stays
  untouched: knowing Phase 5 exists never means implementing a piece of it.
- **The light contract** loads no skill, so it gains its own clause — read
  the whole plan first, choose what does not complicate later phases,
  without implementing any part of them.
- **The run inspector** (the chat watching `/run-workflow`, which holds the
  whole plan from its pre-flight) gains a cross-phase trigger for the
  stop-work question: on each `phase-done`, one cheap coherence look —
  does what the log says landed contradict what any remaining phase's
  `Files:`, `Pattern:` or `Details:` assume? Reading logs and diffs breaks
  no invariant; only writes are forbidden mid-run.

Prevention at the worker, detection at the inspector — and the finalize
whole-diff review stays as the third net, after the fact.

## The reporting register

The second report names a register problem, not a content problem. The chain
collects issues faithfully — `> Issue:`, `> Review:`, `verify.md`, the run
inspection notes — and then presents them in the language they were written
in: implementation-speak, to a reader who never saw the implementation.

`common.md` now owns a `## The reporting register` section, single-source
like the foreman protocol: every report addressed to the person who decides
assumes they do NOT know the implementation details. Name things by what
they do for the user, never by identifier alone; a defect is a consequence
(*se succede X, l'utente vede Y*); identifiers may follow in parentheses but
the sentence must carry its meaning without them; labels — "fallback",
"shadow mode" — are not explanations.

The boundary matters as much as the rule: the register applies at
*presentation* time, when plan artifacts are turned into Italian for the
human. The artifacts themselves stay technical English — repair sessions
and reviews read them, and periphrasis would cost them precision. The
citing consumers: `/finalize-workflow`'s QA pass and findings presentation,
`/run-workflow`'s closing report and stop-work question, and the `<one
line>` slots of the foreman messages.

## Tests

S31, in the S27/S30 mould: `common.md` owns the register section (with its
artifacts-stay-technical boundary), the shared core carries the
plan-is-context paragraph, the shipped light contract carries the
cross-phase clause, the presenting skills cite the register and nobody
restates it. Proven by mutation, four ways. 192 assertions over 30
scenarios, green.
