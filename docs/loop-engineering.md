# Loop engineering — self-correcting autonomous chain

The conceptual foundation of the phased-workflow autonomous chain
(`/write-workflow` → `/run-workflow` → `/execute-phase-agent` / `/repair-phase` →
`/finalize-workflow`). Read this to understand *why* the commands are shaped
the way they are before modifying them.

## For vs loop

A **for** executes a predetermined sequence of steps, once each. A **loop**
iterates against a **feedback signal** (tests, linter, review, done criterion)
until it **converges**, within a bounded budget. Advanced models are trained
to exploit the second form: given a verifier and the freedom to retry, they
self-correct; given one shot, they behave like any model.

The chain keeps the right skeleton for long-running autonomous work:

- **Persistent state in the committed plan** — the loop's memory that survives contexts
- **One fresh session per phase** — no polluted context, every iteration restarts clean
- **Measurable `Done:` criteria** — the convergence condition, written at planning time

## The nested loops (three machine, one human)

```
macro-loop (rolling wave — ambitious plans only; the human at EVERY boundary):
    while the ## Roadmap has macro-phases left:
        /write-workflow        # detail ONLY the next macro (5-8 phases), with hindsight
        run-workflow ...     # the machine loops below
        /finalize-workflow     # commit this macro — bounded diff, review-sized
        human checkpoint       # verify direction, adjust the roadmap

run-workflow (outer loop — bash, consumes no model):
    pre-flight review of the plan          # human in the loop HERE
    while [ ] phases remain:
        claude -p "/goal <phase contract>" # fresh session, ONE phase, goal-guarded
        │  inner convergence loop:
        │    tests + lint → fix → re-run   (max 3 attempts, no-progress detector)
        │    phase-verifier subagent       (MECHANICAL fixed, JUDGMENT → > Review:)
        │    Done-criterion gate           (re-run every criterion literally)
        │  /goal evaluator per turn        (independent model checks the exit condition)
        if phase exits [!]:
            claude -p "/goal <repair contract>"   # ONE fresh-eyes repair
            if still [!]: stop             # NOW it's the human's turn
```

Each loop has its own budget and exit condition. The human doesn't disappear —
they move **to the edges**: plan approval (`/write-workflow`), pre-flight
confirmation (`/run-workflow`), and `/finalize-workflow` (or when repair
fails). Inside, the machine self-corrects.

## Key design decisions

- **Bounded budgets everywhere.** 3 fix attempts per convergence loop, 1 repair
  per phase, a 25-turn clause in every goal contract, notional dollar caps per
  session. Unbounded loops don't converge better — they burn budget against walls.
- **No-progress detector.** If the same failure signature (same failing test +
  same exception) appears twice in a row, stop early. Iterating blindly against
  the same error is the failure mode of naive loops.
- **Independent verification.** The agent that writes code and tests would
  otherwise self-promote. The `phase-verifier` subagent — read-only, own context
  window, fed the Done criterion and pattern reference — breaks the
  self-reference. MECHANICAL findings are fixed in-loop; JUDGMENT findings
  become `> Review:` notes for the human at finalize.
- **`Done:` is the exit condition, not documentation.** "Tests pass" is weaker
  than the plan's Done criterion; the executor re-runs each criterion verbatim
  before closing the phase.
- **Native primitives where they exist.** Guarantees promised by the prompt
  become enforced by the harness: phase and repair sessions run under a native
  `/goal` condition (Claude Code ≥ 2.1.139, runtime-detected with automatic
  fallback) — completion is judged per turn by a fresh small model reading the
  transcript, not by the session that did the work. The independent review is a
  native subagent, so it costs the phase session almost no context.
- **Repair = fresh eyes, not more of the same.** The failed session's
  `> Attempted:` notes are the repair session's input, and repeating a listed
  attempt is forbidden. A fresh context questioning the previous diagnosis
  beats a long context continuing it.
- **The stronger the verification loops, the cheaper the executor can be.**
  A well-guided sonnet — spec closed in the plan, a pattern to copy-adapt, a
  testable Done — handles non-trivial phases: the loop catches its mistakes,
  and a failed phase escalates to a fable repair. Economics: a sonnet phase
  that fails costs a fable repair, so mark sonnet only where first-pass success
  is likely; the net caps the damage, it doesn't make failures free.
- **Light mode for simple phases.** `Effort=low` phases run without the skill
  ritual: a slim `/goal` contract (~450 chars vs the ~9.5KB skill body) carries
  every chain invariant itself — including the `> Done:`/`> Files:` bookkeeping
  notes that the 2x2 experiment showed get silently dropped when the contract
  omits them ("the spec is sovereign"). Measured on the seeded toy fixture
  (n=3): ~37% cheaper and ~60% of the wall time — the `slim` hardcoded control
  vs `plain`, the two arms whose provenance survived the frozen-copy defect. The
  shipped light contract's own "same external outcomes" was never measured
  against it, so that parity is a design claim, not a benchmarked one; see
  `tests/benchmark/results/README.md`. The full ritual remains the default for
  `medium`/`high`/`max` phases and on CLIs without the guard.
- **Rolling-wave macro-phases for ambitious plans.** Beyond ~8-10 phases — or
  when a phase's shape depends on an earlier phase's *outcome* — the plan
  splits into macro-phases: only the first is detailed, the rest live as inert
  `## Roadmap` bullets. Each macro gets its own run-workflow + finalize
  (bounded uncommitted surface, review-sized diffs), and the next
  /write-workflow re-plans with hindsight. This widens the robottinizzabile
  class: "phase 19 depends on phase 12" stops being a rejection reason. The
  macro loop is deliberately manual — its boundary is where human judgment
  pays most, before errors compound.
- **Structured failure notes.** `> Issue:` / `> Attempted:` /
  `> Repair attempted:` / `> Repaired:` / `> Review:` — every state transition
  leaves machine-readable evidence.
- **Never start an iteration on a red baseline.** Every phase session runs the
  green signal *before* its first edit. A phase that inherits someone else's
  breakage otherwise attributes it to itself and spends its whole fix budget —
  plus a repair session — on a bug it did not cause. Each machine mechanism is
  deliberately scoped to the current phase (`never the whole working tree`), so
  none of them has authority over a failure that predates it.
- **Attribute the red baseline, don't just stop.** The failure is matched
  against the `> Files:` notes of the completed phases. *Case A* — a phase
  `[x]` owns those files: it regressed and was closed wrongly, so it is
  **reopened `[x] → [!]`** and the ordinary repair path handles it; the run
  continues. *Case B* — nobody owns it: it pre-dates the run, the chain has no
  mandate over it, and the pending phase goes `[~]` for the human. Ambiguity
  resolves to Case B, because a wrong reopen spends a phase's only repair on
  the wrong bug. Self-repair is preferred over interrupting the human whenever
  the regression has an owner; the one-repair-per-phase guard keeps it bounded.
  Consequence the launcher must absorb: a reopen makes the `[x]` count *drop*,
  so the progress guard has to know a repair landed or it reads real work as
  "stuck".
- **The loop learns across runs, not just within one.** Iterating without ever
  improving the system is a loop-engineering anti-pattern: the same wrong
  pattern reference gets chosen again next time. `/finalize-workflow` closes
  that gap at the only moment where the whole run is visible and the memory
  file still exists — it harvests `> Repaired:` notes (a root cause plus why
  earlier attempts missed it), `new-pattern` phases that landed, and pattern
  references that proved wrong, and proposes them for the project's own
  knowledge base. Silent by
  default: the bar is "would this have saved a future session real work, in a
  way the repo and the git history don't already say?"
- **The cross-phase blind spot lives at finalize.** Each phase is verified in
  isolation; no phase-level check ever sees the whole diff.
  `/finalize-workflow` runs the whole-diff review (effort high for autonomous
  plans) with an explicit cross-phase coherence focus.

## Command choice: who is the verifier?

- `/execute-phase-agent` (via `/run-workflow`) works when the feedback signal is
  **machine-checkable**: measurable Done, runnable tests, pre-made decisions,
  pattern references in the plan.
- `/execute-phase` (interactive) is for phases where **the human is the
  verifier**: UI/visual output, exploratory work, decisions that emerge only
  while doing. The leash reflects the nature of the phase, not the quality of
  the model.

A vague phase fails autonomously on the best model in the world; a
well-specified phase runs autonomously even on sonnet.

## Model-tier map

Strong models go **where judgment happens**; the medium tier executes with an
automatic verifier behind it. This is guidance, not a constraint — the skills'
own model tips carry the same advice, and either can be overridden per run.

"Strongest available" turned out to be too blunt a rule. The sharper question is
**what kind of work the moment actually contains**: fable earns its premium on
introspective and inventive work — ambiguous scope, architecture to invent, an
unknown surface, no obvious decomposition — and on unattended work where nobody
is watching. Where the shape is already clear and the job is to formalise it
precisely, opus at `xhigh` is more literal, cheaper, and better at filling a
dense template without drift. A prescriptive step-by-step prompt actively
degrades fable's output, and most of these skills are exactly that.

| Moment | Model | Why |
|--------|-------|-----|
| Discussion *before* `/write-workflow` | fable, when the plan itself is the hard problem | Ambiguity and novel design are its strength; here there is no template fighting it |
| `/write-workflow` (planning) | fable if the work is introspective/inventive, else opus `xhigh` | The plan is the loop's contract, so quality multiplies — but this skill is a dense template, so on fable read its steps as a contract on the output, not a procedure |
| `/run-workflow` pre-flight | opus `xhigh` | Judgment work, but it ends in an explicit human confirmation, so a misjudgement is caught before the loop starts |
| Autonomous phases | opus default; sonnet when well-specified + solid pattern reference + testable logic; fable for genuinely hard phases | Decided per phase by the pre-flight |
| Interactive phases (`/execute-phase`) | opus default; fable where inventive work survives the approval gate; never sonnet | Suggested per phase by the plan's `Run:` line. Fable's case is halved here — it also earns its premium where nobody is watching, and this path is watched by construction |
| `/repair-phase` | fable at `--effort max` (opus fallback) | By definition the phase's own model already failed once, and nobody is watching |
| `/finalize-workflow` | opus `xhigh` | Most of it is git plumbing; the judgment is concentrated in the whole-diff review, where opus is high-precision *and* high-recall. On a large autonomous diff a reviewer panel beats upgrading the single pass |
| `phase-verifier` subagent | opus (pinned, not inherited) | On a `sonnet` phase an inherited verifier is as weak as the executor it is meant to check — that defeats the independence |

Avoid the fourth quadrant: weak model + judgment-heavy phase = babysitting
mediocrity.

## Validation

Five test tiers cover the chain (2026-07):

1. **Deterministic orchestration tests** (`tests/orchestration/run_tests.sh`),
   **171 assertions over 27 scenarios**, in three kinds. *Mock-driven* (a mock
   `claude` binary drives the run-workflow script, a shipped file since
   4.0.0): /goal call shape, model/effort/cap selection (fable cap doubled,
   `xhigh` → 250), repair success resuming the loop, repair failure stopping
   it, the idempotent `Repair attempted:` marker, relaunch on a `[!]`
   *without* that marker, attribution Case A (a reopened `[x]` phase drops
   the done-count without tripping the progress guard), attribution Case B
   (`[~]` stops the run), fable→opus fallback on session crash, no-progress
   guard, inert `## Roadmap`, the pre-2.1.139 plain-prompt fallback (S1–S13),
   `--validate` gating the launcher before any session and warnings printed
   rather than discarded (S19), every silent fallback announcing itself
   (S20), and the live half of S18 (prose bullets in `## Notes` held inert).
   *Real-git, no mock*: `/import-workflow` classification and its mid-run git
   sequence (S17); the `--plans` location service across root, worktree and
   checkout-less branch (S22). *Static, on what the repo ships*: no frozen
   copy of a shipped contract anywhere in the harness and the light
   contract's per-phase-commit clause intact (S14), every skill inside its
   own `allowed-tools` (S15), the phase-state matches single-source — S18's
   static half, proven by mutation —, no skill or ref still addressing
   `~/.claude/` (S21, proven by mutation), every `-agent` skill a thin
   variant citing its base (S23, proven by mutation), the automation fork
   real rather than decorative (S24), the `EVENT` contract a parent `Monitor`
   watches emitted exactly once — all-`[x]` early exit and validation failure
   included (S25), every `claude -p` prompt namespaced (S26), the
   `Done:`/`Verify:` contract single-source and cited (S27), and the
   per-model steer reaching every sub-session without a `sonnet` phase
   receiving fable's (S28). S16, the KB-sync coverage check, was retired with
   the KB mirror in 5.0.0 — the plugin is the single distribution road, so
   there is no mirror left to drift; the number stays vacant, which is why 28
   scenario numbers make 27 scenarios.

   S15 exists because its gap is quiet by construction. A skill can
   instruct a command its allowlist never pre-approves — `write-workflow` called
   `gh issue view` and an internal knowledge-base MCP without permission for
   either, the worktree
   skills piped git through `grep|head|sed`, `pull-request` invoked the
   `code-review` skill without the `Skill` tool. Nothing fails loudly: the step stops to ask
   for a permission the author meant to grant, and where nobody can answer it
   does not run. Autonomous sessions are gated by `--permission-mode auto`
   rather than by the command's allowlist, so this is a defect of the
   interactive path, which is where all four of those commands live.

   **The suite runs the script under both bash and zsh** (S9). This is not
   redundancy: the production invocation path is the user's shell — zsh on
   macOS — and constructs that are valid bash can abort there. An unbraced
   `$NEXT_PHASE[^0-9]` inside a grep pattern parses as an array subscript in
   zsh and aborts the command, which silently emptied the config-table lookup
   and defaulted *every* phase's model, effort and cap. A bash-only harness
   cannot see it, and `zsh -n` does not either — only a real zsh run does.
   S9 fails on that bug while S1–S8 stay green, which is exactly the shape of
   the blind spot it closes.
2. **Real end-to-end run**: a sonnet session executed a well-patterned fixture
   phase, converged first pass (9 tests green, flake8 zero, Done re-verified
   externally), and the independent verification flagged two genuine coverage
   gaps as `> Review:` notes without blocking the phase.
3. **Benchmark harness** (`tests/benchmark/bench.sh`): fresh fixture copy per
   run, real sessions, metrics from `--output-format json`, success judged
   externally (pytest + flake8 + plan state), CSV output. First calibration
   (n=1 per config, same phase, both succeeded):

   | config | success | turns | cost | duration |
   |--------|---------|-------|------|----------|
   | sonnet, plain prompt | yes | 17 | $0.68 | 163s |
   | sonnet, /goal guard | yes | 21 | $0.71 | 169s |

   On a happy-path phase the /goal guard costs ~4 extra turns and ~4% notional
   cost — the evaluator overhead. The goal run's transcript confirms both new
   primitives were active: its final report cites the phase-verifier's outcome
   and argues the goal condition explicitly ("no other phase exists, so the
   goal condition is satisfied").

   **Provenance:** the guarded arm ran the pre-2.5.0 contract, because until
   `84f68df` the harness held a frozen copy of it. The overhead figure is
   therefore indicative, not current; the shipped contract is longer and admits
   two more outcomes. `tests/benchmark/results/README.md` records what every
   archived run actually executed, and which conclusions survive it.
4. **Goal-evaluator mechanism test**: a /goal contract that by construction
   needs multiple turns — create `counter.txt` at 0, increment by at most 1
   per turn, condition met at exactly 3 — completed with `counter.txt = 3` in
   5 turns ($0.34, sonnet). A plain `claude -p` session gets exactly ONE turn,
   so reaching 3 is direct proof that the independent evaluator sends the
   session back to work until the condition holds — the guard's distinctive
   mechanism, which happy-path benchmarks cannot show.
5. **Seeded-failure 2x2** (`results/run-2026-07-19-seeded-ab/`,
   `results/run-2026-07-19-slim-2x2/`): full-skill vs 300-char slim prompt,
   plain vs /goal, on a fixture whose plan omits that adding a module breaks a
   registry test. 12/12 external successes across all four arms — no outcome
   difference; the `slim` hardcoded control (n=3, whose provenance the
   frozen-copy defect could not touch — not the shipped light contract) cost
   ~37% less and finished in ~60% of the wall time. The one quality gap: the
   slim-goal arm recorded zero
   `> Done:`/`> Files:` notes (0/3) because its contract never asked for them,
   while arms whose active spec asked got them 6/6 and 3/3 — discipline is
   movable between skill prompt and goal contract, but whatever the spec omits
   is silently lost. The production light contract includes the notes clause and
   was re-validated live (notes present, success, $0.48/100s).
   What remains unmeasured: the guard's outcome benefit at realistic lapse
   rates (needs tens of runs), the full ritual's value on hard phases, and
   baseline attribution — no paid run has ever executed a contract containing
   it, so Case A and Case B rest on S11/S12 alone.
