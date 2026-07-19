# Loop engineering — self-correcting autonomous chain

The conceptual foundation of the phased-workflow autonomous chain
(`/write-workflow` → `/run-all-phases` → `/auto-phase` / `/repair-phase` →
`/finalize-workflow`). Read this to understand *why* the commands are shaped
the way they are before modifying them.

## For vs loop

A **for** executes a predetermined sequence of steps, once each. A **loop**
iterates against a **feedback signal** (tests, linter, review, done criterion)
until it **converges**, within a bounded budget. Advanced models are trained
to exploit the second form: given a verifier and the freedom to retry, they
self-correct; given one shot, they behave like any model.

The chain keeps the right skeleton for long-running autonomous work:

- **Persistent state in MEMORY.md** — the loop's memory that survives contexts
- **One fresh session per phase** — no polluted context, every iteration restarts clean
- **Measurable `Done:` criteria** — the convergence condition, written at planning time

## The nested loops (three machine, one human)

```
macro-loop (rolling wave — ambitious plans only; the human at EVERY boundary):
    while the ## Roadmap has macro-phases left:
        /write-workflow        # detail ONLY the next macro (5-8 phases), with hindsight
        run-all-phases ...     # the machine loops below
        /finalize-workflow     # commit this macro — bounded diff, review-sized
        human checkpoint       # verify direction, adjust the roadmap

run-all-phases (outer loop — bash, consumes no model):
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
confirmation (`/run-all-phases`), and `/finalize-workflow` (or when repair
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
  omits them ("the spec is sovereign"). Measured on the seeded fixture: same
  external outcomes, ~40% cheaper, half the wall time. The full ritual remains
  the default for `medium`/`high`/`max` phases and on CLIs without the guard.
- **Rolling-wave macro-phases for ambitious plans.** Beyond ~8-10 phases — or
  when a phase's shape depends on an earlier phase's *outcome* — the plan
  splits into macro-phases: only the first is detailed, the rest live as inert
  `## Roadmap` bullets. Each macro gets its own run-all-phases + finalize
  (bounded uncommitted surface, review-sized diffs), and the next
  /write-workflow re-plans with hindsight. This widens the robottinizzabile
  class: "phase 19 depends on phase 12" stops being a rejection reason. The
  macro loop is deliberately manual — its boundary is where human judgment
  pays most, before errors compound.
- **Structured failure notes.** `> Issue:` / `> Attempted:` /
  `> Repair attempted:` / `> Repaired:` / `> Review:` — every state transition
  leaves machine-readable evidence.
- **The cross-phase blind spot lives at finalize.** Each phase is verified in
  isolation; no phase-level check ever sees the whole diff.
  `/finalize-workflow` runs the whole-diff review (effort high for autonomous
  plans) with an explicit cross-phase coherence focus.

## Command choice: who is the verifier?

- `/auto-phase` (via `/run-all-phases`) works when the feedback signal is
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
automatic verifier behind it.

| Moment | Model | Why |
|--------|-------|-----|
| `/write-workflow` (planning) | strongest available | The plan is the loop's contract: errors propagate to every phase |
| `/run-all-phases` pre-flight | strongest available | Pure judgment work; a mistake wastes an entire run |
| Autonomous phases | opus default; sonnet when well-specified + solid pattern reference + testable logic; fable for genuinely hard phases | Decided per phase by the pre-flight |
| `/repair-phase` | fable (opus fallback) | By definition, the phase's own model already failed once |
| `/finalize-workflow` | strongest available | Last gate before the commit, once per workflow |

Avoid the fourth quadrant: weak model + judgment-heavy phase = babysitting
mediocrity.

## Validation

Four test tiers cover the chain (2026-07):

1. **Deterministic orchestration tests** (`tests/orchestration/run_tests.sh`):
   the run-all-phases bash script, extracted from its own SKILL.md, exercised
   with a mock `claude` over seven scenarios — /goal call shape, model/cap
   selection (fable cap doubled), repair success resuming the loop, repair
   failure stopping it, the idempotent `Repair attempted:` marker, fable→opus
   fallback on session crash, no-progress guard, and the pre-2.1.139 plain-prompt
   fallback. 27/27 assertions.
2. **Real end-to-end run**: a sonnet session executed a well-patterned fixture
   phase, converged first pass (9 tests green, flake8 zero, Done re-verified
   externally), and the independent verification flagged two genuine coverage
   gaps as `> Review:` notes without blocking the phase.
3. **Benchmark harness** (`tests/benchmark/bench.sh`): fresh fixture copy per
   run, real sessions, metrics from `--output-format json`, success judged
   externally (pytest + flake8 + MEMORY state), CSV output. First calibration
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
   difference; slim arms cost ~40% less and finished in half the time. The one
   quality gap: the slim-goal arm recorded zero `> Done:`/`> Files:` notes
   (0/3) because its contract never asked for them, while arms whose active
   spec asked got them 6/6 and 3/3 — discipline is movable between skill
   prompt and goal contract, but whatever the spec omits is silently lost.
   The production light contract includes the notes clause and was
   re-validated live (notes present, success, $0.48/100s).
   What remains unmeasured: the guard's outcome benefit at realistic lapse
   rates (needs tens of runs) and the full ritual's value on hard phases.
