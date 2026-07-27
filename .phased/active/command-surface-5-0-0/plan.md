# Context: wf/command-surface-5-0-0
Parent: main

## Objective
Implement Macro 1 of docs/target-workflow.md — command surface, location and workspace
(items A0, A1, A, B, C, H, K, L) plus the 4.1.0 carried defects that touch the same
files (M.2–M.6) and the release chores (docs, tests, version 5.0.0). Breaking release:
two commands renamed, one retired, two tags removed.

Executed in-session with the approval gate waived by the user ("mano libera"); phases
still commit one by one as `wf(phase N): <title>`.

## Work Plan
- [x] **Phase 1**: Create /resume-workflow (absorbs check-phase-context's audit)
  > Done: skill created — locate/audit/report/approved-edits, healthy early-exit in description and Step 3; check-phase-context step 2 ported verbatim; MAPPING entry added; suite 109/109, S16 green, flake8 clean.
  > Files: plugins/phased-workflow/skills/resume-workflow/SKILL.md, tools/kb-sync.py
  - Pattern: `plugins/phased-workflow/skills/check-phase-context/SKILL.md` (steps 1–4 are the base; its step 2 ported verbatim)
  - Files: plugins/phased-workflow/skills/resume-workflow/SKILL.md (new), tools/kb-sync.py (MAPPING entry)
  - Decisions: name per target-workflow D1; description must cover the healthy case ("just tell me where we are" early-exits with the state report) or it will not trigger when nothing is broken; read-only on source code, may edit only the plan (approved re-phasing / stale [>] reset), each edit its own `wf:` commit. Full recovery flow (attach workspace, drive repairs) is Macro 3 — this phase ships locate → analyse → report → approved plan edits only.
  - Details: new SKILL.md with frontmatter mirroring check-phase-context's allowed-tools; steps: (1) locate the plan and BASE (next-phase.py; from Phase 4 on it also gains --plans), early-exit with the state report when everything is green; (2) the check-phase-context step-2 audit VERBATIM — commit-vs-`> Files:` drift (unlisted files / uncommitted leftovers), oversized-phase judgment with the `vast` exemption; (3) report in Italian (state, commits, coverage, drift, oversized, next step); (4) apply approved re-phasing or stale-[>] reset with its own `wf:` commit. Add MAPPING entry `skills/resume-workflow/SKILL.md → resume-workflow`.
  - Done: skill file exists and S16 logic (every shipped skill mapped) passes: `bash tests/orchestration/run_tests.sh` section S16 green.

- [x] **Phase 2**: Retire /check-phase-context
  > Done: skill dir removed; RETIRED_NAMES + generalised retirement message; MAPPING dropped, KB_ONLY history note; README (mermaid node → /resume-workflow, table row, section, traceability, FAQ); refs/common.md ×2; article-medium.md marked historical. Sweep clean; suite 109/109.
  > Files: plugins/phased-workflow/skills/check-phase-context/SKILL.md (deleted), plugins/phased-workflow/install.sh, tools/kb-sync.py, README.md, plugins/phased-workflow/refs/common.md, docs/article-medium.md
  - Pattern: commit `b0fb06e` (retirement of the four worktree commands)
  - Files: plugins/phased-workflow/skills/check-phase-context/ (delete), plugins/phased-workflow/install.sh (RETIRED_NAMES), tools/kb-sync.py (MAPPING drop + KB_ONLY note), plugins/phased-workflow/refs/common.md (header list, `/check-phase-context` re-phasing mention), README.md:20,31,98,256-258,441,522, docs/article-medium.md:31
  - Decisions: install.sh retirement message generalised (current text says "Retired in 3.0.2 and NOT replaced" — with 5.0.0 some retirees have successors; print name → successor). kb-sync: move the KB title to KB_ONLY with reason "retired in 5.0.0 — absorbed into resume-workflow" so the audit stays clean. article-medium.md gets a top note marking it historical (it documents the pre-3.0 MEMORY.md system wholesale) instead of a surgical edit.
  - Details: delete the skill dir; RETIRED_NAMES += check-phase-context; README mermaid node CPC → RES "/resume-workflow", command table row replaced, section 256 rewritten for /resume-workflow, traceability and FAQ lines updated; refs/common.md updated (header command list, the "check-phase-context re-phasing" example becomes resume-workflow).
  - Done: `grep -ri check-phase-context` over the repo returns only historical mentions (README changelog, docs/target-workflow.md, article header note); suite green.

- [ ] **Phase 3**: Rename /run-all-phases → /run-workflow
  - Pattern: commit `b0fb06e` (rename path already established)
  - Files: plugins/phased-workflow/skills/run-all-phases/ → run-workflow/, plugins/phased-workflow/scripts/run-all-phases.sh → run-workflow.sh, plugins/phased-workflow/install.sh (RETIRED_NAMES + SUPPORT_PATHS comment), tools/kb-sync.py (MAPPING + EMBEDDED), tests/orchestration/run_tests.sh (RUNNER_SRC:11), tests/benchmark/bench.sh:30, README.md (12 mentions: 8,45,57,107,168,178,237,246,347,429,493,537,556), docs/loop-engineering.md (8 mentions: 4,28,32,48,97,141,171,185)
  - Decisions: name `run-workflow` per target-workflow D5 (preserves the run/execute/auto verb distinction; no /exec tab-collision). README:493 keeps the literal `run-all-phases.sh` where it names the OLD 4.0.0 support file being migrated away.
  - Details: git mv both, update SKILL.md internal references and the script's own header comments; sweep every listed mention; RETIRED_NAMES += run-all-phases.
  - Done: `bash tests/orchestration/run_tests.sh` and `zsh` run green with RUNNER_SRC pointing at run-workflow.sh; `grep -rn run-all-phases` returns only historical/changelog mentions.

- [ ] **Phase 4**: Location service — next-phase.py --plans
  - Pattern: `plugins/phased-workflow/scripts/next-phase.py:resolve_plan_path` (extend beside it)
  - Files: plugins/phased-workflow/scripts/next-phase.py, tests/orchestration/run_tests.sh (new scenario S22)
  - Decisions: output format one line per plan, pipe-separated for machine use: `plan|<path or branch:path>|branch|<name>|worktree|<path or ->|phases|<done>/<total>|state|<clean|running|failed|blocked>`; sources: (a) current root `.phased/active/*/plan.md`, (b) every linked worktree from `git worktree list --porcelain`, (c) every `wf/*` branch with no worktree, read WITHOUT checkout via `git ls-tree`/`git show`; exit 0 with no output when none found. `--resolve` unchanged (single-root fast path).
  - Details: add `--plans` flag; helper enumerates the three sources, parses each plan's phase counts/states with the existing parse(); for branch-only plans parse the blob from `git show <branch>:<path>`. S22: temp repo with (a) an active plan in the root, (b) a worktree with its own plan, (c) an orphan wf/ branch with a plan — assert all three lines appear with correct branch/worktree fields.
  - Done: S22 green in both shells; flake8 clean on next-phase.py.

- [ ] **Phase 5**: Skills operate on the plan's root (B)
  - Pattern: `refs/common.md` "Plan directory" section (the shared prose all skills cite)
  - Files: plugins/phased-workflow/refs/common.md, plugins/phased-workflow/skills/{execute-phase,auto-phase,finalize-workflow,pull-request,repair-phase,run-workflow,resume-workflow}/SKILL.md
  - Decisions: the rule lives ONCE in refs/common.md (new "Plan location" paragraph): resolve via `--resolve`; when it fails or the user names another workflow, use `--plans`, disambiguate if several, and from then on every git command runs `git -C <plan root>` and every path is anchored there. Skills get one pointer line each, not restated prose (the anti-duplication lesson).
  - Details: write the common.md paragraph; adjust each skill's "Find the plan" step to cite it; finalize-workflow's git commands annotated with `git -C` where they assume cwd.
  - Done: every listed SKILL.md cites the common.md rule; S15 (allowed-tools) still green; suite green.

- [ ] **Phase 6**: Workspace lifecycle (C)
  - Pattern: `plugins/phased-workflow/skills/write-workflow/SKILL.md:71-79` (the worktree block being moved)
  - Files: plugins/phased-workflow/skills/write-workflow/SKILL.md, plugins/phased-workflow/scripts/run-workflow.sh, plugins/phased-workflow/skills/run-workflow/SKILL.md, plugins/phased-workflow/skills/finalize-workflow/SKILL.md
  - Decisions: write-workflow stops creating worktrees entirely (branch + plan only). run-workflow.sh gains create-or-attach: if the active plan's branch is checked out in the current root → run here (no worktree); if the plan lives on a branch with an existing worktree → cd there; if on a wf/* branch with neither → `git worktree add .claude/worktrees/<slug> <branch>` + cp settings.local.json, announce it in one line (D3), run there. Worktree location stays `.claude/worktrees/<slug>` (D4). finalize keeps offering removal (already does).
  - Details: delete write-workflow Step 3 worktree block and its closing-message lines; run-workflow.sh: resolve the plan first (--plans), derive PLAN_ROOT, prefix the plan/git accesses with it, add the create-or-attach block before the loop; SKILL.md pre-flight mentions it launches from anywhere.
  - Done: suite green (S1–S13 exercise the launcher from a repo root where the branch is checked out — the "run here" path); manual smoke: `--plans` + launcher resolves from a subdirectory.

- [ ] **Phase 7**: Retire parallel:N and group:N (H)
  - Pattern: target-workflow.md item H (decided; blast radius listed there)
  - Files: plugins/phased-workflow/scripts/next-phase.py, plugins/phased-workflow/skills/write-workflow/SKILL.md, plugins/phased-workflow/skills/execute-phase/SKILL.md, plugins/phased-workflow/refs/common.md, plugins/phased-workflow/refs/write-workflow-autonomous.md, plugins/phased-workflow/scripts/run-workflow.sh (comments + fallback NOTE), tests/orchestration/run_tests.sh (S20a wording; any fixture carrying tags)
  - Decisions: `vast` survives. Old plans degrade gracefully: TAG_RE keeps only `vast`, so `parallel:N`/`group:N` become _taglike → "malformed tag (valid: vast)" warnings, never errors. Selector simplifies: blockers() = all preceding must be [x]; group_unit(), `unit:` output and the [>]-alternative rule die. execute-phase loses the group-unit invocation, `> Grouped:` closure and `wf(phase N-M):` commit; write-workflow sizing keeps Standard/Split/vast.
  - Details: strip both tags from selector (docstring, TAG_RE, accessors, blockers, group_unit, recommend), prose files and launcher NOTE; S20a asserts the new NOTE text ("ignores [>] resumes and validation order" or equivalent honest claim); update fixtures if any carry tags.
  - Done: suite green in both shells; `grep -rn 'parallel:\|group:' plugins/ tests/` returns nothing but the malformed-tag validator message and historical docs.

- [ ] **Phase 8**: Agent launcher + finalize-workflow-agent (K)
  - Pattern: `plugins/phased-workflow/scripts/run-workflow.sh` (claude -p invocation shape), `plugins/phased-workflow/agents/phase-verifier.md` (read-only verifier split)
  - Files: plugins/phased-workflow/scripts/agent-session.sh (new), plugins/phased-workflow/skills/finalize-workflow-agent/SKILL.md (new), plugins/phased-workflow/skills/finalize-workflow/SKILL.md, tools/kb-sync.py (2 MAPPING entries), plugins/phased-workflow/install.sh (SUPPORT_PATHS unchanged — plugin-scoped)
  - Decisions: agent-session.sh <skill> [--model M] [--effort E]: resolves the plan (--plans; several → error listing them), cds to its root, runs `claude -p "/<skill>" --permission-mode auto` teeing to `log/<skill>.txt`. The sub-session prompt is shipped here, never composed by the caller. finalize-workflow-agent is READ-ONLY: verify every phase's Done:, review the whole BASE..HEAD diff, return classified findings (confirmed / dismissed / cross-phase); never touches history, never edits. finalize-workflow: when the plan's branch has a worktree or cwd is outside the plan root, silently run the agent via agent-session.sh and read its report instead of the in-session code-review; otherwise in-session review as today. Fix the allowed-tools inconsistency: add Agent to finalize-workflow's frontmatter (its Step 4 panel needs it). run-workflow.sh keeps its own tested invocation (S14 extracts contracts from it) — noted as accepted divergence from "one launcher".
  - Details: write the script; write the agent skill (thin: constraints + delegate the review criteria to finalize-workflow's Step 4 text via reference); rewire finalize Step 4; MAPPING += both.
  - Done: S16 green (new skills mapped); `bash -n agent-session.sh` clean; suite green.

- [ ] **Phase 9**: -agent convention — execute-phase-agent + shared core + guard (L)
  - Pattern: `plugins/phased-workflow/refs/common.md` (the extract-shared-prose precedent)
  - Files: plugins/phased-workflow/refs/phase-execution.md (new), plugins/phased-workflow/skills/auto-phase/ → execute-phase-agent/, plugins/phased-workflow/skills/execute-phase/SKILL.md, plugins/phased-workflow/scripts/run-workflow.sh (PHASE_PROMPT text + pre-2.1.139 fallback '/auto-phase'), tests/benchmark/bench.sh:9-10,80, tests/orchestration/run_tests.sh (S21 fixture path + new S23 guard), tools/kb-sync.py (MAPPING + title), plugins/phased-workflow/install.sh (RETIRED_NAMES += auto-phase), plugins/phased-workflow/refs/common.md (command list)
  - Decisions: refs/phase-execution.md holds the shared execution core (phase selection acting on recommendation, implement-from-Pattern, outcome fields, one-commit-per-phase format, WIP escape). execute-phase keeps: gate, interactive questions, user-verifier for UI. execute-phase-agent keeps: no-questions, baseline check + attribution, convergence loop, verifier policy — and must cite both the base skill and the core ref. Guard S23: every skills/*-agent/SKILL.md ≤ 100 lines AND names its base skill AND cites refs/phase-execution.md or the base's criteria — asserted with a mutation check that runs the REAL guard (per M.4 idiom). repair-phase keeps its name this wave (no interactive sibling exists yet; noted in common.md as agent-natured).
  - Details: extract core; rewrite both skills thin; rename dir; PHASE_PROMPT "Use the auto-phase skill" → "Use the execute-phase-agent skill"; fallback prompt '/execute-phase-agent'; sweep bench.sh comments; S21's mutation fixture appends to skills/execute-phase-agent/SKILL.md (path update).
  - Done: suite green in both shells (S14 contract assertions still extract; S23 green including its mutation); `grep -rn auto-phase` only in historical docs/changelog.

- [ ] **Phase 10**: Carried defects — validator warnings surfaced, guard coverage (M.2–M.6)
  - Pattern: tests/orchestration/run_tests.sh S15 (mutation checks re-run the real script — the correct idiom)
  - Files: plugins/phased-workflow/scripts/run-workflow.sh (M.2), tests/orchestration/check_state_matches.py (new, M.3), tests/orchestration/check_home_paths.py (new, M.4), tests/orchestration/run_tests.sh (S18, S21 rewired; header M.6), plugins/phased-workflow/scripts/next-phase.py + plugins/phased-workflow/refs/common.md (M.5: `Verified` added to KNOWN_NOTE_FIELDS and documented)
  - Decisions: M.2 — the launcher prints the validator output whenever it is non-empty, not only on failure (warnings become visible; still proceeds on exit 0). M.3 — the S18 guard moves to check_state_matches.py and covers BOTH grep and awk lines: any line matching a phase-state bracket outside the four helpers must carry the `\*\*Phase` anchor; S18's mutation check strips the anchor from the awk block on a copy and asserts the real guard goes red. M.4 — S21's walker moves to check_home_paths.py, used by both the check and its mutation. M.5 — `Verified` becomes a known note field; the NOTE_RE wrapped-continuation false positive stays, documented in the validator comment. M.6 — header rewritten to describe S1–S23 accurately (live vs static vs hybrid).
  - Details: as per decisions; extend S19 with one assertion that a warnings-only plan run PRINTS the warning lines.
  - Done: suite green in both shells; deliberate mutations (anchor stripped, ~/.claude/ path reintroduced) each turn the suite red when applied by hand during the phase and are reverted.

- [ ] **Phase 11**: Docs, versioning, release notes (M.7 included)
  - Pattern: README.md `## What changed in 4.1.0` (line 608) — same shape for 5.0.0
  - Files: README.md, docs/loop-engineering.md, docs/article-medium.md (historical note if not already added in Phase 2), docs/target-workflow.md (mark Macro 1 done), CLAUDE.md.example, plugins/phased-workflow/.claude-plugin/plugin.json, .claude-plugin/marketplace.json, ~/.claude/CLAUDE.md (user's global — the auto-phase/run-all-phases exception line)
  - Decisions: version 5.0.0 (breaking: renames + retirement + tag removal). M.7 fixed with the accurate split: 17 scenarios drive the launcher against the mock (S1–S13, S17, S19, S20), static checks S14–S16, S21–S23, S18 both — counts restated in README:556-565 and loop-engineering:184-200. README "What changed in 5.0.0" section lists: /resume-workflow (absorbs /check-phase-context), /run-workflow (was /run-all-phases), /execute-phase-agent (was /auto-phase), finalize-workflow-agent + agent-session launcher, --plans location service, worktree lifecycle moved to execution, parallel:N/group:N retired, validator warnings surfaced, guard coverage extended. User's global CLAUDE.md: the exception line renames the two commands it cites.
  - Details: sweep all stale names/counts; update both JSON versions; keep README:493's historical file references intact.
  - Done: `grep -rn '4\.1\.0' README.md plugins/` shows only the historical changelog section; suite green; validator green on the benchmark fixture plan (CI's last step).

- [ ] **Phase 12**: Coherence review and auto-fix (final)
  - Pattern: cross-check against Phases 1–11
  - Files: only files written by Phases 1–11; .phased/active/command-surface-5-0-0/review.md (new)
  - Decisions: auto-fix only tool-fixable lint and mechanical stragglers (a missed rename); logic/design findings go to review.md, not fixed. Mutation spot-checks: revert one awk anchor and one contract clause on a copy, confirm the suite catches both.
  - Details: full suite bash + zsh, flake8, validator on the benchmark fixture AND on this very plan; repo-wide greps for run-all-phases / auto-phase / check-phase-context / parallel: / group: outside historical sections; write review.md (Auto-fixed / Flagged for human / Final state).
  - Done: review.md exists with the three sections; flake8 zero; both suites green; this plan validates clean.

## Notes
- Breaking release (5.0.0): users typing /run-all-phases, /auto-phase or /check-phase-context get the RETIRED_NAMES migration; KB titles preserved via KB_ONLY notes.
- The "one launcher, two callers" consolidation is delivered as agent-session.sh for finalize; run-workflow.sh keeps its own invocation because S14 extracts the shipped contracts from it — recorded as an accepted divergence to revisit in Macro 2.
- Macro 2 (D, E), Macro 2b (J, J2, J3) and Macro 3 (G) are in .phased/roadmap.md.
- docs/target-workflow.md is committed with this plan as the design record.
