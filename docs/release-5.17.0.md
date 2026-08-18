# 5.17.0 — the names are proposals, and closing a phase becomes a skill

Agent-chosen method names are the part of a diff users most often want to
reword — and until now the first chance to reword them was after the merge,
one commit per name. This release makes every new callable findable, puts
its name in front of a human exactly once, and prices the review at a
single keypress for whoever trusts the proposals.

## The marker

Every method or function a phase creates is born with an end-of-line
comment on its definition line, in the file's own comment token:

```python
def calc_totals(self):  # wf:phase-3:new
```

The name is a proposal. A prefix or a suffix on the name itself was the
first idea, and both die on the same rock: in framework code the name often
IS the API — dispatch by prefix (`rpc_*`-style magic) breaks under a
prefix, hooks matched literally break under a suffix. A comment marks every
callable, framework-bound or free, and accepting a proposed name costs
deleting a comment instead of a rename with call sites.

The marker is scaffolding, like the `wf(phase N)` commits: it never reaches
the parent branch. The contract (format, minimality, who strips when) lives
in `refs/common.md`; the review procedure in `refs/naming-review.md` —
skills cite them, they never restate them.

## The naming review

One map — proposed name, kind (`free` or `framework`), necessity, file,
phase — then ONE question. **Necessity** is the minimality contract applied
where it finally can be: with every new callable in one view, a helper with
a single caller, a speculative abstraction or a duplicate of an earlier
phase's work gets a `⚠` and its reason — above the question, so even the
accept-all keypress happens with the flags in sight. Then:

- **Accept all** (recommended): the review reduces to stripping the
  markers. A user less exacting about names presses enter once and pays
  nothing more.
- **Review one by one**: keep or rename, per method — plus *Inline/remove*
  on the `⚠`-flagged ones; renames and removals are applied to the
  definition AND every call site, and the narrow green signal re-runs
  before anything commits.

The sweep is blocking in both paths: a grep for `wf:phase-` over the
touched files must come back empty before the closing commit — a marker
that survives consolidation is noise shipped to the parent.

Interactive runs review at the end of each phase; autonomous runs cannot
ask mid-run, so markers accumulate in the phase commits and
`/finalize-workflow` runs one review for the whole workflow (its new
Step 3 — the single declared exception to finalize's no-source-edits rule,
because the edits are the user's own decisions).

## `/close-phase`

The `[x]` path of phase closing — Done gate, naming review, plan record,
ONE phase commit, foreman notification — was prose repeated through the
shared core; now it is a skill of its own, and that buys a third way in:

- `/execute-phase` invokes it as its closing step;
- the model can invoke it mid-conversation when the phase's work is done;
- the user can invoke it manually on a `[>]` phase whose work a dead
  session finished but never closed — before this, the only honest move
  was resetting completed work to `[ ]`.

A standalone close gates on evidence (the `> WIP:` note, the diff from its
checkpoint, the phase's own `Done:`): closing unverified work would forge
the one guarantee `[x]` gives the plan's next reader. Failure never routes
through it — a phase that fails closes `[!]` where it failed.

## Minimality, checked by the verifier

The discipline that makes the map short enough to read: a phase introduces
only the callables its objective and `Done:` require. The `phase-verifier`
agent now checks it — a helper with one caller that could be inlined, a
speculative abstraction, a parameter nothing passes is a JUDGMENT finding
(plainly dead code is MECHANICAL: remove). It also checks the marker
itself: a new callable without one escapes the naming review, and that is
MECHANICAL too.

## Renumbering

`/finalize-workflow` gains the naming review as Step 3; the steps after it
shift by one (the scope review is Step 4, the pre-commit review Step 5, the
lessons pass Step 6, archive Step 7, close-out Step 8). Cross-references in
`common.md`, `run-workflow` and `finalize-workflow-agent` follow.
