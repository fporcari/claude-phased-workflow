# Design notes — phased-workflow

Why the plugin is shaped the way it is. **Nothing here is read at runtime**: the
skills and refs carry the behaviour, this file carries the reasons. It exists so
that rationale addressed to the maintainer stops costing context in every
session that runs a phase.

Add to it whenever a skill is tempted to explain itself.

## The interactive phase boundary, and what it costs

Interactive phases end where a human can open the thing and judge it, so they
come out bigger than autonomous ones — as a consequence, not as a goal. What the
boundary buys: a phase cannot close on half a button, so no verification step
can be a trivial "try this for me".

What it costs, accepted deliberately: a big phase runs in one chat, whose
context can fill. `/execute-phase` offers the WIP escape hatch (`[>]` plus a
`> WIP:` note) and a new chat resumes from it — which makes that path
load-bearing rather than theoretical.

## No execution config on interactive plans

Interactive plans carry no "Suggested execution config" table: nothing reads it.
No per-phase model hints either — interactive execution follows
`/execute-phase`'s own rule (`opus` floor, never `sonnet`), so a hint could only
repeat it or contradict it. A phase mechanical enough to tempt a `sonnet` hint
is a phase that belongs on the autonomous side of the `/write-workflow` Step 2
fork.

## A missing `Mode:` header

A plan with no `Mode:` header stays legal and reads as interactive — that is the
compatibility path for plans written before the fork existed. Plans written by
`/write-workflow` always state the header explicitly.

## Why adopting a feature branch is safe

`/write-workflow` may adopt the feature branch you are already on instead of
nesting a `wf/` branch inside it. That is safe because the workflow's base is
the commit that added the plan, not the branch point: whatever the branch
already carried stays outside the workflow, and `/finalize-workflow`
consolidates from the plan commit forward. Without that marker the interleaving
ambiguity between pre-existing work and workflow work comes straight back.

## Why phase logs are `.txt`

`.phased/active/<slug>/log/phase-N.txt`, not `.log`: `*.log` sits in most global
gitignores and these logs are meant to be committed with the workflow.

## One verification mechanism, two thicknesses

`Verify:` is thick in interactive mode and thin in autonomous, never absent — an
autonomous project startup still wants human eyes on the result. One mechanism
in two thicknesses beats two mechanisms that drift apart.

## Invocation: which skills stay model-invoked

Every shipped skill is user-invoked (`disable-model-invocation: true`) except
three, each for a concrete reason:

- `execute-phase-agent` and `repair-phase` — `scripts/run-workflow.sh` reaches
  them from *inside* a `/goal` contract, whose body is prose ("Use the
  execute-phase-agent skill …"). That is model invocation; stripping their
  description would break the autonomous chain on every CLI ≥ 2.1.139.
- `resume-workflow` — the entry point and router: the one skill the agent should
  be able to reach on its own when the user asks where the work stands, and the
  place that names the others.

The rest are only ever typed, by the user or by a launcher
(`claude -p "/phased-workflow:<skill>"`, which works fine on a user-invoked
skill — verified).
