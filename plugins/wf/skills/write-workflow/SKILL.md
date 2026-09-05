---
description: Write a phased work plan from the current conversation — branch, plan directory, first commit
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(mkdir:*), Bash(cp:*), Bash(cd:*), Bash(command:*), Bash(activate_gnr_context:*), Bash(python3:*), Read, Grep, Glob, Write, AskUserQuestion, Agent, mcp__ccd_session_mgmt__set_session_title, mcp__visualize__read_me, mcp__visualize__show_widget
---

# Write Workflow

Plan a work session, then open the branch and commit the plan. The plan is the **only** deliverable.

1. **NEVER edit source code.** Read anything; write nothing outside `.phased/`.
2. **Do not implement.** The user runs `/execute-phase` afterwards.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` and `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` once at start, and `${CLAUDE_PLUGIN_ROOT}/refs/foreman.md` only at Step 4, only after Step 2 settled `Channel: relayed` or a legacy plan — on `Channel: in-chat` nothing creates a relay, so it is never read — core conventions, the contract layer planning authors, the take-command protocol. **The board** an interactive plan closes with is specified once in `${CLAUDE_PLUGIN_ROOT}/refs/board.md` — read it at Step 6, not before.

## Step 1: Where are we

```bash
git branch --show-current
git rev-parse --show-toplevel
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null \
  || git symbolic-ref --short refs/remotes/origin/HEAD   # the repo's default branch (origin/<name> on the fallback), never one from memory
```

**On a feature branch** — read what is already there (`git log origin/<base>..HEAD --oneline`, `git diff --stat origin/<base>...HEAD`, the full diff, and `gh issue view <number>` if the branch starts with one), summarise it, then ask: *"What do you want to plan on this branch?"*

**On the base branch** — no exploration. Ask straight away: *"You are on `<branch>`. What do you want to do?"*

The user's answer is the primary input. Read code only in service of the plan.

**Then look, before deciding anything.** A plan on hypotheses buys its imprecision back one clarify round at a time, and four classes account for
most: a literal asserted unique and never grepped for duplicates, a behaviour transcribed from a design doc the code contradicts, a remedy (flag, env
var, CLI option) unchecked against the tool's real interface, arithmetic stated without being computed — cheap here, expensive at a phase gate, and
what Step 2 sizes on.

This same fork decides the branch in Step 4 — remember which side you are on.

Before the automation fork, apply `${CLAUDE_PLUGIN_ROOT}/refs/execution-policy.md` to choose
one engineer task, one durable phase, several phases or macro-phases. Present the
shape and reason once. If one task wins, present the self-contained brief from
Step 3 and stop at its handoff gate; skip workflow mode/channel questions.

## Step 2: The automation fork

Before building the plan, settle how it will run. This is one explicit question, asked once, and its answer picks the plan format — never default silently to one mode.

Derive the recommendation from the work just discussed and state it in one line with its reason (there is no fixed default; the recommendation follows the task):

- **UI, declarative, or visual work — anything whose success is "I'll know it when I see it"** → recommend **interactive**.
- **Heavy refactor, project startup, mechanical migration — well-specified work with a measurable done** → recommend **autonomous**.

Ask with `AskUserQuestion` (recommended option first, per `common.md`), two options:

- **Autonomous** — `/run-workflow` runs the whole plan unattended, one self-correcting sub-session per phase.
- **Interactive** — `/execute-phase` with a human approval gate on each phase; the channel below decides whether that is one chat per phase or one conversation throughout.

The answer routes the rest of this skill:

- **Autonomous** → read `${CLAUDE_PLUGIN_ROOT}/refs/write-workflow-autonomous.md` and apply its stricter refinement and format on top of the steps below; the plan carries `Mode: autonomous`.
- **Interactive** → continue with this file's format; the plan carries `Mode: interactive`.

**Then the channel** — a second question, put only once the first is answered and never in the same `AskUserQuestion`, since the mode answer decides whether it is asked at all: `Mode:` says how the work runs, `Channel:` where its decisions travel (`contracts.md` → *The channel*). Every new plan writes the field.

- `Mode: autonomous` → `Channel: relayed`, always: nobody is at a gate, so the relay is the only route a decision has.
- `Mode: interactive` → **ask**, one line, recommendation first. `in-chat` when the same person sits at every gate: one conversation plans and
  executes in sequence, and a hop between chats buys nothing where the loop is closed already. `relayed` when different chats or times pick up the
  phases, or several workflows run at once — anything putting a chat boundary between a decision and the phase needing it. Phases stay ordered and
  serial either way.

## Step 3: Build the plan

Extract from the conversation: objective, phases, files per phase, pattern references, decisions, sizing, notes.

**One chat, or a workflow.** Apply the shared delivery-shape policy; carry the settled
contract into a self-contained brief for a fresh engineer session. On One chat,
write `~/.phased/prompts/<slug>.md` and hand over its path; skip Steps 4–6.

**The one-chat brief** — filled from the plan just built, self-contained for a chat that has read nothing else; the recon, the decisions and the contract tests are already paid for:

```
Run in ONE fresh chat — model fable (or opus), effort high — from <repo root>, on <base branch>.
# <objective, one paragraph: what done looks like for the user>
## Decided — never reopened: <every Decisions: line of the plan>
## Code: <file → pattern to copy-adapt as path:symbol, one line each; files that do not exist yet marked new>
## Constraints: <Must not break: lines>; the repo's CLAUDE.md applies; no new dependency without asking
## Method: contract tests first (<their paths, or the tests written below>), then implement; run <lint cmd> and <test cmd>; loop until green, at most two diagnosed corrections (the Stop rule below)
## Done: <the plan's re-runnable Done: criteria, merged into one list>
## Deliverable: branch <wf/<slug>, or as the user said>, one commit, a report of at most 10 lines: what changed, what was verified, what was left
## Stop: a decision not listed under Decided → stop and ask; Done not green after two attempts → stop and report what is red and why
```

**Write nothing about the code you have not seen.** `Files:`, `Pattern:` and any `Decisions:` line asserting how the code behaves rest on the Step 1 pass.
Files that do not exist yet are ordinary plan output: a new module is intent the phase realises, not a claim about what is there.

**Pattern references.** On `Channel: relayed` every `/execute-phase` runs in a fresh chat, so whatever isn't in the plan gets re-discovered there, phase after phase; on `Channel: in-chat` a compact costs the same. Either way the plan is the memory. While the code is in front of you, find 1–2 existing examples to copy-adapt for each phase that writes non-trivial code, and record concrete paths in `Pattern:`. Library-standard work → `library-standard`; nothing comparable → `new-pattern`. From ~3 such phases up, dispatch one read-only Explore subagent per phase — **at most 4 at a time**, in waves — instead of searching serially. Each returns at most 2 candidates as `<path>:<symbol> — <why it is the closest example>`, or exactly `NO CANDIDATE`. A phase coming back `NO CANDIDATE` gets `new-pattern`; it never gets a guess.

**Decisions.** `/execute-phase` has a single approval gate, so every choice needing the user's judgment — naming, signatures, library, API shape, trade-offs — is settled *here*, batched into AskUserQuestion, and recorded in `Decisions:`. Two shapes are named because both cost a gate correction in the field: when two phases read and write the same table's UI surface, settle the row-set boundary between them explicitly — who lists what, who excludes whose rows — rather than settling each phase's surface in isolation; and on a `ui` phase, record layout composition (which surface carries which zone) as mockup-negotiable intent, not as a fixed Decision — the mockup loop is what exists to settle it, and freezing it before any visual makes the user's own gate judgment a plan contradiction. A phase containing "decide later" is not ready. On a real architectural fork, give a recommendation with its trade-off; say if it is the kind of choice a judge panel would decide better, and let the user ask for one.

**Contract tests.** One more option, asked with the Decisions batch: author the tests of EVERY phase now, while the whole design sits in one context —
into `.phased/active/<slug>/tests/phase-N/`, committed with the plan, each phase's `Done:` opening with "the plan's tests for this phase, copied into
the test tree, pass". Recommend it on well-specified work — behaviour that must survive is what a test states best; where a signature is not settled
yet, author that test as a skeleton (`wf:contract:` comment lines + red body) instead of guessing. The whole contract — the two precisions, where the
tests live, the child's read-only rule, the integrity check at close — lives once in `contracts.md` → *Contract tests*; writing them inside `.phased/`
keeps this skill's own first rule intact. Authoring them is plan-time work: derive each phase's tests from its `Details:` and `Done:`, in the repo's
own test style, and present them with the plan. Then, before the plan commit, RUN the repo's own linter over them (a `Done:` demanding a clean lint on
the copied test and a copy that must stay byte-identical are one requirement) and CHECK every import path and fixture they lean on against the repo:
an import no file in the repo uses is a premise to verify against the loader, not a convention to assume — the field's one true plan-defect claim was
exactly such an import.

**The consumer question.** When `.phased/roadmap.md` has unstarted macro-phases — or the discussion names later work that will consume this plan's
output — ask it with the Decisions batch: *who consumes what this workflow builds, and what will they require of it?* The answer becomes the plan's
`Must not break:` header lines, backed by skeleton contract tests where a requirement can be stated as behaviour; "nobody yet" is written down too.
Field semantics live once in `contracts.md` → *Must not break:*. On a roadmap carrying mini-scopes, the answer starts there, confirmed rather than
reconstructed: collect the lines of `Requires of earlier work` from the later macros that touch this plan's output, **inherit the contracts in transit
across this macro** — produced by an earlier one, consumed by a later one, they enter this plan's `Must not break:` too (`contracts.md` → *Must not
break:*, producer-to-consumer rule) — and take the macro's own `Ends at:` as a planning constraint: the last phases must land the system at that
border.

**Sizing.** The boundary depends on the mode chosen in Step 2.

*Interactive plans — the boundary is **"something a human can look at exists"***. A phase ends where the user can open the thing and judge it, so phases come out **bigger** — as a consequence, not as a goal. The point is what it makes impossible: a phase cannot close on half a button, so no verification step can be a trivial "try this for me". The user's own example — customer and supplier master tables *with their UI* — is one phase here, not a model phase plus a UI phase.

*Autonomous plans — one coherent result, closed by a re-runnable `Done:`* (the stricter rules live in `${CLAUDE_PLUGIN_ROOT}/refs/write-workflow-autonomous.md`).

Either way:
1. Too small to verify alone (a model half, a migration, a schema)? Merge it into the phase that makes it verifiable — a phase boundary the user cannot verify is a boundary in the wrong place.
2. **Split** — two concerns in one phase: just write more phases, no tag.
3. **`vast`** — one indivisible concern with a broad surface. Use bounded reconnaissance and reviewable batches; file count alone never requires a split.
4. **`ui`** — a phase whose deliverable is judged by eye: a page, a form, a dashboard. Interactive plans only (an autonomous run has nobody to approve a mockup). At execution the approval gate includes a rendered HTML mockup iterated with the user, and verification adds a browser pass plus a fidelity judge against that mockup (`contracts.md` → *Verification*). Tag it here so the executing chat knows before exploring.

The split-vs-`vast` call and the `ui` tag materially change execution — batch them into the Decisions questions. Phases always run in order, each in its own chat; there are no parallel or grouped phases.

**Verification fields.** `Done:` and `Verify:` are two audiences, and their contract lives once in `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` → *Verification* — read it there rather than inferring it. When writing an interactive plan: give every phase a `Done:` the machine can re-run, and add `Verify:` steps only for what genuinely needs human eyes, each with its *when* (`now` / `deferred: needs Phase M`). What a browser agent could assert belongs in `Done:`, never on the human's list. On a `ui` phase the `Verify:` list is authored COMPLETE here — the checks the human will run at that phase are pre-established now, and execution may add but never drop or reword them (`contracts.md` → *Verification*, authored checks are foreman-owned).

**Run hint.** Every phase carries a `Run: <model> / <effort>` line: advice for the human who opens that chat, never something the plan enforces — the model is picked when the session starts, before any skill has read the plan. That is also why it is written down instead of only said here: the chat that needs it is opened days later, and by then this conversation is gone.

- **Effort** — start low and climb only for a reason. A phase whose `Decisions:` and `Pattern:` are settled is where high effort buys least: it gets spent re-exploring what planning already decided. `low` mechanical, `medium` the standard phase, `high` where real design judgment survives inside the phase, `xhigh` a wide multi-file surface, `max` practically never (overthinking, diminishing returns). Levels copied from an older plan rarely transfer — decide them here, for this plan.
- **Model** — `opus` is the floor and the default; `sonnet` is not in the palette (field experience regretted every sonnet phase — a phase mechanical enough to tempt it belongs on the autonomous side of the fork, on `opus` at `low`). `fable` only where inventive work survives *after* the approval gate: architecture to invent, an unknown surface, no obvious decomposition. Half of its usual case is absent here — fable also earns its premium where nobody is watching, and interactive work is watched by construction — so a phase whose ambiguity is "the user will say whether it looks right" is `opus`, not `fable`.

**Present the plan**, each phase with its `Run:` line, and iterate until the user approves.

**Close the presentation with the branch line and the gate line** (`common.md` → *The gate line*). When *One chat, or a workflow* found none of its three reasons, the gate is instead an `AskUserQuestion` with **One chat** first (the prompt file, no branch) and **Workflow** second; otherwise:

> Branch: \<what will happen\>   (say so if you would rather have it otherwise)
> **Proceed?** On your ok, I create the branch and write `.phased/active/<slug>/plan.md`.

The branch line is pre-filled per Step 4 and flippable.

## Step 4: Open the branch

Only after approval, and before writing anything.

Derive the slug from the objective: kebab-case, strip accents, ≤50 chars, a leading issue number kept as prefix (`123-fix-login`).

**On the base branch** → `wf/<slug>`, no question asked — in a worktree by default, below.

**On a feature branch** → the default is to **adopt it** as the workflow branch: `.phased/` goes there, no new branch, and `Parent:` is that branch's own base. You created that branch on purpose; nesting another inside it buys nothing. The alternative, offered in the branch line above, is `wf/<slug>` off it — take it when the workflow is a distinct chunk the user may want to merge or drop on its own; the current branch then becomes the `Parent:`.

**Worktree by default.** On the `wf/<slug>` path the branch opens in its own worktree, cut from the parent, so this checkout never leaves it: whatever the user does here while the run or the phase chats work cannot collide with them, and a `git switch` here cannot break a run.

```bash
git worktree add .claude/worktrees/<slug> -b wf/<slug>
mkdir -p .claude/worktrees/<slug>/.claude && cp .claude/settings.local.json .claude/worktrees/<slug>/.claude/
command -v activate_gnr_context >/dev/null && (cd .claude/worktrees/<slug> && activate_gnr_context)
```

From here on every path and every git command of this skill is anchored at the worktree root (`common.md` → *Plan location*): `.phased/` and the plan commit land there, never in this checkout. The third line is the `genropy-worktree` plugin, when installed: it writes the GenroPy env (own `.gnr/`, own ports) into the worktree's `.claude/settings.local.json`, which Claude Code reads at session start — so every chat and sub-session opened there runs `gnr` against the worktree's code, and planning is the one moment early enough for that. The branch line flips it to "in this checkout" (`git switch -c wf/<slug>`); on `Channel: in-chat` that is the default instead, since this conversation IS the workspace. Not offered on the adopt path — a branch already checked out cannot be added as a worktree. `/finalize-workflow` removes the worktree; the user never manages it.

## Step 5: Write it

`.phased/active/` already occupied → stop and say so: one branch, one plan. Otherwise create `.phased/active/<slug>/` at the workspace root (the worktree, when one was opened) holding `plan.md`, an empty `notes.md`, and — on `Channel: relayed` — `foreman.json`: **this chat takes command of the workflow it is creating**, per `foreman.md` → *The foreman* (write the file — it rides Step 6's plan commit, no second one; this chat titles itself there too, and the closing message states it). On `Channel: in-chat` there is no relay to command: no `foreman.json`, no take-command commit, and the same conversation carries the work.

```
# Context: <branch-name>
Parent: <parent-branch> | Issue: #<number> (if present)
Mode: interactive
Channel: <in-chat|relayed>
Must not break: <one line per contract owned by later work — contracts.md → *Must not break:*; omit only when no roadmap and no known consumer>

## Objective
[2-3 sentences]

## Work Plan
- [ ] **Phase 1**: <concise title>
  - Run: opus / medium
  - Pattern: `path/to/example.py:func` (or `library-standard` / `new-pattern`)
  - Files: <involved files, if known>
  - Decisions: <choices already settled — omit if none>
  - Details: <what to do concretely>
- [ ] **Phase 2**: table foo with its TH UI (model + webpage)  `ui`
  - Run: opus / low
  > Batches: 1 model + relations | 2 TableHandler view | 3 form and its tests
  - Files: packages/foo/model/foo.py, packages/foo/webpages/foo.py
  - Details: table + columns + relations, then TableHandler view + form.
  - Done: end-to-end test — create a row via the form, assert it persists and reloads in the grid
  - Verify: now — the form reads well: field order, labels, nothing cramped
  - Verify: deferred: needs Phase 3 — the renamed amount column still lines up in the grid
- [ ] **Phase 3**: rename legacyAmount → amount across the web layer  `vast`
  - Run: opus / xhigh
  - Files: discovery rule — all references to `legacyAmount` under packages/foo/ and gnr/web/
  - Details: rename + deprecated alias.

## Notes
[Attention points, dependencies, breaking changes]
```

Phases run strictly in order: a phase starts only when every phase above it is `[x]`.

Write no `## Suggested execution config` table on an interactive plan: nothing reads one here, and the validator warns about it. The per-phase `Run:` line is the interactive equivalent — a suggestion in the plan body, `opus`|`fable` only, read by `/execute-phase` to scale its exploration and reported by `/resume-workflow` before the next chat is opened.

## Step 6: Commit and close

The plan is the branch's first commit — everything after it is the workflow:

```bash
git add .phased && git commit -m "wf: plan for <slug>"
```

In a worktree, both commands run there (`git -C .claude/worktrees/<slug>`). Verify it is not empty (`git show --stat HEAD`). An empty commit means `.phased/` is excluded by a `.gitignore` — say so and stop rather than working around it; the whole chain depends on the plan being tracked.

```
Plan written to .phased/active/<slug>/plan.md (<N> phases), committed on <branch>.
Workspace: .claude/worktrees/<slug> — open the phase chats there; /run-workflow and /resume-workflow find it from here too.   (worktree only; on in-chat this conversation operates there through the plan root)
relayed → this chat is the foreman, now titled `wf:<slug>:foreman`, the address phase chats report to; launch /execute-phase in a new chat and this one stays the board (a successor foreman chat opens on fable / high — foreman.md). in-chat → no relay: /execute-phase runs here, phase after phase, every gate in this conversation.
Phase 1 — suggested: <model>, effort <effort>.
```

Where the title could not be set — the tool is absent — that line becomes the ask instead, per `foreman.md` → *The foreman*, take-command step 3.

The last line repeats Phase 1's `Run:` hint, because the model and the effort are chosen when that session starts — reading it afterwards is too late.

**Then draw the board**, as specified in `${CLAUDE_PLUGIN_ROOT}/refs/board.md` — the same strip `/resume-workflow` draws, one source for both. Here every row is `[ ]` and Phase 1 is the emphasised one: the plan was just written, there is no history yet.

**Only after the commit, never during Step 3's presentation.** The plan is iterated in prose, and a board naming a branch that does not exist yet is a trap. On an autonomous plan, no board at all.

(Autonomous plans use the closing message in the autonomous reference file.)
