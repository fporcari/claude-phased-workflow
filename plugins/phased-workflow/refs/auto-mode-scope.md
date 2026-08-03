# Auto-mode permission scope

Read by the two skills that decide whether a phase can run unattended:
`/run-workflow` (pre-flight) and `/write-workflow` on the autonomous branch
(`write-workflow-autonomous.md`). No other skill needs it.

Sub-sessions launch with `--permission-mode auto`. The classifier that judges
each call is Claude Code's own — this plugin ships no hooks and no permission
rules — so the list below is a *description* of what that mode is expected to
deny plus the *convention* this plugin recommends when writing phases, not a
guarantee the plugin itself can enforce.

Under that mode, routine local operations in project scope (git
status/log/diff/show, edits in the working directory, push to the working
branch, manifest-driven installs) are auto-conceded, and these categories are
expected to be denied:

- `git push --force` or push to main/master/default branch — blocked
  (push to the working branch is fine)
- `pip install <pkg>` / `npm install <pkg>` / `brew install <pkg>` for
  agent-chosen packages (typosquat risk) — blocked. Manifest-driven
  installs (`pip install -r requirements.txt`, `npm install` without
  args) are auto-allowed.
- `rm -rf` / `git reset --hard` / `git clean -fdx` / `mv` / `cp` onto
  **pre-existing** files — blocked. Files the agent itself created in the
  session are fine.
- Production deploys, prod db migrations, `kubectl exec` / `ssh`
  targeting prod hosts — blocked
- `curl | bash` / `iex (iwr ...)` / running code from external sources —
  blocked
- Self-modification of `~/.claude/settings.json` or other agent config —
  blocked
- Data exfiltration, public repo creation, writing to external systems
  (Jira/Linear/Slack/PagerDuty/…) — blocked
