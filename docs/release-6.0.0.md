# 6.0.0 — the plugin is renamed `wf`

The prefix was eating the name. Every plugin skill is listed and typed as
`/<plugin>:<skill>`, and with a sixteen-character plugin name the part that says
what the command *does* arrived last and half-read:

> `/phased-workflow:execute-phase` · `/phased-workflow:execute-phase-agent`

The plugin is now `wf` — the same two letters the workflow branches already carry
(`wf/<slug>`), so the prefix reads as the namespace it is and the skill name is
what you see:

> `/wf:execute-phase` · `/wf:execute-phase-agent`

The report is Giovanni's.

## What this costs an existing user

One reinstall, because the plugin name is its install identity:

```bash
claude plugin uninstall phased-workflow@claude-phased-workflow
claude plugin install wf@claude-phased-workflow
```

Skip the uninstall and you keep two installs, the stale one still answering the
bare `/<name>` form with a 5.x version of the skill.

**Nothing else moves.** The marketplace is still `claude-phased-workflow`, the
repo and its URL are unchanged, and no workflow state carries the plugin name:
`.phased/` plans, `wf/` branches, phase commits, `verify.md` — all name-free, so a
workflow interrupted under 5.x resumes under 6.0.0 with no migration. The bare
`/<name>` form is unaffected.

## What changed

- `plugin.json` → `"name": "wf"`; `marketplace.json` → the plugin entry and its
  `source`, now `./plugins/wf`. The plugin directory moved with it.
- The launchers needed no change of substance: `run-workflow.sh` and
  `agent-session.sh` have read `PLUGIN_NAME` out of `plugin.json` since 5.2.1
  rather than carrying the string, so only their literal fallback was retyped.
  That indirection is what made this release a rename and not a sweep.
- `refs/board.md`'s card commands, the README's install, update and per-project
  blocks, and `install.sh`'s messages.
- `install.sh`'s installed-plugin gate accepts either name: a machine migrating
  off the legacy flat install may still carry the pre-rename entry, and reading
  only the new one would have left its flat copies in place, silently shadowing
  the plugin.

## The guard

The two orchestration assertions that pin the namespaced launcher prompt (S7,
S7b) now expect `/wf:` — they are the checks that fail loudly if a future rename
touches `plugin.json` and forgets the launchers' fallback. 207 assertions, green
under bash and zsh.
