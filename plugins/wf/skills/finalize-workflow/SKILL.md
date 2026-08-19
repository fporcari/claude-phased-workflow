---
description: Finalize the workflow - verify all phases, prepare final commit
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cd:*), Bash(head:*), Bash(sed:*), Bash(grep:*), Bash(python3:*), Bash(bash:*), Read, Grep, Glob, Write, Edit, AskUserQuestion, Skill, Agent, SendUserFile, SendMessage, ListAgents, mcp__ccd_session_mgmt__send_message, mcp__ccd_session_mgmt__list_sessions
---

# Finalize Workflow

Verify the work plan is complete and turn the working tree into one clean commit. **Never edit source code here** — findings get reported and delegated. One declared exception: Step 3's naming review, whose edits are the user's own naming decisions plus marker removal.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md`, `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` and `${CLAUDE_PLUGIN_ROOT}/refs/foreman.md` once at start — core conventions, the contract layer (verify.md, markers, Must not break:), the reporting register and foreman messaging.

## Step 1: Find the plan and the base

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve
git branch --show-current
git worktree list --porcelain
```

Set `IN_WORKTREE` from whether the cwd is in the worktree list. No active plan → stop; the plan lives on the workflow branch, so check `git branch --show-current` before concluding there is nothing to finalize — and check `--plans` first: the workflow may live in another checkout (`common.md` → *Plan location*). When it does, every git command below runs `git -C <plan root>` and every path is anchored there; the consolidation itself (Step 8) must happen on the plan's branch, never on the cwd's.

Read the plan for `Parent:`, the issue number and the phase states. **Resolve the parent ref**: `origin/<parent>` if `git rev-parse --verify` finds it, otherwise the local `<parent>`.

Then resolve the two things every step below depends on:

```bash
BASE=$(git log -1 --diff-filter=A --format=%H -- <plan path>)   # the commit that ADDED the plan
git rev-list --count "$BASE"^..<parent>                         # 0 => BASE is the branch point
```

`BASE` is the workflow's base: everything after it belongs to this run, everything before it does not. That second command tells you which shape you are in — **dedicated branch** (the plan commit *is* the branch point: the branch is the workflow) or **adopted branch** (the branch already carried commits, which must survive untouched). Step 4 and Step 8 differ between the two; nothing else does.

## Step 2: Verify completion

All phases `[x]` → proceed. Otherwise report the incomplete ones (warn specifically that a `[>]` may be a dead session) and ask whether to finalize anyway (default: no).

**Present the QA pass.** Collect every `Verify:` step from the plan — authored fields and `> Verify:` notes alike — *and* the whole of `verify.md` if it exists (the deferred checks the executing skill dated to a later phase — `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md` → *Verification*). Deliver them as the **QA page** defined there: ONE checklist, grouped by phase, each check with the action to exercise and the result the user should see; a deferred step whose phase has since landed is now due. Phrase every item per `foreman.md` → *The reporting register*: the reader knows what the feature should do, not how the phases built it. Then ask whether they have been done — not as a blocker, but never silently skipped either: if the user says no, say plainly that the workflow closes with those checks outstanding. **Keep the answer**: whether a human exercises the result is one of the inputs Step 5's recommendation reads.

`verify.md` is the sibling of `review.md`, not a duplicate: this list is what the user must *exercise*, `review.md` is what they must *judge*. Present both.

## Step 3: Naming review

Autonomous runs accumulate `wf:phase-N:new` markers on the callables the phases created — nobody could answer a naming question mid-run (`contracts.md` → *New-method markers and minimality*). Collect them over the union of every phase's `> Files:` (`grep -rn "wf:phase-[0-9]*:new" <files>`); none → skip in one line. Found → run `${CLAUDE_PLUGIN_ROOT}/refs/naming-review.md` for the whole workflow: ONE map, accept-all as the recommended fast path, renames applied with their call sites, markers stripped, the narrow signal re-run when anything was renamed. Commit the result on the workflow branch:

```bash
git add -A && git commit -q -m "wf: method naming review"
```

**This is the one step of finalize that edits source, by design** — the edits are the user's naming decisions plus marker removal, and the commit lands before the scope review so what gets reviewed is what will ship. The ref's sweep is blocking: a marker that survives here reaches the parent branch.

## Step 4: Review the scope

No staging heuristics any more, and no guessing: the workflow is exactly `git log --oneline "$BASE"..HEAD`, one commit per phase plus the plan commit. Show it, with `git diff --stat "$BASE"..HEAD`.

The tree must be clean. If `git status --short` shows anything, a phase closed without committing or someone edited by hand — report it and ask whether to include it before going on; do not sweep it in silently.

**On a programme (`.phased/roadmap.md` exists): the roadmap check.** Compare
what this macro actually built — the diff above, read against the plan's
`Must not break:` lines — with the remaining macro-phases' mini-scopes:
every shape a later macro would have to undo or work around is a finding
(`contracts.md` → *Must not break:*). Where the roadmap declares an `Ends at:`
for this macro, compare it with the state actually delivered — a leg about
to close in Puglia is caught at the close of the leg, not at the departure
of the next. Contracts in transit across this macro — produced by an
earlier one, consumed by a later one — are checked the same way: lost
luggage is a finding. This is the last cheap moment to act — the next macro is
planned against this commit. Findings feed Step 5's
review as explicit focus points and the closing report; deep measurement
(retro-fitted contract tests against the landed code) belongs to `/doctor`,
not here.

Consolidation happens at Step 8, once the review has passed, and its shape depends on Step 1:

- **Dedicated branch** — the branch *is* the workflow, so the parent takes it whole with `git merge --squash`. Nothing to reset here.
- **Adopted branch** — the commits before `BASE` are not yours: `git reset --soft "$BASE"^` collapses only the workflow, leaving them untouched.

## Step 5: Pre-commit review

**When the plan lives in another checkout (its own worktree), or the cwd is outside the plan's root**, do not review in-session: silently run the shipped verify agent in a clean sub-session at the plan's root —

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agent-session.sh" finalize-workflow-agent
```

— and read its report (stdout, teed to the plan's `log/finalize-workflow-agent.txt`). Its prompt ships in the plugin, not composed here: that is what keeps the review independent. Treat its FINDINGS exactly like the in-session review's below, and its VERIFY-NOTES as Step 2's `> Verify:` collection. The agent never touches history; every decision stays here, with the user.

**Otherwise** (the plan is in this root, no worktree of its own), the review runs in-session via the built-in `code-review` skill (Skill tool) — never with `--fix` — and its depth is the user's call, not a guess. Ask ONE `AskUserQuestion` — **Extended** / **Light** / **None** — and compute the recommended option from what finalize already knows:

- **The QA pass exercises the deliverable** (Step 2's checks cover what the workflow built, and the user does them — a human eye lands on the result) → recommend **Light**. Every phase was already verified in isolation — in interactive runs by the user as each diff landed — so what nobody has seen is the diff as a whole. Light hunts exactly that residue and nothing else: effort `low`, scoped to **cross-phase issues only** — one phase breaking another's assumption, helpers duplicated by sessions unaware of each other, naming or pattern drift between phases.
- **Nothing a human will exercise** (internal work with no QA check on the deliverable, or the user declined the QA pass) → recommend **Extended**: this review is the only eye on the work. Whole diff, effort `medium` — `high` when the plan is `Mode: autonomous`.
- **`> Review:` notes on any phase, or a `## Run inspection` section in `notes.md`** → recommend **Extended** regardless (nobody read that code as it landed), effort `high`. Whatever the user picks, those notes are never dropped: Extended and Light take each one as an explicit focus point that must come out confirmed or explicitly dismissed; **None** presents them raw, for the user to judge alone.
- **None** is always on offer, its price stated in the option itself: nobody — the user included — has seen the whole diff at once, and the workflow closes without that pass.

Extended also hunts cross-phase issues — Light's whole scope is a subset of Extended's.

**Large autonomous diffs:** add a fourth option, **Panel**, and recommend it in place of Extended — 4 dimensions (correctness, cross-phase coherence, pattern conformance, test coverage) in parallel, each finding then verified by 3 independent skeptics prompted to *refute* it, keeping only what survives a majority. Read-only, under ~15 agents, never edits source.

The worktree path above is exempt from the question: the agent's prompt ships fixed in the plugin, and that is what keeps its review independent.

Findings → present them per `foreman.md` → *The reporting register*: the short form (verdict line, one line per finding, its consequence for the user), passed through the `report-judge` comprehension probe before showing — **skip the probe when the review returns no findings**: a clean verdict line has nothing to misread — delivered as the register's report page where the session can render one. Then ONE question — *"The pre-commit review found N problems. Fix them first, or shall I go on to the commit?"* (recommended: fix first) — on the degraded chat-only path with the register's detail option folded in (*Expand the details before deciding*), never as a second question. Fixing is delegated, not done here; then re-run `/finalize-workflow`.

This step is the only whole-diff review on the "Merge into parent" and "Commit only" paths — `/pull-request` adds a maintainer-grade one only on the PR path.

## Step 6: Capture durable lessons

**This step is mandatory and runs before anything is archived or removed.** `.phased/` never reaches the parent, and the workflow branch is deletable at Step 8 — so this is the only path by which anything learned during the run outlives it. Skipping it silently is how the loop stops learning across runs.

Scan the plan and its `notes.md` for: `> Repaired:` notes (a root cause *plus why earlier attempts missed it* — the highest-value kind, it encodes a trap); the per-phase `## Phase N` rationale entries the executing chats left there (`foreman.md` → *The foreman*) — that file is how the run's reasoning outlives its executor chats; `new-pattern` phases that landed cleanly (now there IS a reference); `> Review:` findings that revealed a convention rather than a one-off; and pattern references that proved **wrong**.


One bar: **would this have saved a future session real work, in a way the repo and git history don't already say?** Framework quirks, non-obvious API behaviour, "we do it like X here" → yes. Bugs specific to this diff, anything visible by opening the file → no.

Nothing clears the bar → say so explicitly, in one line, naming what you scanned. Something does → propose it via AskUserQuestion with a draft title and a two-line summary, and on approval write it wherever this project keeps durable know-how, following whatever your global rules say about that. Prefer correcting an existing entry over adding a near-duplicate. Never publish without approval.

## Step 7: Archive the plan

The run is over and its lessons are out. Move the plan directory into the archive and commit it on the workflow branch:

```bash
git mv .phased/active/<slug> .phased/done/<slug>
git commit -q -m "wf: archive plan for <slug>"
```

It stays on this branch — logs, notes and phase history included — and never reaches the parent. If `.phased/roadmap.md` exists, leave it in place: the next macro-phase is written against it.

## Step 8: Close out

Build the commit message from the objective, the completed phases, the actual diff and the issue (`fixes #N`):

```
<type>: <concise summary>

<detailed description, grouped logically>

[Fixes #N]
```

Present it, then ask ONE `AskUserQuestion` — choosing a path approves the message as shown, so say right above the question that edits to the message are welcome before choosing:

- **Pull request** (Recommended) — clean branch off the parent, squash, PR to `<parent-branch>`
- **Merge into parent** — squash straight onto `<parent-branch>` and push
- **Commit only** — leave the branch as it is, decide later

One gate, not two: approving the commit message separately was a second round-trip that bought nothing.

**Merge into parent** → from the main repo (`git worktree list --porcelain | head -1 | sed 's/worktree //'`): switch to the parent, pull, then

```bash
git merge --squash <workflow-branch>
git rm -r -f .phased
git commit    # the message approved above
git push
```

On an **adopted branch** there is nothing to squash onto the parent — the workflow is consolidated in place:

```bash
git tag "wf-archive/<slug>" HEAD     # keep the per-phase history reachable
git reset --soft "$BASE"^
git rm -r -f .phased
git commit                           # the message approved above
```

The commits that preceded `BASE` stay exactly as they were; the branch then reaches the parent by the ordinary merge or PR.

**Say the trade-off out loud before doing it.** Consolidating in place drops the per-phase commits and the archived plan from the branch — unlike the dedicated-branch path, no separate branch is left holding them. The tag is what keeps them reachable (`git log wf-archive/<slug>`), and Step 6 is what carries the lessons out regardless. Delete the tag once the work is merged and the history is no longer wanted.

**Pull request** → branch off the **parent**, not off the workflow branch, so the PR carries one commit and no `.phased/`:

```bash
git switch <parent> && git pull
git switch -c <type>/<slug>
git merge --squash <workflow-branch>
git rm -r -f .phased
git commit
git push -u origin <type>/<slug>
```

Then: *"Branch pushed. Launch `/pull-request` to open the PR to `<parent>`."*

**Commit only** → nothing else happens; the workflow branch holds everything.

Whichever path ran: send the foreman the closing `workflow finalized` message per `foreman.md` → *The foreman* — best-effort. `list_sessions` excludes the current session, so when this chat IS the foreman the title lookup finds nothing and the skip is automatic.

After the first two, offer to delete the workflow branch and its worktree (default: yes) — `git worktree remove .claude/worktrees/<slug>` + `git branch -D <workflow-branch>`. **Unless `.phased/roadmap.md` still lists unstarted macro-phases:** then keep the branch, say why, and remind the user *"The roadmap has further macro-phases. Next step: a new chat and `/write-workflow` to detail the next one — with the hindsight of the one just committed."* If `IN_WORKTREE`, remind the user that the worktree itself is plain git: `git worktree list` shows the stale ones, `git worktree remove <path>` clears them.

## Rules

- **NO source code editing** — report findings, delegate fixes. The one exception is Step 3's naming review: renames the user chose and marker removal, committed as its own `wf:` commit
- Show what will happen before any git operation; be especially careful with resets
- Never delete the workflow branch before Step 6 has run: it is the only thing carrying the run's lessons out
