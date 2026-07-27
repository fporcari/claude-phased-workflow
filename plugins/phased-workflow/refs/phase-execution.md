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

## Record the outcome

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

## Context escape hatch

Context running out mid-phase with substantial work left: commit what
exists as `wf(phase N): partial — <title>`, keep `[>]`, add
`> WIP: <what is done, what remains>`, and exit — the next invocation
resumes from a clean tree.
