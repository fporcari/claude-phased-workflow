# Coherence review — review-hardening-4-1-0 (Phase 10)

Final coherence review of the file set written by Phases 1–9, plus auto-fix of
mechanical issues. Baseline before this phase was green (flake8 clean; bash and
zsh suites 109/0), so no red-baseline attribution applied.

## Auto-fixed

| File | What | How |
|------|------|-----|
| `plugins/phased-workflow/install.sh` (line 84) | The migration tool printed `claude plugin install phased-workflow@fporcari/claude-phased-workflow` — the **GitHub slug** as the install ref. `README.md` (line 463) documents the correct ref as `phased-workflow@claude-phased-workflow` (the **marketplace name** declared in `marketplace.json`, confirmed = `claude-phased-workflow`) and explicitly warns "not the GitHub slug you passed to `marketplace add`". install.sh contradicted the repo's own documented convention. | Manual one-token edit to the marketplace-name form, matching README and `marketplace.json`. The sibling `marketplace add fporcari/claude-phased-workflow` line (line 83) is correct as-is — `marketplace add` takes the slug — and was left untouched. Mechanical: the correct value is unambiguously documented in-repo, the file is a deprecated ≤4.0.0 migration tool with no test coverage of its output, and `bash -n` + both suites stayed green after. |

No lint findings to fix: `flake8 .` reported zero errors before and after (the
only Python file in the set, `next-phase.py`, was already clean — no unused
imports, no formatting issues).

## Flagged for human

These are content/design/historical matters, deliberately not auto-fixed per the
phase's rule ("Never auto-fix: logic errors, design divergences, missing edge
cases, anything architectural").

1. **`plugins/phased-workflow/skills/auto-phase/SKILL.md` (line 2) — frontmatter
   `description` still says "no commit", but the skill commits every phase.**
   The `description:` reads `Execute the next phase autonomously — no
   confirmations, auto-test, no commit`, yet the skill body says the opposite:
   line 8 ("record the outcome, **commit**, exit") and line 13 ("**One commit, at
   the end, for your own phase** (Step 6)"), and Step 6 runs `git add -A && git
   commit`. This is the one place the per-phase-commit correction of Phases 8–9
   did not reach, and it is user-visible (it is the text shown in the skill
   listing). It is `execute-phase` that does not commit — its description
   correctly omits any commit claim. *This concerns the commit architecture (the
   subject of Phase 8), so it is flagged rather than auto-fixed.*
   **Suggested action:** drop the trailing `, no commit` from the description (or
   reword to "auto-commits each phase"), so it matches the body and the 4.1.0
   commit model.

2. **`README.md` — line 243 vs line 424 disagree on whether `/auto-phase`'s
   independent verifier always runs.** Line 243 lists "Independent verification"
   as an unconditional numbered step of the loop; line 424 states the verifier
   "now runs only where it earns its keep — a `sonnet` phase, a `new-pattern`
   phase, or a repair." The skill body (`auto-phase/SKILL.md` Step 5) matches line
   424. Line 243 reads as a pre-change description. Minor, internal to README.
   **Suggested action:** reconcile line 243 to note the verifier runs
   conditionally, consistent with line 424 and the skill.

3. **`docs/article-medium.md` — describes a retired command set and older
   conventions.** It documents `/create-context` / `/close-context` /
   `/clean-contexts` (retired in 3.0.2), uses `MEMORY.md` as the coordination file
   rather than `.phased/active/<slug>/plan.md`, recommends "Haiku" (outside the
   fable/sonnet/opus tier map), uses the slug install form (line ~190), and says
   "six commands" while listing seven. Phase 9 deliberately only `git mv`-ed this
   file (no content rewrite) and treated it as a published narrative — so this is
   **likely intentional historical content**, flagged only for completeness.
   **Suggested action:** if the article is meant to reflect current behavior,
   refresh it; if it is a historical/published piece, add a "written against
   version X" note. Low priority.

## Final state

**Specific cross-checks (all pass):**

- **Phases 1/2/3/4/8 coexist in `run-all-phases.sh` without one undoing another.**
  Phase 1's four helpers (`phase_re`/`phase_count`/`phase_any`/`phase_lines`) are
  present and used at all 10 call sites; Phase 2's `SCRIPT_DIR`/`NEXT_PHASE_PY`
  self-resolution present, zero `HOME/.claude` refs; Phase 3's `--validate`
  pre-loop gate present; Phase 4's `REC_RAW=$(… 2>&1)` (no `2>/dev/null` on the
  selector line) and 7 `NOTE:` lines present; Phase 8's `LIGHT_PROMPT` carries the
  `wf(phase N): <title>` clause and no `Never commit`. `bash -n` and `zsh -n`
  clean.
- **No phase-state grep bypasses Phase 1's helpers.** Every state match on `$PLAN`
  goes through the four helpers or `first_bang_block`'s strict awk
  (`^- \[[ x!~>]\] \*\*Phase` / `^- \[!\] \*\*Phase`). The remaining greps are a
  table-row lookup (`^\|…Phase N`), note-field matches (`Repair attempted:`,
  `^[[:space:]]*> WIP:`), a different-file roadmap read (`.phased/roadmap.md`), and
  a plan-list line count — none of which read a plan phase-state.
- **No `~/.claude/` under `skills/` or `refs/` except the documented exemption.**
  Only `refs/common.md:165` (`settings.json` mention). `${CLAUDE_PLUGIN_ROOT}` is
  still present across 11 skill/ref files after Phase 9's re-edits.
- **Doc numbers match reality.** Suite `RESULT:` = "109 passed, 0 failed" over
  scenarios S1–S21 (= 21); README states "109 assertions over 21 scenarios"
  (line 557), describes S18–S21 and the CI workflow, and carries no stale
  `62 assertions` / `62/62` / "extracts the script from its own SKILL.md" claim.
  Every `~37%` / `~60%` benchmark figure (README, `loop-engineering.md` ×2, the
  launcher comment) names its provenance (n=3 seeded toy fixture, `slim` hardcoded
  control — not the shipped light mode) in the same breath; the stale
  "~40% cheaper / half the wall time" wording is gone. Versions = `4.1.0` in
  `plugin.json` and both `marketplace.json` fields. `article-medium.md` moved to
  `docs/` (root copy gone, no broken inbound links). `minchiate` gone from
  `plugins/`. `ci.yml` parses and references only files that exist;
  `next-phase.py --validate` on the benchmark fixture = 0 errors / 0 warnings.

**Linter:** `flake8 .` → 0 errors.

**Test suites:** `bash tests/orchestration/run_tests.sh` → 109 passed, 0 failed
(exit 0); `zsh tests/orchestration/run_tests.sh` → 109 passed, 0 failed (exit 0).

**Files reviewed (21 — the union of Phases 1–9 `Files:` lists):**
`plugins/phased-workflow/scripts/run-all-phases.sh`,
`plugins/phased-workflow/scripts/next-phase.py`,
`plugins/phased-workflow/install.sh`,
`tests/orchestration/run_tests.sh`,
`plugins/phased-workflow/skills/write-workflow/SKILL.md`,
`plugins/phased-workflow/skills/auto-phase/SKILL.md`,
`plugins/phased-workflow/skills/check-phase-context/SKILL.md`,
`plugins/phased-workflow/skills/execute-phase/SKILL.md`,
`plugins/phased-workflow/skills/finalize-workflow/SKILL.md`,
`plugins/phased-workflow/skills/import-workflow/SKILL.md`,
`plugins/phased-workflow/skills/pull-request/SKILL.md`,
`plugins/phased-workflow/skills/repair-phase/SKILL.md`,
`plugins/phased-workflow/skills/run-all-phases/SKILL.md`,
`plugins/phased-workflow/refs/common.md`,
`plugins/phased-workflow/refs/write-workflow-autonomous.md`,
`.github/workflows/ci.yml`,
`README.md`,
`docs/loop-engineering.md`,
`docs/article-medium.md`,
`plugins/phased-workflow/.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json`.
