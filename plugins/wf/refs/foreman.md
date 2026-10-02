# The foreman layer — chat hierarchy, messaging, reporting

The supervision half of the shared conventions, split out so that only its
consumers pay for it: the skills that take command, depose, message upward or
report to the decision-maker read this file. **The chat hierarchy belongs to
the two relayed modes, `manual` and `autonomous`**: an assisted workflow is one
conversation with no relay (`refs/phase-execution.md` → *Routing a decision*),
and it reaches this file only for the reporting register and the wf-lessons
ledger. A headless
`-agent` session needs only the *Sending to the foreman* message formats, and
only when it reaches its notify step — read that section then, not at start.
Core conventions stay in `refs/common.md`; the contract layer in
`refs/contracts.md`.

## The foreman — chat hierarchy and messaging

One chat commands each manual or autonomous workflow (the **foreman**) — the
chat that wrote the plan, or launched `/run-workflow`; the chats that build a
manual workflow's phases, and the headless sessions that execute an autonomous
one's, are its children and report to it. **This section is the single source of the
protocol** — the skills cite it, they never restate it.

**The foreman commands; it does not execute.** Its context has to hold the whole
plan — that is what lets it answer for any phase — so no skill ever runs a
phase inside the foreman chat: on `manual` each phase is built in a chat of its
own, and while a run is in flight the launcher holds the plan's writer lock and
the phases are its sub-sessions' to build. Two
exceptions, both intended: launching `/run-workflow` from the foreman (it
supervises, it does not implement), and the **QA fix** with its **final touch**
once every phase is `[x]` — the corrections the user's check and the pre-commit
review turn up, applied and committed by the foreman itself when no decision is
open (`/quality-check` → *Step 5: One final touch*): the human is at the gate,
no phase is left to command, a phase's ceremony buys nothing and a phase per
finding is a loop. An assisted plan has no foreman at all: its one
conversation decides at the gate and launches an executor subagent for the
build — a different mode, not a breach of this rule.

**The foreman's own model is advice too, written down for the same reason the
`Run:` hint is**: a chat's model and effort are chosen when it opens, before any
skill has read the plan. Suggested `fable` / `high` — the foreman's output is
judgment and prose to humans (a consult answered, a QA question worded, a report
delivered), where `opus` reads flat and `sonnet` invents; `high` because the QA
fix and the final touch are code, and `xhigh` on pre-digested input is overthinking. Nothing enforces it.

**And the mirror: a phase session executes; it does not supervise.** No skill
ever recommends `/resume-workflow` — or any re-planning of the whole plan —
inside a session that is executing a phase: a *Next step* naming it is always
worded as the foreman chat, or a fresh one if the foreman is gone. The hazard
is concrete, not stylistic: `/resume-workflow` takes command when no session
bears the title, so an executing session running it writes `foreman.json` in
its own name and becomes a foreman that is also executing — the very thing the
paragraph above forbids, reached from the other side. A child that believes
the foreman is dead is usually a child that looked on the wrong channel
(*Sending to the foreman*, below): check that before concluding anything.
What an executing session may always do is edit the plan for its OWN phase,
which mid-phase it is the only writer of — never its contract fields, though
(`Done:`, authored `Verify:`, `Pattern:`, `Files:`, `Decisions:`): additions
ride `>` lines, a contract edit is a plan-defect claim the foreman judges, and
the close diffs the phase block against the plan commit to catch a silent
loss.

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
   address the workflow's other chats report to."* Until the chat bears the title,
   notifications skip silently; nothing breaks.
4. In the same breath, one more line: *"Allow this chat to send
   cross-session messages and commit under `.phased/` without asking —
   answering a phase chat's `clarify?`, or a run's `stop-work?` or
   `plan-defect?`, happens while you are in another chat, and a permission
   prompt here has nobody in front of it."*
   Field-tested: on default permissions the foreman DECIDES and then dies on
   the prompt — the run falls back to its own stop conditions and the human
   ends up attending two chats, the exact thing the protocol exists to avoid.
   Advice, like the rename: nothing breaks if ignored, the fallback absorbs it.

**The other chats of a workflow title themselves too.** An assisted
workflow's one conversation is `wf:<slug>`, once, when `/write-workflow` or
`/execute-phase` first runs there; a manual workflow's phase chat — the **worker**, one
chat cleared between phases — is `wf:<slug>:phase-N — <phase title>`, retitled at every phase, which is also how a resuming chat finds it
(`refs/phase-execution.md` → *Resuming a `[>]` phase*). Only a foreman's title
is an address, so this is legibility more than protocol: the session list stops
being a wall of auto-generated summaries and one prefix groups the workflows. Unattended sessions carry no title — a
`claude -p` session has neither the tools nor a reader for it.

**Channel floors — single source.** The messaging layer rides the most
unstable platform surface this plugin touches, so its version floors live
HERE and nowhere else (a skill cites this section, it never restates a
number): cross-session `SendMessage` in the CLI needs **≥ 2.1.224**; the
desktop session-management tools (`list_sessions`/`send_message`) have no
version floor but exist only in desktop chats; a `claude -p` sub-session
reaches neither world (field-tested, below); an assisted plan needs none
of it. The launcher's own floors
(`/goal` ≥ 2.1.139, `fable` ≥ 2.1.170) are detected at runtime by
`run-workflow.sh`, which declares its fallback in a NOTE. **Declare the
channel when reporting state**: a skill that reports where the workflow
stands (`/resume-workflow`'s report, `/run-workflow`'s first relay) says in
one line which branch is alive in this installation — desktop tools, CLI
`SendMessage`, or neither — so a dead channel reads as declared degradation,
never as a silent skip discovered later.

A third branch reaches this channel from outside a chat: the dashboard's
queued request (`board.md` → *The dashboard, where it exists*), which the
attached chat drains and delivers here — the page never writes a session.

**Sending to the foreman** (children, at phase end and on plan changes): read
`foreman.json`, `list_sessions`, exact title match → `send_message` to that
session id. In the CLI the same by name — `ListAgents` + `SendMessage` (*Channel
floors* above). **`list_sessions` first, always** — and *first* means before any
conclusion about who is reachable. **A tool missing from your tool list is not a
missing tool.** `list_sessions` and `send_message` are deferred behind
`ToolSearch` while `ListAgents` is always loaded, so the branch that works is
the one you have to go and fetch and the branch that fails is already there.
Absence is proved by a `ToolSearch` that comes back with nothing, never by a
tool list that does not mention it, and never by a channel that ran and returned
no match — an empty `ListAgents` says nothing about a desktop session. A chat
carrying both toolsets (Claude Code inside the desktop app) is neither world,
and this is the whole reason the rule is written as an order. Field-tested on
2.1.226: a `claude -p` sub-session carries both tools but its `ListAgents` sees
NO desktop sessions — CLI and desktop are separate worlds, so unattended
children still end at the silent skip and the foreman messaging is
desktop-chat-to-desktop-chat. One plain-text message, header line first:

```
[wf:<slug>] phase N done — <title>. Commit <short hash>. Verify: <n now, m deferred>.
[wf:<slug>] phase N closed, result rejected — <what the person judged wrong, one line>. The pending phases need re-planning.
[wf:<slug>] phase N closed short — <what landed>. Remaining: <one line>; it needs a phase of its own.
[wf:<slug>] phase N FAILED — <title>. Issue: <one line>.
[wf:<slug>] phase N blocked — <one line>.
[wf:<slug>] plan changed at phase N — <one-line summary of the approved deviation>.
[wf:<slug>] clarify? phase N — <the plan ambiguity, one line; the phase waits until answered>.
[wf:<slug>] clarify: noted phase N — <what the user decided, one line; no reply expected>.
[wf:<slug>] workflow finalized — <consolidation outcome, one line>.
[wf:<slug>] stop-work? — <what looks wrong, one line; the run keeps burning until answered>.
[wf:<slug>] plan-defect? phase N — <the child's claim, one line; the run holds until answered>.
```

The `<one line>` slots — the Issue, the blocked reason, the stop-work
reason — are written in the reporting register (below): the consequence
first, no bare identifiers.

**Three of the messages are questions, not reports** — `clarify?`,
`stop-work?` and `plan-defect?`. They ride the same upward channel and carry
DIFFERENT decision policies, and the human sits at opposite ends: at the child
for `clarify?` (a manual phase, with its user building it), at the foreman for
`stop-work?` and `plan-defect?` (their children are `claude -p`, with nobody in
front of them). Unlike the reports, a question expects a reply on the message's
own reply path — the silent-skip rule below still governs *sending* it, never
answering the human in its place.

**Clarify.** On `Mode: manual`, `/execute-phase` sends `clarify?` when its phase
hits an ambiguity in the PLAN — objective, `Done:`, `Files:`, `Pattern:`, a
contract test — at the gate or mid-phase, before asking its own user: the
foreman wrote the plan and holds the reasons it is shaped that way, so the user
is not made to reconstruct them. The scope is strict: local technical choices
and the phase's own approval stay with the human in the phase chat. An
ambiguity does not have to be recognized to be routed: **struggle is the
symptom of one nobody has named** — the stop-loss in `/execute-phase` sends the
premise its failed attempts leaned on, *assuming X — does it hold?*

**The answer's form follows where the answer comes from**, never how sure the
foreman feels:

1. **It is already written** — the plan, `notes.md`, a decision on record →
   `clarify: <answer> — <where: the plan line or notes.md § Phase M>`. The phase
   chat shows it to the user in one line and proceeds: nothing new was decided,
   so nothing is asked, and the user can still stop it there.
2. **It is a decision the foreman takes now** — a plan edit, a reading the plan
   does not state → the foreman records it in `notes.md` under the phase's
   `## Phase N` and commits it BEFORE replying — its own file, never contended
   with the child's working tree — then replies `clarify: proposed — <decision,
   one line>`, with any plan edit as before-text → after-text pairs, never a
   literal patch (the child's plan holds a `[>]` marker the foreman never saw).
   The child shows it to the user and asks; accepted, it applies the edit
   verbatim — the hands, not the author — committing `.phased/` alone as
   `wf: clarify phase N — <one line>`, no permission asked (the branch is
   unpushed, the edit is the plan's, the acceptance was the gate). The foreman
   does NOT touch the plan: mid-phase its one writer is the child. A rejection
   travels back up with its reason exactly ONCE (`clarify? phase N — user
   rejected: <reason>`); no convergence → the question is the user's.
3. **It is not there, and it is not the foreman's to decide** → `clarify:
   ask-user` at once, with what the foreman does know — no guess, no second
   round. The child asks the user, records the answer in `notes.md` under
   `## Phase N`, and sends `clarify: noted phase N — <the answer>`: a report,
   no reply expected. The foreman takes note of it, so that its next answer
   cites it instead of contradicting it.

The human lives ONLY in the phase chat: the foreman never addresses the person
about a `clarify?`. Delivery is never assumed — the channel has been seen
accepting a message and taking minutes to arrive — so the disk is the road that
never fails: a child re-reads `notes.md` before waiting, and a plan change sent
mid-phase closes with **confirm receipt before acting**, so a late batch cannot
execute a superseded instruction. The child sends only when the foreman is
ANOTHER session, and that check is free: the title lookup runs on
`list_sessions`, which excludes the current session, so finding nothing there
means this chat is the foreman or the foreman is dead — both land on asking the
human directly. That channel alone licenses the inference: an empty
`ListAgents` is no evidence of an unreachable foreman. An unanswered question
cannot skip in silence like a report: no reply within ~3 minutes (the foreman
is an idle chat the message has to wake) → the child re-reads `.phased/` before
falling back — a committed decision found there IS the reply, presented to the
human with the note that the message never arrived; only a silent disk hands
the question to the human. A `clarify?` answered by forms 2 or 3 is a skill gap
made visible — the plan carried an ambiguity nothing surfaced earlier — so the
foreman appends a ledger entry, best-effort, per *Skill lessons — the
wf-lessons ledger* below.

**Stop-work.** `/run-workflow`'s inspector sends `stop-work?` when continuing
looks like wasted tokens. A foreman receiving it does not judge on its own —
it puts ONE AskUserQuestion to its user immediately (*Stop workflow* /
*Go on*, with the inspector's reason) and replies with the decision on
the message's own reply path: `stop-work: granted` or `stop-work: denied —
continue`. No reply reaching the inspector → the run's own stop conditions
govern, as if nothing was asked. After a granted stop the flow is human:
talk it through, correct the plan (`/resume-workflow` re-phasing or hand
edits), then a fresh `/run-workflow` restarts the work.

**Plan-defect claims.** An unattended phase that believes the PLAN is at fault —
a contract test premise, a `Done:` built on a false assumption — closes `[!]`
with `> Issue: plan-defect claim — …` (`refs/contracts.md` → *Contract tests*),
and the launcher HOLDS the repair — no deadline unless
`RUN_WORKFLOW_CONSULT_TIMEOUT` is set — while `/run-workflow`'s inspector relays
the claim here as `plan-defect?`. The foreman takes neither the child's word nor
a repair's green for it — field count: two claims wrong, one right, the right
one "dissolved" by a repair bending the code to the test. While the launcher
holds, the foreman CHECKS the claim against the code it names, then puts ONE
AskUserQuestion to its user, claim, evidence and its own verdict attached:
**Apply the declared edit** (only when the claim carries its edit as before-text
→ after-text; recommended when the check confirmed it — a repair session is
spend disproportionate to a one-line fix, and never the door to rewriting the
contract), **Authorize repair** (recommended when the check did not — a
fresh-eyes session *testing* implementability beats an armchair verdict), or
**Stop the run** (when the claim matches an ambiguity the foreman knows it left
in the plan). The reply travels on the message's own reply path — `plan-defect:
repair`, `plan-defect: apply` or `plan-defect: stop` — and the inspector turns
it into the answer file the launcher waits on. No reply → the run keeps holding:
the decision is the human's whenever they arrive, a stop request during the hold
ends the run, and only an explicit timeout hands the claim to the repair
unadvised. **On apply the hands are the inspector's**: the launcher keeps
holding on a second file while the run's inspector — the one session attached to
the workspace — applies exactly the declared edit to BOTH contract copies (the
plan's `tests/phase-N/` and the in-tree copy, byte-identical), re-runs the
phase's `Done:`, and reports the outcome in `<slug>-apply-outcome`: on green it
has already flipped the phase `[x]` (`> Done:` re-stated as re-run, `> Applied:
plan-defect edit — <one line>`, the `> Issue:` kept for the record) and
committed `wf: plan defect phase N — applied — <one line>`; red — or the window
closing (`RUN_WORKFLOW_APPLY_TIMEOUT`, a hard deadline: reset what was touched,
write `red`, stand down) — hands the claim to the repair as usual. The hold is
the one sanctioned mid-run write: the tree is the applier's from the `apply`
answer to the outcome file, for the declared edit and nothing more — an apply
that grows into a rewrite is a stop wearing apply's clothes. **After a granted
stop the work is the foreman's**: the run is dead and the tree free, so it
clarifies with its user, edits the plan AND the contract tests itself
(before-text → after-text discipline, committed as `wf: plan defect phase N —
<one line>`), then decides whether the code the phase already committed needs
`/repair-phase` — launched by the foreman, not left implicit — and relaunches
`/run-workflow`. Every outcome is a ledger moment: a claim that was true — apply
included — means `/write-workflow` let the defect through; a false one means the
child's own gate cried wolf.

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
its own paragraph states (for `clarify?`, to the disk and then the phase
chat's user; for `stop-work?`, to the run's own stop conditions; for
`plan-defect?`, to holding the run until a human answers) — and even
a question is never worth a retry loop. A foreman receiving one
re-reads `.phased/` before answering — the plan on disk, not the message
text, is the state — and answers with the DELTA, not the board: what
changed, what it blocks, what to launch next, in the register below. A board is
for a human asking where the work stands; a phase closing is one line moving, and
redrawing the whole position for it is a recomputation dressed as an update, paid
in tokens on every message (`refs/board.md` → *When it is drawn*).

**Deposing a foreman** (`/resume-workflow`, when another session holds the
title and the user wants this chat in charge): best-effort farewell message to
the old session, retitle it to `wf:<slug>:deposed` (`set_session_title` takes
the other session's id, read from `list_sessions`), then take command as above.
The old chat may be dead; nothing here is allowed to block on it.

**Per-phase rationale.** A phase that makes a non-obvious choice appends it
to `notes.md` under a `## Phase N` heading — why this way, what was rejected.
That is what `/finalize-workflow`'s lessons pass reads: executor
chats are gone by then, and they carry no title to be reached at anyway —
the file is the only mechanism.

## Skill lessons — the wf-lessons ledger

A misunderstanding that reached the foreman is evidence about a SKILL, not
only about this plan: an executor that stopped `blocked` on a question, or a
plan-defect claim that proved true, means the plan carried an ambiguity that
`/write-workflow`'s questions did not surface and `/execute-phase`'s gate did
not catch; a rejected result says the same about
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
`/quality-check`'s QA pass and findings presentation, the `stop-work?`
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
`> Review:`, `> Verify:` notes, `notes.md`, the quality-check agent's report)
stay technical English: repair sessions and reviews read them, and
periphrasis would cost them precision.

**A report has a shape, not only a vocabulary.** The short form IS the
report: one verdict line first — landed or not, and the single fact that
matters most — then one line per finding, and nothing else. Detail is never
volunteered: the artifacts hold it, the reader pulls it through the question
below. A wall of clear sentences is still a wall.

**Delivery depends on the channel.** The closing reports — `/run-workflow`'s
run-end summary, `/quality-check`'s findings presentation — are hypertext where
the session can render a file to the user: a **report page**, the verdict on
top, one line per finding, each finding a closed `<details>` expansion opening
on its detail drawn from the plan artifacts. The page is written outside the
repo (`<transport>-report.html`, the prefix `next-phase.py --transport` names —
a file in the tree would dirty it) and handed over with `SendUserFile` and
`display: render`, which is load-bearing: left to choose, the client attaches a
page outside the project folder as a download card, which is what the field run
got. The verdict line is repeated in chat beside it; the reader pulls detail at
their own pace, and no detail question is asked. The cap survives inside the
expansions: each one answers a precise question of the decision-maker — never
the phase chronicle. Without a way to render the page (CLI, headless), degrade
declared: the short form in chat, then exactly ONE question governs detail — a
dedicated one (*Expand all / Let me pick / That's enough*) when the report ends
the exchange, folded as an extra option into the decision question the skill
already asks when there is one, never two questions stacked. A user who is away
answers when they return; the question waits, no special case. The one-way
surfaces — the foreman one-liners, push notifications, the `stop-work?` reason
(itself already a question, about the work) — carry the short form only: never a
page, never the question.

**The report-judge gate.** Before a closing report is shown, it passes the
`wf:report-judge` agent (Agent tool — namespaced, like every agent this plugin
ships) — a comprehension probe, not a critique. Fresh context by design: the
agent gets the draft (for a report page, its collapsed layer only — what is
visible with every expansion closed) and a one-line brief of what the workflow
was about, not the code and not the plan. It first retells in its own words what
it understood happened, then answers the decision-maker's three questions from
the draft alone — did it land, what do I decide now, what is still pending.
Compare retelling and answers with what the artifacts say: a misreading, a wrong
or missing answer, or an `OPAQUE:` sentence names exactly what the report buries
— rewrite and re-probe once, then show. Best-effort like every notification: no
Agent tool, or the judge errors → show the report anyway, saying the gate was
skipped. One-liners and pushes are not gated — they are one line by
construction.

## Notifications

How a skill surfaces state depends on whether the user is at the keyboard:

- **Local ping** — `osascript -e 'display notification …'` — when the user is
  present. `/execute-phase` runs one chat at a time with the user watching, so
  a desktop notification on each phase outcome is the right, cheap signal.
- **PushNotification** — when the user may be away. `/run-workflow` launches a
  detached run they are meant to walk away from. Where the push lands is the
  user's own notification setup, never this chain's business. Reserve it for
  what is worth an interruption: the
  **first** failure of a run, any plan-defect consult (the run holds for the
  gate's window — the one push the user can still act on), any blocked phase,
  and the run ending — routine per-phase progress is not pushed. Each message leads with what the user would
  act on, one line under 200 characters, no markdown.

