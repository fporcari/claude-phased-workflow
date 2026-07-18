# Shared conventions — phased-workflow skills

Single source of truth for the blocks that used to be repeated in every
phased-workflow command (`/write-workflow`, `/execute-phase`, `/auto-phase`,
`/run-all-phases`, `/finalize-workflow`, `/check-phase-context`,
`/push-context-memory`). Skills point here instead of restating them.

## Language

All written content (memory files, phase notes, code, comments, commits,
PRs, issues) in English. Conversation with the user in Italian.

## AskUserQuestion style

Use `AskUserQuestion` for every question to the user. When a sensible
default exists, put the recommended option FIRST and append
"(Recommended)" to its label (the tool has no default-answer parameter).
For multiple-choice lists, one option per line, checkbox style.

## MEMORY.md path resolution

The work plan file is always `$(git rev-parse --show-toplevel)/.claude/MEMORY.md`
— the `.claude/` directory inside the git repository root. Do NOT confuse
it with Claude Code's auto-memory directory (`~/.claude/projects/.../memory/`).
Parallel plans live next to it as `memory_<name>.md`; each worktree has its
own plan at `<worktree_root>/.claude/MEMORY.md`.

## Phase selection

The next eligible phase is computed deterministically by:

```bash
python3 ~/.claude/scripts/next-phase.py <memory-file>
```

It prints a status table for all phases plus one `recommendation:` line
(`next: N` / `next: N unit: N,M` / `resume-candidate: N` / `attention: ...`
/ `done` / `blocked: ...`). The semantics it implements — also the manual
fallback if the script is unavailable — are:

- `[x]` done → skip; `[!]` issue / `[~]` blocked → skip (the user must
  resolve them); like any non-completed phase, they block what follows.
- A `[ ]` phase is blocked while any preceding phase NOT in its same
  `parallel:N` group is not `[x]`. A phase without `parallel:N` is a
  synchronization barrier: it requires ALL preceding phases `[x]`.
- A `[>]` phase with a free `[ ]` alternative in the same `parallel:N`
  group → take the alternative.
- A selected `group:N` phase pulls in its whole consecutive run of the
  same `N` as one unit (one chat, single end-to-end test on the last).
- `[>]` phases are resume candidates only when nothing else is eligible;
  the script reports their age and whether a `> WIP:` note exists — what
  to do with that is the calling skill's decision.

## Failure and repair notes

Note fields the autonomous chain writes on phases, and what consumes them:

- `> Issue:` — root symptom and current diagnosis; written by `/auto-phase`
  when a phase exits `[!]`.
- `> Attempted:` — numbered list of fixes tried, each with its error
  signature. Mandatory on `[!]`: it is the input of `/repair-phase`, which
  must NOT repeat those attempts.
- `> Repaired:` — on a phase turned `[x]` by `/repair-phase`: the actual
  root cause and why the previous attempts missed it.
- `> Repair attempted: <ISO timestamp> — <diagnosis>` — appended by
  `/repair-phase` when the repair fails. It is the idempotent marker:
  `/run-all-phases` launches at most ONE repair per phase and stops for
  human review when this note exists. Deleting the note grants another
  repair round after manual intervention.
- `> Review:` — judgment-level findings from the per-phase independent
  verification, flagged for the human at finalize; they never block `[x]`.

`/repair-phase` always targets the FIRST `[!]` phase in the plan.

## Auto-mode blocked categories

Sub-sessions launched with `--permission-mode auto` auto-concede routine
local operations in project scope (git status/log/diff/show, edits in the
working directory, push to the working branch, manifest-driven installs)
and BLOCK these categories:

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
