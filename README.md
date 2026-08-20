<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/logo-on-dark.svg?v=2">
  <img src="docs/img/logo.svg?v=2" alt="Claude Code phased workflow" width="520">
</picture>

# Working in phases with Claude Code

**Version 6.19.0** — see the [Changelog](#changelog). For people who already use Claude Code freestyle, with good results, and want to know what a method adds — no leap of faith required.

> **Rather try it than read about it?** [Workflow tutorial game](https://fporcari.github.io/workflow-tutorial-game/) — the method as an interactive tutorial, in the browser, nothing to install.

## Quickstart

```bash
> /write-workflow      # asks: interactive or autonomous? then branch + plan
> /execute-phase       # interactive: one phase per chat
> /run-workflow        # autonomous: the whole plan, unattended
> /quality-check       # QA page, whole-diff review — stamps the plan
> /finalize-workflow   # lessons, archive, one clean commit
> /resume-workflow     # lost? this reads the branch and tells you where you are
> /help                # the map: from where you are to the command that comes next
```

Interactive phases **stop for you**: when a phase leaves you something to check by hand, it commits its work, stays open and waits — your ok is what closes it. Nothing is reported to anyone before you have answered.

Install in [Getting started](#getting-started); every command, marker and file in the [Cheatsheet](#cheatsheet).

---

## First, the problem

Freestyle works — genuinely — for any job that fits inside one chat. The trouble starts when the work is bigger than a session:

1. **Long chats rot.** The context fills up, decisions made at the start fall out the other end, Claude re-does analysis it already did, and quality degrades the further you go.
2. **A chat is not a medium.** `--resume` gives you the conversation back, not the state: it is on your machine, in your list, and to find out where you were you have to re-read it. Meanwhile the things that matter — where you are, what is missing, why you chose this way — cannot be read by another session, another agent, or a colleague. What lives only in a chat lives for one person, on one laptop.
3. **Unattended work burns tokens in the dark.** You leave Claude working alone, step out, and nobody notices it is circling the same error until you come back.
4. **"Done" is self-certification.** Claude says "done, everything works" — but it is Claude saying it. On interfaces it is worse: whether a page *looks right* is not something a test decides.

> **"Isn't this overkill?"**
> Fair objection. For the twenty-minute fix you are right: open a chat and go — this tool has nothing for you. It pays off when the work outlives one session, when you come back to it in pieces across different days, or when you want to let it run alone without surprises on the bill. Below that threshold: freestyle away.

> ### Every arrow into a chat can die. Every arrow into disk survives.
>
> The whole answer to the four walls rests on that sentence: chats are day labor, the project lives on git.

## The work splits into phases

*Answers wall 1: long chats rot.*

Instead of one endless chat, you first write a **plan** that splits the work into phases. A phase is a small piece with three things in writing: the goal, the files it may touch, and a "done" criterion *a machine* can check:

```markdown
- [ ] **Phase 3**: Token counter in the launcher
  - Details: add the cumulative per-run count
  - Files: lib/launcher.sh, tests/test_launcher.sh
  - Done: tests pass && the log reports the total
```

Then every phase runs in a **brand-new session** that reads the plan and starts with fresh context. No 400-message chats: the memory of the work lives in the plan, not in the conversation. Like a construction site — today's crew reads the drawings pinned in the site office, not the memories of yesterday's crew.

## Interactive or autonomous

*The choice underneath everything: how much leash?*

The plan is the same; what changes is **who verifies**:

- **Interactive** — one phase at a time; you look at the result and say go, and the phase does not close until you have. Claude Code as you already use it, but with a map.
- **Autonomous** — you launch it and go grocery shopping. "Done" is not declared by whoever wrote the code: a separate checker says it (the loop below). You get a notification when it finishes or when it stops.

|  | Interactive | Autonomous |
|---|---|---|
| Who verifies | you, phase by phase | tests, lint, and an independent reviewer |
| When something fails | you discuss it in the chat, or send the defect to a repair chat of its own | one fresh-eyes repair, then it stops |
| Interfaces | a mockup is approved before any code is written | runs straight through with no visual judgment: the eye check lands on the bill, for you, at the end |
| Login | always the human | always the human — fixed rule, no exceptions |

## The loop: never a hamster in a wheel

*Answers walls 3 and 4: who checks, and when to stop.*

In autonomous mode every phase goes through a fixed cycle. Verification is done by a session with **fresh eyes and read-only access**: it did not write the code, so it has no stake in defending it. And the attempts are **counted**: if the problem is still there after one repair, the run stops and writes down why — instead of grinding tokens all night.

![The phase loop: execute, verify with fresh eyes, one repair, then stop](docs/img/loop.svg)

## The close: quality first, then finalize

*And when the plan is done — who looks at the whole?*

While the robot runs, every check that only a human eye can do — "is the page what it should be?" — does not stop the train: it is **put on the bill**, in a `verify.md` file that accumulates phase by phase. When the plan is done, the first thing you do is the eye check against that list: like at a restaurant, the bill arrives once, at the till — not one course at a time. The bill comes as a **QA page** — a rendered checklist, one checkbox per check, each with the action to exercise and the result you should see — so you work through it at your own pace and tick as you go.

Then you run `/quality-check` — and here is the point that is easy to miss: up to now **nobody has ever seen the work as a whole**. Every phase was born in a fresh session and was checked in isolation: that is the price of always-clean context. The quality check pays it in one pass, with a review of the entire diff that hunts precisely the problems *between* phases — one phase breaking another's assumption, the same helper written twice by sessions that never met, style drifting along the way. When it is done, it **stamps the plan** — date, depth, QA answer, findings — and that stamp is what lets the close be honest about what was checked.

**How deep that review goes is your call, not a fixed cost.** The quality check asks once — extended, light, or none — and recommends from what it knows: when a human eye lands on the result anyway (you vetted each phase as it ran, or the QA page exercises what was built), the light pass hunts only the between-phases residue at a fraction of the tokens; when nothing human ever looks at the work, the extended pass is the only eye it gets and earns its price. On large autonomous jobs a fourth option appears, the **panel**: four reviewers in parallel (correctness, cross-phase coherence, pattern conformance, test coverage), and every finding then faces three skeptics instructed to *refute* it — only what survives reaches you. And the quality check **never touches the code** (one declared exception: the naming review applies your own naming decisions); it reports and delegates — the decisions stay yours.

The close itself is `/finalize-workflow`, and it does only the closing: it gates on the stamp (no quality check on file → it asks whether to run one first), rescues the **lessons of the run** (the traps discovered, the "why the first attempts missed") — because the workflow branch gets thrown away, and without this step the method never learns — and turns the whole job into **one clean commit**, with three exits to choose from: pull request, direct merge on the parent, or "just commit, I'll decide later".

## Git is the memory, not an archive

*Answers wall 2: where the memory lives, if a chat holds it for one person only.*

Every job is a **branch**, and the plan travels committed inside the branch: any session — or colleague — that opens the branch has everything, without asking anyone.

- **One phase = one clean commit**, saying what it did. The history reads like the plan.
- **Regressions have a culprit**: every phase declares the files it touches, so when something breaks, git says which phase broke it.
- **Half-done work is not lost**: work in progress leaves a committed footprint too, so the next session resumes from there instead of doing archaeology.

That is why no chat is worth going back to: close everything, come back in three days on another machine, and `/resume-workflow` reads the branch and picks up — no `--resume` to hunt for, no scrollback to re-read.

## Model and effort, per phase

*The part nobody does freestyle: how much brain per piece?*

Not every phase deserves the same brain — and big brains are expensive. At planning time each phase gets **the model and the effort level that fit it**: the routine phase runs on the light model, the delicate one on the heavy model. Freestyle, you pay for the top model even to rename a variable.

And there is the rule that inverts instinct: **a well-specified phase runs alone even on a mid model; a vague phase fails even on the best in the world.** When something goes wrong, the knob to turn is not "more power" — it is "better spec". That is why the method invests everything in the quality of the plan: that is where the yield is, and the bill.

## Compared to Spec Kit, OpenSpec, Task Master

Those tools attack the planning half of the problem: they structure *what to build* — constitutions and specs (Spec Kit), spec-change proposals (OpenSpec), task graphs from a PRD (Task Master) — and then hand the tasks back to your assistant to execute as usual. This plugin overlaps with them on planning and keeps going where they stop, because the four walls above are execution problems: disposable sessions with the committed plan as shared memory, "done" re-checked by an evaluator that did not write the code, bounded budgets with automatic repair and a stop-work channel for unattended runs, and one cross-phase review of the whole diff before a single clean commit lands. If you already keep specs in one of those formats, `/import-workflow` adapts an existing plan instead of starting over.

---

# Under the hood

*From here down, the details — for whoever wants them.*

## Who talks to whom

Three tiers: desktop chats at the top (with the human inside), disposable sessions in the middle, disk at the bottom. All the real work converges at the bottom.

![Workflow architecture: desktop chats, headless sessions, and the git branch every write converges on](docs/img/architecture.svg)

Messages between chats are best-effort by design — any of them can be lost and the run still stands, because a chat that wants the truth re-reads `.phased/` from disk instead of trusting what it was told.

## The cast

| Role | Runs where | Writes what | Dies when |
|---|---|---|---|
| Foreman | desktop chat | nothing on the code: decisions only | replaceable — its identity lives in `foreman.json`, not in the chat |
| Inspector | desktop chat | inspection notes | with the chat that launched the run |
| Phase chat | desktop chat | code + the phase commit | when its phase closes — or earlier, handing over or standing down for a repair |
| Executor | headless `claude -p` | code + the phase commit | every phase — born with fresh context |
| Verifier | headless | nothing: read-only, emits findings | after the verdict |
| UI judge | headless | nothing: compares screenshots to the approved mockup — interactive `ui` phases only | after the verdict |
| Repair | desktop chat (`/repair-phase`) or headless (`-agent`) | the fix, one attempt | after the attempt — one chat is one attempt |

## Succession

`foreman.json` says who commands: if the foreman chat dies, the first `/resume-workflow` takes command by reading the file. Succession never depends on the old chat answering — it works on the plan and the notes alone. The same holds one level down: a phase chat hands over through a `partial` commit, a `> WIP:` note and its rationale in `notes.md`, and the chat that picks the phase up asks the old one only for what the disk could not carry.

If a phase dies midway (a `[>]` marker left hanging), the committed evidence of the work in progress lets the next session resume from there: the phase is reopened, not the story reconstructed.

## Stop-work

The inspector has one power beyond reporting: when continuing looks like waste — a repair cascade, a tripped budget cap, phases closing suspiciously fast, an outcome that undermines a phase still to run — it sends the foreman one of the protocol's two questions: `stop-work?`

The foreman **does not decide alone**: it turns the question to you (*Stop workflow / Go on*). The agent is the smoke detector; the switch stays in your hand.

## Clarify

The protocol's other question belongs to interactive mode, and its decision policy is the mirror image. When a phase chat hits an ambiguity in the plan — what the objective means, what `Done:` covers — you are not the first responder: the foreman authored the plan and holds the reasons it is shaped that way, so the phase chat asks it first (`clarify?`). The foreman decides, writes the decision to disk (its notes, committed), and replies carrying the plan edit the decision implies; the phase chat shows you the decision and, on your ok, applies that edit and commits it — no other confirmation asked of anyone, anywhere. A foreman in doubt does not guess: it sends the question back down, rephrased, and the phase chat puts it to you.

Either way you stay in one chat: the foreman never speaks to you directly. And because the decision is committed before the reply travels, a lost message loses nothing: the phase chat re-reads the plan directory before bothering you, and only a silent disk means the question falls back to you exactly as it did before the protocol existed.

The ambiguity does not have to be recognized to be routed. A phase chat that keeps failing against the same obstacle — or finds itself debating with you about *why* something does not work — is showing the symptom of an ambiguity nobody has named: after the second attempt it stops and sends the foreman its suspected presupposition instead of burning your time on diagnosis. The answer lands the phase on known ground — a defect goes to `/repair-phase`, a wrong plan follows the rejection road. And every misunderstanding that reached the foreman leaves a trace beyond this workflow: the foreman appends what failed, why, and a proposed skill patch to `~/.phased/wf-lessons.md` — a ledger a human reviews in the plugin's own repository; nothing patches itself.

## The plan's markers

| Marker | Meaning |
|---|---|
| `[ ]` | to do — nobody has picked it up yet |
| `[>]` | in progress — set by the executor at start; hanging beyond ~2h, resume flags it as a suspect dead session. Also the state of a phase whose code is done and committed and which is waiting for *your* checks (`> Testing:`) — that one is not stale, it is waiting |
| `[x]` | closed and verified: the `Done:` criterion passed, the phase commit exists |
| `[!]` | failed with the bounded attempts exhausted — one automatic fresh-eyes repair, then it waits for you. A machine verdict only: a result *you* judge wrong never lands here, it becomes new phases |
| `[~]` | blocked on a red baseline no phase owns — the chain has no mandate over it, so it goes to the human |

Every transition leaves structured notes on the phase (`> Done:`, `> Files:`, `> Issue:`, `> Attempted:`, `> Repaired:`, `> Review:`, `> Verify:`, `> Testing:`) — the machine-readable evidence that makes fresh-eyes repair and the final review possible. The full vocabulary lives in [refs/common.md](plugins/wf/refs/common.md), with the contract layer in [refs/contracts.md](plugins/wf/refs/contracts.md) and the foreman protocol in [refs/foreman.md](plugins/wf/refs/foreman.md).

## Where the plan lives

```
.phased/                        # committed on the workflow branch, never reaches the parent
  roadmap.md                    # megaplans only — macro-phases still to detail
  active/<slug>/                # exactly one at a time
    plan.md                     # the work plan
    notes.md                    # per-phase rationale + run inspection notes
    verify.md                   # the bill: human checks deferred to the end
    foreman.json                # which chat commands this workflow
    mockups/phase-N.html        # ui phases — the approved visual contract
    log/phase-N.txt             # transcript of each autonomous sub-session
  done/<slug>/                  # archived by /finalize-workflow
```

## Commands

### Core workflow

| Command | When | What it does |
|---------|------|--------------|
| `/scope-workflow <what>` | the work is still vague | interrogates you one question at a time until every decision the plan needs is settled — facts looked up, never asked |
| `/write-workflow` | after discussing the work | asks the one automation question (interactive or autonomous?), opens the `wf/` branch, writes and commits the plan |
| `/import-workflow` | you already have a plan or a handoff | adapts it to the format, preserving phase states verbatim and reporting gaps instead of inventing them |
| `/execute-phase` | interactive execution | one phase per chat: one approval gate up front (with a rendered mockup on `ui` phases), then no interruptions |
| `/close-phase` | the phase's work is finished | naming review of the new methods (accept-all is one keypress), Done gate, `[x]` record, one phase commit — invoked by `/execute-phase`, by the model when the work is done, or manually on a `[>]` phase a dead session left complete |
| `/resume-workflow` | "where were we?" | read-only audit of plan vs git: drift, stale phases, next step — and the board strip, on interactive plans |
| `/quality-check` | all phases done | QA page from `verify.md` (a checklist you tick as you exercise), naming review of what autonomous phases created, whole-diff review at the depth you choose — then it stamps the plan |
| `/finalize-workflow` | quality check stamped | gates on the stamp (offers `/quality-check` when it is missing or stale), lessons, plan archive, one clean commit — PR, merge, or leave it |
| `/pull-request` | delivering by PR | maintainer-grade review, then creates the PR |

### Autonomous execution

| Command | When | What it does |
|---------|------|--------------|
| `/run-workflow` | the whole plan, unattended | pre-flight review, then one fresh `/goal`-guarded session per phase; the launching chat stays on as the run's inspector |
| `/execute-phase-agent` | one phase, unattended | the same phase execution with nobody to ask: convergence loop, independent verification where it earns its keep, `Done:` gate |
| `/repair-phase` | a phase came back `[!]`, or you found a defect mid-phase | fresh-eyes repair in a chat of its own — asks you what is wrong, never repeats a listed attempt, and you decide when it is fixed. Closes an `[!]` phase; hands a `[>]` one back to the chat that owns it |
| `/repair-phase-agent` | the same, unattended | `[!]` only, no questions, the outcome is the run's exit condition |

### Auxiliary

| Command | When | What it does |
|---------|------|--------------|
| `/issue <number>` | starting from a GitHub issue | loads and analyzes it — analysis only, the plan comes from `/write-workflow` |
| `/help` | which command do I type now? | the map of the plugin: from where the work stands to the command that takes it forward, plus one line per command — reads no state |

Every command declares its own `allowed-tools`, and the test suite fails if a skill instructs a command its allowlist does not permit.

## Getting started

Prerequisites:

- [Claude Code](https://claude.com/claude-code) **≥ 2.1.170** for autonomous runs — `/goal` guards the sub-sessions (2.1.139; older versions fall back to plain skill prompts at runtime) and the repair session runs on `fable` (2.1.170; on an older CLI the run still completes, falling back to `opus`, and a phase that pins `Model: fable` fails to launch). The interactive path needs no more than **≥ 2.1.139**.
- `bash` and `python3` on `PATH` — every skill resolves the active plan through `scripts/next-phase.py`, and the autonomous launchers are shell scripts. This holds for the interactive path too, not just for `/run-workflow`.
- `git` with a remote, `gh` authenticated.

macOS and Linux. Windows is not supported: the launchers need a bash shell, which Claude Code no longer requires there, and `python3` is not the interpreter's name on that platform. Under WSL it behaves like Linux.

The desktop app adds the live run monitor and notifications; the CLI works without them.

**Install from the marketplace (recommended):**

```bash
claude plugin marketplace add fporcari/claude-phased-workflow
claude plugin install wf@claude-phased-workflow
```

Note the reference: `wf@` is the plugin, `claude-phased-workflow` is the **marketplace name** declared in `marketplace.json` — not the GitHub slug.

**Upgrading from 5.x** — the plugin was renamed `phased-workflow` → `wf` in 6.0.0, so the old entry has to go or you keep two installs:

```bash
claude plugin uninstall phased-workflow@claude-phased-workflow
claude plugin install wf@claude-phased-workflow
```

Nothing else changes: `.phased/` plans, `wf/` branches and phase commits carry no plugin name. Typed commands become `/wf:<name>` — the bare `/<name>` form works as before.

**Update to a new release** — one command; it refreshes the marketplace from GitHub by itself, no separate `marketplace update` needed. Restart open sessions to load the new version:

```bash
claude plugin update wf@claude-phased-workflow
```

**Per-project** (in the project's `.claude/settings.json`):

```json
{
  "plugins": {
    "marketplaces": ["fporcari/claude-phased-workflow"],
    "installed": ["wf@claude-phased-workflow"]
  }
}
```

**From a clone** (for developing the workflow itself):

```bash
git clone https://github.com/fporcari/claude-phased-workflow.git
claude plugin marketplace add ./claude-phased-workflow
claude plugin install wf@claude-phased-workflow
```

Installing the plugin is the whole install — skills, launcher, phase selector, verifier subagent and shared refs all resolve through `${CLAUDE_PLUGIN_ROOT}`. **Never copy the skills into `~/.claude/commands/`**: a flat copy wins the bare `/<name>` over the plugin and keeps an old version running without you noticing. Migrating from ≤ 4.0.0? A one-time `install.sh` in the plugin cache moves the superseded flat copies aside — moving, never deleting.

First use:

```bash
claude
# discuss the work, then:
> /write-workflow      # it asks: interactive or autonomous?
# interactive: a new chat per phase        autonomous: one command
> /execute-phase                           > /run-workflow
# when every phase is done:
> /quality-check
> /finalize-workflow
```

## Tests

```bash
bash tests/orchestration/run_tests.sh     # free: no sessions, no model
```

**210 assertions over 32 scenarios** (S1–S33, S16 retired). The launcher scenarios drive the shipped `/run-workflow` script against a mock `claude` binary — call shape, model/effort/cap selection, repair resuming or stopping the loop, red-baseline attribution, the no-progress guard. The rest guard invariants that live in prose, each proven by mutation: break the clause and the assert must fail. The suite runs under **both bash and zsh**, because the production shell is zsh and a bash-only harness cannot see zsh-specific breakage. The scenario-by-scenario catalog is in [docs/design-notes.md](docs/design-notes.md); CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs flake8, both suites and the plan validator on every push and PR.

There is also a benchmark harness (`tests/benchmark/bench.sh`) that runs real sessions on a fixture project and judges success externally — pytest, flake8 and plan state, never the session's self-report. [tests/benchmark/results/README.md](tests/benchmark/results/README.md) records what each archived run actually measured and which conclusions survive it — including the ones that did not.

## GenroPy worktree support

If you develop with [GenroPy](https://www.genropy.org/), the `genropy-worktree` plugin makes `gnr` CLI commands work from workflow worktrees — see [plugins/genropy-worktree/README.md](plugins/genropy-worktree/README.md).

## Cheatsheet

*Every command, marker and file — one screen.*

| You want to | Type | Where it belongs |
|---|---|---|
| turn a vague idea into settled decisions | `/scope-workflow <what>` | before the plan exists |
| turn the discussion into a plan on a branch | `/write-workflow` | it asks: interactive or autonomous? |
| bring in a plan you already have | `/import-workflow [path]` | instead of `/write-workflow` |
| start from a GitHub issue | `/issue <number>` | analysis only — no plan, no code |
| do the next phase, one phase per chat | `/execute-phase` | interactive |
| close a phase whose work is finished | `/close-phase` | interactive — usually called for you |
| run the whole plan unattended | `/run-workflow` | autonomous |
| run exactly one phase unattended | `/execute-phase-agent` | autonomous |
| retry a phase that came back `[!]` | `/repair-phase` | one attempt, fresh eyes — `-agent` for the unattended run |
| chase a defect without burning the phase chat | `/repair-phase` in a new chat | the phase chat stands down, the repair hands back |
| hand a long phase to a fresh chat | say *"pass the baton"* | it commits, writes down the why, and stops |
| close a phase on what it reached | `/close-phase` | when the rest deserves a phase of its own |
| ask where the work stands | `/resume-workflow` | the foreman chat — never the one running a phase |
| check the job: QA page, whole-diff review, the stamp | `/quality-check` | when every phase is `[x]` |
| close the job: lessons, archive, one commit | `/finalize-workflow` | when the quality check is stamped |
| deliver by pull request | `/pull-request` | after finalize, if you chose to leave it |
| find the right command from wherever you are | `/help` | the routing map — reads no state |

**Plan markers** — `[ ]` to do · `[>]` in progress, or done and waiting for your checks (`> Testing:`) · `[x]` done and verified · `[!]` something is demonstrably broken: failed, or under repair · `[~]` blocked on a red baseline nobody owns.

**On disk**, committed on the `wf/` branch, under `.phased/active/<slug>/` — `plan.md` the work · `notes.md` the why · `verify.md` the human bill · `foreman.json` who commands · `mockups/` the visual contract of `ui` phases · `log/` the sub-session transcripts.

**Who says "done"** — interactive: you do, phase by phase, and nothing closes or is reported before you have. Autonomous: tests, lint and a read-only verifier that did not write the code. Login is the human's in both, with no exception.

**Lost?** `/resume-workflow`. It needs the branch, nothing else — not the chat that started it, not the machine it ran on.

## Changelog

One entry per release in [CHANGELOG.md](CHANGELOG.md) — the most recent:

| Version | In one line |
|---|---|
| 6.19.0 | minimality covers surface and prose: the named over-engineering idioms (accessors for public attributes, delegate-only wrappers, narrating comments) are prevented by the steer and hunted by the verifier and the naming review |
| 6.18.0 | the close splits in two: `/quality-check` (QA pass, naming review, whole-diff review — stamps the plan) and a `/finalize-workflow` that only closes, gating on the stamp |
| 6.17.0 | a "the plan is wrong" claim from an unattended phase is routed to the foreman before any repair: the launcher holds, the foreman decides — authorize the fresh-eyes repair (the default; both field claims proved wrong) or stop and fix plan and tests itself |
| 6.16.0 | the doctrine mass is measured: every skill's closure (SKILL.md + cited refs) is computed against a 1500-line budget, so growth pays at merge time instead of degrading sessions in the field |
| 6.15.0 | the messaging channel is declared, not discovered: version floors single-source in `foreman.md` → *Channel floors*, and the state-reporting skills say which branch is alive in this installation |
| 6.14.0 | the doctrine splits by consumer — `common.md` core plus `contracts.md` and `foreman.md` — so a headless phase session drops from ~1140 to ~790 lines and reads the foreman layer only at its notify step |
| 6.13.0 | sonnet leaves the model palette: field experience regretted every sonnet phase; mechanical work is `opus` at `low` effort, and legacy plans that carry sonnet still run |
| 6.12.1 | sessions are not phases: the launcher's loop budget doubles the pending count so a `[>]` resume cannot starve the tail, and exhausting it is declared out loud |
| 6.12.0 | the programme is a graph, not a chain: a contract lives from producer to consumer, every macro it crosses inherits it into `Must not break:`, and the judge and finalize check the luggage in transit |
| 6.11.0 | the macro split is scoped, not just listed: a mini-scope per macro at split time, a fresh-eyes coherence judge on the itinerary (`Ends at:` ≡ next `Starts from:`) and the contract graph, and finalize checking the delivered border |
| 6.10.1 | the programme contract reaches the unattended path too: light-mode phases and the run inspector's coherence look now read `Must not break:` and the roadmap |
| 6.10.0 | a future consumer's contract travels backwards (#15): `Must not break:` in the plan header, the consumer question at planning, the roadmap check at macro close, and `/doctor` turning a consumer measured late into a measured list of reds |
| 6.9.0 | `/doctor`: is the work still coherent with the plan — coherence audit, contract-test integrity, and a blind retro-fit of missing tests, verified phase by phase, findings never fixed in place |
| 6.8.0 | the contract between phases becomes enforceable: plan-time contract tests (executable or skeleton), `ui` checks pre-established in the plan, a compatibility line at the gate — and no child rewrites what the plan authored |
| 6.7.1 | a repair says so on the plan: the chat names the phase it is repairing, and `[!]` stops being ambiguous between broken and being-worked-on |
| 6.7.0 | struggle routes up before it burns tokens (the stop-loss), `/help` maps the commands, and every misunderstanding leaves a skill-patch proposal in the wf-lessons ledger |
| 6.6.0 | repair splits in two: with you it asks what is wrong and hands the phase back, unattended it closes on its own — and a defect found mid-phase leaves the phase chat |
| 6.5.0 | a phase that outgrew its chat closes on what it reached: the `Done:` is corrected to the truth and the foreman grows a phase for the remainder |

The deep rationale — why the commands are shaped the way they are, the design decisions and the trade-offs behind them — lives in [docs/design-notes.md](docs/design-notes.md) and [docs/loop-engineering.md](docs/loop-engineering.md). The Italian source of this README's structure is [docs/architettura-it.html](docs/architettura-it.html).

## License

MIT
