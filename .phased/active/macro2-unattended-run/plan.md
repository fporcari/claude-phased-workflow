# Context: wf/macro2-unattended-run
Parent: main
Mode: autonomous

## Objective
Implement Macro 2 of `docs/target-workflow.md` — the unattended run — and ship it as
5.1.0. Item D turns the automation choice into one explicit question asked *before* the
plan is written, whose answer selects the plan format (`Mode: interactive` /
`Mode: autonomous`) and is honoured by every skill that consumes a plan. Item E makes a
run reportable while it is still running: stable event lines in the launcher, a
background launch watched by a Monitor, a proactive notification on the first `[!]` and
at the end, and one line about Remote Control at the only moment it matters.

## Work Plan
- [ ] **Phase 1**: Mode header semantics in the plan validator
  - Pattern reference: `plugins/phased-workflow/scripts/next-phase.py:validate` — the `mode_autonomous` flag (its `^Mode:\s*autonomous\b` match) and the `Mode: autonomous requires a "## Suggested execution config" table` error are the two sites to generalise. Test idiom: `tests/orchestration/run_tests.sh` S19b/S19c (plan fixture, `finish_setup; run`, `assert` on `out.log`) plus that section's direct-invocation warning case (`WARN_PLAN`).
  - Files: plugins/phased-workflow/scripts/next-phase.py, tests/orchestration/run_tests.sh
  - Decisions:
    - One match per plan: `MODE_RE = re.compile(r'^Mode:\s*(\S+)\s*$')`, value lowercased. Accepted values: `autonomous`, `interactive`.
    - Unknown value → **error**, naming it: `Mode: '<value>' is not one of: autonomous, interactive`. A typo must never degrade silently into the interactive default.
    - No `Mode:` line → no finding at all. Legacy plans read as interactive.
    - `Mode: interactive` together with a `## Suggested execution config` table → **warning**: nothing reads that table on an interactive plan, and its presence means a half-converted plan.
    - `Mode: autonomous` without the table stays the existing error, unchanged.
    - Findings keep the existing `(lineno, severity, message)` shape. No new machinery, no new exit codes.
  - Details: in `validate()` replace the inline autonomous match with `MODE_RE`, record the value and its line number, and derive `mode_autonomous` / `mode_interactive` from it. After the loop, add the unknown-value error (anchored at the `Mode:` line) and the interactive-plus-table warning (anchored at the table's line). Then extend S19: (f) a live run on a plan carrying `Mode: robot` is rejected, the gate names `robot`, and `.claude/invocations.log` stays empty; (g) direct `--validate` on a `Mode: interactive` plan carrying a config table exits 0 and prints exactly one `warning:` line, naming the table; (h) direct `--validate` on a plan with no `Mode:` line and no table exits 0 with no finding. Update the suite's header comment so S19's description mentions Mode validation — the header has to keep matching what the suite runs.
  - Done: `bash tests/orchestration/run_tests.sh` exits 0 and prints no line containing `FAIL`; `flake8 plugins/phased-workflow/scripts/next-phase.py` reports zero errors.
- [ ] **Phase 2**: The automation fork in /write-workflow
  - Pattern reference: `plugins/phased-workflow/skills/write-workflow/SKILL.md` — its own step structure and the `Mode:` routing line the fork replaces; `plugins/phased-workflow/refs/common.md` → *AskUserQuestion style* for the question shape. Test idiom: `tests/orchestration/run_tests.sh` S23 — a guard function printing one line per violation, asserted empty, then re-run unchanged on a mutated copy.
  - Files: plugins/phased-workflow/skills/write-workflow/SKILL.md, plugins/phased-workflow/refs/write-workflow-autonomous.md, tests/orchestration/run_tests.sh
  - Decisions:
    - The fork becomes `## Step 2: The automation fork`, between today's Step 1 and today's Step 2; the following steps renumber to 3..6, and the two internal cross-references ("This same fork decides the branch in Step 4", "pre-filled per Step 3") are updated to the new numbers.
    - One AskUserQuestion, two options: autonomous (`/run-workflow` runs it unattended) and interactive (one chat per phase with `/execute-phase`). The recommended option comes first per `common.md`, and *which* one is recommended is derived from the work just discussed and stated in one line with its reason: UI work → interactive; heavy refactor, project startup, mechanical migration → autonomous. No fixed default.
    - The answer routes the rest of the skill: autonomous → read `refs/write-workflow-autonomous.md` and apply it on top; interactive → continue with this file's format.
    - Both formats carry an explicit header: `Mode: interactive` in this skill's plan template, `Mode: autonomous` in the reference's (already there). A plan with no header stays legal and reads as interactive.
    - The clause "plans are **interactive** by default; don't ask" is deleted — it is the exact instruction the fork replaces.
    - `refs/write-workflow-autonomous.md` loses its own "Confirm with the user … before starting" line: with the fork, that is the same question twice. Its *Honesty check* becomes the documented way back — if the refinement shows the task does not fit, flip the fork to interactive instead of forcing the plan.
    - The interactive plan format is NOT otherwise changed: `Verify:` and the manual sizing rules belong to Macro 2b.
  - Details: edit the two files as decided. Then add S24 to the suite: an `s24_guard()` function over the skills dir and the refs dir printing one line per violation — `write-workflow/SKILL.md` must contain a `## Step 2: The automation fork` heading, must contain `Mode: interactive`, and must not contain `don't ask`; `write-workflow-autonomous.md` must not contain `Confirm with the user`. Assert its output empty, then prove it by re-running the same function on a copy with the fork heading removed, and on a copy with `don't ask` reintroduced — non-empty both times. Add S24 to the suite header comment.
  - Done: `bash tests/orchestration/run_tests.sh` exits 0 with no `FAIL` line and its output carries the S24 assertions; `grep -c "don't ask" plugins/phased-workflow/skills/write-workflow/SKILL.md` prints 0; `grep -c "Confirm with the user" plugins/phased-workflow/refs/write-workflow-autonomous.md` prints 0.
- [ ] **Phase 3**: The fork's consumers — /run-workflow pre-flight and /import-workflow
  - Pattern reference: `plugins/phased-workflow/skills/run-workflow/SKILL.md` pre-flight steps 1-6 (the refinement offer it already makes, and its `wf: refine plan for autonomous run` commit) and `plugins/phased-workflow/skills/import-workflow/SKILL.md` step 3 *Map onto the plan format* with its gap report. Guard: Phase 2's `s24_guard()`.
  - Files: plugins/phased-workflow/skills/run-workflow/SKILL.md, plugins/phased-workflow/skills/import-workflow/SKILL.md, tests/orchestration/run_tests.sh
  - Decisions:
    - `/run-workflow`'s pre-flight reads the plan's `Mode:` header as its first act. `autonomous` → proceed as today. `interactive` → say so plainly and offer the conversion (refine every phase to the autonomous bar, add the execution config table, flip the header to `Mode: autonomous`, commit the rewrite as the existing `wf: refine plan for autonomous run`) or stop. Never convert silently. No header → legacy plan, treated as today, with no accusation.
    - `/import-workflow` asks the same fork question and writes the resulting header into the imported plan. It points at `/write-workflow`'s Step 2 for the question and the derivation rule rather than restating them — one source. Its existing gap report against the autonomous-ready bar stays, and is what the autonomous answer feeds.
    - Neither skill gains a tool: both already declare what they need.
  - Details: add the mode read and its three branches to `/run-workflow`'s pre-flight step 1; add the fork to `/import-workflow`'s mapping step. Extend `s24_guard()`: `run-workflow/SKILL.md` must mention `Mode: interactive` and the conversion offer; `import-workflow/SKILL.md` must write a mode header. Extend the mutation proof to one of the two new rules.
  - Done: `bash tests/orchestration/run_tests.sh` exits 0 with no `FAIL` line; `grep -q "Mode: interactive" plugins/phased-workflow/skills/run-workflow/SKILL.md` succeeds; `grep -qE "Mode: (interactive|autonomous)" plugins/phased-workflow/skills/import-workflow/SKILL.md` succeeds.
- [ ] **Phase 4**: Stable EVENT lines in the launcher
  - Pattern reference: `plugins/phased-workflow/scripts/run-workflow.sh` — its existing `echo "NOTE: …"` announcement sites, the `phase_re`/`phase_lines` helpers, and the three outcome branches (`[!]` before the repair session, `[~]` blocked, end-of-loop summary). Test idiom: S3/S4 (mock queue → `run` → `assert` on `out.log`) and S20a (an announced line asserted verbatim).
  - Files: plugins/phased-workflow/scripts/run-workflow.sh, tests/orchestration/run_tests.sh
  - Decisions:
    - Exactly three event tokens, one line each on stdout, prefix `EVENT: `:
      `EVENT: phase-failed <N>` — when the loop finds a `[!]` phase, before launching the repair session;
      `EVENT: phase-blocked <N>` — when it finds a `[~]` phase;
      `EVENT: run-end <status> <done>/<total>` — once, after the summary, with status `ok` when every phase is `[x]`, `stopped` otherwise.
    - Nothing else becomes an event: per-phase progress stays human prose. The set is small on purpose — every token becomes a notification in the parent chat.
    - Events go to **stdout only**. No file inside the repo and no `osascript`: the launcher must stay silent under the test suite, and must not write into `.phased/` — a file appended mid-phase dirties the tree at the next phase's start and lands inside that phase's commit, which is what the clean-tree invariant and red-baseline attribution rest on.
    - Phase numbers come from the phase helpers already in the file, never from a second grep.
  - Details: add the three echoes at the three sites, taking the phase number from the existing helpers. Then add S25's live half: a run whose mock fails phase 1 and whose repair fails prints `EVENT: phase-failed 1`; a run on the blocked fixture prints `EVENT: phase-blocked`; a clean three-phase run prints `EVENT: run-end ok 3/3` exactly once. Add S25 to the suite header comment.
  - Done: `bash -n plugins/phased-workflow/scripts/run-workflow.sh` exits 0; `bash tests/orchestration/run_tests.sh` exits 0 with no `FAIL` line and its output carries the S25 live assertions.
- [ ] **Phase 5**: The notification protocol in /run-workflow
  - Pattern reference: `plugins/phased-workflow/skills/run-workflow/SKILL.md` → *Execution* (the single Bash call it owns today) and `plugins/phased-workflow/refs/common.md` section shape (a short shared convention the skills point at). Guard idiom: S14 (extract the shipped string from the real file, assert on what was extracted) plus `tests/orchestration/check_allowlists.py`'s `TOOL_HINTS` coupling (S15).
  - Files: plugins/phased-workflow/skills/run-workflow/SKILL.md, plugins/phased-workflow/refs/common.md, tests/orchestration/check_allowlists.py, tests/orchestration/run_tests.sh
  - Decisions:
    - Launch: `mkdir -p "${TMPDIR:-/tmp}/phased-workflow"`, then `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-workflow.sh" 2>&1 | tee "${TMPDIR:-/tmp}/phased-workflow/<slug>-run.log"`, run in background. The log lives outside the repo for the reason stated in Phase 4.
    - Watch: one persistent Monitor on that log, filtered to the event tokens and self-terminating on `run-end`: `tail -f -n +1 <log> | awk '/^EVENT: (phase-failed|phase-blocked)/ {print; fflush()} /^EVENT: run-end/ {print; fflush(); exit}'`.
    - Push policy: PushNotification on the **first** `phase-failed` of the run, on any `phase-blocked`, and once when the run ends — the end push comes from the background command's own completion, not from the `run-end` event, so there is exactly one source per notification and no duplicate. At most one failure push per run. Nothing else is pushed: routine progress is not worth an interruption.
    - Message shape: lead with what the user would act on, under 200 characters, one line, no markdown — e.g. `run stopped: phase 4 [!] after repair, 3/7 done — see its > Issue: note`.
    - While the run is in background the parent session does **not** write to the repository. The run owns the working tree, and a parent-side edit breaks the clean-tree invariant every phase session checks.
    - Degradation is declared, not silent: without Monitor or PushNotification, run the script in the foreground exactly as today and report once at the end — and say that the early `[!]` notification needs the background path.
    - The launch confirmation gains one line: the run stays attached to this session, so leave the app open; with Remote Control connected the end-of-run and first-`[!]` notifications reach the phone.
    - `/execute-phase`'s `osascript` notification stays as it is: there the user is present, and a local ping is the right tool.
  - Details: add the Remote Control line to the pre-flight confirmation (step 6) and rewrite *Execution* with the launch, the Monitor, the push policy and the fallback; add `Monitor` and `PushNotification` to the skill's `allowed-tools`. Add a short *Notifications* section to `refs/common.md` carrying the policy once (local ping when the user is present, PushNotification when they may be away, what is worth a push) and point the skill at it. Add `Monitor` and `PushNotification` to `TOOL_HINTS` in `check_allowlists.py`, so a skill instructing them must declare them. Then add S25's static half: extract every `EVENT: <token>` emitted by `run-workflow.sh` and assert each token appears in `run-workflow/SKILL.md`; prove it by re-running the same guard on a copy of the skill with the `phase-failed` token removed.
  - Done: `bash tests/orchestration/run_tests.sh` exits 0 with no `FAIL` line; `python3 tests/orchestration/check_allowlists.py plugins/phased-workflow/skills` exits 0; `grep -q "Remote Control" plugins/phased-workflow/skills/run-workflow/SKILL.md` succeeds.
- [ ] **Phase 6**: Documentation and the 5.1.0 release notes
  - Pattern reference: `README.md` → *What changed in 5.0.0* (the section this one is modelled on: one bullet per item, naming the item and its guard) and `docs/target-workflow.md` → item K's *DECIDED for finalize* paragraph (the shape for recording a settled mechanism together with what was rejected).
  - Files: README.md, docs/loop-engineering.md, docs/target-workflow.md, plugins/phased-workflow/.claude-plugin/plugin.json, .claude-plugin/marketplace.json
  - Decisions:
    - Version `5.1.0` in all three places: `plugin.json`, and both `version` fields in `.claude-plugin/marketplace.json` (the `metadata` one and the plugin entry).
    - README: the `/write-workflow` section states the fork; *Plan Format* documents `Mode: interactive` beside `Mode: autonomous` and that a missing header means interactive; the `/run-workflow` section carries the Remote Control line and the notification behaviour; a new *What changed in 5.1.0* section goes above the 5.0.0 one; the FAQ gains "can I walk away during a run?", answered with the attached-session plus Remote Control fact.
    - README's *Why no commit during phases?* is corrected: the claim that `/execute-phase` never commits has been false since 5.0.0 — `refs/phase-execution.md` gives both paths one commit per phase. The FAQ answer that repeats the claim is corrected in the same pass.
    - `docs/target-workflow.md`: items D and E gain the settled mechanism and what was rejected (an event file inside `.phased/`, `osascript` in the launcher, detachment per D2); the Macro 2 entry in the macro split is marked DONE in 5.1.0, like Macro 1's.
    - `docs/loop-engineering.md`: only where it describes the launcher's output or the walking-away story. No rewrite.
  - Details: apply the edits above, then grep both docs and the README for the retired claim rather than the README alone.
  - Done: `grep -rn "never commits" README.md docs/ | grep -c "execute-phase"` prints 0; `grep -c '"version": "5.1.0"' .claude-plugin/marketplace.json` prints 2 and the same grep on `plugins/phased-workflow/.claude-plugin/plugin.json` prints 1; `grep -q "What changed in 5.1.0" README.md` succeeds; `grep -q "DONE in 5.1.0" docs/target-workflow.md` succeeds; `bash tests/orchestration/run_tests.sh` exits 0.
- [ ] **Phase 7**: Coherence review and auto-fix (final, mandatory)
  - Pattern reference: same as Phases 1..6 (cross-check against them)
  - Files: only the files written by Phases 1..6 (collect them from their `Files:` fields). Never touch a pre-existing file they did not modify.
  - Decisions:
    - Auto-fix directly: tool-fixable lint (flake8 on the Python files), unused imports, formatting, trivially mechanical fixes. Re-run the suite after each non-tooling fix; if one breaks a test, roll back that fix and flag it instead.
    - Never auto-fix: logic errors, design divergences from the pattern reference, missing edge cases, anything architectural. Those go to `review.md` only.
    - Specific cross-checks for this wave: the fork question is described in exactly one place and cited elsewhere (no second copy of the derivation rule); the `EVENT:` token set in the launcher, in the skill and in S25 agree; no new prose reintroduces `~/.claude/` paths (S21) or exceeds a skill's `allowed-tools` (S15).
  - Details: convergence loop (max 3 cycles) of `flake8` scoped to the touched Python files → auto-fix → `flake8` → `bash tests/orchestration/run_tests.sh`; stop early if a cycle makes no progress. Then write `.phased/active/macro2-unattended-run/review.md` with three sections: **Auto-fixed** (file, what, tool), **Flagged for human** (file, description, suggested action), **Final state** (flake8 output, suite result, files reviewed).
  - Done: `review.md` exists in the plan directory with the three sections; `flake8` reports zero errors on the touched Python files; `bash tests/orchestration/run_tests.sh` exits 0 with no `FAIL` line.

## Notes
- **Baseline at the plan commit:** `bash tests/orchestration/run_tests.sh` → `RESULT: 122 passed, 0 failed`; `flake8` clean. A phase that finds the suite already red before its own edits must attribute that, not absorb it.
- **The run executes the installed plugin copy** (`~/.claude/plugins/cache/claude-phased-workflow/phased-workflow/5.0.0/`), not this repository's files. Rewriting `run-workflow.sh` and the skills during the run is therefore safe and has no effect on the run in progress — the changes take effect at the next plugin update.
- **New test numbers:** S24 (the automation fork is not decorative — static, mutation-proven), S25 (the EVENT contract — live on the mock plus a static drift guard). S16 stays vacant.
- **Nothing is renamed and no command is added,** so `install.sh`'s `RETIRED_NAMES` and the distribution path stay untouched.
- **Out of scope, deliberately:** Macro 2b (manual mode — `Verify:`, `verify.md`, the `ui-test` split, the manual sizing rules). The interactive branch of the fork keeps today's plan format; only the header and the routing land here.
- **D2 stands:** attached session plus Remote Control, no detachment. A detached run has no session to notify from, which is the whole reason the notification lives on the session side.

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | medium | opus |
| Phase 2 | high | opus |
| Phase 3 | medium | opus |
| Phase 4 | medium | opus |
| Phase 5 | high | opus |
| Phase 6 | medium | opus |
| Phase 7 | xhigh | opus |
