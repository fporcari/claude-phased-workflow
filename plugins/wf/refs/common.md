# Shared conventions — phased-workflow skills

Single source of truth for the blocks that used to be repeated in every
phased-workflow command (`/write-workflow`, `/import-workflow`,
`/execute-phase`, `/execute-phase-agent`, `/run-workflow`, `/finalize-workflow`,
`/resume-workflow`, `/push-context-memory`). Skills point here instead
of restating them.

## Language

All written content (plans, phase notes, code, comments, commits, PRs,
issues) in English: the artifacts outlive the chat that produced them, and
what reads them next is usually another session.

**The conversation is in the user's language, never in one this plugin
picks.** Follow their own configuration — global instructions, output style,
or simply the language they are writing in. Every wording quoted below and in
the skills (gate lines, question options, closing messages, board labels) is
the English **canon of what to say**, not the language to say it in.

## AskUserQuestion style

Use `AskUserQuestion` for every question to the user. When a sensible
default exists, put the recommended option FIRST and append
"(Recommended)" to its label (the tool has no default-answer parameter).
For multiple-choice lists, one option per line, checkbox style.

## The gate line

A skill that stops to wait for the user must say so — an implicit wait
reads as hesitation, and only someone who knows the flow by heart guesses
that a reply is expected. Every presentation that ends in a wait closes
with ONE line, plain text, **never inside a code fence** (fenced text
reads as log output, not as a question addressed to the user):

> **Proceed?** On your ok, \<exactly what happens next\>.

The verb can change (*Confirm?* / *Launch?*), the shape cannot: a bold
one-word question, then what the ok unlocks. Multi-way choices go through
`AskUserQuestion` instead (style above); the gate line is for the binary
"go" that unblocks the skill.

## Plan directory

Every workflow keeps its plan and its working notes in `.phased/`, at the
git repository root:

```
.phased/
  roadmap.md              # megaplans only — spans macro-phases
  active/<slug>/          # exactly one at a time
    plan.md               # the work plan
    notes.md              # free-form annotations + per-phase rationale
                          #   (## Phase N headings — see "The foreman")
    foreman.json          # which chat commands this workflow (see "The foreman")
    verify.md             # human checks a phase deferred to a wider context
                          #   (see "Verification: Done: and Verify:" below)
    mockups/phase-N.html  # ui-tagged phases — the approved visual contract
                          #   (see "Verification" below; written by /execute-phase)
    tests/phase-N/        # contract tests authored at plan time — the
                          #   executable contract (see "Contract tests" below)
    log/phase-N.txt       # stdout of each /run-workflow sub-session, committed
  done/<slug>/            # moved here by /finalize-workflow
```

The active plan is `<git root>/.phased/active/*/plan.md`, resolved by:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve
```

`active/` holds exactly ONE plan directory — one branch, one plan, no
discovery. No match means there is no workflow in this repository: run
`/write-workflow`, or `/import-workflow` on an older plan. Several matches
are an anomaly to report to the user, never to guess at.

`.phased/` is committed on the workflow branch and never reaches the parent:
`/finalize-workflow` drops it from the squashed commit.

## Plan location — operating from anywhere

`--resolve` answers for the repository you are standing in. When it fails, or
the user means a different workflow, list every reachable plan instead:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --plans
```

One pipe-separated line per plan: location (a filesystem path, or
`branch:path` for a `wf/*` branch with no checkout), branch, checkout path
(`-` when none), phase counts, state. Several plans → ask the user which one,
never guess.

Once a plan outside the current root is chosen, anchor every command to ITS
root: `git -C <plan root>` for every git invocation, and every path (the plan
file, `log/`, `.phased/`) resolved against that root, never against the cwd.
A plan whose branch has no checkout cannot be operated on directly — attach
or create its worktree first (`/run-workflow` does this itself; other skills
say so and stop).

## Workflow branch

Every plan gets a branch, so that everything belonging to the run is
identifiable without heuristics.

- `/write-workflow` either creates `wf/<slug>` or adopts the branch you are
  already on (its own rules decide); either way `Parent:` in the plan records
  where the work goes back to.
- The plan is committed first, as `wf: plan for <slug>`.
- Each completed phase is ONE commit, `wf(phase N): <title>`, including the
  plan's own status update. A phase closing `[!]` commits too, as
  `wf(phase N): FAILED — <title>`: repair needs to see the failing code, and
  it needs to start from a clean tree.

**The base of the workflow is the commit that added the plan**, not the
branch point:

```bash
git log -1 --diff-filter=A --format=%H -- .phased/active/<slug>/plan.md
```

On a dedicated `wf/` branch the two coincide. On an adopted branch that
already carried commits, only this marker separates the workflow from the
work that preceded it, and `/finalize-workflow` consolidates from here.

**The plan is a tracked file**, so any skill that edits it dirties the tree.
Edits made outside a phase — a `/resume-workflow` re-phasing, a
`/repair-phase` note, hand annotations in `notes.md` — get their own
`wf: <what changed>` commit. Otherwise the "clean tree at phase start"
invariant that `/execute-phase-agent` relies on is false.

## Phase selection

The next eligible phase is computed deterministically by:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
```

Called with no argument it resolves the active plan itself; pass a path to
point it at a specific one.

It prints a status table for all phases plus one `recommendation:` line
(`next: N` / `resume-candidate: N` / `attention: ...` / `done` /
`blocked: ...`). The semantics it implements — also the manual fallback if
the script is unavailable — are:

- `[x]` done → skip; `[!]` issue / `[~]` blocked → skip (the user must
  resolve them); like any non-completed phase, they block what follows.
- Phases run strictly in order: a `[ ]` phase is blocked while ANY
  preceding phase is not `[x]`.
- `[>]` phases are resume candidates only when nothing else is eligible;
  the script reports their age and whether a `> WIP:` note exists — what
  to do with that is the calling skill's decision.

## Verification: `Done:` and `Verify:`

Two fields, two audiences. **This section is the single source of the
contract** — the skills cite it, they never restate it.

- **`Done:`** — the machine's exit condition: tests, lint, build, a named
  output. Re-runnable verbatim by whoever reads the plan next. It stays
  machine-checkable in both modes; `/execute-phase-agent` re-runs it before
  closing a phase.
- **`Verify:`** — steps a *person* performs, each with the result they should
  see. Never a substitute for a weak `Done:`: a phase whose tests could have
  covered it does not get to push the work onto the human.

**Every `Verify:` step carries a *when*:**

- `now` — check it at the end of this phase; it makes sense on its own.
- `deferred: needs Phase M` — it only makes sense in a wider context, so it is
  **dated, not skipped**.

A `now` step also **gates the close in interactive mode**: the phase commits
its work and stays `[>]` until the human has run those checks — the mechanic
is in `refs/phase-execution.md` → *Awaiting the human's checks*. Autonomous
mode has nobody to wait for and closes as before.

```
  > Verify: now — open /foo, save a row, it reappears in the grid after reload
  > Verify: deferred: needs Phase 5 — the invoice total matches the order once
    the pricing phase lands
```

**One contract, two origins.** A `Verify:` step is either **authored in the
plan** (a field on the phase, written by `/write-workflow`) or **surfaced at
execution**. The executing skill carries the authored ones into its
end-of-phase `> Verify:` notes exactly like its own — deferred ones into
`verify.md` — so the QA pass reads ONE list and an authored check can never
fall between the two syntaxes.

**Split by who can check it.** What an agent can assert never reaches the human
list: the flow works, the record persists, the grid reloads — that is what a
browser-driving skill (`ui-test` where installed; it ships separately, not with
this plugin) exercises. **No such skill available → declare it, and hand
exactly those checks to the human as `Verify: now` steps** — a named fallback,
never a silent skip. The human list otherwise carries only what needs human
judgment: aesthetics, "is this interaction right?", UX ambiguity.
Without this split the list fills with automatable work and stops being read.

**Browser verification and logins.** Before driving any browser check,
establish whether the target is login-gated — always, as the first step. When
it is, the login is performed by the **human operator** in the visible browser
window, every time: the executing agent never types, logs, or persists
credentials, whatever impersonation convention the project offers (those
conventions belong to the browser-driving skill, never to this plugin). One
login per session usually suffices — the cookie persists across iterations.

**The mockup is the visual contract** of a `ui`-tagged phase: approved at the
phase's gate, saved as `mockups/phase-N.html` in the plan directory, committed
with the phase. The browser pass screenshots the real page next to it, and a
fresh-context judge (the `ui-judge` agent) compares the two — because the
author of a UI is the worst judge of its own fidelity. What the judge flags as
a human call lands in `> Review:`; what remains for human eyes (taste beyond
the mockup) stays on the `Verify:` list.

**Deferred steps accumulate in `verify.md`** in the plan directory, appended per
phase, and `/finalize-workflow` presents the file as one QA pass at the end
instead of scattering checks the user cannot yet perform.

**The QA pass is delivered as a QA page** where the session can render a file
to the user (SendUserFile on the desktop): a manual test plan written outside
the repo (`${TMPDIR:-/tmp}/phased-workflow/<slug>-qa.html` — a file in the
tree would dirty it), one checkbox per check, grouped by phase, each item
naming the action to exercise and the result the user should see — the
reporting register applies. A deferred step whose phase has since landed is
marked as now due. The checkboxes are the user's own tracking while they work
through the list — purely client-side, nothing reports back to the session:
the presenting skill still asks its one question about the outcome afterwards.
It is a work sheet, not a closing report, so the report-judge gate does not
apply to it. Without a way to render the page (CLI, headless), degrade
declared: the same list in chat, grouped by phase.

The mechanism is **thick in interactive mode and thin in autonomous, never
absent**: an autonomous project startup still wants human eyes on the result.

**Authored checks are foreman-owned.** After the plan commit, the contract
fields — `Done:`, the authored `Verify:` steps, the contract tests where the
plan carries them — belong to the plan's author, never to the phase executing
them. On a `ui` phase the authored `Verify:` list is written COMPLETE at
planning time: the checks the human will run at that phase are pre-established
in the plan, not improvised at the gate — the mockup loop refines the look,
never the checklist. The executing chat may ADD surfaced steps — an addition
strengthens the contract — but never drops or rewords an authored one on its
own: a check that no longer fits is a plan ambiguity, routed through the
foreman (`clarify?`), whose reply carries the edit. The sanctioned protocols
that already reshape the contract — closed short, a rejected result — keep
working as written: both report to the foreman by construction.

`verify.md` and `review.md` are siblings, not duplicates: `review.md` says
*"here is what I noticed and will not decide for you"* — the user reads and
judges; `verify.md` says *"here is what you must exercise"* — the user does.

## Contract tests — the executable contract

An option `/write-workflow` puts to the user: the tests of EVERY phase are
authored at planning time, while the whole design sits in one context, and
committed with the plan under `.phased/active/<slug>/tests/phase-N/`. Each
such phase's `Done:` opens with them. **This section is the single source of
the contract** — the skills cite it, they never restate it.

What the tests buy is bindingness: a later phase's premise stops being prose
an executor may skim and becomes a red test the phase cannot close over.
Recommended where the work is refactoring or otherwise well-specified —
behaviour that must survive is exactly what a test states best; on
exploratory work prefer skeletons (below) over guessed signatures.

**Each test is authored at one of two precisions**, chosen per test by how
settled the surface is:

- **Executable** — the design already fixes the signatures (a refactor: they
  exist today). Real, runnable test code. Read-only for the child in its
  entirety.
- **Skeleton** — the behaviour is decided, the bindings are not. A named test
  whose contract is stated in comment lines carrying the `wf:contract:`
  marker, with a red body (`pytest.fail("phase N pending")` or the repo
  equivalent):

  ```python
  def test_invoice_total_survives_rename():
      # wf:contract: renaming legacyAmount -> amount keeps invoice.total()
      # wf:contract: equal to the sum of its lines after reload
      pytest.fail("phase 3 pending")
  ```

  The child replaces the red body with a real implementation of exactly what
  the `wf:contract:` lines state; the test name and those lines are
  read-only. Red by construction either way: no phase closes over an
  unimplemented contract, and no signature gets guessed at planning.

The rules, in both execution modes:

- **The phase copies its own tests verbatim** from `tests/phase-N/` into the
  repo's test tree at phase start, and implements until they are green. The
  copy — and a skeleton's body — is the phase's work; the contract is not.
- **The contract is read-only for the child.** A test that cannot pass as
  written — a wrong premise, an assertion the design outgrew — is a plan
  ambiguity, never a local fix: interactive phases route it as `clarify?`
  (*The foreman*), and the foreman's reply carries the exact test edit as
  before-text → after-text, applied verbatim by the child and committed as
  `wf: clarify phase N — <one line>`. Unattended phases have nobody to ask:
  the phase closes `[!]` with `> Issue:` naming the test — a contract that
  cannot be met unchanged is a plan defect, not a licence to edit it.
- **The close verifies the copy.** `/close-phase`'s Done gate (and the
  phase-verifier, where it runs) checks the in-tree copy against the plan
  copy: executable tests byte-identical; skeletons with their test names and
  every `wf:contract:` line surviving verbatim and no red body left. Any
  divergence must be covered by a foreman decision recorded in `notes.md`
  under the phase's `## Phase N` — a silent one blocks the close.

A plan without the option keeps today's behaviour: tests are written by each
phase, and the cross-phase direction is prose
(`refs/phase-execution.md` → *The plan is context*).

## Must not break: — contracts owned by the future

A plan header field, one line per constraint, recording what this workflow
must leave intact — including, on a programme split into macro-phases, what
a LATER macro-phase will require of the work built here. **This section is
the single source of the contract** — the skills cite it, they never
restate it.

The field exists because hindsight flows forward and constraints do not:
each macro is planned by its own `/write-workflow` after the previous one
landed, and nothing else carries a future consumer's requirements backwards.
The failure it answers is documented (issue #15): a data shape chosen
correctly for one macro's own scope could not carry what a macro planned
much later measured it needs — nothing destroyed, but the cost landed on
the wrong side of the programme.

- **Written by `/write-workflow` — the consumer question.** When
  `.phased/roadmap.md` has unstarted macro-phases (or the discussion names
  later work that will consume this plan's output), planning asks: *who
  consumes what this workflow builds, and what will they require of it?*
  The answer lands here; genuinely unknown is written as `Must not break:
  unknown — consumers not yet measured`, because an EMPTY field on a macro
  whose output another one consumes is itself a finding.
- **Backed by skeletons where it can be.** A future consumer's requirement
  is "behaviour decided, bindings unknown" by definition — the exact case
  `wf:contract:` skeletons exist for (*Contract tests* above). A constraint
  statable as behaviour is written as a skeleton in the plan's `tests/`,
  owned by the future macro but red against this one's work.
- **A contract lives from producer to consumer, across everything between.**
  The dependency structure of a programme is a graph, not a chain: Macro 5
  may require what Macro 2 builds, with other macros in between. The
  constraint therefore binds more than its producer — every macro between
  the one that builds the thing and the one that consumes it inherits the
  line into its own `Must not break:`, because what is **in transit** must
  not be lost by a leg it merely crosses. The tour version: you saw the
  Uffizi on the Italy leg in order to compare them with the Prado on the
  Spain leg — no leg in between may lose that luggage.
- **Read at execution.** `/execute-phase`'s compatibility line and the
  shared core's plan-is-context skim treat these lines — and, where a
  roadmap exists, its remaining macro-phases — as premises of the same rank
  as a pending phase's: a choice that breaks one goes up as `clarify?`
  before any approval.
- **Checked at the close of the macro.** `/finalize-workflow`'s roadmap
  check compares what was built against this field and the roadmap's
  remaining macro-phases, and reports every shape a later macro would have
  to undo — the last cheap moment to act, since the next macro is planned
  against this commit.
- **Audited by `/doctor`, retroactively too.** A consumer measured late can
  be handed to the doctor as contract skeletons against the component that
  must serve it: the reds enumerate exactly which requirements the landed
  shape cannot carry.

## New-method markers and minimality

Two disciplines on every method or function a phase CREATES. They hold in
both execution modes; **this section is the single source of the contract**
(the review procedure lives in `refs/naming-review.md` — skills cite these
two, they never restate them).

**Minimality.** A phase introduces only the callables its objective and
`Done:` criterion require. A helper "for later", a speculative abstraction,
a second code path nothing exercises — that is scope the plan did not buy,
and the phase verifier reports it. When in doubt, inline the code: a future
phase can extract the helper the day two callers exist.

**The marker.** Every new method or function carries, on its definition
line, an end-of-line comment in the file's own comment token:

```python
def calc_totals(self):  # wf:phase-3:new
```

The name is a *proposal*: agent-chosen names are the part of a diff users
most often want to reword, so each one stays findable until a human has
ruled on it. Names that ARE framework API (dispatch by prefix or suffix, a
hook the framework matches literally) carry the marker too — they appear in
the review as fixed names, where only the free part, if any, can change.

The marker is scaffolding, like the `wf(phase N)` commits — it never
reaches the parent branch:

- **interactive runs** — `/close-phase` runs the naming review at the end
  of each phase; accepted or renamed, the markers die with the phase commit.
- **autonomous runs** — nobody can answer a naming question mid-run, so
  markers accumulate in the phase commits and `/finalize-workflow` runs ONE
  naming review for the whole workflow before consolidating.

The sweep is blocking either way: before a phase commit closes the review,
and again before the workflow consolidates, a grep for `wf:phase-` over the
touched files must come back empty.

## Failure and repair notes

**`[!]` is a machine verdict, never a human one.** A phase is `[!]` when its
`Done:` came back red and the bounded attempts are exhausted — that is what
`/repair-phase` reads, and its whole job is to make a `Done:` green again.

What the marker asserts is that **something is demonstrably broken**: a red
signal, or a defect that reproduces. A person is often the one who *saw* it,
and mid-phase it is `/repair-phase` that writes it down and marks the phase
`[!]` with their confirmation, for as long as the repair lasts — that is not a
human verdict, it is a human pointing at a machine-checkable fact. The verdict
a person cannot make is the other one, below: a phase whose result they judge
wrong with everything green.
**A person judging the result wrong is a different thing**, including when
they say the phase is broken: if the `Done:` passed, the machine has nothing
to repair. Marking it `[!]` sends the next session — or an unattended run,
which repairs without asking — at code whose tests are already green, to fix
a disagreement no test states.

So a rejected result never moves the marker. Its `Done:` passed, so the phase
is `[x]` — closed, and closed carrying a problem: the verdict stays on it as
`> Review:`, rejected options included, so nobody proposes them again. A phase
that already carries `> Issue:` / `> Attempted:` keeps them: they are the
record of what its own tests went through, not a claim about the design.

What changes is the **decomposition**, and not only by addition: the phases
that have not run yet were written for the design just rejected, so
`/resume-workflow` re-plans them — rewriting what no longer fits, adding what
is missing — from the person's own account of what went wrong. It owns that
edit and its commit.

`phase N closed short` is the same family: a phase that outgrew its chat
(`refs/phase-execution.md` → *When the phase outgrows its chat*) closes on
the sub-result it reached, and the remainder needs a phase the child does not
write — sizing is the foreman's job, and a phase that overran is evidence
about the sizing.

**The foreman is told, in one line** — `phase N closed, result rejected`,
above. It is the one report that is not routine: the plan it authored is
about to change, and it holds the reasons the plan was shaped that way. It
answers as it answers any message, with the delta (`refs/board.md` → *When it
is drawn*): a rejection is the moment a board is most tempting and least
useful — the shape is about to change, so drawing the old one costs tokens to
show a position nobody will act on. The re-planning itself is a conversation,
and it happens where the person is. A rejection is also a ledger moment
(*Skill lessons — the wf-lessons ledger*): the design conversation let a bad
idea through, and where it did is a lesson about the skill, not only about
this plan.

Note fields the autonomous chain writes on phases, and what consumes them:

- `> Issue:` — root symptom and current diagnosis; written by `/execute-phase-agent`
  when a phase exits `[!]`.
- `> Attempted:` — numbered list of fixes tried, each with its error
  signature. Mandatory on `[!]`: it is the input of `/repair-phase`, which
  must NOT repeat those attempts.
- `> Repair started: <ISO timestamp> — chat <title>` — written by
  `/repair-phase` the moment it takes the phase under repair, committed with
  that transition, and removed by the edit that records the outcome. It is
  what separates a phase somebody is repairing right now from one left
  broken: `[!]` alone does not say, so a foreman reading the plan cold would
  send a second repair into the same working tree. A marker whose chat is
  gone is stale, and a stale one means the repair can be taken up again.
- `> Repaired:` — on a phase turned `[x]` by `/repair-phase`: the actual
  root cause and why the previous attempts missed it.
- `> Repair attempted: <ISO timestamp> — <diagnosis>` — appended by
  `/repair-phase` when the repair fails. It is the idempotent marker:
  `/run-workflow` launches at most ONE repair per phase and stops for
  human review when this note exists. Deleting the note grants another
  repair round after manual intervention.
- `> Review:` — judgment-level findings from the per-phase independent
  verification, flagged for the human at finalize; they never block `[x]`.
- `> Verify:` — one manual check left to the human, carrying its *when*
  (`now` / `deferred: needs Phase M`); written by the executing skill —
  thick in `/execute-phase`, thin in `/execute-phase-agent` — deferred
  ones copied into `verify.md`, all of them collected by
  `/finalize-workflow`. Semantics in *Verification* above.
- `> Verified:` — optional record of the verification evidence a phase ran
  (which test, which check, what confirmed the `Done:`).

`/repair-phase` always targets the FIRST `[!]` phase in the plan.

## The foreman — chat hierarchy and messaging

One chat commands each workflow (the **foreman**); the chats
that execute phases are its children and report to it. **This section is the
single source of the protocol** — the skills cite it, they never restate it.

**The foreman commands; it does not execute.** Its context has to hold the whole
plan — that is what lets it answer for any phase — so no skill ever recommends
running `/execute-phase` in the foreman chat: a *Next step* naming that skill is
always worded as a fresh chat. Launching an unattended run (`/run-workflow`) from
the foreman is the exception and the intended one: it supervises there, it does
not implement. Nothing is enforced — a user who executes a phase in the foreman
chat lands in the degenerate branches below (*when this chat IS the foreman*),
which keep working. Those are a fallback, never advice.

**And the mirror: a phase chat executes; it does not supervise.** No skill
ever recommends `/resume-workflow` — or any re-planning of the whole plan —
inside a chat that is executing a phase: a *Next step* naming it is always
worded as the foreman chat, or a fresh one if the foreman is gone. The hazard
is concrete, not stylistic: `/resume-workflow` takes command when no session
bears the title, so a phase chat running it writes `foreman.json` in its own
name and becomes a foreman that is also executing — the very thing the
paragraph above forbids, reached from the other side. A child that believes
the foreman is dead is usually a child that looked on the wrong channel
(*Sending to the foreman*, below): check that before concluding anything.
What a phase chat may always do is edit the plan for its OWN phase, which
mid-phase it is the only writer of.

**The foreman's identity lives in a file, and its address is its TITLE.**
A session cannot read its own id, but every *other* session sees both title
and id in `list_sessions` — so the title is the one address that works. It is
also one a session can set for itself: `set_session_title` takes the literal
`"self"` (field-tested on 2.1.234 — the 5.10.1 note saying the tool refuses
the current session is superseded), and it returns the title it replaced. The
chat titles itself; the protocol has no manual step left.

`.phased/active/<slug>/foreman.json`:

```json
{
  "foreman": "wf:<slug>:foreman",
  "since": "<ISO timestamp>",
  "history": [
    {"foreman": "<previous title>", "deposed": "<ISO timestamp>"}
  ]
}
```

**Taking command** — run by `/write-workflow` and `/import-workflow` at plan
creation, and by `/resume-workflow` when no other session claims the title
(a missing `foreman.json` is the normal state of any pre-protocol workflow —
absence is migration, not an error):

1. Write `foreman.json` — `foreman` is the title above, `since` now. A
   foreman replaced by deposition moves into `history` with its deposition
   timestamp. **Idempotent by content**: if the file already carries exactly
   this title and no other session claims it, leave it untouched — no commit,
   no history entry; re-claiming a title you already hold is not an event.
2. Commit it (`wf: foreman — takes command`), or fold it into the commit the
   skill is already making (plan, import). Tracked like the plan: left
   uncommitted it breaks the clean-tree invariant.
3. Title this chat `wf:<slug>:foreman` — `set_session_title` with
   `session_id: "self"`. Best-effort like the rest of this channel: where
   the tool is absent (CLI sessions, unattended runs) ask the user instead,
   one line — *"Rename this chat to `wf:<slug>:foreman` — it is the
   address phase chats report to."* Until the chat bears the title,
   notifications skip silently; nothing breaks.
4. In the same breath, one more line: *"Allow this chat to send
   cross-session messages and commit under `.phased/` without asking —
   answering a phase chat's `clarify?` happens while you are in the other
   chat, and a permission prompt here has nobody in front of it."*
   Field-tested: on default permissions the foreman DECIDES and then dies on
   the prompt — the child times out into its fallback and the human ends up
   attending two chats, the exact thing the protocol exists to avoid. Advice,
   like the rename: nothing breaks if ignored, the fallback absorbs it.

**Children title themselves too**, `wf:<slug>:phase-N — <phase title>`, by
the same call at the start of the phase. Nothing addresses them — only the
foreman's title is an address — so this is legibility, not protocol: the
session list stops being a wall of auto-generated summaries, one prefix
groups the workflow, and each chat says which phase it is holding.

A repair chat titles itself too, `wf:<slug>:repair-N — <phase title>`, and the
`repair-` prefix is not cosmetic: `/repair-phase` sends its outcome to
`wf:<slug>:phase-N` by exact match when it hands a phase back, so a repair
wearing that title would address itself. Unattended repairs skip the title —
a `claude -p` session has neither the tools nor a reader for it.

**Sending to the foreman** (children, at phase end and on plan changes):
read `foreman.json`, `list_sessions`, exact title match → `send_message` to
that session id. In the CLI the same by name — `ListAgents` + `SendMessage`
(≥ 2.1.224). **`list_sessions` first, always** — and *first* means before any
conclusion about who is reachable. **A tool missing from your tool list is not
a missing tool.** `list_sessions` and `send_message` are deferred behind
`ToolSearch` while `ListAgents` is always loaded, so the branch that works is
the one you have to go and fetch and the branch that fails is already there.
Absence is proved by a `ToolSearch` that comes back with nothing, never by a
tool list that does not mention it, and never by a channel that ran and
returned no match — an empty `ListAgents` says nothing about a desktop
session. A chat carrying both toolsets (Claude Code inside the desktop app)
is neither world, and this is the whole reason the rule is written as an
order. Field-tested
on 2.1.226: a `claude -p` sub-session carries both tools but its
`ListAgents` sees NO desktop sessions — CLI and desktop are separate worlds,
so unattended children still end at the silent skip and the foreman
messaging is desktop-chat-to-desktop-chat. One plain-text message,
header line first:

```
[wf:<slug>] phase N done — <title>. Commit <short hash>. Verify: <n now, m deferred>.
[wf:<slug>] phase N closed, result rejected — <what the person judged wrong, one line>. The pending phases need re-planning.
[wf:<slug>] phase N closed short — <what landed>. Remaining: <one line>; it needs a phase of its own.
[wf:<slug>] phase N FAILED — <title>. Issue: <one line>.
[wf:<slug>] phase N blocked — <one line>.
[wf:<slug>] plan changed at phase N — <one-line summary of the approved deviation>.
[wf:<slug>] workflow finalized — <consolidation outcome, one line>.
[wf:<slug>] stop-work? — <what looks wrong, one line; the run keeps burning until answered>.
[wf:<slug>] clarify? phase N — <the plan ambiguity, one line; the phase waits until answered>.
```

The `<one line>` slots — the Issue, the blocked reason, the stop-work
reason — are written in the reporting register (below): the consequence
first, no bare identifiers.

**Two of the messages are questions, not reports** — `stop-work?` and
`clarify?`. They ride the same upward channel and carry OPPOSITE decision
policies, and the human sits at opposite ends: at the foreman for
`stop-work?` (its children are `claude -p`, with nobody in front of them),
at the child for `clarify?` (an interactive phase, with its user watching).
Unlike the reports, a question expects a reply on the message's own reply
path — the silent-skip rule below still governs *sending* it, never
answering the human in its place.

**Stop-work.** `/run-workflow`'s inspector sends `stop-work?` when continuing
looks like wasted tokens. A foreman receiving it does not judge on its own —
it puts ONE AskUserQuestion to its user immediately (*Stop workflow* /
*Go on*, with the inspector's reason) and replies with the decision on
the message's own reply path: `stop-work: granted` or `stop-work: denied —
continue`. No reply reaching the inspector → the run's own stop conditions
govern, as if nothing was asked. After a granted stop the flow is human:
talk it through, correct the plan (`/resume-workflow` re-phasing or hand
edits), then a fresh `/run-workflow` restarts the work.

**Clarify.** `/execute-phase` sends `clarify?` when an interactive phase hits
an ambiguity in the PLAN — objective, `Done:`, `Files:`, `Pattern:` — before
asking its own user: the foreman authored the plan and holds the reasons it
is shaped that way, so it answers better than the human, who would have to
reconstruct them. The scope is strict: local technical choices and the
phase's own approval gates stay with the human in the child chat, or
interactive mode loses its point.

An ambiguity does not have to be recognized to be routed: **struggle is the
symptom of one nobody has named**. A phase failing twice against the same
obstacle, or a chat whose exchange with its user has turned from deciding
into diagnosing why the approach does not work, stops before the third
attempt and before the next diagnostic message — checkpoint, then `clarify?`
carrying the suspected presupposition (*assuming X — does it hold?*): tokens
spent debating a symptom in the child chat are the cost this routing exists
to avoid. The answer lands the phase on known ground — the presupposition
holds → what remains is a defect, and it leaves the chat
(`refs/phase-execution.md` → *Handing a defect to repair*); it was false →
the plan is wrong there, and the foreman's decision follows the ordinary
roads below, a plan edit in the reply or a re-planning of what has not run
(*Failure and repair notes*).

Where `stop-work?` forbids the foreman
from judging, here deciding is its FIRST attempt — and the decision takes
two roads, because the field test saw either one alone die (a permission
prompt killed one round, an unresolvable address the other; the disk was the
only channel that never failed):

1. **Disk**: the foreman records the decision in `notes.md`, under the
   phase's `## Phase N` heading, and commits it BEFORE replying — its own
   file, never contended with the child's working tree.
2. **Reply**: `clarify: <decision, one line>`. When the decision changes the
   plan, the reply also carries the exact plan edit, as before-text →
   after-text pairs — never a literal patch: the child's plan holds a `[>]`
   marker the foreman never saw. The foreman does NOT touch the plan: one
   writer per working tree, and mid-phase that writer is the child.
3. **The child applies on acceptance**: it shows the human the decision and,
   accepted, applies the foreman's edit verbatim — the hands, not the
   author — committing `.phased/` alone as `wf: clarify phase N — <one
   line>`. Nobody asks permission for that commit: the workflow branch is
   unpushed, the edit touches the plan directory only, and the human gate
   was the acceptance itself. A foreman in doubt
does not guess: it replies `clarify: ask-user — <the question, rephrased
better than the child put it>`, and the child asks the human. Either way
the human lives ONLY in the child chat — the foreman never addresses the
person: the child shows what the foreman decided and asks confirmation
before acting on it. A rejected decision travels back up with its reason
exactly ONCE (`clarify? phase N — user rejected: <reason>`); no convergence
→ the question is the human's, as it is without the protocol. The child
sends only when the foreman is ANOTHER session, and that check is free: the
title lookup runs on `list_sessions`, which excludes the current session, so
finding nothing there means this chat is the foreman or the foreman is dead —
both land on asking the human directly, today's behaviour. That channel alone
licenses the inference: an empty `ListAgents` is no evidence of an unreachable
foreman, and a false unreachable degrades in silence into attending the
human — the exact outcome this protocol exists to avoid. An unanswered
question cannot skip in silence like a report: no reply within ~3 minutes (the
foreman is an idle chat the message has to wake) → the child re-reads
`.phased/` — `notes.md` included — before falling back: a committed decision
found there IS the reply, presented to the human for confirmation with the
note that the message never arrived; only a silent disk hands the question
to the human as the foreman's failure to answer. A `clarify?` answered is
also a skill gap made visible — the plan carried an ambiguity nothing
surfaced earlier — so after the reply the foreman appends a ledger entry,
best-effort, per *Skill lessons — the wf-lessons ledger* below.

**Replying on the desktop**: the reply travels by `send_message`
(session-management) with the incoming message's `from` attribute as the
`session_id`. `SendMessage` does not resolve desktop sessions or their
titles (field-tested: id, title and `ListAgents` names all unreachable) —
its "copy the from as your to" advice belongs to the agent world, not here.

**Best-effort, always, in both directions.** No `foreman.json`, no way to
reach sessions (the desktop session-management tools are absent in unattended
runs; on a CLI < 2.1.224 there is no cross-session `SendMessage` either, and
where one exists the target may still be invisible to `ListAgents`), no
session bearing the title, delivery refused → skip in silence and move on. A notification never fails a phase, never asks
the user anything, and never becomes a retry loop. An undeliverable or
unanswered *question* is the one exception to the silence — it falls back as
its own paragraph states (for `clarify?`, to the disk re-read and then the
child's user; for `stop-work?`, to the run's own stop conditions) — and even
a question is never worth a retry loop. A foreman receiving one
re-reads `.phased/` before answering — the plan on disk, not the message
text, is the state — and answers with the DELTA, not the board: what
changed, what it blocks, what to launch next, in the register below. A board
is for a human asking where the work stands; a phase closing is one line
moving, and redrawing the whole position for it is a recomputation dressed
as an update, paid in tokens on every message (`refs/board.md` → *When it is
drawn*).

**Deposing a foreman** (`/resume-workflow`, when another session holds the
title and the user wants this chat in charge): best-effort farewell message
to the old session, retitle it to `wf:<slug>:deposed` (`set_session_title`
takes the other session's id, read from `list_sessions`), then take command
as above. The
old chat may be dead; nothing here is allowed to block on it.

**Per-phase rationale.** A phase that makes a non-obvious choice appends it
to `notes.md` under a `## Phase N` heading — why this way, what was rejected.
That is what `/finalize-workflow`'s lessons pass (its Step 6) reads: executor
chats are gone by then, and they carry no title to be reached at anyway —
the file is the only mechanism.

## Skill lessons — the wf-lessons ledger

A misunderstanding that reached the foreman is evidence about a SKILL, not
only about this plan: a `clarify?` answered means the plan carried an
ambiguity that `/write-workflow`'s questions did not surface and
`/execute-phase`'s gate did not catch; a rejected result says the same about
the design conversation; a repair whose root cause was a plan defect says it
about the planning again. The plan-level lesson goes to `notes.md` as
always. The plugin-level lesson would die with the chat, so it goes to a
ledger at a fixed path — outside every repository, and outside the installed
plugin, which an update overwrites:

```
~/.phased/wf-lessons.md
```

**The foreman writes it**, right after the event that exposed the gap. One
entry, appended — create the file and its directory on first use:

```
## <ISO date> — <slug> — skill: <the skill that failed>
Failure: <what happened, one line>
Why: <where the skill's own procedure let it through>
Patch proposal: <section/step> — before-text → after-text
```

**A proposal, never a patch.** Nothing here edits the plugin: a
self-diagnosed patch applied automatically is how instructions accumulate
contradictions. The ledger is consumed in the plugin's own repository — a
human reads the entries, keeps what deserves keeping, turns it into a real
skill edit with its own release, and deletes what was consumed.

Best-effort, like every foreman action: write denied, path unreachable →
skip in silence. A lesson never blocks a reply, a phase, or a run.

## The reporting register

Every report addressed to the person who decides — the foreman one-liners,
`/finalize-workflow`'s QA pass and findings presentation, the `stop-work?`
question, a run's closing summary — assumes the reader does NOT know the
implementation details. They were not in the session that wrote the code;
in an autonomous run, nobody was. **This section is the single source of
the register** — the skills cite it, they never restate it.

- **Name things by what they do for the user**, never by identifier alone:
  "the check that stops an empty invoice from being saved", not
  "`validate_invoice()` in `invoice.py`".
- **A defect is a consequence**: *if X happens, the user sees Y*. An
  internal state nobody would notice is not a finding a decision-maker can
  act on.
- **Identifiers may follow in parentheses**, as the record for whoever does
  the fixing — but the sentence must carry its meaning without them.
- **Labels are not explanations.** "Fallback", "shadow mode", "refactor"
  explain nothing to someone who has not read the code: state the mechanism
  in plain words instead.

The register applies at *presentation* time, when plan artifacts are turned
into prose for the human, in their language. The artifacts themselves (`> Issue:`,
`> Review:`, `> Verify:` notes, `notes.md`, the finalize agent's report)
stay technical English: repair sessions and reviews read them, and
periphrasis would cost them precision.

**A report has a shape, not only a vocabulary.** The short form IS the
report: one verdict line first — landed or not, and the single fact that
matters most — then one line per finding, and nothing else. Detail is never
volunteered: the artifacts hold it, the reader pulls it through the question
below. A wall of clear sentences is still a wall.

**Delivery depends on the channel.** The closing reports —
`/run-workflow`'s run-end summary, `/finalize-workflow`'s findings
presentation — are hypertext where the session can render a file to the
user (SendUserFile on the desktop): a **report page**, the verdict on top,
one line per finding, each finding a closed `<details>` expansion opening
on its detail drawn from the plan artifacts. The page is written outside
the repo (`${TMPDIR:-/tmp}/phased-workflow/<slug>-report.html` — a file in
the tree would dirty it), and the verdict line is repeated in chat beside
it. The reader pulls detail at their own pace; no detail question is
asked. The cap survives inside the expansions: each one answers a precise
question of the decision-maker — never the phase chronicle. Without a way
to render the page (CLI, headless), degrade declared: the short form in
chat, then exactly ONE question governs detail — a dedicated one (*Expand
all / Let me pick / That's enough*) when the report ends the exchange,
folded as an extra option into the decision question the skill already
asks when there is one, never two questions stacked. A user who is away
answers when they return; the question waits, no special case. The one-way
surfaces — the foreman one-liners, push notifications, the `stop-work?`
reason (itself already a question, about the work) — carry the
short form only: never a page, never the question.

**The report-judge gate.** Before a closing report is shown, it passes the
`report-judge` agent (Agent tool) — a comprehension probe, not a critique.
Fresh context by design: the agent gets the draft (for a report page, its
collapsed layer only — what is visible with every expansion closed) and a
one-line brief of what the workflow was about, not the code and not the
plan. It first retells in its own words what it understood happened, then
answers the decision-maker's three questions from the draft alone — did it
land, what do I decide now, what is still pending. Compare retelling and
answers with what the artifacts say: a misreading, a wrong or missing
answer, or an `OPAQUE:` sentence names exactly what the report buries —
rewrite and re-probe once, then show. Best-effort like every notification: no Agent
tool, or the judge errors → show the report anyway, saying the gate was
skipped. One-liners and pushes are not gated — they are one line by
construction.

## Notifications

How a skill surfaces state depends on whether the user is at the keyboard:

- **Local ping** — `osascript -e 'display notification …'` — when the user is
  present. `/execute-phase` runs one chat at a time with the user watching, so
  a desktop notification on each phase outcome is the right, cheap signal.
- **PushNotification** — when the user may be away. `/run-workflow` launches a
  background run they are meant to walk away from. Where the push lands is the
  user's own notification setup, never this chain's business. Reserve it for
  what is worth an interruption: the
  **first** failure of a run, any blocked phase, and the run ending — routine
  per-phase progress is not pushed. Each message leads with what the user would
  act on, one line under 200 characters, no markdown.

## Auto-mode permission scope

What `--permission-mode auto` is expected to deny, and the convention for
writing phases around it, live in
`${CLAUDE_PLUGIN_ROOT}/refs/auto-mode-scope.md` — read it only when deciding
whether a phase can run unattended (`/run-workflow` pre-flight,
`/write-workflow` on the autonomous branch).
