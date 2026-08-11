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

---

# Superseded README material (v1 → v2, 2026-08-11)

README v2 ([#9](https://github.com/fporcari/claude-phased-workflow/issues/9)) is
problem-first and half the length; what it cut moved here rather than dying.
Sections below are the v1 material whose substance is not already carried by a
skill, a ref or another doc.

## Key design decisions

- **Why worktrees?** Git worktrees create isolated working directories on
  separate branches. Each worktree has its own file tree, so parallel workflows
  don't interfere. `git add -A` in a worktree is safe — everything there belongs
  to that workflow. They are opt-in: `/run-workflow` creates one on demand for
  autonomous runs; interactive work stays on the branch in your session.
- **Why one commit per phase, then a squash?** Both paths commit once per phase
  (`wf(phase N): <title>`) on the throwaway workflow branch, because the
  mechanics live once in `refs/phase-execution.md`. The per-phase commit is
  load-bearing: repair needs the failing code in history, and red-baseline
  attribution matches a failure against the `> Files:` of *committed* phases.
  `/finalize-workflow` squashes those commits into one clean commit on the
  parent — the parent receives exactly one commit either way. (Before 5.0.0 the
  interactive path did not commit — the claim survived in older docs longer
  than in the code.)
- **Why a separate `/write-workflow` command?** Planning is a natural
  conversation. Forcing it into a structured command felt rigid. You talk, then
  `/write-workflow` captures the result: the plan comes from the discussion,
  not from a template.
- **Why merge instead of cherry-pick?** When finalizing a sub-task worktree,
  merging into the parent preserves history, avoids duplicate commits, and
  makes the merge visible in `git log`.

## The parallel sub-tasks pattern

A long feature branch (`feat-auth-refactor`) can host several workflows at
once, one worktree each (`refactor-login`, `refactor-sessions`,
`refactor-tokens`), each with its own plan under `.phased/`, its own VS Code
window, finalized independently with **merge on parent** back into the feature
branch — which then reaches `develop` by one PR. Conflicts between sub-tasks
emerge at merge time, exactly like in a human team, but with full visibility.
Without worktrees the same works serially: one plan per branch,
`next-phase.py --plans` lists every workflow reachable from the repo,
including branches with no checkout.

## Model & effort — the full reasoning

The README states the inverted rule; the operative detail lives in
`/run-workflow`'s pre-flight (autonomous) and in the per-phase `Run:` hint
(interactive). The reasoning worth keeping:

- The stronger the verification loops, the cheaper the executor can be. The
  economics still bite: a sonnet phase that fails costs a fable repair, so
  sonnet pays only where first-pass success is likely. Marking a phase `sonnet`
  is a commitment about the *plan*, not the model — whatever the skill no
  longer spells out, that phase's `Details:`/`Done:` must.
- Effort: start low and climb only for a reason. A phase that passed pre-flight
  is well-specified *by construction*, so high effort gets spent re-exploring
  decisions the plan already settled. `max` overthinks; effort levels copied
  from an older plan rarely transfer.
- Interactive plans use two values only (`opus` floor and default, `fable`
  where inventive work survives past the approval gate): `sonnet` never —
  a phase mechanical enough for it belongs on the autonomous side of the fork.
  Fable's premium case is unwatched work, and interactive is watched by
  construction.
- The independent verifier does not run on every phase. Current models verify
  their own work as they go; a second pass on a well-specified phase produces
  re-litigation, not findings. It runs where it earns its keep: `sonnet`
  phases, `new-pattern` phases, repairs. The `Done:` gate runs always — a
  contract check against a criterion the executor did not write is a different
  thing from re-reading your own work. The verifier is pinned to opus rather
  than inherited: on a sonnet phase an inherited verifier is as weak as the
  executor it checks.

## The human moves to the edges

Autonomous does not mean unsupervised — supervision concentrates where it
pays: plan approval, pre-flight confirmation, the macro-phase boundary,
finalize, and any phase left `[!]`/`[~]`. Inside those edges the machine
self-corrects. Nothing reaches the parent branch without the human: per-phase
commits land only on the throwaway workflow branch.

## Macro-phases (rolling wave)

Beyond ~8–10 phases, or when a phase's shape depends on an earlier phase's
*outcome*, `/write-workflow` splits the work into macro-phases: only the first
is detailed, the rest stay as inert bullets in `.phased/roadmap.md`. Each
macro gets its own `/run-workflow` + `/finalize-workflow`, and the next
`/write-workflow` re-plans with hindsight. The macro loop is deliberately
manual — its boundary is where human judgment pays most, before errors
compound.

## FAQ answers worth keeping

- **Skip or reorder phases?** The plan is Markdown — edit it;
  `/resume-workflow` verifies consistency. New work goes in the tail, never in
  the middle: phase numbers are contiguous and committed history names them.
- **Plan from any branch?** From a base branch `/write-workflow` opens
  `wf/<slug>`; from a feature branch it adopts it (see *Why adopting a feature
  branch is safe* above).
- **Walk away during a run?** Yes — the run stays attached to the launching
  session; leave the app open. It survives you leaving the house, not the Mac
  shutting down. No detached mode on purpose: a detached run would have no
  live session to notify from.
- **Can it push without me?** Nothing reaches the parent branch without you,
  and nothing pushes without you.
- **Old `MEMORY.md` plans?** `/import-workflow` maps them onto the new layout,
  preserving states and notes, reporting gaps instead of filling them.

## Known patterns

Plan-and-Execute (LangChain/LlamaIndex) · Checkpoint & Resume (CI/CD) ·
Shared state via artifact (blackboard architecture) · Context-window
management (short focused sessions) · Worktree isolation. The point of this
plugin is making explicit and user-controllable what agent products do
internally and opaquely.

## The test suite, scenario by scenario

**198 assertions over 31 scenarios** — S1 through S32, S16 retired with the KB
mirror. S1–S13 run the shipped `/run-workflow` script against a mock `claude`
binary: `/goal` call shape, model/effort/cap selection, repair succeeding and
resuming the loop, repair failing and stopping it, the idempotent repair
marker, relaunch on a `[!]` without that marker, attribution Case A (a
reopened phase drops the done-count without tripping the progress guard) and
Case B (`[~]` stops the run), fable→opus fallback on a session crash, the
no-progress guard, the inert `## Roadmap`, and the pre-2.1.139 prompt
fallback. S19: `next-phase.py --validate` gates the launcher, and warnings are
printed, not discarded. S20: every silent fallback announces itself with a
`NOTE:`. S17 and S22 build real git repos (import classification;
the `--plans` location service). S18 is a hybrid: prose bullets in `## Notes`
stay inert, and every phase-state match is single-source.

Prose invariants, each proven by mutation: S21 (plugin paths, never
`~/.claude`), S23 (`-agent` skills are thin variants citing their base), S24
(the automation fork is real), S25 (the `EVENT` contract, emitted exactly
once on every exit path), S26 (every sub-session prompt namespaced), S27 (the
`Done:`/`Verify:` contract single-source in `common.md`), S28 (per-model
steering reaches every sub-session), S29 (the resume path leaves
machine-readable evidence), S30 (the foreman protocol single-source and
cited), S31 (cross-phase awareness ships, and the reporting register is
single-source), S32 (the closing report's shape, the report page, the
report-judge comprehension probe and the single detail question —
single-source and cited, the agent shipped).

Static checks on what the repo ships: S14 (no frozen copy of a shipped
contract; the light contract carries its per-phase-commit clause), S15 (every
skill inside its own `allowed-tools`, prose included), S18's static half, S21,
S23.

## Internal mirror (Softwell)

As of 5.0.0 the internal knowledge-base topic no longer mirrors the skills: it
holds the install guide plus internal-only commands (`ui-test`,
`push-context-memory`). One distribution road — this repo, via the plugin
marketplace; the old sync tooling (`tools/kb-sync.py`, test S16) is retired.
