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

## The gate line

A skill that stops to wait for the user must say so — an implicit wait
reads as hesitation, and only someone who knows the flow by heart guesses
that a reply is expected. Every presentation that ends in a wait closes
with ONE line, plain text, **never inside a code fence** (fenced text
reads as log output, not as a question addressed to the user):

> **Procedo?** Al tuo ok \<exactly what happens next\>.

The verb can change (*Confermi?* / *Lancio?*), the shape cannot: a bold
one-word question, then what the ok unlocks. Multi-way choices go through
`AskUserQuestion` instead (style above); the gate line is for the binary
"go" that unblocks the skill.

## Plan directory

Every workflow keeps its plan and its working notes in `.phased/`, at the
git repository root:

```
.phased/
  roadmap.md              # megaplans only — spans macro-phases
  active/<slug>/          # exactly one at a time
    plan.md               # the work plan
    notes.md              # free-form annotations + per-phase rationale
                          #   (## Phase N headings — see "The foreman")
    foreman.json          # which chat commands this workflow (see "The foreman")
    handover.md           # outgoing foreman's note to the incoming one, optional
    verify.md             # human checks a phase deferred to a wider context
                          #   (see "Verification: Done: and Verify:" below)
    log/phase-N.txt       # stdout of each /run-workflow sub-session, committed
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
work that preceded it, and `/finalize-workflow` consolidates from here.

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

**One contract, two origins.** A `Verify:` step is either **authored in the
plan** (a field on the phase, written by `/write-workflow`) or **surfaced at
execution**. The executing skill carries the authored ones into its
end-of-phase `> Verify:` notes exactly like its own — deferred ones into
`verify.md` — so the QA pass reads ONE list and an authored check can never
fall between the two syntaxes.

**Split by who can check it.** What an agent can assert never reaches the human
list: the flow works, the record persists, the grid reloads — that is what a
browser-driving skill (`ui-test` where installed; it ships separately, not with
this plugin) exercises. **No such skill available → declare it, and hand
exactly those checks to the human as `Verify: now` steps** — a named fallback,
never a silent skip. The human list otherwise carries only what needs human
judgment: aesthetics, "is this interaction right?", UX ambiguity.
Without this split the list fills with automatable work and stops being read.

**Deferred steps accumulate in `verify.md`** in the plan directory, appended per
phase, and `/finalize-workflow` presents the file as one QA pass at the end
instead of scattering checks the user cannot yet perform.

The mechanism is **thick in interactive mode and thin in autonomous, never
absent**: an autonomous project startup still wants human eyes on the result.

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
  (`now` / `deferred: needs Phase M`); written by the executing skill —
  thick in `/execute-phase`, thin in `/execute-phase-agent` — deferred
  ones copied into `verify.md`, all of them collected by
  `/finalize-workflow`. Semantics in *Verification* above.
- `> Verified:` — optional record of the verification evidence a phase ran
  (which test, which check, what confirmed the `Done:`).

`/repair-phase` always targets the FIRST `[!]` phase in the plan.

## The foreman — chat hierarchy and messaging

One chat commands each workflow (the **foreman** — capocantiere in the user's
own metaphor); the chats that execute phases are its children. **This section
is the single source of the protocol** — the skills cite it, they never
restate it.

**The identity of the foreman lives in a file, never in any chat's memory:**

`.phased/active/<slug>/foreman.json`

```json
{
  "session": "wf:<slug>:foreman",
  "since": "<ISO timestamp>",
  "status": "active",
  "history": [
    {"session": "<previous session name>", "deposed": "<ISO timestamp>"}
  ]
}
```

`session` is the name a messaging tool can target. Whoever wants to talk to
the foreman reads this file — no session discovery, no guessing.

**Taking command** — the shared step run by `/write-workflow` and
`/import-workflow` at plan creation, and by `/resume-workflow` when it finds
no active foreman (the normal state of any workflow created before this
protocol existed — absence is migration, not an error):

1. Rename this session to `wf:<slug>:foreman` — in the desktop app via the
   session-management `set_session_title` tool; in the CLI, where the model
   cannot rename its own session, ask the user for one `/rename
   wf:<slug>:foreman` (or note the launch used `--name`). A failed or skipped
   rename does not stop the step: the file still records the best name known.
2. Write `foreman.json` — status `active`, `since` now; a previous foreman, if
   any, moves into `history` with its deposition timestamp.
3. Commit it: `git add .phased && git commit -q -m "wf: foreman — <session
   name> takes command"`. The file is tracked like the plan: left
   uncommitted, it breaks the clean-tree invariant the next phase relies on.
   When the skill's own flow already has a commit coming (the plan commit of
   `/write-workflow`, the import commit), fold the file into that commit
   instead of making a second one.

**Deposing a foreman** (`/resume-workflow`, when a new session takes over an
existing one): best-effort message to the old session — *"You are deposed as
foreman of wf:<slug>. Append anything only you know to handover.md; the new
foreman reads it and the plan."* — and best-effort retitle of the old session
to `wf:<slug>:deposed`. Then read `handover.md` if present, and take command
as above. Neither the message nor the retitle may block: the file is the
truth, the retitle is cosmetic.

**Messaging — children to foreman.** Executing skills notify the foreman at
phase end and on plan changes. To send: read `foreman.json`, then use
whatever session-messaging tool the environment offers — `SendMessage` (with
`ListAgents` to confirm the target) in the CLI, Claude Code ≥ 2.1.224, or the
session-management `send_message` in the desktop app. One plain-text message,
header line first:

```
[wf:<slug>] phase N done — <title>. Commit <short hash>. Verify: <n now, m deferred>.
[wf:<slug>] phase N FAILED — <title>. Issue: <one line>.
[wf:<slug>] phase N blocked — <one line>.
[wf:<slug>] plan changed at phase N — <one-line summary of the approved deviation>.
[wf:<slug>] workflow finalized — <consolidation outcome, one line>.
```

**Best-effort, always, in both directions.** No `foreman.json`, no messaging
tool available, target session not found, delivery refused → skip in silence
and move on. A notification never fails a phase, never asks the user
anything, and never becomes a retry loop. A foreman that receives such a
message treats it as a prompt to re-read `.phased/` and redraw its board —
the plan on disk, not the message text, is the state.

**Handover.** `handover.md` in the plan directory is the outgoing foreman's
note to the incoming one — context that lives only in chat: user intent, the
tone behind decisions, what to watch. The foreman appends to it when
something worth handing over happens; `/resume-workflow` reads it at
takeover. Optional by design: the plan and `notes.md` are the primary record,
and a takeover from a dead chat must work with the files alone.

**Per-phase rationale.** A phase that makes a non-obvious choice appends it
to `notes.md` under a `## Phase N` heading — why this way, what was rejected.
That is what `/finalize-workflow`'s lessons pass (its Step 5) reads instead
of interrogating executor chats that no longer exist; interactive children
still alive may additionally be queried by message, but the file is the
mechanism, the message the extra.

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

## Auto-mode permission scope

What `--permission-mode auto` is expected to deny, and the convention for
writing phases around it, live in
`${CLAUDE_PLUGIN_ROOT}/refs/auto-mode-scope.md` — read it only when deciding
whether a phase can run unattended (`/run-workflow` pre-flight,
`/write-workflow` on the autonomous branch).
