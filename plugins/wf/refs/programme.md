# The roadmap across macro-phases

A programme split into macro-phases is planned one macro at a time, and
`.phased/roadmap.md` is the only document that crosses from one to the next.
Its format, the mini-scopes and the seam review are
`refs/write-workflow-autonomous.md` → *Macro-phases*, for manual plans too.
**This file is the single source of its lifecycle** — read by the skills
that open, close or report a macro (`/write-workflow`, `/finalize-workflow`,
`/resume-workflow`); the others never restate it.

## It lives on the parent

`roadmap.md` is the one file under `.phased/` that reaches the parent:
`/finalize-workflow` drops everything else from the consolidated commit and
keeps it, so the next macro's `/write-workflow` — run on the parent, its
`wf/<slug>` cut from it — finds it there. Field case: a Macro 1 closed by
"Merge into parent" left the roadmap on a branch 150 commits away from
`main`, where the next chat never looks and from which the next macro would
drag the unsquashed history along.

## Its headings carry the state

On the parent a macro is closed or not started; `(current)` exists only on
the branch of the macro in flight.

```
## Macro 1 (done): <title> — closed by wf/<slug>
## Macro 2 (done): <title> — brought forward into Macro 1
## Macro 3 (current): <title> — detailed in active/<slug>/plan.md
## Macro 4: <title>
```

- `/write-workflow` marks its macro `(current)` in the plan commit.
- `/finalize-workflow` turns it `(done)` in the archive commit, with every
  macro the plan absorbed whole. One absorbed in part stays unstarted and
  gains `- Delivered early: <what>, by Macro N`.
- Nothing else is edited at the close: a hindsight that changes a later
  macro is applied by the `/write-workflow` that plans it.

The flip travels **inside the consolidated commit**: code and roadmap land
together, and a revert of the one reverts the other. On the "Pull request"
path it reaches the parent when the PR merges — until then the next macro
is not startable, which is the truth. On "Commit only" it stays on the
workflow branch, and whoever consolidates that branch later keeps it.

## The cycle

The same in both modes: build the phases (`/execute-phase` or
`/run-workflow`) → `/quality-check` → `/finalize-workflow` → **human
checkpoint** → a new chat on the parent, whose `/write-workflow` details the
next macro starting from its mini-scope (`Open decisions` its scoping
agenda, the later macros' `Requires` its `Must not break:`, its `Ends at:` a
planning constraint). A new chat, because a foreman commands one macro
(`refs/foreman.md` → *The foreman*): only the roadmap, the commit on the
parent and the wf-lessons ledger cross the boundary.

## Parallel macros

Independent macros run side by side, each in its own worktree and PR.
Independent means the seam graph says so — every `Consumes:` names a macro
already `(done)` on the parent — never a guess. Each starts from the parent,
so each worktree carries the roadmap, and two `(current)` markers on two
branches are normal. **Each finalize flips only its own heading** and those
of the macros it absorbed — never another block — so the second to land
merges cleanly onto the first (`git pull` before the squash, or a rebase of
the PR branch). A conflict in `roadmap.md` is resolved by keeping both flips.

## Carry-over of a roadmap left behind

A programme closed before 6.52.0 keeps its roadmap only on the old
`wf/<slug>` branch or its `wf-archive/<slug>` tag. On the parent, clean tree:

```bash
git checkout <old ref> -- .phased/roadmap.md
# flip the closed macro and the ones it absorbed to (done), drop (current)
git add .phased/roadmap.md
git commit -m "wf: roadmap — carried over from <old ref>"
```

Pushed only on the user's say-so. The old branch then holds nothing the
programme needs: offer the archive tag and the deletion as
`/finalize-workflow` does.
