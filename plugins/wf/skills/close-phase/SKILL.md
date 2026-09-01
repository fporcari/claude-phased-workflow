---
description: Close the phase whose work is finished — naming review of the new methods, Done gate, plan update to [x], ONE phase commit, foreman notification. Invoke at the end of an interactive phase, when the user says the phase is done, or manually on a [>] phase whose work a dead session left complete but unclosed.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, AskUserQuestion, SendMessage, ListAgents, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions
---

# Close Phase

Turn finished work into a closed phase: naming review, Done gate, `[x]`
record, ONE phase commit, foreman notification. **The happy path only** — a
failing phase closes `[!]` where it failed, inside the executing skill; this one never writes `[!]` or `[~]`.

Three ways in, one mechanic:

- **From `/execute-phase`** — its closing step is this skill.
- **Model-invoked** — the phase work is done and verified; closing is not
  a question, so nothing asks permission to *start*.
- **Manual** — `/close-phase` on a `[>]` phase whose work a dead session
  finished but never closed.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` and
`${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` once at start — core conventions
plus the contract layer this close verifies. The relay's message formats are
reached at the notify step through the shared core, not read at start.
**Shared mechanics:** `${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md`
(outcome format, phase commit, notify) and
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
the route it arrived by (`contracts.md` → *The channel*).

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
*When the phase outgrows its chat*): say which criteria are unreached,
propose the `Done:` narrowed to the sub-result that exists, and close on the
user's ok — the `closed short` outcome, whose closing line names
`/resume-workflow` in the foreman chat on `Channel: relayed`, and the
re-planning with the user at the gate where there is no relay.

## Step 3: Naming review

Run `${CLAUDE_PLUGIN_ROOT}/refs/naming-review.md` scoped to this phase's
touched files. Fast path, one keypress: accept all → markers stripped.
Renames re-run the narrow signal per the ref before anything commits.

## Step 4: Record, commit, notify

A phase held open for the human's checks carries a `> Testing:` note (`${CLAUDE_PLUGIN_ROOT}/refs/phase-execution.md` → *Awaiting the human's checks*): drop it here — `[x]` and the note contradict each other, and the checks it was waiting for are recorded as `> Verify:` like every other.

**Closing a phase whose result the person rejected** is this same close with a different report: the `> Review:` verdict is recorded like any other note, and the outcome is the `result rejected` one instead of the `done` one (`refs/phase-execution.md` → *Rejected result*), because what follows is a re-planning, not the next phase. On `Channel: relayed` the closing line names `/resume-workflow` **in the foreman chat** — never here, since a phase chat executes and does not supervise. Where there is no relay the re-planning happens with the user at this gate.

Exactly as `refs/phase-execution.md` specifies — *Record the outcome*, *The
phase commit*, *Notify the foreman*: the `[x]` entry with `> Done:`,
`> Files:` (ALL touched files), the `> Review:`/`> Verify:` notes handed
over by the caller; ONE phase commit `wf(phase N): <title>` carrying code,
naming-review edits and plan update together, whatever `partial` commits
preceded it; then, on `Channel: relayed`, the message, best-effort. A rename worth remembering goes to `notes.md` under
`## Phase N` before the commit.

```bash
osascript -e 'display notification "Phase N closed: <title>" with title "Claude — <repo>/<branch>" sound name "Glass"'
```

Close with the next step, always: the next phase with its `Run:` hint quoted,
or `/quality-check` (then `/finalize-workflow`) when this was the last — the
user must never need to know the flow by heart to keep moving. On
`Channel: relayed` the next phase is a new chat's `/execute-phase`; on
`Channel: in-chat` it is `/execute-phase` again in this same conversation,
which is where the gate already is.

## Rules

- Happy path only: never write `[!]` or `[~]`, and never absorb a criterion that is *red* — a criterion merely **unreached**, with what exists green, is the closed-short case above, and it is closed by narrowing the `Done:` with the user, never by ignoring it
- ONE phase commit — naming-review edits never get their own; planned
  `Batches:` land as `partial` commits before it, never as a second close
- A standalone close without evidence of completed work is a refusal, not a favour
- The naming-review sweep (grep for `wf:phase-` over the touched files, empty) runs before the commit, even on the accept-all path
