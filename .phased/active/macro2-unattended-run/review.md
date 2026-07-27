# Coherence review — Phase 7 (macro2-unattended-run)

Final coherence review and auto-fix over the files written by Phases 1–6.
Scope: only files these phases modified; no pre-existing file was touched.

## Auto-fixed

| File | What | Tool |
|------|------|------|
| — | Nothing to fix. | — |

The convergence loop ran once and stopped on no-progress: `flake8` on the two
touched Python files (`plugins/phased-workflow/scripts/next-phase.py`,
`tests/orchestration/check_allowlists.py`) was already clean, and the suite was
already green, so there was no tool-fixable lint, no unused import and no
mechanical formatting to correct. Phase 7 made no code edits.

## Flagged for human

None. Nothing architectural, no logic error, no divergence from the pattern
references, no missing edge case surfaced. The wave's four coherence
cross-checks all held:

1. **The automation fork lives in exactly one place, cited elsewhere.** The
   derivation rule ("Heavy refactor, project startup, mechanical migration →
   autonomous"; UI work → interactive) appears only in
   `write-workflow/SKILL.md:38`. `import-workflow/SKILL.md:55` points at
   `/write-workflow`'s *Step 2* explicitly — "do not restate them here, that
   skill is the one source" — rather than copying the rule. No second copy of
   the derivation rule exists in the skills or refs dirs. (The other two grep
   hits for the keywords are unrelated "untested UI work" prose in
   `execute-phase/SKILL.md` and `common.md`.)
2. **The `EVENT:` token set agrees across launcher, skill and S25.** The
   launcher emits exactly `phase-failed` (`run-workflow.sh:331`),
   `phase-blocked` (`:382`) and `run-end` (`:454`); `run-workflow/SKILL.md:57`
   names all three; S25 in `run_tests.sh` asserts all three live plus a static
   drift guard. No token is emitted that the skill or the test does not know
   about, and none is documented that the launcher does not emit.
3. **No new prose reintroduces `~/.claude/` plugin paths (S21).** Every
   `~/.claude/` occurrence in the touched files is legitimate: the documented
   S21 exemption (`refs/common.md:194`, the `settings.json` self-modification
   mention) and README/`docs` migration-and-legacy narrative, which S21 does
   not scope. `check_home_paths.py` (S21) passes.
4. **No skill exceeds its `allowed-tools` (S15).** `check_allowlists.py`
   reports 0 findings; the `Monitor` and `PushNotification` tools that
   `run-workflow/SKILL.md` now instructs are declared in its `allowed-tools`
   and pinned in `TOOL_HINTS`.

Additional cross-package consistency checks, all coherent:

- **Version bump is uniform.** `5.1.0` appears twice in
  `.claude-plugin/marketplace.json` and once in
  `plugins/phased-workflow/.claude-plugin/plugin.json`; no stray `5.0.0`
  remains in either file.
- **The "`/execute-phase` never commits" claim stays retired.**
  `grep -rn "never commits" README.md docs/ | grep -c "execute-phase"` → 0.
- **The `Mode:` header chain is closed end to end.** `/write-workflow` writes
  `Mode: interactive`, `refs/write-workflow-autonomous.md` writes
  `Mode: autonomous`, `/run-workflow` reads and branches on `Mode: interactive`,
  `/import-workflow` writes a `Mode:` header, and `next-phase.py` validates the
  value (`MODE_RE`/`MODES`).

## Final state

- **flake8** (touched Python files
  `plugins/phased-workflow/scripts/next-phase.py`,
  `tests/orchestration/check_allowlists.py`): exit 0, zero errors.
- **Suite** (`bash tests/orchestration/run_tests.sh`): exit 0, `RESULT: 142
  passed, 0 failed`, no `FAIL` line.
- **check_allowlists.py** (`plugins/phased-workflow/skills`): 0 findings.

### Files reviewed (deliverables of Phases 1–6)

- `.claude-plugin/marketplace.json`
- `README.md`
- `docs/target-workflow.md`
- `plugins/phased-workflow/.claude-plugin/plugin.json`
- `plugins/phased-workflow/refs/common.md`
- `plugins/phased-workflow/refs/write-workflow-autonomous.md`
- `plugins/phased-workflow/scripts/next-phase.py`
- `plugins/phased-workflow/scripts/run-workflow.sh`
- `plugins/phased-workflow/skills/import-workflow/SKILL.md`
- `plugins/phased-workflow/skills/run-workflow/SKILL.md`
- `plugins/phased-workflow/skills/write-workflow/SKILL.md`
- `tests/orchestration/check_allowlists.py`
- `tests/orchestration/run_tests.sh`

`docs/loop-engineering.md` was deliberately left untouched by Phase 6 and is
correctly absent from the branch diff — no review action needed.
