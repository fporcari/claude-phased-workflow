---
description: Close the phase whose work is finished — naming review of the new methods, Done gate, plan update to [x], ONE phase commit, and on a manual plan the foreman notification. Invoke at the end of an attended phase, when the user says the phase is done, or manually on a [>] phase whose work a dead executor left complete but unclosed.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, AskUserQuestion, SendMessage, ListAgents, ToolSearch, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions, mcp__ccd_session_mgmt__clear_session
---

# Close Phase

Turn finished work into a closed phase: naming review, Done gate, `[x]`
record, ONE phase commit. **The happy path only** — a failing phase closes
`[!]` where it failed, inside the executor; this one never writes `[!]` or `[~]`.
Attended plans only (`manual`, `assisted`): an autonomous run's executor
closes inline. A manual plan's foreman is told the outcome from here; an
assisted plan has no foreman, and nothing is sent.

Three ways in, one mechanic:

- **From `/execute-phase`** — its closing step is this skill.
- **Model-invoked** — the phase work is done and verified; closing is not
  a question, so nothing asks permission to *start*.
- **Manual** — `/close-phase` on a `[>]` phase whose work a dead executor
  finished but never closed.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` and
`${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` once at start — core conventions
plus the contract layer this close verifies. The relay layer is never read.
**Shared mechanics:** `${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md`
(outcome format, phase commit) and
`${CLAUDE_PLUGIN_ROOT}/refs/naming-review.md` — cited, never restated.

## Step 1: Identify the phase

Invoked from the executing conversation, the phase is the one just executed —
no lookup needed; the caller's outcome material (touched files, `> Review:`/`> Verify:` notes) travels with the invocation.

Invoked standalone, resolve the plan first
(`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve`; from outside
the plan's root, `--plans` + `git -C` per `common.md` → *Plan location*). The
phase to close is the `[>]` one; none → nothing to close, say so and stop.

**A standalone close gates on evidence.** This session did not write the
work, so the work must speak: read the phase's `> WIP:` note, diff from its
`commit:` (`git diff <commit>..HEAD`), and check what exists against the
phase's `Done:`. No note, no `partial` commit, or a diff that does not reach
`Done:` → a resume-or-reset case (`refs/phase-execution.md` → *Resuming a `[>]` phase*), not a close: say so and stop, or `[x]` forges its guarantee.

## Step 2: The Done gate

Re-check the phase's `Done:` literally, criterion by criterion — run the
named tests, the named lint, verify the named output. An unmet criterion
blocks the close: report it and stop, leaving the phase `[>]`. Re-running
checks that just passed is cheap, and makes `[x]` a contract, not a claim.

**Contract tests gate the close too.** Where the plan carries
`tests/phase-N/` for this phase (`contracts.md` → *Contract tests*), check
the in-tree copies against the plan copies AND the plan copies against the
plan commit (`git diff` over `tests/phase-N/` empty — editing both copies
makes them agree): executable tests byte-identical, skeleton names and every
`wf:contract:` line surviving verbatim, no red body left. A divergence with
no covering decision in `notes.md` under `## Phase N` blocks the
close like a red criterion: the wrong writer edited the contract, and
closing would launder the edit into `[x]`. The gate reads the record, never
the route it arrived by (`contracts.md` → *Where decisions travel*).

**The contract FIELDS gate it the same way** (`contracts.md` → *Authored
checks are foreman-owned*: `Done:`, authored `Verify:`, `Pattern:`, `Files:`,
`Decisions:` are never the child's to edit) — markers and `>` notes move legitimately,
so diff the extraction, not the file:
```bash
PC=$(git log -1 --format=%H --grep "^wf: plan for <slug>$")
diff <(git show "$PC:.phased/active/<slug>/plan.md" | python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --contract-block <N> -) <(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --contract-block <N> ".phased/active/<slug>/plan.md")
```

A diff with no covering decision in `notes.md` under `## Phase N`
blocks the close like a diverged contract test: restore the fields from the
plan commit, or take the recorded wording of the decision. An empty `PC` blocks it
too, and `PC` searches HEAD's own history, never `--all`: the plan commit is
by construction an ancestor of the branch the phase ran on, and `--all` can
answer with a reused slug's commit from another branch.

**Two ways a criterion goes unmet, and only one of them is a refusal.**
Something the phase built is red — a failing test, a lint error — and the
close stops, full stop: that is repair territory, never absorbed here. A
criterion covering work the phase never got to, with what exists green, is
the **closed short** case (`${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md` →
*When the phase outgrows its chat or its executor*): say which criteria are
unreached, propose the `Done:` narrowed to the sub-result that exists, and
close on the user's ok — the `closed short` outcome, whose re-planning takes
its road in `refs/phase-execution.md` → *Routing a decision*: the foreman on a
manual plan, the user at this gate on an assisted one.

## Step 3: Naming review

Run `${CLAUDE_PLUGIN_ROOT}/refs/naming-review.md` scoped to this phase's
touched files. Fast path, one keypress: accept all → markers stripped.
Renames re-run the narrow signal per the ref before anything commits.

## Step 4: Record and commit

A phase held open for the human's checks carries a `> Testing:` note (`${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md` → *Awaiting the human's checks*): drop it here — `[x]` and the note contradict each other, and the checks it was waiting for are recorded as `> Verify:` like every other.

**Closing a phase whose result the person rejected** is this same close with a different report: the `> Review:` verdict is recorded like any other note, and the outcome is the `result rejected` one instead of the `done` one (`refs/phase-execution.md` → *Rejected result*), because what follows is a re-planning, not the next phase — the foreman's on a manual plan, the user's here at this gate on an assisted one, per *Routing a decision*.

Exactly as `refs/phase-execution.md` specifies — *Record the outcome*, *The
phase commit*, *Notify the foreman*: the `[x]` entry with `> Done:`, `> Files:` (ALL touched
files), the `> Review:`/`> Verify:` notes handed over by the caller; ONE
phase commit `wf(phase N): <title>` carrying code, naming-review edits and
plan update together, whatever `partial` commits preceded it — the gate
commit and the executor's included; then, on a manual plan, the foreman
message, best-effort — an assisted plan has no foreman and sends nothing. A
rename worth remembering goes to `notes.md` under `## Phase N`
before the commit.

```bash
osascript -e 'display notification "Phase N closed: <title>" with title "Claude — <repo>/<branch>" sound name "Glass"'
```

Close with the next step, always: the next phase with its `Run:` hint quoted,
or `/quality-check` (then `/finalize-workflow`) when this was the last — the
user must never need to know the flow by heart to keep moving. On a manual
plan the next phase is `/execute-phase` in this same chat, cleared — it is
already in the plan's checkout; on an assisted plan it is `/execute-phase`
again, in this same conversation, which is where the gate already is.

**Clear this chat — manual plans, `done` outcome only**, as the very last
act: `clear_session` on `session_id: "self"`. Everything the next phase
needs is on disk by now — the commit, `notes.md`, the plan, `mockups/`,
`verify.md` — so the next phase starts on an empty context in the right
folder. The clear lands when this turn ends: the closing message goes
first, and says that the chat is about to be cleared and that "Resume
previous session" brings it back. Refused (the chat is pinned, on Remote
Control, or holds a queued message) or no tool → the closing line asks for
`/clear` instead. Never on `closed short` or `result rejected` — what
follows is a re-planning, and its discussion may still need this chat —
never in a foreman chat, never on an assisted plan, whose conversation
carries the workflow.

## Rules

- Happy path only: never write `[!]` or `[~]`, and never absorb a criterion that is *red* — a criterion merely **unreached**, with what exists green, is the closed-short case above, and it is closed by narrowing the `Done:` with the user, never by ignoring it
- ONE phase commit — naming-review edits never get their own; planned
  `Batches:` land as `partial` commits before it, never as a second close
- A standalone close without evidence of completed work is a refusal, not a favour
- The naming-review sweep (grep for `wf:phase-` over the touched files, empty) runs before the commit, even on the accept-all path
