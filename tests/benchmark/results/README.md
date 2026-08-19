# Archived benchmark runs — provenance

> **Verification status, 2026-08-19:** the contract-tests flow (6.8.0), the
> doctor's blind retro-fit (6.9.0) and the coherence judge (6.11.0) have one
> n=1 smoke each — 3/3 passed, see `run-2026-08-19-6x-smoke/` — which is
> sanity, not statistics. The rest of the 6.x tier (the programme-contract
> graph at execution time, the 6.14.0 consumer split) remains
> **spec-verified only**. The scenarios live in `../scenarios-6x/`.

Every directory here is a real paid session, and none of them can be reproduced.
So what matters is knowing **which version of the chain each one actually
measured**, because until `84f68df` the harness could not tell you: `bench.sh`
carried frozen copies of the launcher contracts (`GOAL_CONTRACT`,
`SLIM_GOAL_CONTRACT`) instead of reading them from
`skills/run-all-phases/SKILL.md`, and the copies were not updated when the
shipped contracts changed. The harness reported "the current chain" while
running an older text.

The copies are gone — the guarded arms now extract the contracts live, `S14` in
`tests/orchestration/run_tests.sh` fails if a frozen copy is reintroduced, and
every CSV row records the contract sha and the effort it ran at. This file
covers the archive left behind.

## What each run measured

Contract generations, reconstructed from git history:

| Gen | `PHASE_PROMPT` (full) | `LIGHT_PROMPT` (light) |
|-----|----------------------|------------------------|
| **G1** | no baseline attribution | no `> Done:`/`> Files:` notes clause, no baseline attribution |
| **G2** | — | notes clause added (`bca94ba`) |
| **G3** = shipped today | baseline attribution: Case A reopen `[x] → [!]`, Case B `[~]` | notes clause **and** baseline attribution |

| Run | Arms | Contract executed | Effort | Status |
|-----|------|-------------------|--------|--------|
| `run-2026-07-18-plain-vs-goal` | plain, goal | plain: live `/auto-phase` · goal: **G1** | CLI default | **goal arm superseded** |
| `run-2026-07-19-seeded-ab` | plain ×3, goal ×3 | plain: live `/auto-phase` · goal: **G1** | CLI default | **goal arms superseded** |
| `run-2026-07-19-slim-2x2` | slim ×3, slimgoal ×3 | slim: hardcoded control (unchanged) · slimgoal: **G1** | CLI default | **slimgoal arms superseded** |
| `run-2026-07-19-light-contract-validation` | lightv2 | **G2** | CLI default | valid for the notes clause only |
| `run-2026-07-19-goal-mechanism` | bespoke counter contract | not a shipped contract | CLI default | valid |

"CLI default" means no arm ever passed `--effort`, while the fixture's own
config table declares `Effort=low`. `bench.sh` now defaults to the fixture's
declared effort and records it per row.

## Which conclusions still stand

- **Light mode is cheaper and faster.** Survives. The `slim` arm — a hardcoded
  control that never touched the frozen copies — cost ~37% less than `plain`
  ($0.442 vs $0.698 mean) and finished in ~60% of the wall time (95s vs 159s
  mean, excluding the instrumentation outlier below). The claim never depended
  on the guarded arms.
- **The `> Done:`/`> Files:` notes clause is load-bearing.** Survives, and the
  provenance makes it *stronger*: the `slimgoal` arm recorded 0/3 notes because
  the contract it ran (G1) genuinely had no notes clause. That is what the
  experiment found; the clause was added in response, and `lightv2` (G2)
  re-validated it live.
- **"The /goal guard costs ~4 extra turns and ~4% notional cost."** Superseded.
  Measured G1 against a live `/auto-phase`; the shipped G3 contract is longer
  and admits two more outcomes. The direction is plausible, the number is not
  current.
- **Nothing here measures baseline attribution.** No archived run used a
  contract that contains it. Case A / Case B are covered only by the
  deterministic tests (S11, S12), never by a paid session.

## Not re-run, on purpose

The stale arms were not re-executed. The only claim they carried that mattered —
cost and wall-clock of the slim path — is independently supported by an arm the
defect could not touch, so re-running would buy provenance for a conclusion
already held up elsewhere. What is genuinely unmeasured (attribution, the
guard's outcome benefit at realistic lapse rates) needs a different experiment,
not a repeat of this one; see issue #5 for its cheap first step.

## Instrumentation caveat

`run-2026-07-19-seeded-ab/sonnet-plain-2` reports `num_turns=3` and
`duration_ms=30s` for a session the harness clocked at 233s wall, having done
the full phase (5 tests, registry update, verifier note). The JSON metadata
describes part of that session, not all of it.

Consequence for any future design: **turn count is a fragile primary endpoint.**
Across the archive, per-arm cost CV is 7–14%, but the `plain` arm's turn CV is
57% — entirely this one run. Cost is the stable measurement, and it is ~99%
cache-read tokens, so it tracks context size rather than output volume. Run
`tools/bench-stats.py` to recompute all of this from the files.
