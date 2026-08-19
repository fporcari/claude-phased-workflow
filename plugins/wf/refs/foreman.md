# The foreman layer — chat hierarchy, messaging, reporting

The supervision half of the shared conventions, split out so that only its
consumers pay for it: the skills that take command, depose, message upward or
report to the decision-maker read this file. A headless `-agent` session
needs only the *Sending to the foreman* message formats, and only when it
reaches its notify step — read that section then, not at start. Core
conventions stay in `refs/common.md`; the contract layer in
`refs/contracts.md`.

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

**Channel floors — single source.** The messaging layer rides the most
unstable platform surface this plugin touches, so its version floors live
HERE and nowhere else (a skill cites this section, it never restates a
number): cross-session `SendMessage` in the CLI needs **≥ 2.1.224**; the
desktop session-management tools (`list_sessions`/`send_message`) have no
version floor but exist only in desktop chats; a `claude -p` sub-session
reaches neither world (field-tested, below). The launcher's own floors
(`/goal` ≥ 2.1.139, `fable` ≥ 2.1.170) are detected at runtime by
`run-workflow.sh`, which declares its fallback in a NOTE. **Declare the
channel when reporting state**: a skill that reports where the workflow
stands (`/resume-workflow`'s report, `/run-workflow`'s first relay) says in
one line which branch is alive in this installation — desktop tools, CLI
`SendMessage`, or neither — so a dead channel reads as declared degradation,
never as a silent skip discovered later.

**Sending to the foreman** (children, at phase end and on plan changes):
read `foreman.json`, `list_sessions`, exact title match → `send_message` to
that session id. In the CLI the same by name — `ListAgents` + `SendMessage`
(*Channel floors* above). **`list_sessions` first, always** — and *first* means before any
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
(`refs/common.md` → *Failure and repair notes*).

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

