# Context: wf/review-hardening-4-1-0
Parent: main
Mode: autonomous

## Objective
Act on the seven findings of the external review of claude-phased-workflow 4.0.0,
all verified against the current code. Three are defects in the autonomous
launcher (phase-state matching that reads prose bullets as phases, no plan
validation, silent degradation of the phase selector), two are distribution and
CI gaps, and two are documentation claims that outrun their evidence. Ship as
4.1.0.

## Work Plan

- [x] **Phase 1**: Unify every phase-state match in the launcher
  > Done: Centralised every phase-state match in run-all-phases.sh behind four
  > single-source helpers (phase_re/phase_count/phase_any/phase_lines); all ten
  > call sites, first_bang_block's awk and the WIP grep now go through the strict
  > `**Phase` anchor. Added S18 (decoys inert + static regression guard). Suite:
  > 84 passed / 0 failed under both bash and zsh (>77); bash -n and zsh -n clean.
  > Files: plugins/phased-workflow/scripts/run-all-phases.sh, tests/orchestration/run_tests.sh
  - Pattern reference: `plugins/phased-workflow/scripts/run-all-phases.sh` — the
    `REMAINING=$(grep -c '^\- \[ \] \*\*Phase' ...)` line is the one already-correct
    strict match; propagate exactly its shape. For the new test scenario, copy-adapt
    `S8` in `tests/orchestration/run_tests.sh` (roadmap-inert): structurally the same
    test — text in the plan that must not be read as a phase line.
  - Files:
    - `plugins/phased-workflow/scripts/run-all-phases.sh`
    - `tests/orchestration/run_tests.sh`
  - Decisions:
    - The pattern lives in exactly ONE place, a `phase_re` helper returning
      `^- \[<state>\] \*\*Phase`, with `phase_count <state>` and `phase_any <state>`
      wrappers over `grep -c` / `grep -q`. Every state match goes through them,
      including the three that are already strict — the win is single-source, not
      just correctness.
    - Drop the redundant `\-` escape used by the existing patterns; the helper emits
      `^- \[`.
    - The summary listing uses a fourth form, `phase_lines`, with the ERE
      `^- \[[ x!~>]\] \*\*Phase` — it must show every state at once.
    - `grep -q 'WIP:'` is tightened to `^[[:space:]]*> WIP:` in the same pass: it is
      the documented note format, and an unanchored `WIP:` anywhere in the file is
      the same class of false positive.
    - `first_bang_block`'s awk is part of this change: `/^- \[/` becomes
      `/^- \[[ x!~>]\] \*\*Phase/` and `/^- \[!\]/` becomes `/^- \[!\] \*\*Phase/`.
  - Details:
    1. Add near the top of `run-all-phases.sh`, after `PLAN` is resolved:
       `phase_re() { printf '^- \\[%s\\] \\*\\*Phase' "$1"; }`,
       `phase_count() { grep -c "$(phase_re "$1")" "$PLAN" 2>/dev/null || true; }`,
       `phase_any() { grep -q "$(phase_re "$1")" "$PLAN" 2>/dev/null; }`,
       `phase_lines() { grep -E '^- \[[ x!~>]\] \*\*Phase' "$PLAN" 2>/dev/null; }`.
       Comment them with the reason: a plain `- [!]` bullet in `## Notes` used to
       launch a real fable repair session at cap $300 and stop the run.
    2. Replace all ten call sites: `REMAINING` and the loop-top guard and the
       file-order `grep -n` fallback (state `' '`), `BEFORE_DONE` / `AFTER_DONE`
       (state `x`), the two `[!]` checks, the `[~]` check, the `[>]` check, and the
       final summary `grep '^\- \['` → `phase_lines | head -20`. Keep the existing
       `${VAR:-0}` guards and the `|| true` on the counts — `grep -c` exits 1 on no
       match.
    3. Rewrite `first_bang_block`'s two awk patterns as decided above.
    4. Add scenario `S18` to `tests/orchestration/run_tests.sh`, modelled on `S8`.
       Fixture: `fixture2` plus a `## Notes` section holding five decoys at column 0
       — `- [x] decided to use sqlite`, `- [!] the parser rewrite is open upstream`,
       `- [~] waiting on the upstream release`, `- [>] follow up later`, and a bare
       `WIP: rewrite the tokenizer`. Mock queue completes both phases. Assert: both
       phases reach `[x]`, exactly 2 `CALL:` entries in `invocations.log`, no
       `repair-phase` invocation, and `out.log` contains none of
       `A phase failed`, `A phase is blocked`, `No progress in the last run`.
    5. Add a static assertion in the same scenario, following the `extract()`
       python3-heredoc idiom already used by `S14`: read `$RUNNER_SRC`, and for every
       line containing `grep` whose pattern includes a bracketed state
       (`\[` followed by one of `x ! ~ >` or a space, then `\]`), fail unless the
       line is one of the four helper definitions. This is the regression guard: it
       fails if a future edit reintroduces an unqualified state grep.
  - Done: `bash tests/orchestration/run_tests.sh` exits 0 with `S18` green and no
    prior assertion lost (assertion count strictly greater than 77); `zsh
    tests/orchestration/run_tests.sh` also exits 0; `bash -n` and `zsh -n` clean on
    `plugins/phased-workflow/scripts/run-all-phases.sh`.

- [ ] **Phase 2**: Launcher and install.sh resolve their own paths
  - Pattern reference: `plugins/phased-workflow/install.sh` — its
    `SRC="$(cd "$(dirname "$0")" && pwd)"` is the in-repo idiom for a script
    locating its own directory. For the superseded-files handling, copy-adapt the
    "Legacy flat commands" block at the bottom of the same file: it already does
    move-not-delete into a `~/.claude/phased-workflow-superseded-*` directory with
    an explanatory message.
  - Files:
    - `plugins/phased-workflow/scripts/run-all-phases.sh`
    - `plugins/phased-workflow/install.sh`
    - `tests/orchestration/run_tests.sh`
  - Decisions:
    - `$(dirname "$0")`, never `${BASH_SOURCE[0]}`: this script is also run under
      zsh, where `BASH_SOURCE` does not exist. The genropy-worktree install.sh uses
      `BASH_SOURCE` — do not copy that one.
    - The selector is resolved once into `NEXT_PHASE_PY` at the top, next to the
      launcher itself. If it is not there the install is broken, but the run still
      degrades to file order rather than hard-stopping — the loud warning for that
      path is Phase 4's job, not this one's.
    - `install.sh` stops installing support files entirely. It keeps two jobs: the
      existing legacy flat-command migration, and a new pass that moves the orphaned
      support copies to `~/.claude/phased-workflow-superseded-support/`.
    - Only the five files this plugin ever installed are moved:
      `workflow-refs/common.md`, `workflow-refs/write-workflow-autonomous.md`,
      `scripts/next-phase.py`, `scripts/run-all-phases.sh`,
      `agents/phase-verifier.md`. Move, never delete, and never touch anything else
      under those directories.
    - `agents/phase-verifier.md` is the one that matters: it is not namespaced, so it
      wins over the plugin's `phased-workflow:phase-verifier` and keeps a stale
      verifier running. Say so in the script's output.
  - Details:
    1. In `run-all-phases.sh`, after `REPO_ROOT`, add
       `SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)` and
       `NEXT_PHASE_PY="$SCRIPT_DIR/next-phase.py"`. Replace the
       `python3 "$HOME/.claude/scripts/next-phase.py" "$PLAN"` invocation with
       `python3 "$NEXT_PHASE_PY" "$PLAN"`. Comment why: the launcher and the selector
       ship in the same plugin directory, so they can never be two different
       versions, and `${CLAUDE_PLUGIN_ROOT}` is not needed inside a script that can
       find itself.
    2. In `install.sh`: delete the `mkdir -p`/`cp`/`chmod` block and the "Support
       files installed:" echo list. Replace with a `SUPPORT_STALE` pass over the five
       paths above; when any exist, `mkdir -p
       "$HOME/.claude/phased-workflow-superseded-support"`, `mv` each one there, and
       print what moved, where to, that it was moved and not deleted, and that the
       plugin now carries these files itself. When none exist, print one line saying
       there is nothing to migrate.
    3. Update the script's header comment: install.sh is a migration tool for
       machines that ran 4.0.0 or earlier, not part of the install path.
    4. In `tests/orchestration/run_tests.sh`, the harness copies the runner to
       `$OT/runner.sh` — it must now also copy `next-phase.py` next to it, so the
       suite exercises the repo's selector instead of whatever is installed on the
       machine. Add `cp "$TESTDIR/../../plugins/phased-workflow/scripts/next-phase.py"
       "$OT/next-phase.py"` beside the existing runner copy.
    5. Add an assertion to `S1` proving the selector is actually reached: assert that
       `out.log` does NOT contain the file-order fallback path. Since Phase 4 adds
       the warning text, use a state check instead here: run `S1` with
       `HOME=/nonexistent` prefixed and assert the phases still complete and the
       per-phase models are still read correctly — proof the run no longer depends
       on `$HOME`.
  - Done: `bash tests/orchestration/run_tests.sh` and `zsh
    tests/orchestration/run_tests.sh` both exit 0; the suite passes with
    `HOME=/nonexistent bash tests/orchestration/run_tests.sh` too;
    `grep -c 'HOME/.claude' plugins/phased-workflow/scripts/run-all-phases.sh`
    returns 0; `bash -n plugins/phased-workflow/install.sh` clean and
    `grep -c 'cp "$SRC"' plugins/phased-workflow/install.sh` returns 0.

- [ ] **Phase 3**: `next-phase.py --validate` and the launcher's pre-loop gate
  - Pattern reference: `plugins/phased-workflow/scripts/next-phase.py` — the
    `--resolve` flag in `main()` is the precedent for adding a mode to this script
    rather than writing a second one, and `PHASE_RE` / `TAG_RE` / `parse()` are
    reused as-is so there is no fourth parser. For the test, copy-adapt `S17`, which
    already drives `next-phase.py` directly as a classifier over fixture files.
  - Files:
    - `plugins/phased-workflow/scripts/next-phase.py`
    - `plugins/phased-workflow/scripts/run-all-phases.sh`
    - `tests/orchestration/run_tests.sh`
  - Decisions:
    - A mode of `next-phase.py`, not a standalone script: the whole point is that the
      validator and the selector agree, which only holds if they share the regexes.
    - Two severities. **error** (exit 1): no `## Work Plan`; a `- [` line inside
      `## Work Plan` that `PHASE_RE` rejects; zero phases; duplicate phase numbers;
      numbers not contiguous ascending from 1; no `Parent:` line; `Mode: autonomous`
      without a `## Suggested execution config` table; a table whose header columns
      are not `Phase | Effort | Model` in that order; a phase with no table row or a
      table row for a nonexistent phase; an Effort outside
      `low|medium|high|xhigh|max` or a Model outside `fable|sonnet|opus`.
      **warning** (exit 0): a `> Field:` note not in the documented set; a
      column-0 `- [` checkbox bullet outside `## Work Plan`; a backticked token on a
      phase line that `TAG_RE` rejects; both `group:N` and `parallel:N` on one phase;
      `group:N` on a `Mode: autonomous` plan.
    - Warnings never block. A validator that rejects a legitimate plan is worse than
      the silent defaults it replaces, so anything with a plausible false positive is
      a warning by construction.
    - Known note fields, taken from `refs/common.md` and the README's Note Fields
      table: `Done`, `Files`, `Issue`, `Attempted`, `Repaired`, `Repair attempted`,
      `Review`, `Blocked`, `WIP`, `In execution since`.
    - Exit codes: 0 clean or warnings only, 1 validation errors, 2 plan unreadable or
      not resolvable. Output one `<path>:<line>: error|warning: <message>` per finding
      plus a final `validate: N error(s), M warning(s)`.
    - The launcher gate is a hard stop before the loop, and it prints the validator's
      own output verbatim — no re-wording, no summary.
  - Details:
    1. Add `--validate` to the argparse in `main()`, mutually compatible with the
       positional `plan` argument. Implement `validate(path, phases, text)` returning
       a list of `(lineno, severity, message)`; print them sorted by line number.
    2. Reuse `parse()` for the phase list. For the section and table checks, walk the
       raw lines once: track the current `## ` heading, capture the table rows under
       `## Suggested execution config`, and split them on `|` the same way the
       launcher's `col()` does — by position, not by keyword.
    3. Implement every rule listed in Decisions, each emitting the documented
       severity. Keep the module docstring in step: add `--validate` to the Output
       section.
    4. In `run-all-phases.sh`, immediately after `PLAN`/`PLAN_DIR` are resolved and
       before the `REMAINING` count, run
       `python3 "$NEXT_PHASE_PY" --validate "$PLAN"`; capture combined output; on
       non-zero, print it, print one line telling the user to fix the plan and
       relaunch, and `exit 1`. Guard the case where the selector is missing: if
       `NEXT_PHASE_PY` does not exist, skip the gate with a warning rather than
       aborting.
    5. Add scenario `S19` with four cases, each a fixture written to
       `.phased/active/toy/plan.md` and the runner invoked: (a) the healthy
       `fixture3` validates clean and the run proceeds; (b) a plan whose phase line
       reads `- [ ] **Phase 1** : one` (space before the colon) is rejected with a
       non-zero gate, `out.log` names the line, and **no** `claude` session is
       launched; (c) a `Mode: autonomous` plan with the execution-config table
       removed is rejected; (d) a plan with `| Phase 1 | turbo | opus |` is rejected
       naming the bad Effort. Plus a direct-invocation case: an unknown `> Foo:` note
       yields exit 0 with a `warning:` line.
  - Done: `python3 plugins/phased-workflow/scripts/next-phase.py --validate
    tests/benchmark/fixture/.phased/active/bench/plan.md` exits 0;
    `bash tests/orchestration/run_tests.sh` and `zsh tests/orchestration/run_tests.sh`
    both exit 0 with `S19` green; `flake8 plugins/phased-workflow/scripts/next-phase.py`
    reports zero errors.

- [ ] **Phase 4**: Make every silent fallback loud
  - Pattern reference: `plugins/phased-workflow/scripts/run-all-phases.sh` — the
    `echo "NOTE: claude ${CLAUDE_VER:-unknown} < 2.1.139 — /goal guard unavailable,
    using plain skill prompts."` line is the in-repo precedent for a fallback that
    announces itself; match its `NOTE:` prefix and its "what was lost" phrasing.
  - Files:
    - `plugins/phased-workflow/scripts/run-all-phases.sh`
    - `tests/orchestration/run_tests.sh`
  - Decisions:
    - Three fallbacks get a `NOTE:` line, each naming the value it read, the value it
      substituted, and the consequence: unrecognised Model → `opus`, unrecognised
      Effort → `high`, and the selector's `*)` branch → file order.
    - The selector fallback is the serious one and says so: file order ignores
      `parallel:N` and `group:N` barriers, so the launcher may apply one phase's
      model, effort and cap to a different phase than the sub-session executes.
    - Its stderr stops going to `/dev/null`: capture it and include it in the NOTE, so
      the reason (missing file, syntax error, unreadable plan) is visible.
    - An empty Model or Effort cell — the "no table row" case — is a validation error
      as of Phase 3, so by the time this NOTE can fire the cause is a value the
      launcher does not support, not a missing table. Word it accordingly.
  - Details:
    1. In the `case "$MODEL"` and `case "$EFFORT"` blocks, add an `echo "NOTE: ..."`
       to the `*)` arm before the assignment, quoting the raw value read from the
       table (`${MODEL:-<empty>}`).
    2. Change the selector invocation to keep stderr:
       `REC_RAW=$(python3 "$NEXT_PHASE_PY" "$PLAN" 2>&1)`, then extract
       `REC` from it with the existing `sed -n 's/^recommendation: //p'`. In the
       `case`'s `*)` arm, print a `NOTE:` naming the fallback, the consequence for
       `parallel:N` / `group:N` barriers, and the first line of `REC_RAW` as the
       reason.
    3. Add scenario `S20`. It must force the fallback path, which after Phase 2 means
       running a launcher with no `next-phase.py` beside it: copy `$OT/runner.sh` to a
       fresh directory that has no sibling selector, run it there against `fixture2`,
       and assert `out.log` contains the selector NOTE, names the barrier
       consequence, and that both phases still complete. Second case: `fixture2` with
       `| Phase 1 | turbo | banana |` bypassing the gate — invoke the runner with the
       validator's own file removed as above — and assert both the Model and Effort
       NOTEs appear and that the call still used `--model opus --effort high`.
  - Done: `bash tests/orchestration/run_tests.sh` and `zsh
    tests/orchestration/run_tests.sh` both exit 0 with `S20` green;
    `grep -c '2>/dev/null' ` on the selector invocation line in
    `plugins/phased-workflow/scripts/run-all-phases.sh` returns 0; `bash -n` and
    `zsh -n` clean on that file.

- [ ] **Phase 5**: Retire the VS Code worktree ritual from `/write-workflow`
  - Pattern reference: `plugins/phased-workflow/install.sh` — its `RETIRED_NAMES`
    block is the in-repo precedent for the principle at stake: a retired feature must
    not leave a working remnant behind. This is the same defect one level down, inside
    a skill body instead of in `~/.claude/commands/`.
  - Files:
    - `plugins/phased-workflow/skills/write-workflow/SKILL.md`
  - Decisions:
    - Scope is the **VS Code identity ritual only**. `git worktree add` stays: commit
      `b0fb06e`, which retired all four worktree commands, states the direction
      explicitly — *"Worktrees stay — they are plain git, and /write-workflow still
      creates one for autonomous plans"*. Do not remove worktree creation.
    - Removed: the `command -v code ... && code <path>` line, the sentence about
      hashing the branch name to a hue at 65% saturation / 35% lightness, the whole
      `python3` heredoc that writes `workbench.colorCustomizations`, the
      `git update-index --assume-unchanged .vscode/settings.json` line, and the
      paragraph explaining why that file is hidden from `git status`.
    - Kept: `git worktree add`, the `mkdir -p` for the worktree's `.claude`, and the
      `cp` of `settings.local.json`. The `.vscode` component of the `mkdir -p` goes
      with the ritual — nothing writes there any more.
    - `allowed-tools` loses `Bash(code:*)` and `Bash(command:*)`: verified that the
      skill uses `code` and `command -v` nowhere else. `Bash(cp:*)` and
      `Bash(python3:*)` stay — `cp` carries `settings.local.json` and `python3` runs
      `next-phase.py`.
  - Details:
    1. In `plugins/phased-workflow/skills/write-workflow/SKILL.md`, delete the two
       items listed above from the `**Worktree**` section: the `code` invocation
       inside the first fenced block, and everything from "Give the window its own
       identity by hashing…" through the paragraph ending
       "reversibly (`--no-assume-unchanged`)" — the sentence, the second fenced block
       and the trailing explanation.
    2. Keep the surviving half of the sentence that precedes the deleted text: "One
       command creates branch and worktree together, and the main repo stays put — do
       NOT `git switch -c` first, a branch checked out in the main repo cannot be
       added as a worktree." That warning is about `git worktree add`, not about VS
       Code, and it must survive.
    3. Drop `.claude/worktrees/<slug>/.vscode` from the `mkdir -p` line.
    4. Remove `Bash(command:*)` and `Bash(code:*)` from the `allowed-tools`
       frontmatter, leaving the rest of the list and its order untouched.
  - Done: `grep -c 'colorCustomizations\|titleBar\|assume-unchanged\|command -v code\|
    hashing' plugins/phased-workflow/skills/write-workflow/SKILL.md` returns 0;
    `grep -c 'Bash(code:\*)\|Bash(command:\*)'
    plugins/phased-workflow/skills/write-workflow/SKILL.md` returns 0;
    `grep -c 'git worktree add' plugins/phased-workflow/skills/write-workflow/SKILL.md`
    returns 1; `python3 tests/orchestration/check_allowlists.py
    plugins/phased-workflow/skills` exits 0; `bash tests/orchestration/run_tests.sh`
    exits 0 with `S15` green.

- [ ] **Phase 6**: Skills and refs address the plugin, not `~/.claude`
  - Pattern reference: `library-standard` — documented platform behaviour. The
    plugins reference states that `${CLAUDE_PLUGIN_ROOT}` substitutes in "Skill and
    agent content — anywhere the placeholder appears"
    (code.claude.com/docs/en/plugins-reference, Environment variables). No in-repo
    example exists yet; this phase creates it.
  - Files:
    - `plugins/phased-workflow/skills/auto-phase/SKILL.md`
    - `plugins/phased-workflow/skills/check-phase-context/SKILL.md`
    - `plugins/phased-workflow/skills/execute-phase/SKILL.md`
    - `plugins/phased-workflow/skills/finalize-workflow/SKILL.md`
    - `plugins/phased-workflow/skills/import-workflow/SKILL.md`
    - `plugins/phased-workflow/skills/pull-request/SKILL.md`
    - `plugins/phased-workflow/skills/repair-phase/SKILL.md`
    - `plugins/phased-workflow/skills/run-all-phases/SKILL.md`
    - `plugins/phased-workflow/skills/write-workflow/SKILL.md`
    - `plugins/phased-workflow/refs/common.md`
    - `plugins/phased-workflow/refs/write-workflow-autonomous.md`
    - `plugins/phased-workflow/scripts/next-phase.py` (module docstring only)
    - `tests/orchestration/run_tests.sh`
  - Decisions:
    - Two substitutions only: `~/.claude/scripts/` → `${CLAUDE_PLUGIN_ROOT}/scripts/`
      and `~/.claude/workflow-refs/` → `${CLAUDE_PLUGIN_ROOT}/refs/`. Note the
      directory rename: the plugin ships `refs/`, not `workflow-refs/`.
    - `skills/issue/SKILL.md` has no such reference and is not touched.
    - **Four occurrences must NOT change.** A blind sed over the repo breaks all four:
      - `refs/common.md`, Auto-mode blocked categories: "Self-modification of
        `~/.claude/settings.json`" — a different file, and the sentence is about what
        auto mode denies.
      - `install.sh`: every `$HOME/.claude/commands/` reference belongs to the legacy
        migration and must keep pointing there.
      - `tools/kb-sync.py`: the `~/.claude/commands/{name}.md` string is the KB
        channel's own target, out of scope for this workflow.
      - `tests/orchestration/run_tests.sh`, inside `S15`: the
        `python3 ~/.claude/scripts/next-phase.py --resolve` line is deliberate
        fixture text appended to a mutated skill to prove the allowlist checker
        catches an inline command. Changing it invalidates the test.
    - `allowed-tools` frontmatter is not touched: the placeholder expands to an
      absolute path, and every affected skill already permits `Bash(python3:*)` or
      unrestricted `Bash`.
    - `run-all-phases/SKILL.md` invokes the launcher as
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-all-phases.sh"` — quoted, since the
      resolved path can contain a version directory.
  - Details:
    1. Substitute in each of the twelve files listed above, honouring the four
       exclusions. Work file by file, not with a repo-wide sed.
    2. In `next-phase.py`'s docstring, the pointer to the canonical semantics becomes
       `${CLAUDE_PLUGIN_ROOT}/refs/common.md`.
    3. Add scenario `S21`: a static guard asserting that no file under
       `plugins/phased-workflow/skills/` or `plugins/phased-workflow/refs/` contains
       `~/.claude/` or `$HOME/.claude/`, with a single documented exemption for the
       `settings.json` mention in `refs/common.md`. Implement it as a python3
       heredoc, following the `S15`/`S16` style, and print the offending file and
       line when it fails.
    4. Re-run `python3 tests/orchestration/check_allowlists.py
       plugins/phased-workflow/skills` and confirm it still reports clean — the
       placeholder must not read as a new command to the inline scanner.
  - Done: `bash tests/orchestration/run_tests.sh` and `zsh
    tests/orchestration/run_tests.sh` both exit 0 with `S21` and the existing `S15`
    green; `grep -rn '~/.claude/\|\$HOME/.claude/' plugins/phased-workflow/skills/
    plugins/phased-workflow/refs/` returns only the `refs/common.md`
    `settings.json` line.

- [ ] **Phase 7**: Continuous integration
  - Pattern reference: `new-pattern (flagged: higher risk)` — the repo has no
    `.github/` at all, and a workflow file cannot be executed locally, so the `Done:`
    below verifies the YAML and runs every command the workflow will run, not the
    workflow itself.
  - Files:
    - `.github/workflows/ci.yml`
  - Decisions:
    - Triggers: `push` on `main`, and `pull_request` targeting `main`.
    - One job on `ubuntu-latest`, `actions/checkout@v4`, `actions/setup-python@v5`
      with Python 3.12.
    - `zsh` is not preinstalled: `sudo apt-get update && sudo apt-get install -y zsh`
      as an explicit step.
    - A git identity is required. `S17` creates real commits, and `git commit` fails
      without `user.email` / `user.name` on a fresh runner — set them with
      `git config --global` before the test step.
    - No `claude` CLI is needed: the suite puts its own mock on `PATH`, and the mock
      answers `--version`. Do not add an install step for it.
    - The benchmark harness is never run in CI — it costs real sessions.
    - Steps, in order: install zsh; `pip install flake8`; `flake8 .`; git identity;
      `bash tests/orchestration/run_tests.sh`; `zsh tests/orchestration/run_tests.sh`;
      `python3 plugins/phased-workflow/scripts/next-phase.py --validate
      tests/benchmark/fixture/.phased/active/bench/plan.md`.
    - The bash and zsh runs are separate steps, not a matrix: they share every other
      setup step and a matrix would double the installs for nothing.
  - Details:
    1. Create `.github/workflows/ci.yml` with `name: ci`, the triggers and the single
       `test` job described above, each step named for what it guards.
    2. `flake8 .` needs no arguments — `setup.cfg` already defines the scope and
       excludes the benchmark fixtures on purpose.
    3. Do not add a step that runs `install.sh`: as of Phase 2 it mutates `~/.claude`
       and has nothing to verify in CI.
  - Done: `python3 -c "import yaml,sys;
    yaml.safe_load(open('.github/workflows/ci.yml'))"` succeeds; the file contains a
    `zsh tests/orchestration/run_tests.sh` step, a `flake8` step, an `apt-get install`
    step for zsh and a `git config --global user.email` step; and every shell command
    the workflow runs, executed locally in sequence, exits 0.

- [ ] **Phase 8**: Align the documentation with the evidence, and release 4.1.0
  - Pattern reference: `tests/benchmark/results/README.md` — the one document in this
    repo that already does honest provenance: it states what each run measured, which
    conclusions survive, and which are superseded. Match its register and its habit
    of naming the limitation in the same sentence as the number.
  - Files:
    - `README.md`
    - `docs/loop-engineering.md`
    - `plugins/phased-workflow/refs/common.md`
    - `plugins/phased-workflow/skills/run-all-phases/SKILL.md`
    - `plugins/phased-workflow/refs/write-workflow-autonomous.md`
    - `plugins/phased-workflow/scripts/run-all-phases.sh` (the light-mode comment only)
    - `article-medium.md` → `docs/article-medium.md`
    - `plugins/phased-workflow/.claude-plugin/plugin.json`
    - `.claude-plugin/marketplace.json`
  - Decisions:
    - The benchmark numbers keep their magnitude and gain their provenance in the same
      breath: n=3 on a toy fixture, and — the part currently missing everywhere — the
      figures come from the `slim` hardcoded control, not from the light mode that
      ships, whose "same external outcomes" was never measured against the shipped G3
      contract. Three places state this claim with two different numbers
      (`README.md`, `docs/loop-engineering.md` twice, and "~40% cheaper, half the wall
      time" in the launcher comment); all three become one wording.
    - The test counts are restated from the suite's own final line after Phases 1–7,
      not from today's 77 — this phase runs last and reads the real number. The claim
      that the suite "extracts the bash script from its own `SKILL.md`" is deleted:
      the script has been a shipped file since 4.0.0.
    - Auto-mode blocked categories are reframed, not removed. They stop being stated
      as what the mode blocks and become: what `--permission-mode auto`'s classifier
      is expected to deny, plus the plugin's own recommended policy for writing
      phases. The reason is stated once: the classifier is Claude Code's, the plugin
      ships no hooks and no permissions, so the enumeration is a description and a
      convention — not a guarantee this plugin can make. Same reframing in all three
      places that assert it.
    - Softwell and Sourcerer: the `README.md` KB-mirror paragraph moves out of the
      install section into a short "Internal mirror (Softwell)" note at the end, so a
      reader outside Softwell never meets it while installing. The
      `docs/loop-engineering.md` mention is rewritten to name the tool generically
      ("an internal knowledge-base MCP"). The author bio in `article-medium.md` keeps
      its Softwell mention — it is a bio.
    - `minchiate-da-fixare` / `cose-da-segnalare` in
      `refs/write-workflow-autonomous.md` becomes English. The Italian "Closing
      message" block in the same file stays Italian: it is the message shown to the
      user, and `refs/common.md` prescribes Italian for conversation. Same for the
      Italian option text in its "Scope safety" bullet.
    - Version 4.1.0, not 5.0.0: paths move inside the plugin and `install.sh` stops
      installing, but a user who updates and never runs `install.sh` is strictly
      better off than before. Nothing a consumer depends on breaks.
    - `install.sh` is removed from the install instructions and described as a
      one-time migration for machines that ran 4.0.0 or earlier.
  - Details:
    1. `README.md`: rewrite the light-mode bullet with the provenance; correct the
       Tests section (real assertion and scenario counts, delete the SKILL.md
       extraction claim, add the new scenarios from Phases 1–7 to the S-list, mention
       the CI workflow); rewrite the installation section so the plugin install is
       the whole install and `install.sh` is a migration note; move the Softwell/KB
       paragraph to its own short section at the end.
    2. `docs/loop-engineering.md`: same provenance wording at both occurrences of the
       numbers; update the assertion count; generalise the Sourcerer mention.
    3. `plugins/phased-workflow/scripts/run-all-phases.sh`: the light-mode comment
       adopts the same single wording — no third set of numbers.
    4. `refs/common.md`, `skills/run-all-phases/SKILL.md` and
       `refs/write-workflow-autonomous.md`: reframe the blocked categories as decided,
       and fix the Italianism.
    5. `git mv article-medium.md docs/article-medium.md`, and fix any link to it.
    6. Bump `version` to `4.1.0` in `plugins/phased-workflow/.claude-plugin/plugin.json`
       and in both places it appears in `.claude-plugin/marketplace.json`.
  - Done: `grep -rn '37%\|60% of the wall\|40% cheaper' README.md
    docs/loop-engineering.md plugins/phased-workflow/scripts/run-all-phases.sh` shows
    every surviving occurrence accompanied by the `slim`-control provenance;
    `grep -rn '62 assertions\|62/62\|from its own .SKILL.md.' README.md
    docs/loop-engineering.md` returns nothing; the assertion count stated in
    `README.md` equals the `RESULT:` line of `bash tests/orchestration/run_tests.sh`;
    `grep -rn 'minchiate' plugins/` returns nothing; `ls article-medium.md` fails and
    `ls docs/article-medium.md` succeeds; `python3 -c "import json;
    assert json.load(open('plugins/phased-workflow/.claude-plugin/plugin.json'))['version']
    == '4.1.0'"` succeeds; `bash tests/orchestration/run_tests.sh` still exits 0.

- [ ] **Phase 9**: Coherence review and auto-fix (final, mandatory)
  - Pattern reference: same as Phases 1–8 (cross-check against them)
  - Files: only the files written by Phases 1–8 (collect them from their `Files:`
    fields). Never touch a pre-existing file they did not modify.
  - Decisions:
    - Auto-fix directly: tool-fixable lint (flake8 findings on the python files),
      unused imports, formatting, trivially mechanical fixes. Re-run the tests after
      each non-tooling fix; if one breaks a test, roll back that fix and flag it
      instead.
    - Never auto-fix: logic errors, design divergences from the pattern reference,
      missing edge cases, anything architectural. Those go to `review.md` only.
    - Specific cross-checks for this workflow: that Phases 1, 2, 3 and 4 all edited
      `run-all-phases.sh` without one undoing another; that no phase-state grep
      bypasses Phase 1's helpers; that no file under `skills/` or `refs/` still
      addresses `~/.claude/` except the documented exemption; that the numbers stated
      in the docs match what the suite and the benchmark provenance actually say.
  - Details: convergence loop (max 3 cycles) of linter scoped to the file set →
    auto-fix → linter → test suite; stop early if a cycle makes no progress. Run the
    suite under both bash and zsh. Then write
    `.phased/active/review-hardening-4-1-0/review.md` with three sections:
    **Auto-fixed** (file, what, tool), **Flagged for human** (file, description,
    suggested action), **Final state** (linter output, suite result, files reviewed).
  - Done: `review.md` exists in the plan directory with the three sections; `flake8 .`
    reports zero errors; `bash tests/orchestration/run_tests.sh` and `zsh
    tests/orchestration/run_tests.sh` both exit 0.

## Notes

- **The run edits the repo, not the tool executing it.** The sub-sessions run the
  installed plugin 4.0.0 (`~/.claude/plugins/cache/...` for the skills,
  `~/.claude/scripts/run-all-phases.sh` for the launcher), while every phase writes
  to `plugins/phased-workflow/` in this worktree. The launcher therefore never
  modifies itself mid-run, and no phase executes `install.sh`.
- **Phase ordering is load-bearing between Phases 2 and 3.** Phase 3 adds a
  `--validate` gate to the repo's launcher, and `run_tests.sh` runs that launcher.
  Before Phase 2 the launcher reads `$HOME/.claude/scripts/next-phase.py` — the
  installed 4.0.0 copy, which does not know `--validate` — so the gate would abort
  every scenario and Phase 3's `Done:` would be unverifiable. Do not reorder them.
- **No `parallel:N` anywhere.** Phases 1–4 all edit
  `plugins/phased-workflow/scripts/run-all-phases.sh`, and Phases 1–4 plus Phase 6 all
  edit `tests/orchestration/run_tests.sh`. Everything is a synchronization barrier by
  construction.
- **Phase 5 is not one of the seven review findings.** It came from the user while this
  plan was being written, on seeing `/write-workflow` open a colour-titled VS Code
  window for this very worktree. That ritual is a leftover of the retired
  `/create-context`; the review never mentioned it.
- **Scope deliberately left out.** Point 3 of the review offered real enforcement
  (a plugin-level `PreToolUse` hook gated on an env marker set by the launcher) as an
  alternative to reframing the documentation. The user chose reframing. The hook is
  not in this plan: it would run in every session of every user of the plugin, and it
  would duplicate a classifier Claude Code already applies. If it is ever wanted it
  is its own workflow, not a phase here.
- **What the review got wrong, recorded so it is not re-fixed later.** The claim that
  a stray `- [x]` bullet inflates the done-count and masks a stall is false as
  written: `BEFORE_DONE` and `AFTER_DONE` are a difference, so a pre-existing decoy
  cancels out. Only a `- [x]` added to the plan *during* a run falsifies the delta.
  The damaging cases are the non-differential matches, verified end-to-end against
  the shipped launcher: a `- [~]` bullet in `## Notes` halts a healthy run, and a
  `- [!]` bullet launches a fable repair session at cap $300 after a successful
  phase. Phase 1 is scoped to the real failure mode.
- **The suite currently does not test the phase selector.** `run_tests.sh` copies the
  repo's launcher but the launcher reads `$HOME/.claude/scripts/next-phase.py`, so
  S1–S13 validate whatever is installed on the machine — and pass identically when it
  is absent, because the file-order fallback is silent. Phase 2 closes this as a side
  effect; Phase 4 makes the fallback audible.
- **The gate at 2.1.139 already warns** and needs no change; `--effort` and
  `--max-budget-usd` both exist on the current CLI (verified on 2.1.211). Only the
  model, effort and selector fallbacks are silent.

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | medium | opus |
| Phase 2 | medium | opus |
| Phase 3 | high | opus |
| Phase 4 | low | opus |
| Phase 5 | low | opus |
| Phase 6 | medium | opus |
| Phase 7 | low | opus |
| Phase 8 | high | opus |
| Phase 9 | xhigh | opus |
