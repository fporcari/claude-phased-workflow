# 5.3.0 — per-model prompt steering for autonomous sessions

Each `/run-workflow` sub-session (phase and repair) now receives a model-matched
`--append-system-prompt`: a common token-discipline steer (headless output is a log
nobody reads live — silence between tool calls, three-sentence close) plus one line
damping the chosen model's known drift, per Anthropic's model-specific prompting
guidance:

- **opus** — phase scope only, no verification beyond the `Done:` criteria, subagents
  only for wide independent exploration
- **sonnet** — literal execution of `Details:`; a real design gap closes the phase `[!]`
  instead of inventing a design
- **fable** — act on settled decisions, ground claims in tool results

The goal contracts stay byte-stable (tests extract them); the flag sits after the
model/effort/permission/cap sequence the tests assert on. `execute-phase-agent` gains
the same output-is-a-log non-negotiable for launcher-less runs; `write-workflow-autonomous`
and `run-workflow` document the steering so plans stop restating style rules. S28 guards
it: live (each session carries the common steer plus its own model's line, never
another's) and static (both repair call sites append one).
