# Phase execution — shared core

Loaded by `/execute-phase` (interactive) and `/execute-phase-agent`
(unattended). The two modes differ by *where decisions get made* — live in
the chat, or pre-made in the plan — never by these mechanics. A rule that
changes here changes for both; that is the point (the `Never commit`
leftover of 4.1.0 is what happens when siblings carry their own copies).

## Select the phase

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
```

Act on `recommendation:` — `next: N` → take it; `done` → exit suggesting
`/finalize-workflow`; `blocked: ...` → report the reason and stop;
`resume-candidate: N` and `attention: ...` → mode-specific, see the calling
skill. Script unavailable → apply the semantics in `refs/common.md`.

Mark the selected phase `[>]` with `> In execution since <ISO timestamp>`.

## Implement

Read the phase's `Pattern:` example first — it is the model to copy-adapt —
then its `Files:`. Write the code the phase describes, and nothing else.
Never invent framework APIs. ONE phase per invocation; no out-of-scope
refactoring.

**New callables: minimal, and marked.** Introduce only the methods and
functions the phase's `Done:` requires, and give every one of them the
end-of-line marker on its definition line — `# wf:phase-N:new`, in the
file's own comment token — per `refs/common.md` → *New-method markers and
minimality*. The name you choose is a proposal: the naming review
(`refs/naming-review.md`) is where a human accepts or rewords it —
`/close-phase` in interactive runs, `/finalize-workflow` in autonomous
ones — so never spend a question on a name here.

**The plan is context, not just a queue.** Before the first edit, skim the
whole plan once — every phase, not only yours. The `> Done:`/`> Files:`
notes of completed phases say what already exists: reuse it, never
duplicate it. The pending phases say where the work is heading: a
micro-choice this phase leaves open (a name, where a helper lives, a data
shape) is decided in favour of the phases that come after, and a choice
that would force a successor to undo or work around it is the wrong choice
even when it is locally cheaper. Scope is unchanged: knowing Phase 5
exists never means implementing a piece of it here.

## Record the outcome

The `[x]` path has a skill of its own: in interactive runs `/close-phase`
performs this section and the two that follow (naming review included);
`/execute-phase-agent` performs them inline, markers left in place. The
`[!]` and `[~]` outcomes are always recorded directly by the executing
skill — failure never routes through `/close-phase`.

```
- [x] **Phase N**: title
  > Done: brief description
  > Files: path/a.py, path/b.py, ...
  > Review: judgment-level findings flagged for finalize (omit if none)
```

```
- [!] **Phase N**: title
  > Issue: root symptom and current diagnosis
  > Attempted: 1) <fix tried> → <error signature>  2) <fix tried> → <error signature>
  > Files: path/a.py, path/b.py, ...
```

```
- [~] **Phase N**: title
  > Blocked: <what blocks it — e.g. a pre-existing red baseline nobody owns>
```

**Always list ALL touched files in `> Files:`** — later baseline checks
attribute regressions by them, and `/repair-phase` diffs against them.
`> Attempted:` is mandatory on `[!]`: it is the input of `/repair-phase`,
which must not repeat those attempts.

## The phase commit

One commit, at the end, the phase's code and its own plan status update
together — so the next phase starts from a clean tree:

```bash
git add -A && git commit -q -m "wf(phase N): <title>"
```

A phase closing `[!]` commits too, as `wf(phase N): FAILED — <title>`, and
leaves the failing code **in place**: repair has to see it.

A choice the phase made that the plan did not settle — why this way, what was
rejected — goes into `notes.md` under a `## Phase N` heading before the
commit, per `refs/common.md` → *The foreman* (per-phase rationale): finalize
reads the file, not the memory of a chat that no longer exists.

## Notify the foreman

After the phase commit, send the workflow's foreman chat one message with the
outcome — done, FAILED, or blocked — in the exact format and by the exact
mechanics of `refs/common.md` → *The foreman*. Best-effort: no
`foreman.json`, no messaging tool, delivery refused → skip in silence. The
notification never fails a phase and is never worth a retry loop.

## WIP checkpoints

A phase big enough to die halfway must leave evidence along the way. Two
triggers, one mechanic:

- **Coherent sub-result** — the phase reaches something demonstrable (the
  schema exists, the logic passes its test) with substantial work still
  ahead: checkpoint it, without asking. In practice this concerns
  interactive phases, sized to "something a human can look at"; an
  autonomous phase rarely lives long enough to need one.
- **Context running out** — the same mechanic, forced: checkpoint what
  exists and exit; the next invocation resumes from a clean tree.

Commit and note travel together — never one without the other, so the
note's `commit:` always points at code that exists:

```bash
git add -A && git commit -q -m "wf(phase N): partial — <sub-result>"
```

Keep the phase `[>]` and write (or replace) the structured `> WIP:` note.
**This is the single source of its format** — the skills cite it, they
never restate it:

```
> WIP: done: <demonstrable so far> | missing: <what remains of Done:> | next: <first concrete action> | commit: <short hash>
```

Each key earns its place at resume time: `done:` is what a fresh session
must not redo, `missing:` is what remains of the phase's own `Done:`,
`next:` is where it starts, `commit:` is the hash it diffs from instead of
trusting the story. Free prose is what made resume unreliable: a fresh
session reading vague prose reinterprets, and reinterpretation is how work
gets redone or contradicted.

**Resuming a `[>]` phase** — the calling skill decides *whether* to take
it over; this is *how*: read the `> WIP:` note, run
`git log --oneline` over the phase's `partial` commits and
`git diff <commit>..HEAD`, and continue from `next:` toward the phase's
own `Done:`. What `done:` claims and the diff confirms is not redone. A
`[>]` phase with no `> WIP:` note and no `partial` commit carries no
evidence — reset it to `[ ]` with
`> Execution interrupted, phase available for retry` rather than guessing
what a dead session did.

Checkpoints are not phase commits: `/finalize-workflow` squashes them with
everything else, and red-baseline attribution keeps matching against the
`> Files:` of *completed* phases, which a `[>]` phase does not yet have.

## Awaiting the human's checks

Interactive mode only — an unattended phase has nobody to hand a check to.
**When verification leaves the human at least one `Verify: now` step, the
code is finished but the phase is not.** It is committed and left `[>]`, so
nothing closes on a result nobody has looked at yet.

The mechanic is the checkpoint above — a `partial` commit — plus the note
that says what it waits for. **This is the single source of its format** —
the skills cite it, they never restate it:

```
> Testing: awaiting the human's `Verify: now` checks | commit: <short hash>
```

The checks themselves stay in their own `> Verify: now` notes: one syntax,
not two. `next-phase.py` reports such a phase as `blocked:` — only the human
clears it, so an unattended run stops and says so instead of resuming a
phase with nothing left to implement. What the checks turn up is ordinary
work on the still-open phase: commit it the same way, replace the note. The
human's ok is what runs `/close-phase`, and closing drops the note.
