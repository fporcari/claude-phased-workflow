# 5.8.0 — the resume path leaves evidence, and the version claim is checked

Two things close here. One is the leftover 5.2.0 named out loud: *bigger interactive
phases make the resume path (`[>]` plus `> WIP:`) load-bearing, and it still has no real
test coverage*. The other is smaller and of the same family — a claim living in a document
with nothing to keep it true.

## A phase big enough to die halfway leaves evidence along the way

5.2.0 sized interactive phases to "something a human can look at exists". That is the
right boundary, and it makes phases long enough to be interrupted mid-flight. What the
interrupted phase left behind was a `partial` commit fired at the worst possible moment —
when context was already running out — and a free-prose note, `> WIP: <what is done, what
remains>`.

Prose is the defect. A fresh session reading a vague account reinterprets it, and
reinterpretation is how work gets redone or contradicted: the same
failure-through-observable-state class as 4.1.0's `Never commit` cascade, where one mode's
constraint propagated through the state of the repo.

**Checkpoints become the rule, with two triggers and one mechanic.** A coherent,
demonstrable sub-result — the schema exists, the logic passes its test — checkpoints
without asking, while substantial work is still ahead. Context running out is the same
mechanic, forced. Commit and note travel together, never one without the other, so the
note's hash always points at code that exists.

**The note gets a format**, and `refs/phase-execution.md` is its single source — the
skills cite it, they never restate it:

```
> WIP: done: <demonstrable so far> | missing: <what remains of Done:> | next: <first concrete action> | commit: <short hash>
```

Every key earns its place at resume time: `done:` is what the fresh session must not redo,
`missing:` is what remains of the phase's own `Done:`, `next:` is where it starts, and
`commit:` is the hash it **diffs from instead of trusting the story**. What `done:` claims
and the diff confirms is not redone; the rest is.

Resume mechanics live in the same section, so the split stays clean: the mode decides
*whether* to take a `[>]` phase over, the ref says *how*. And a `[>]` phase with no note
and no `partial` commit carries no evidence at all — it is reset to `[ ]` rather than
guessed at.

Checkpoints are not phase commits. `/finalize-workflow` squashes them with everything
else, and red-baseline attribution keeps matching against the `> Files:` of *completed*
phases — which a `[>]` phase does not yet have. `/execute-phase`'s dying-session rule
changes accordingly: it stops resetting a phase whose checkpoint **is** the handoff.

**The tooling surfaces the evidence.** `next-phase.py` carries the ref into the status
table and the `resume-candidate:` line (`wip: yes, wip-commit: abc1234`, or `wip: yes (no
commit ref)` when it is missing), and the validator *warns* — never blocks, since all
three have plausible live-session false positives — on several `[>]` phases, a `[>]` with
no `In execution since` note, and a WIP note with no `commit:` ref.

**S29** covers it, live and static: the selector reports the ref, each warning fires by
name, warnings exit 0, healthy evidence draws none, the format lives once and
`/execute-phase` cites it without restating a format of its own. Suite 171 → 181.

## One home for release notes, and a version claim CI checks

Five `What changed in X` sections were still inline in the README while seven other
releases had their notes in `docs/` — where a note lived depended on when it was written.
All of them are in `docs/release-*.md` now, the two that were missing (5.3.0 and 5.5.0)
written from their own commits, and the README keeps a single `## Changelog` index, one
line per release, complete from 4.1.0.

The README's opening line states the version, which turns it into a claim that can be
checked — so CI checks it: the build fails when README, `plugin.json` and
`marketplace.json` disagree. A version claim that survives in a document longer than in
the code is the `Never commit` defect wearing a different hat, and the plugin cache is
keyed by version (5.5.0 learned that the hard way).

## Still not claimed

The resume hardening is not finished. There is no live kill-mid-phase scenario driving a
real session, and `/resume-workflow`'s stale-`[>]` reporting does not yet show the WIP
commit, though the selector output it reads already carries it. What 5.8.0 gives resume is
a contract worth testing; the live scenario builds on top of it.
