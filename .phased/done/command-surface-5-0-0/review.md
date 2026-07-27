# Coherence review — command-surface-5-0-0 (Phase 12)

## Auto-fixed

Nothing needed fixing in this pass: the per-phase verification (suite after
every phase, both shells; flake8 on every touched Python file; targeted
smoke tests for the launcher attach path and the tag degradation) left no
mechanical stragglers for the final sweep to catch. The repo-wide greps for
`run-all-phases`, `auto-phase`, `check-phase-context`, `` `parallel:N` ``
and `` `group:N` `` return only intentional mentions: the 5.0.0 changelog,
the retirement/rename machinery (RETIRED_NAMES, KB_ONLY history notes), the
historical ≤4.0.0 support-file path in `install.sh` SUPPORT_PATHS and
README's migration note, the historical benchmark results, and the
article marked historical.

## Flagged for human

1. **KB sync needs a manual pass** (`tools/kb-sync.py`): the MAPPING now
   points at three new/renamed titles (`resume-workflow`, `run-workflow`,
   `execute-phase-agent`, `finalize-workflow-agent`) and one new EMBEDDED
   script (`agent-session.sh`). Run `kb-sync.py --create` + `--audit` when
   Sourcerer is reachable; the old KB titles are parked in KB_ONLY as
   history and can be edited KB-side to point readers at the successors.
2. **"One launcher, two callers" is delivered asymmetrically by design**:
   `agent-session.sh` serves finalize (and future callers), while
   `run-workflow.sh` keeps its own claude invocation because S14 extracts
   the shipped contracts from that file and the suite runs it as a lone
   copy. Revisit in Macro 2 if the divergence starts costing.
3. **The installed plugin cache is still 4.x** on this machine
   (`~/.claude/plugins/cache/claude-phased-workflow/phased-workflow/4.0.0`):
   after merging, the marketplace update + `install.sh` migration will
   retire the stale flat names (`check-phase-context`, `run-all-phases`,
   `auto-phase`).
4. **`docs/article-medium.md`** is kept wholesale as the origin story with
   a historical note; if a current-architecture article is ever wanted, it
   is a rewrite, not an edit.

## Final state

- Orchestration suite: **124 assertions / 23 scenarios, 0 failed**, under
  bash and zsh.
- flake8: zero findings repo-wide.
- `next-phase.py --validate`: 0 errors / 0 warnings on the benchmark
  fixture (the CI gate) and on this plan itself.
- Mutation spot-checks during the release: "Never commit." reintroduced in
  the shipped contract → S14 red; `**Phase` anchor stripped from the awk
  block → S18 red (now a standing mutation inside the suite, as are S21's
  and S23's); guard scripts extracted so mutations run the real checks.
- Files reviewed: the Files: lists of Phases 1–11 (skills, refs, scripts,
  tests, tools, docs, both plugin manifests).
