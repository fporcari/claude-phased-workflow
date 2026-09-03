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
  to that workflow. `/write-workflow` opens one by default for a `wf/` branch
  (flippable in its branch line; `Channel: in-chat` stays in the checkout, since
  that conversation IS the workspace), so the checkout you planned from never
  leaves the parent and a `git switch` there cannot break a run; the launcher
  still creates one on demand for a plan whose branch has no checkout.
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
  *(Superseded 2026-08-19: field experience regretted every sonnet phase — the
  first-pass-success bet kept losing. Sonnet left the palette; mechanical work
  is opus at low effort, where light mode already strips the ritual that was
  sonnet's supposed saving. The launcher still accepts legacy plans carrying
  it.)*
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

## A test on the consumer proves nothing about the producer

A contract test asserted that the page READS `.tags`. It passed. No tag was
ever visible, because the rows the grid is built from come from a second
projection that names its fields one by one and did not name `tags` — the
renderer was handed `undefined` on every row.

The defect survived a full autonomous run, an Extended whole-diff review and
the run's own coherence review, and was caught only by a browser pass. All
three read the code; none of them could see that a value stops travelling
somewhere between the payload that carries it and the projection that renders
it.

So: on any field that crosses a layer, assert the ROAD — producer, every
projection in between, consumer — not the endpoint. A test that names one end
is a test that goes green while the feature is invisible. The same shape recurs
wherever a payload is re-projected for a view, which in this codebase is
`roadmap._phases` and anything downstream of it.

## Light mode and contract tests do not mix

The launcher runs a `low`-effort phase in LIGHT mode: a slim `/goal` contract
WITHOUT the execute-phase-agent skill. The effort level is chosen for the work
("this one is mechanical"), and it silently also decides which DOCTRINE the
phase receives. Nothing couples the two.

On a plan carrying contract tests that coupling bites hard, because light mode
withholds exactly the rules such a plan depends on: that the contract is
read-only, and that a test which cannot pass as written is a plan-defect claim
to be raised rather than a local fix. The measured correlation from the
wfdash-open-findings run is exact — the three light-mode phases all edited
their own contract test inside the plan directory (24, 13 and 59 diff lines,
one of them deleting three `wf:contract:` lines that constrained a later
phase); the two full-mode phases did not touch it at all.

A plan that ships contract tests therefore has no `low` phases. The saving that
tempts you there is the ritual light mode strips, and the ritual is the part
that protects the contract.

## The consult has no deadline

The plan-defect consult held the repair for 600 seconds and then let the repair
judge the claim. The window was sized for a user at the keyboard; the run it
guards is the one the user walks away from. On the 7-location-hours-calendar run
the phase failed at 00:10 with a TRUE claim — its contract test imported a
resource by a dotted path GenroPy never resolves — the foreman verified it on
the code within minutes, and the human was asleep. At 00:20 the repair took
over, built a `lib/resources/__init__.py` shim so the path resolved, deleted the
correct component the failed phase had written, recorded its own verifier's
objection as a `> Review:` and closed green. The coherence phase read the green
as legitimate. The morning cost one revert.

Holding costs nothing — the launcher polls a file — while a wrong repair costs a
fable session, a phase built on it and the revert. So the hold has no deadline:
the human decides whenever they arrive, a stop request during the hold ends the
run cleanly, and `RUN_WORKFLOW_CONSULT_TIMEOUT` remains as the explicit opt-in
for whoever wants the old behaviour. Two rules follow it. The foreman checks the
claim against the code while the launcher holds, so the morning decision is
made on a verified finding — and the recommended option follows that check,
apply when it confirmed the claim, repair when it did not. And a repair that
reaches green only through surface outside the phase's `Files:`, or with a
verifier JUDGMENT against the contract's own premise, has confirmed the claim
at a price, not dissolved it: it closes `[!]` with the workaround described and
not committed. The "both claims were wrong" prior the refs carried is now two
wrong and one right, and it reads that way.

## The suite is not parallel-safe

`tests/orchestration/run_tests.sh` cannot be run concurrently with itself. Two
overlapping bash runs produced four phantom failures; each run alone is green
under both shells. The scenarios share fixture paths and the `${TMPDIR}` files
the launcher uses, so a second run walks through the first one's state. If CI
is ever split for speed, split it by scenario into separate checkouts, never by
running the same script twice at once.

## Phase sizing: decision boundaries, not file counts

*Written 2026-09-01 as the design the change was edited against, and landed
the same day in 6.30.0. It stands as the rationale; where it and the skills
disagree, the skills are what ships, and the corrections recorded at the end
are the places where that happened.*

**Originating requirement: [issue #22](https://github.com/fporcari/claude-phased-workflow/issues/22)**,
"Protocol overhead dominates on attended serial work". This section is the answer
to it, and its numbers are the measurement this design is accountable to: one
10-phase attended run costing 11
chats, ~35 cross-session messages, ~25 apparatus commits against 10 phase
commits, and 9 clarify rounds of 5 legs each. The count of phases was the
symptom; the cause was planning before anyone had read the code, which produces
phases built on hypotheses and then renegotiates them one at a time, on the most
expensive channel available.

**#22 is answered by 6.30.0, and what the release owes the field is one
measurement**: an equivalent case, planned on `Channel: in-chat`, runs in a
single chat with no foreman and no receipts and comes out as a handful of
decisional phases without the nine clarify rounds. Prose is not the fix, the
routing is — and the first attended run on the new channel is what confirms
the routing did what this section says.

### The definition

> A phase is the largest coherent unit of work that can be executed, verified
> and reviewed without an intermediate result forcing the rest to be re-planned.

It carries two cut criteria that answer different questions, and keeping them
apart is the whole point:

- **re-planning** decides *how many* phases there are — one per decision
  boundary;
- **reviewability** decides *how big* one may get, at a fixed number of
  decisions.

### Reviewability cuts produce batches, not phases

When only the second criterion pushes for a cut, the work stays **one phase**
and splits internally into batches. The phase owns `Done:`, its
state, its gate and `/close-phase`; a batch owns nothing but a commit. "Unit of
review" therefore means *a commit that can be read on its own at the end of the
phase* — not a review between batches, and not a pause.

So both properties hold at once: phase count tracks decision boundaries, commit
size keeps the diff readable, and nothing between batches costs a context
reset, a gate or a re-plan.

Why not simply call them phases: give a cut a state and a gate and it becomes
exactly the boundary the post-mortem indicted — a context to rebuild and an
invitation to a clarify round, bought for a reason (diff length) that has
nothing to do with judgment.

### Sizing against the executor

Current models do their best work carrying one task from start to finish in a
single context. Fine-grained phasing is what small models needed and what large
ones pay for. 291 mechanically rewritten call sites are one phase, batched;
three unknown root causes are three phases, because each finding re-plans the
next.

### Triage: three questions, three outputs

Reconnaissance comes first, then the dimensions — and they do not weigh on the
same thing:

| dimension | determines |
|---|---|
| uncertainty — do we already know what to do? | phase count |
| branching — can an intermediate result change the next step? | phase count |
| verifiability — does a reliable check exist? | how much checking |
| blast radius — is a mistake isolated and reversible? | how much checking |
| attendance — is a human at the gate? | which channel |
| parallelism — one workflow, or several at once? | which channel |

Triage returns `(n phases, how much checking, which channel)`. The third output
is the one #22 is about, and it is why "how much control" and "which apparatus"
must not be read off the same axis: **foreman, messaging and receipts are a
channel, not a control**. They exist because when nobody is at the gate, disk
and messages are the only way a decision can travel. With a human at the gate
the foreman removes nobody from the loop — it inserts a hop in the middle of one
that was already closed, and every clarify pays its five legs to cross it.

So dangerous-but-attended work gets heavy verification on a light apparatus, and
a two-output triage would have got exactly that case wrong — routing "high blast
radius" to the heavy preset and dragging the relay in with it. Sizing,
control and channel are three independent choices; a single "small/medium/large"
label collapses all three and then activates the wrong components.

**Parallelism is a property of the surroundings, never of the workflow.** Phases
stay ordered and serial: a `[ ]` phase is blocked while any preceding phase is
not `[x]`, the launcher runs one session at a time, and nothing here changes
that. The dimension earns its row only because *several distinct workflows or
executors* — already supported today, each with its own plan and branch — cannot
share an attended gate, which forces the relayed channel. It must never be read
as a promise of parallel phases inside one plan; the launcher does not run them,
and a plan that implied otherwise would be describing a machine that does not
exist.

### Three axes, one new header

The three triage outputs stay three independent values — and only one of them
needs a field. Three outputs do not license three headers:

- **`n phases`** — a sizing outcome, and **already expressed by the plan's own
  structure**: the phases are there, numbered and countable. A one-phase plan is
  `n=1` and nothing more; "single-phase" is not a profile, not a channel, and
  must never become an enum value that quietly also means "no foreman". A
  one-phase plan can run unattended, and a fifteen-phase plan can run in one
  attended chat.
- **checking depth** — **already expressed** by `Done:`, `Verify:`, the presence
  of authored contract tests and the verifier configuration. There is nothing
  left for a header to say that those four do not already say more precisely. If
  a concrete runtime consumer ever turns up needing a separate field for it,
  that is a decision to take on the evidence, not in advance.
- **channel** — the only one with no existing expression, because it is a
  *routing* fact: where a decision travels. It gets the one new header.

No preset shipped. An earlier draft named three — `solo`, `standard`,
`supervised` — as planning-time shorthands expanded into the plan's structure
and its `Channel:` value; what landed is the two questions themselves (`Mode:`,
then `Channel:`, in `/write-workflow` → *Step 2*) and the sizing rule, because
a label that expands into three independent choices is exactly the collapse
the previous paragraph refuses. Dangerous-but-attended work (thick `Verify:`,
authored contract tests, `Channel: in-chat`) stays expressible field by field,
which is the property a preset would have had to preserve anyway.

The plan gains exactly two fields:

- **`Channel:`** — plan header, optional, `in-chat` or `relayed`.
- **`Batches:`** — per phase, optional, the planned subdivision.

Same `plan.md`, same states, same `/close-phase`. Not a second plugin and not a
second plan format: a "lite" variant is a second surface to maintain, and two
surfaces drift. It is also why the smallest preset stays inside the protocol
rather than being #22's "no plugin at all" — that proposal drops the tracked
plan with a re-runnable `Done:` and one commit per phase, which the same issue
lists first among the things that paid *at every size*. The apparatus is what
should switch off; the artifacts stay.

The channel axis does NOT replace `Mode:`, though a first draft of this
section said it would: the two fields answer different questions (`Mode:` how
the work runs, `Channel:` where its decisions travel), and `Mode: interactive`
means, and keeps meaning, a chat per phase with the relay between them. The
resolution and its reasons are under *Compatibility plan* below.

### Reconnaissance before interrogation

`/scope-workflow` interrogates the user one question at a time before the plan
exists, and a good share of the clarify rounds it generates are questions the
code could have answered. The recon pass goes first: read, then ask only what is
genuinely undetermined.

What recon must actually check is not a matter of taste: #22's lessons ledger
has eight entries with one shared root, and they fall into four classes, each of
which came back as a full clarify round —

- **literals** asserted as unique and never grepped for duplicates;
- **behaviour** transcribed from a design doc that the code contradicts;
- **remedies** (a flag, an env var, a CLI option) never checked against the
  tool's real interface;
- **arithmetic** — counts and totals stated without being computed.

Any of the four is cheap to verify while reading and expensive to discover from
a phase gate.

### `Files:` and `Decisions:` stay in the plan, with an entry rule

After recon the planner still writes the probable area and files, the evidence
found, the known constraints and the decisions already settled.

The entry rule binds **claims about existing code, and only those**: an assertion
about what a file contains, what a call site looks like, how a tool behaves, how
many of something there are, must cite the grep or the file behind it or not be
written. It does not bind design intent. **Files that do not exist yet are
plannable output** — a new service, a new module, a new test file are legitimate
plan content, named in advance, and the rule that applies to them is the
ordinary one: they are a proposal the phase realises, not a fact being asserted.
Reading the rule as "only write filenames you have opened" would forbid planning
anything new, which is not what the #22 defects were: every one of them was a
false statement about code that already existed.

The executor records the actual files and the decisions that emerged in
`notes.md`. What produced vagueness was compiling those sections from memory,
not their presence; moving them wholesale into the output would only make the
autonomous prompt vague again. The gap between what the planner predicted and
what `notes.md` records is diagnostic material on the planner.

### `model:` / `effort:` as overrides — not in 6.30.0

Proposed and deliberately left out of this release: the default would belong
to the workflow, and a phase would override it only with the reason written
next to it, so plans stop binding themselves to the current model roster. It is
independent of the channel axis, it touches the launcher's `Run:` parsing, and
nothing in #22 needed it — so it waits for evidence of its own. If it ever
lands, *No execution config on interactive plans* above still holds: the
override is the autonomous side's.

### Batch commits against the one-phase-one-commit invariant

The invariant is stated in `refs/common.md` → *Each completed phase is ONE
commit, `wf(phase N): <title>`* and read by `close-phase`, `quality-check`,
`finalize-workflow`, `resume-workflow`, `next-phase.py` and `run-workflow.sh`.
Batches must not break it, and they do not have to: the mechanism already
exists.

`refs/phase-execution.md` → *WIP checkpoints* already defines a second commit
form inside a phase — `wf(phase N): partial — <sub-result>` — created when a
long phase outlives its chat. Every consumer downstream already tolerates it.
Batches are that same commit form, **promoted from escape hatch to planned
subdivision**: same prefix, same shape, decided at planning time instead of
discovered when the context fills. Nothing new is invented, and the invariant
holds as it always did, restated precisely:

> A phase produces exactly one **phase commit** — the one that carries `[x]`,
> the plan status update and the naming-review edits. Any number of `partial`
> commits may precede it. `partial` commits are code checkpoints, never phase
> closures.

Effects on the four consumers that count:

- **`/close-phase`** — unchanged in mechanics. Its `Done:` gate runs against the
  phase, not the batch, and it still produces the single phase commit. What
  changes is one existing rule that must be re-read rather than rewritten:
  today a `[>]` phase with no `> WIP:` note *and* no `partial` commit "carries
  no work" (`phase-execution.md`). Under planned batches a `partial` commit
  becomes an expected intermediate state rather than evidence of an interrupted
  chat, so the resume heuristic must distinguish *planned batch* from
  *interrupted phase* — a plan-side batch list is what supplies that, and it is
  the one contract addition batches actually require.
- **`/quality-check`** — this is the real breakage. It states `git log --oneline
  "$BASE"..HEAD` is "one commit per phase plus the plan commit", with no staging
  heuristics by design. With batches the log is one commit per phase *plus its
  partials*, so the pass must group by phase (the `wf(phase N):` prefix already
  carries the key) instead of assuming one line per phase. The one-line-per-phase
  presentation survives; the parsing behind it does not.
- **`/finalize-workflow`** — unaffected by construction. It consolidates the
  whole workflow into a single commit on the parent, so batch granularity never
  leaves the throwaway workflow branch. Which is also the honest statement of
  what batches buy: readability *during* review, nothing at all afterwards.
- **`/resume-workflow`** — its oversized-phase heuristic flags a phase whose
  commit spans more than ~10 files. That heuristic must move to the batch, or a
  correctly batched fat phase reads as a sizing failure. This is the check that
  keeps the batch mechanism honest, so it should get stricter, not be dropped:
  an oversized *batch* is exactly the field signal named under *The risk being
  accepted*.

### Consumer inventory: what the in-chat channel actually touches

The first draft of this section named `/scope-workflow`, `/write-workflow` and
`contracts.md` as the edit surface. That was wrong, and wrong in the way the
section itself warns against — written before the consumers were read. The
relay channel is not confined to the writers; it is load-bearing in the readers
and in two gates.

The one finding that changes the design: **the foreman is not only a channel,
it is an authority of record.** `close-phase` blocks a close when the diff has
no covering foreman decision in `notes.md` under `## Phase N`; `contracts.md`
makes authored checks foreman-owned, routes test edits through a `clarify?`
whose reply carries the edit, and requires every divergence to be covered by a
foreman decision; `common.md` assigns phase sizing to the foreman. Deleting the
relay on the in-chat channel would leave those gates pointing at nobody.

The resolution costs far less than rewriting them, and it is a co-location, not
an identification. **On the in-chat channel the foreman's procedural role is
co-located with the executor: there is no relay between conversations.**
Decision authority stays with the user present at the gate, and `notes.md`
remains the mandatory record of decisions. The human is not "the foreman" —
the role is a position in the protocol, the user is the one who decides, and
collapsing the two would smuggle the relay's authority onto a person who never
agreed to hold it.

Three statements follow, and they are the ones the implementation must not
blur:

- the **decision record is mandatory on both channels**;
- the **message is mandatory only on the relayed channel**;
- the absence of the message **neither removes nor weakens the contractual
  gates** — a gate that asks for a covering decision keeps asking for it, and
  gets it from `notes.md`.

Two existing facts make this cheap: `phase-execution.md` already specifies *no
`foreman.json`, no messaging tool, delivery refused → skip in silence*, so the
messaging leg is degradable by design; and `foreman.json` is a pointer to a
chat, which on the in-chat channel is simply the current one.

The surface, grouped by what each consumer assumes:

| consumer | what it assumes | what the channel axis changes |
|---|---|---|
| `refs/common.md` | `foreman.json` in the layout; sizing is the foreman's job; one commit per phase | who plays the role; batch wording |
| `refs/contracts.md` | authored checks foreman-owned; `clarify?`; divergence needs a covering decision | the decision's author and channel, not its existence |
| `refs/phase-execution.md` | notify step; WIP `partial` commits; closing short; rejected result | notify already degrades silently; batch wording |
| `refs/foreman.md` (453 lines) | the relay itself | not loaded at all in-chat — the largest single context saving |
| `refs/board.md` | `Mode: interactive` only | reads the channel axis instead |
| `/execute-phase` | per-phase chat title; ambiguities and stop-loss routed up; seam question | routing target is this chat; the title stops being per-phase |
| `/close-phase` | foreman notification, the covering-decision gate | the gate stays, its authority is local |
| `/resume-workflow` | Step 1b take-command; `foreman.json`; oversized-by-commit | take-command is a no-op in-chat; oversized moves to the batch |
| `/quality-check` | one commit per phase in `git log` | must group by phase prefix |
| `/finalize-workflow` | consolidation to one commit | unaffected |
| `/write-workflow`, `/scope-workflow` | `Mode:` fork, recon absent | triage, recon, the three axes |
| the `-agent` skills and `/run-workflow` | the relayed channel by construction | unchanged — this is the channel they exist for |
| `next-phase.py`, `run-workflow.sh` | parse `Mode:`; progress is "the plan gains exactly one `[x]`" | progress is phase-level, so batches leave it intact; the `Mode:` parse gains the axes |
| `scripts/wfdash/*` | `foreman.json`, inbox/outbox | renders an in-chat workflow with no relay |
| `tests/orchestration/` | prose invariants proven by mutation; launcher scenarios | every grepped clause moved here moves its guard with it |

Two consequences worth stating before the implementation inventory:

1. The edit is **wide and shallow on the readers, narrow and deep on two
   gates**. The gates (`close-phase`'s covering decision, `contracts.md`'s
   authored-check ownership) are where a mistake silently removes a control.
2. `refs/foreman.md` staying loadable-but-unloaded is what converts the channel
   axis into a real context saving. If the in-chat channel still had to ingest
   it, the axis would buy tokens back only at the messaging layer, which is
   not where the mass is.

### Compatibility plan

A protocol change has three kinds of consumer, and only the first is in this
repo's control.

**1. Plans already written.** An earlier draft of this section proposed mapping
`Mode: interactive` onto the in-chat channel. That was wrong, and wrong in a way
worth recording: **`Mode: interactive` is not the in-chat channel.** It means
today, and keeps meaning, a chat per phase with the foreman relay between them.
Mapping it silently would change the semantics of every workflow already
running.

The two fields are therefore orthogonal and stay so:

- **`Mode:`** keeps its job — the execution mode, `interactive` or
  `autonomous`. Nothing about its meaning changes.
- **`Channel:`** is the new optional field and the only one that decides where
  decisions travel: `in-chat` or `relayed`.
- **New plans always write `Channel:`.**
- **A plan with no `Channel:` keeps today's behaviour**, exactly, and is neither
  rewritten nor reinterpreted. Absence is legacy, not a default to be inferred:
  the legacy behaviour of each `Mode:` is what it already is, relay included.
- **`Mode: autonomous` with `Channel: in-chat` is invalid** and fails
  validation. There is no attended gate in an unattended run, so an in-chat
  channel there would name a conversation nobody is in.

Consequently a workflow in flight when the plugin updates continues under the
semantics it was created with — not because a mapping reproduces it, but because
nothing reads a field the plan does not carry. `/doctor` may report a plan as
pre-upgrade; it never repairs one in place, and no plan file is ever rewritten
by the upgrade.

The additive-and-optional rule has a limit that matters more than it looks:
**optional means "a known field that may be absent", never "any field is
tolerated".** `next-phase.py` accepts the new fields by name and keeps rejecting
everything else, so `Chanel: in-chat` fails validation instead of being ignored
in silence. A typo in a routing field that decides where decisions travel is
exactly the defect that must not pass.

**2. The Claude Code harness.** Every surface this design leans on is already in
`docs/claude-code-compat.md` and watched by `/check-claude-update`: headless
plugin-skill invocation, CLI flags and model aliases, agent frontmatter, auto
permission mode, the `SendMessage` floor for cross-session messaging. The
channel axis *reduces* exposure rather than adding to it — an in-chat workflow
needs no `SendMessage` at all, which makes the 2.1.224 floor conditional on the
relayed channel instead of global. That floor's row in the compat table should
say so once the change lands, and it is the only compat-table edit this design
requires.

**3. Anything outside this repository.** Out of scope here, and deliberately so:
other repositories are adapted and verified in their own environment, after this
contract is stable. What this design owes them is not an inventory but a
guarantee narrow enough to be checked from the outside, without reading a single
skill:

- the plan gains **two optional fields and no others**: `Channel:` in the header
  and `Batches:` per phase;
- **`Mode:` keeps its current meaning** — `interactive` or `autonomous`, the
  execution mode, relay included;
- **a plan with no `Channel:` behaves exactly as it does today**, unrewritten and
  uninterpreted;
- `Mode: autonomous` with `Channel: in-chat` is **invalid** and fails validation;
- an **unknown field still fails validation** — optional is by name, never by
  tolerance;
- the **phase commit keeps its shape**, `wf(phase N): <title>`;
- `partial` commits, already legal, **may become more frequent**.

Every one of the six is observable from a plan file and a `git log`, which is
what makes the guarantee worth stating rather than merely intending.

### What the implementation corrected in this section

Written after the change landed, and kept because each item corrects something
this section originally got wrong — the pattern being that a plausible reading of
a file is not a reading of it, which is the very defect #22 measured.

- **The covering-decision gate has three sites, not two.** `close-phase` gates
  the close, `contracts.md` owns the rule, and `/doctor` re-checks the same
  divergence at audit time — in the same words. A change that fixed the first two
  would have left the third quietly relay-bound.
- **`scope-workflow` already looked before it asked.** *Establish the ground*
  exists and states that a fact is looked up, never asked. What was missing was
  the checklist, not the ordering.
- **The channel is a field of its own, and `Mode:` is not it.** `Mode:
  interactive` means a chat per phase *with* the relay; mapping it onto the
  in-chat channel would have changed the semantics of every running workflow.
  Hence `Channel:`, optional, absent meaning legacy.
- **A batch is not a checkpoint.** Both end in a `partial` commit, which made
  "one mechanic, three triggers" look right; it is not. A checkpoint writes the
  `> WIP:` note because something is stopping, a batch writes none because
  nothing is — and a batch that wrote one would make a phase mid-work read as
  abandoned.
- **The doc-mass budget priced the change.** Three closures went over the
  1500-line ceiling and were paid, never raised. Most of it came from
  `close-phase` and `execute-phase` dropping their direct `refs/foreman.md`
  citations once the routing fork lived in one place: −453 closure lines each,
  which is the context saving this section predicted, arriving as a test failure
  rather than as a claim.
- **Three consumers needed nothing.** `run-workflow.sh` never parses `Mode:` and
  its `--validate` gate already rejects the invalid pairing; `board.md` keys on
  `Mode:`, which the channel does not change; `wfdash`'s `read_foreman` already
  returns `None` when there is no `foreman.json`, which is exactly the in-chat
  case.

### What it changes for macro-phases

*Macro-phases (rolling wave)* already carries the right criterion in its second
clause — a phase whose shape depends on an earlier phase's outcome. Decision-
boundary sizing is that same rule applied one level down, which makes the `~8–10
phases` trigger the weaker half: with phases sized on decisions, counts fall and
macro splitting should follow the outcome-dependency clause, not the count.

### The risk being accepted

This trades reviewability against context cost, and the batch mechanism is the
whole mitigation. That is the part to watch in the field: batch commits arriving
that cannot be read against the phase's `Done:` mean the cut criterion slipped
and the phase was too big.

The other direction has a cheaper instrument. #22 measured ~25 apparatus commits
(clarify, notes, receipts) against 10 phase commits. That ratio is a **diagnostic
signal, not a verdict**: it says *look at this run*, never *this run was wrong*.
A genuinely exploratory workflow, or one whose phases legitimately renegotiated
scope, can sit above 1:1 and be healthy; a run can also sit below it and be a
disaster. What makes it worth keeping is that it is mechanical — visible in
`git log` on the workflow branch — so it points attention without anyone having
to trust an impression of slowness. Read it against the two causes it usually
has (a channel nobody was consuming, or a plan written unseen) and confirm or
discard by reading the apparatus commits themselves.

## The final touch, and the loop it closes

*Written 2026-09-03, landed in 6.35.0.*

**The measurement.** The `3-accesso-ambulatorio-id` run on Demetra, issue #3 bug 1:
where does an `accesso` born from `appuntamento.completa()`, a walk-in or the group
branch get its `ambulatorio_id`. Foreman chat 2026-09-02 10:35 → 2026-09-03 12:30.

| Round | Phases | Diff (`packages/ tools/ tests/ docs/`) | Outcome |
|---|---|---|---|
| 1 — the plan | 1–3 | 7 files, +302 −7 | bug fixed, verified by hand |
| 2 — after quality check #1 | 4–9 | 39 files, +968 −426 | two `[!]`, two repairs |
| 3 — after quality check #2 | 10–13 | 19 files, +302 −150 | done by the foreman in its chat, minutes |

26 `wf:` commits, 13 phases, 145M cache-read tokens in the foreman alone. Round 2 is
three times the diff of the fix it was reviewing.

**The mechanism.** Two rules that are each right on their own compose into a loop.
Step 5 of `/quality-check` runs a recall-biased review — *err on the side of
surfacing* — which finds eight to ten things on any diff of a few hundred lines,
and then says *fixing is delegated; re-run `/quality-check`*. The 6.32.0 QA fix
could not absorb them: its boundary was the user's one sentence and *no new
callable*, and a review finding is neither. So each finding became a phase via
`/resume-workflow`, the phases produced a diff, the re-run review read it at the
same effort and found ten more. Nothing in the protocol made the second review
smaller than the first, so nothing made the sequence converge. It ended when the
user asked the foreman to do the fixes itself — which it did, four phases in
minutes, with the same contract tests as verification.

**The correction.** Three moves, in the order they bite.

1. *The boundary is decisions, not size.* A correction is a QA fix when no decision
   is open — the user's sentence or the plan's `Decisions:` already says what right
   looks like — whatever code it takes. Size was the wrong proxy: the second round's
   three new helpers and three FK rules were all decided; they were only large.
2. *The final touch.* Review findings are fixed by the foreman as one table and one
   commit, and the re-check after it is Light at `low` over the touched files. A
   second high-effort pass is the loop restarting, so it is forbidden by name.
   What still leaves the chat is a surface the plan never built, as ONE phase.
3. *One chat, or a workflow.* The fix itself was one session — its decisions were
   in the issue, its diff read in one sitting. The plan's quality (recon, `Pattern:`,
   `Done:`, contract tests) is the plan's, not the phase boundaries': a single session
   handed it as a prompt gets the same quality in a warm context, and none of the
   duplicated helpers that separate sessions produced. A workflow pays for exactly
   three reasons — the work does not fit one context, an intermediate result changes
   what comes next, it must run unattended — and `/issue` and `/write-workflow` now
   ask the question on them; when none holds the plan becomes a one-chat brief — a
   self-contained prompt with the decisions, the patterns, the method, the `Done:`
   and two stop rules — written to `~/.phased/prompts/<slug>.md`, not a workflow.
   `Channel: in-chat` sits between the two; this run took the most expensive tier,
   relayed and autonomous, for a job that belonged to the cheapest.

**What it owes the field.** One quality check that ends in a final touch and a
stamp, on a run where the review found things — and a `/issue` that sends a
one-session fix to one session.

## Known patterns

Plan-and-Execute (LangChain/LlamaIndex) · Checkpoint & Resume (CI/CD) ·
Shared state via artifact (blackboard architecture) · Context-window
management (short focused sessions) · Worktree isolation. The point of this
plugin is making explicit and user-controllable what agent products do
internally and opaquely.

## The test suite, and how to add to it

The count lives in `README.md`, where `check_readme_continuity.py` holds it to
what `run_tests.sh` actually contains. This file carried a hand-written
scenario-by-scenario catalog for a while and it rotted twenty scenarios behind
the suite — which is most of why that guard exists. The per-scenario detail is
now the comment block above each `echo "== SN: ..."` in
`tests/orchestration/run_tests.sh`: what the scenario is for, and which field
failure it came from. It sits on the code it describes, so it cannot drift.

Three kinds, and the difference matters when adding one:

- **Launcher-driven** — the shipped `run-workflow.sh` against a mock `claude`
  binary: call shape, model/effort/cap selection, repair resuming or stopping
  the loop, attribution of a red baseline, the no-progress guard. They build
  real git repos and run the real script, and they catch what reading cannot.
- **Prose invariants, proven by mutation** — a doctrine clause is grepped where
  it must live, then the SAME guard is re-run on a copy with the clause broken,
  which must fail. A guard nobody proved can pass vacuously; every mutation
  directory starts from the full pristine refs set for that reason.
- **Static checks on what ships** — allowlists, home paths, phase-state
  single-sourcing, doc mass, README continuity, the optional-surface rule. Each
  is its own file under `tests/orchestration/`, so the scenario re-runs the REAL
  check on a mutated copy instead of a reimplementation of it.

## Internal mirror (Softwell)

As of 5.0.0 the internal knowledge-base topic no longer mirrors the skills: it
holds the install guide plus internal-only commands (`ui-test`,
`push-context-memory`). One distribution road — this repo, via the plugin
marketplace; the old sync tooling (`tools/kb-sync.py`, test S16) is retired.
