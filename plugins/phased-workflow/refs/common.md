# Shared conventions — phased-workflow skills

Single source of truth for the blocks that used to be repeated in every
phased-workflow command (`/write-workflow`, `/import-workflow`,
`/execute-phase`, `/execute-phase-agent`, `/run-workflow`, `/finalize-workflow`,
`/resume-workflow`, `/push-context-memory`). Skills point here instead
of restating them.

## Language

All written content (plans, phase notes, code, comments, commits, PRs,
issues) in English. Conversation with the user in Italian.

## AskUserQuestion style

Use `AskUserQuestion` for every question to the user. When a sensible
default exists, put the recommended option FIRST and append
"(Recommended)" to its label (the tool has no default-answer parameter).
For multiple-choice lists, one option per line, checkbox style.

## Plan directory

Every workflow keeps its plan and its working notes in `.phased/`, at the
git repository root:

```
.phased/
  roadmap.md              # megaplans only — spans macro-phases
  active/<slug>/          # exactly one at a time
    plan.md               # the work plan
    notes.md              # free-form annotations
    verify.md             # human checks a phase deferred to a wider context
                          #   (see "Verification: Done: and Verify:" below)
    log/phase-N.txt       # stdout of each /run-workflow sub-session (.txt,
                          #   not .log: `*.log` sits in most global gitignores
                          #   and these are meant to be committed)
  done/<slug>/            # moved here by /finalize-workflow
```

The active plan is `<git root>/.phased/active/*/plan.md`, resolved by:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve
```

`active/` holds exactly ONE plan directory — one branch, one plan, no
discovery. No match means there is no workflow in this repository: run
`/write-workflow`, or `/import-workflow` on an older plan. Several matches
are an anomaly to report to the user, never to guess at.

`.phased/` is committed on the workflow branch and never reaches the parent:
`/finalize-workflow` drops it from the squashed commit.

## Plan location — operating from anywhere

`--resolve` answers for the repository you are standing in. When it fails, or
the user means a different workflow, list every reachable plan instead:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --plans
```

One pipe-separated line per plan: location (a filesystem path, or
`branch:path` for a `wf/*` branch with no checkout), branch, checkout path
(`-` when none), phase counts, state. Several plans → ask the user which one,
never guess.

Once a plan outside the current root is chosen, anchor every command to ITS
root: `git -C <plan root>` for every git invocation, and every path (the plan
file, `log/`, `.phased/`) resolved against that root, never against the cwd.
A plan whose branch has no checkout cannot be operated on directly — attach
or create its worktree first (`/run-workflow` does this itself; other skills
say so and stop).

## Workflow branch

Every plan gets a branch, so that everything belonging to the run is
identifiable without heuristics.

- `/write-workflow` either creates `wf/<slug>` or adopts the branch you are
  already on (its own rules decide); either way `Parent:` in the plan records
  where the work goes back to.
- The plan is committed first, as `wf: plan for <slug>`.
- Each completed phase is ONE commit, `wf(phase N): <title>`, including the
  plan's own status update. A phase closing `[!]` commits too, as
  `wf(phase N): FAILED — <title>`: repair needs to see the failing code, and
  it needs to start from a clean tree.

**The base of the workflow is the commit that added the plan**, not the
branch point:

```bash
git log -1 --diff-filter=A --format=%H -- .phased/active/<slug>/plan.md
```

On a dedicated `wf/` branch the two coincide. On an adopted branch that
already carried commits, only this marker separates the workflow from the
work that preceded it — `/finalize-workflow` consolidates from here, and
without it the interleaving ambiguity comes straight back.

**The plan is a tracked file**, so any skill that edits it dirties the tree.
Edits made outside a phase — a `/resume-workflow` re-phasing, a
`/repair-phase` note, hand annotations in `notes.md` — get their own
`wf: <what changed>` commit. Otherwise the "clean tree at phase start"
invariant that `/execute-phase-agent` relies on is false.

## Phase selection

The next eligible phase is computed deterministically by:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
```

Called with no argument it resolves the active plan itself; pass a path to
point it at a specific one.

It prints a status table for all phases plus one `recommendation:` line
(`next: N` / `resume-candidate: N` / `attention: ...` / `done` /
`blocked: ...`). The semantics it implements — also the manual fallback if
the script is unavailable — are:

- `[x]` done → skip; `[!]` issue / `[~]` blocked → skip (the user must
  resolve them); like any non-completed phase, they block what follows.
- Phases run strictly in order: a `[ ]` phase is blocked while ANY
  preceding phase is not `[x]`.
- `[>]` phases are resume candidates only when nothing else is eligible;
  the script reports their age and whether a `> WIP:` note exists — what
  to do with that is the calling skill's decision.

## Verification: `Done:` and `Verify:`

Two fields, two audiences. **This section is the single source of the
contract** — the skills cite it, they never restate it.

- **`Done:`** — the machine's exit condition: tests, lint, build, a named
  output. Re-runnable verbatim by whoever reads the plan next. It stays
  machine-checkable in both modes; `/execute-phase-agent` re-runs it before
  closing a phase.
- **`Verify:`** — steps a *person* performs, each with the result they should
  see. Never a substitute for a weak `Done:`: a phase whose tests could have
  covered it does not get to push the work onto the human.

**Every `Verify:` step carries a *when*:**

- `now` — check it at the end of this phase; it makes sense on its own.
- `deferred: needs Phase M` — it only makes sense in a wider context, so it is
  **dated, not skipped**.

```
  > Verify: now — open /foo, save a row, it reappears in the grid after reload
  > Verify: deferred: needs Phase 5 — the invoice total matches the order once
    the pricing phase lands
```

**Split by who can check it.** What an agent can assert never reaches the human
list: the flow works, the record persists, the grid reloads — that is what the
`ui-test` skill drives a real browser for. The human list carries only what
needs human judgment: aesthetics, "is this interaction right?", UX ambiguity.
Without this split the list fills with automatable work and stops being read.

**Deferred steps accumulate in `verify.md`** in the plan directory, appended per
phase, and `/finalize-workflow` presents the file as one QA pass at the end
instead of scattering checks the user cannot yet perform.

The mechanism is **thick in interactive mode and thin in autonomous, never
absent**: an autonomous project startup still wants human eyes on the result.
One mechanism in two thicknesses beats two that drift apart.

`verify.md` and `review.md` are siblings, not duplicates: `review.md` says
*"here is what I noticed and will not decide for you"* — the user reads and
judges; `verify.md` says *"here is what you must exercise"* — the user does.

## Failure and repair notes

Note fields the autonomous chain writes on phases, and what consumes them:

- `> Issue:` — root symptom and current diagnosis; written by `/execute-phase-agent`
  when a phase exits `[!]`.
- `> Attempted:` — numbered list of fixes tried, each with its error
  signature. Mandatory on `[!]`: it is the input of `/repair-phase`, which
  must NOT repeat those attempts.
- `> Repaired:` — on a phase turned `[x]` by `/repair-phase`: the actual
  root cause and why the previous attempts missed it.
- `> Repair attempted: <ISO timestamp> — <diagnosis>` — appended by
  `/repair-phase` when the repair fails. It is the idempotent marker:
  `/run-workflow` launches at most ONE repair per phase and stops for
  human review when this note exists. Deleting the note grants another
  repair round after manual intervention.
- `> Review:` — judgment-level findings from the per-phase independent
  verification, flagged for the human at finalize; they never block `[x]`.
- `> Verify:` — one manual check left to the human, carrying its *when*
  (`now` / `deferred: needs Phase M`); written by `/execute-phase`, deferred
  ones copied into `verify.md`, all of them collected by
  `/finalize-workflow`. Semantics in *Verification* above.
- `> Verified:` — optional record of the verification evidence a phase ran
  (which test, which check, what confirmed the `Done:`).

`/repair-phase` always targets the FIRST `[!]` phase in the plan.

## Notifications

How a skill surfaces state depends on whether the user is at the keyboard:

- **Local ping** — `osascript -e 'display notification …'` — when the user is
  present. `/execute-phase` runs one chat at a time with the user watching, so
  a desktop notification on each phase outcome is the right, cheap signal.
- **PushNotification** — when the user may be away. `/run-workflow` launches a
  background run they are meant to walk away from. Where the push lands is the
  user's own notification setup, never this chain's business. Reserve it for
  what is worth an interruption: the
  **first** failure of a run, any blocked phase, and the run ending — routine
  per-phase progress is not pushed. Each message leads with what the user would
  act on, one line under 200 characters, no markdown.

## Auto-mode permission policy

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
