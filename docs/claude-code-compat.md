# Claude Code compatibility baseline

This file is the bookmark and the checklist for the periodic Claude Code
changelog review (`/check-claude-update`). The check reads the baseline,
examines only changelog entries newer than it, cross-references them against
the surfaces below, and updates the baseline when done.

## Baseline

```
last-checked-version: 2.1.234
last-checked-date: 2026-08-18
```

## Plugin surfaces

The mechanisms of Claude Code this repo's plugins depend on. An update that
changes any of these can break the plugins without a single line of plugin
code changing. Every new changelog entry is judged against this list.

### phased-workflow

1. **Skill frontmatter** — `description`, `disable-model-invocation`,
   `allowed-tools`, `argument-hint` in every `skills/*/SKILL.md`. A parsing or
   semantics change can make a skill model-invocable when it must not be, or
   strip its tool permissions.
2. **Headless plugin-skill invocation** — `claude -p "/phased-workflow:<skill>"`
   in `scripts/run-workflow.sh` and `scripts/agent-session.sh`. The autonomous
   run depends on headless sessions resolving plugin slash commands.
3. **CLI flags** — `--model fable|opus`, `--permission-mode auto` in the same
   scripts. A renamed flag or a removed model alias fails the run at launch.
   `fable` landed in 2.1.170 and sets the floor for autonomous runs; the repair
   session hardcodes it, a phase may pin it via `Model:`.
4. **Settings inheritance** — the scripts copy `.claude/settings.local.json`
   into the plan checkout so sub-sessions inherit permissions. A change in
   where/how sessions read settings stalls the autonomous run on permission
   prompts.
5. **Agent frontmatter** — `name`, `tools`, `model: opus` in `agents/*.md`.
   Model restriction or alias changes silently downgrade the verifier/judge
   agents (since 2.1.223 a warning is shown).
6. **Plugin loading** — manifest parsing (`.claude-plugin/plugin.json`),
   symlinked development installs, plugin cache behavior, skills path
   resolution.
7. **Auto permission mode semantics** — sub-sessions run `--permission-mode
   auto`; changes to the auto-mode classifier or its consecutive-block limits
   alter how far an unattended phase can get.
8. **git worktree assumptions** — the plan checkout is a plugin-managed git
   worktree launched as a *normal* session (cwd inside it). It does not use the
   harness's native worktree isolation; changes to native isolation are
   irrelevant, changes to how sessions treat worktree checkouts are not.
9. **Host toolchain** — `bash` for the launchers and `python3` for
   `scripts/next-phase.py`, which every skill shells out to. Both are assumed
   present under those exact names. A change in which shell Claude Code runs
   Bash tool commands through breaks plan resolution on the interactive path
   too, not only the autonomous one. This is what confines the plugin to
   macOS/Linux (and WSL).

### genropy-worktree

Shell-only (`bin/`, `install.sh`); exposed to git and shell behavior, not to
Claude Code internals. Low sensitivity.

## Classification

Each relevant entry gets one verdict:

- **BREAKING** — a listed surface changes incompatibly; plugin needs a fix.
- **BEHAVIOR** — semantics shift on a listed surface; verify, maybe adapt.
- **POSITIVE** — fixes or improves a listed surface; nothing to do.
- **IRRELEVANT** — does not touch any listed surface.

When in doubt between IRRELEVANT and anything else, flag it: a false alarm
costs one human glance, a false silence does not.

## Review log

| Date | Window | Result |
|------|--------|--------|
| 2026-08-12 | 2.1.221 → 2.1.228 | No breaking changes. POSITIVE: 2.1.228 symlinked-dev-checkout cache fix, 2.1.225 headless 401 + auto-mode fixes, 2.1.224 multi-project install records + subagent cap removal. All other entries irrelevant. |
| 2026-08-18 | 2.1.233 → 2.1.234 | **Five behavior shifts to verify, three of them on the `/goal` guard and the usage-limit path that every autonomous run depends on.** BEHAVIOR: "`/goal`: when background tasks keep a goal waiting for 30+ minutes, Claude now checks in on them instead of waiting indefinitely (set `CLAUDE_CODE_GOAL_CHECKIN_MINUTES=0` to opt out)" (surfaces 2, 5) — every phase session runs as `claude -p '/goal <contract> … Stop after 25 turns.'` (`run-workflow.sh:162-176`), and the skills spawn `phase-verifier`/`ui-judge`/`report-judge`, which since 2.1.232 may run in the background; a check-in injects unplanned turns into a contract whose runaway cap is counted *in turns*. Verify the cap still holds, or set the env var to 0 in the launcher. BEHAVIOR: "Claude Code now continues your session automatically when a claude.ai usage limit resets; turn it off in `/config`" (surfaces 2, 3) — if this reaches headless `claude -p`, a phase session that hits the limit waits for the reset instead of exiting, so the launcher's non-zero-exit paths (the fable→opus repair fallback at `run-workflow.sh:426`, and the parent Monitor that terminates on the launcher's final line) block for as long as the reset takes; the opt-out is an interactive `/config` toggle with no CLI flag named. BEHAVIOR: "`/goal` now clears itself with a notice when a turn dies on an unrecoverable error (e.g. revoked auth, an exhausted credit balance, or a context overflow) instead of staying armed" (surface 2) — the goal guard is what stops a phase session declaring itself done before the plan shows the outcome, and a 25-turn phase can plausibly overflow context; verify the launcher still detects a no-progress session from plan state once the goal disarms itself. BEHAVIOR (low): "Removed the 'Default teammate model' setting from `/config`; agent-team teammates now use the leader's model unless the spawn names one" (surface 5) — all three agents declare `model: opus` in frontmatter; if only an explicit model *on the spawn* counts as "naming one", a verifier spawned from a `fable` phase session silently downgrades, the exact failure surface 5 exists to catch. "agent-team teammates" may name a different feature than Agent-tool subagents; not tested here. BEHAVIOR (low): "Fixed trust prompts omitting the repository-wide scope warning when the directory was first seen before the repository existed there" (surface 8) — not the plan checkout's case (its directory is created fresh by `git worktree add`), but trust-prompt scoping moved again while the 2.1.232 nested-repo trust question is still unverified; check the two together. POSITIVE: auto mode no longer re-checks and denies sandboxed commands' network access after compaction (surface 7 — long unattended phase sessions are exactly that case), session-scoped permission answers no longer dropped when answering background subagent prompts (surfaces 5, 7 — the 2.1.232 background-spawn default), the fullscreen-renderer prompt no longer restarts a session without its permission mode/model/effort flags and `/tui` now declines to switch rather than dropping launch tool rules (surface 3), `strictKnownMarketplaces` no longer accepts SCP-style git sources whose host differs from git's (surface 6 — this repo's manifest is a `./plugins/phased-workflow` path source, unaffected), between-turn background notifications now arrive in `<system-reminder>` tags like mid-turn ones (surface 5). Checked and cleared: removal of the "Allowed by auto mode classifier" line under every Agent call (surfaces 5, 7) — the scripts `tee` session output to `$PLAN_DIR/log/*.txt` and never grep it, every parse runs over the plan file or `next-phase.py`; `claude setup-token` now rejecting extra arguments (surface 3) — no script calls that subcommand and the strictness is scoped to it; the NT-namespace (`\??\`) path hardening and the read-only `~/.claude.json` startup fix are Windows-only (surface 9); `CLAUDE_CODE_PROJECT_DIR_NAME` is opt-in and names the per-project transcript directory only, not settings resolution (surface 4). 40 of 51 entries irrelevant (Remote Control sync/upload/account-switch, permission-preview relay and credential masking, MCP diagnostics secrets, GitLab MR badge, `selection:clear` keybinding, transcript/markdown/`---`/Unicode rendering, queued-`!` and mid-turn dialog fixes, SendMessage/ListAgents naming and list-truncation notices, session titles, `claude-api` skill context cost, `/permissions` and `/add-dir` mid-turn, Mantle admin-pin probe, non-streaming-fallback crash, repo-host userinfo detection). |
| 2026-08-15 | 2.1.232 → 2.1.233 | No breaking changes, no behavior shifts. POSITIVE: skill/command argument substitution fixed to stop re-expanding argument values as template markers (surface 1, e.g. `$1`/`$ARGUMENTS` in `issue`/`pull-request`/`scope-workflow` SKILL.md), `claude plugin validate` now checks a bare `.claude/skills` directory and reports SKILL.md frontmatter parse failures (surfaces 1, 6). Checked and cleared: Todo/task-tracking tools (TaskCreate/Update/List, TodoWrite) disabled by default on Fable 5/Sonnet 5/Opus 4.8/Mythos 5+ — no skill, agent or script in this plugin uses those tools, phase state is tracked entirely in `.phased/` plan files and `next-phase.py` (no listed surface); bundled skill-alias shadowing fix (`/checkup`, `/review`) — no plugin skill name collides; reverted 2.1.232 Bash permission changes for `< file` redirection and Windows Cygwin symlinks — no stdin redirection in any script, and the Windows-only fixes (NTLM path validation, auto-mode `cd &&` regression) fall outside surface 9's macOS/Linux/WSL scope. 15 of 20 entries irrelevant (GitLab MR `--worktree` display, apps-gateway identity/error-forwarding, Bash memory cgroups, WebFetch cache TTL, cloud-session/MCP-v2/idle-CPU/notification-hook fixes, self-hosted-runner startup, screen-reader mode, unrecognized-model stderr diagnostic, GitHub app setup tip). |
| 2026-08-14 | 2.1.231 → 2.1.232 | **Two behavior shifts to verify.** BEHAVIOR: "non-teammate agent spawns in interactive sessions now run in the background by default" (surface 5) — the skills spawn `phase-verifier`, `ui-judge` and `report-judge` and consume their findings in the same step (`report-judge` explicitly "before showing"); no skill passes `run_in_background: false`, so on the interactive path the spawn may return an agent name instead of findings. Headless `claude -p` sub-sessions are outside the entry's stated scope. BEHAVIOR: "Fixed nested git repositories inheriting trust from a parent directory; each repository now requires its own trust confirmation" (surface 8) — the plan checkout is a linked worktree at `$REPO_ROOT/.claude/worktrees/<slug>`, nested under the already-trusted repo root, and `agent-session.sh`/`run-workflow.sh` `cd` into it and launch headless; if a `.git`-file worktree is classified as its own repository, the first run for a new plan meets a trust prompt nothing can answer. Not tested here. BEHAVIOR (low): Fable 5 advisor consent "set up through `/model fable`" (surface 3) — a usage-credits consent step cannot be performed headless, though `run-workflow.sh` already falls back to opus when a fable session exits non-zero. POSITIVE: plugin-marketplace startup race on `known_marketplaces.json` fixed, `/plugin install plugin@marketplace` now refreshes first, GitLab marketplace sources and the `additionalMarketplaces`/`allowedMarketplaces` aliases are additive (surface 6). Checked and cleared: Bash `< file` redirections now permission-checked — no stdin file redirection in any script or skill (surfaces 7, 9); `sandbox.ripgrep` no longer honored from project settings — `.claude/settings.local.json` carries only `permissions.allow`, but note the precedent, the scripts copy project-scope settings into the checkout (surface 4); the PowerShell and Git Bash permission-bypass fixes are Windows-only (surface 9). 42 of 49 entries irrelevant. |
| 2026-08-13 | 2.1.228 → 2.1.231 | No breaking changes, no behavior shifts. POSITIVE: 2.1.229 auto mode no longer fails every tool call when `CLAUDE_CODE_ATTRIBUTION_HEADER` is disabled (surface 7), stray `claude plugin` liveness file no longer blocks cleanup of outdated plugin versions (surface 6), new marketplace `command` sources as an alternative to symlinked dev installs — additive, path sources like this repo's manifest unaffected (surface 6), `/model` no longer rejects Opus/Sonnet 1M behind a custom `ANTHROPIC_BASE_URL` (surface 3), oversized conversations now fail once with a clear message instead of looping on compaction (surface 2). Checked and cleared: the `/commit-push-pr` dangerous-flag de-auto-approval does not reach this plugin (no `--force`/`--amend`/`--no-verify` in any script or skill), and the fail-closed sandbox domain enforcement finds no network config in `.claude/settings.local.json`. 27 of 32 entries irrelevant. |
