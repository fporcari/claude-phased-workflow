---
description: Quality check of the finished workflow — QA pass with the user, naming review, whole-diff review at chosen depth, ONE consolidated correction batch verified once; stamps the plan for /finalize-workflow
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(cd:*), Bash(head:*), Bash(sed:*), Bash(grep:*), Bash(python3:*), Bash(bash:*), Read, Grep, Glob, Write, Edit, AskUserQuestion, Skill, Agent, SendUserFile
---

# Quality Check

The quality half of closing a workflow: verify the plan is complete, put the QA checks in the user's hands, review the whole diff at the depth the user chooses, fix what came out in ONE batch, verify that batch once, and stamp the plan with the outcome. `/finalize-workflow` reads the stamp and does the rest — lessons, archive, consolidation. The shape is the anti-loop: every finding of every source — the user's QA, the naming review, the whole-diff review — lands in one table at one revision, is fixed in one commit, and is verified once over its own delta. Measured on the field (the 6.35.0 changelog carries the numbers): a phase per finding grew a 3-phase plan to 13, and a second high-effort review after the fixes found ten more things on the new diff. Neither happens here.

**Never edit source code here** beyond the one final touch of Step 5 — corrections on decisions already taken: the user's naming decisions plus marker removal, the defects the QA pass surfaced, the review's confirmed findings. What needs a decision nobody gave is asked in one sentence; what needs a surface nobody built is reported and goes to `/resume-workflow` as ONE phase for all such findings together (`foreman.md` → *The foreman*, the QA-fix exception).

**Usage:** `/quality-check` — or `/quality-check light|extended|panel|none` to pre-answer Step 3's depth question (the argument is the user's call made early; everything else still runs).

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md`, `${CLAUDE_PLUGIN_ROOT}/refs/contracts.md`, `${CLAUDE_PLUGIN_ROOT}/refs/foreman.md` and `${CLAUDE_PLUGIN_ROOT}/refs/execution-policy.md` once at start — core conventions, the contract layer (verify.md, markers, the stamp, Must not break:), the reporting register, the correction-and-review budget.

## Step 1: Find the plan, the base and the previous evidence

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve
git branch --show-current
git worktree list --porcelain
```

No active plan → stop; the plan lives on the workflow branch, so check `git branch --show-current` before concluding there is nothing to check — and check `--plans` first: the workflow may live in another checkout (`common.md` → *Plan location*). When it does, every git command below runs `git -C <plan root>` and every path is anchored there.

Read the plan, `notes.md`, `verify.md` and `review.md` where present. Then:

```bash
BASE=$(git log -1 --diff-filter=A --format=%H -- <plan path>)   # the commit that ADDED the plan
REVIEW_HEAD=$(git rev-parse HEAD)                                 # what this check reviews
git status --short
git log --oneline "$BASE"..HEAD
git diff --stat "$BASE"..HEAD
```

`BASE` is the workflow's base: everything after it belongs to this run, everything before it does not (the consolidation shape — dedicated vs adopted branch — is `/finalize-workflow`'s concern). The workflow is exactly that log — the plan commit plus, per phase, one phase commit and any `partial` commits before it (`refs/common.md`): group it by the `wf(phase N):` prefix and show one line per phase, naming its partials. **The tree must be clean.** Anything in `git status --short` means a phase closed without committing or someone edited by hand — report it and ask whether it belongs to the workflow before going on; never sweep it in silently.

All phases `[x]` → proceed. Otherwise report the incomplete ones (warn specifically that a `[>]` may be a dead session) and ask whether to check anyway (default: no); a check on an incomplete run names the missing phases in its report and in its stamp.

**A previous check.** `notes.md` may already carry a `## Final touch` ledger from an earlier run of this skill. It is evidence only for the revisions it names: when its correction commit is `HEAD`, this run resumes at Step 5's verification of that batch instead of a fresh whole-diff review; when commits landed after it, Step 3 reviews the delta since that revision plus the consumers of what changed, not the whole diff again. A ledger without revisions is not coverage — say so and review the whole scope.

## Step 2: Collect QA and naming findings — without editing yet

**The QA pass.** Collect every `Verify:` step from the plan — authored fields and `> Verify:` notes alike — *and* the whole of `verify.md` if it exists (the deferred checks the executing skill dated to a later phase — `contracts.md` → *Verification*). Deliver them as the **QA page** defined there: ONE checklist, grouped by phase, each check with the action to exercise and the result the user should see; a deferred step whose phase has since landed is now due. Phrase every item per `foreman.md` → *The reporting register*: the reader knows what the feature should do, not how the phases built it. Then ask whether they have been done — never a blocker, never silently skipped: if the user says no, say plainly that the stamp will record those checks as declined. **Keep the answer** (`done` / `declined` / `none`): it is an input of Step 3's recommendation and it lands in the stamp. `verify.md` is the sibling of `review.md`, not a duplicate: this list is what the user must *exercise*, `review.md` what they must *judge*. Present both.

**A defect the user reports while exercising the list is a finding**, with what they saw as its reproduction: it goes into Step 4's table with the rest, not into a commit of its own. One exception, so the QA can go on: a defect that blocks exercising the other checks is fixed at once, committed as `wf: qa fix — <one line>`, and recorded in `notes.md` under `## QA fixes` with its commit — already-landed evidence for Step 3, not a second batch.

**The naming map.** Autonomous runs accumulate `wf:phase-N:new` markers on the callables the phases created — nobody could answer a naming question mid-run (`contracts.md` → *New-method markers and minimality*). Collect them over the union of every phase's `> Files:` (`grep -rn "wf:phase-[0-9]*:new" <files>`); none → say so in one line. Found → build the map per `${CLAUDE_PLUGIN_ROOT}/refs/naming-review.md` for the whole workflow — ONE map, accept-all as the recommended fast path, decisions gathered once — but **apply nothing yet**: the renames, their call sites and the marker removal are rows of Step 4's table and land with the final touch. The ref's sweep still binds: a marker that survives Step 5 is a blocker named in the stamp, because it would reach the parent branch.

## Step 3: Review the whole scope — once

**On a programme (`.phased/roadmap.md` exists): the roadmap check.** Compare what this macro actually built — the diff above, read against the plan's `Must not break:` lines — with the remaining macro-phases' mini-scopes: every shape a later macro would have to undo or work around is a finding (`contracts.md` → *Must not break:*). Where the roadmap declares an `Ends at:` for this macro, compare it with the state actually delivered — a leg about to close in Puglia is caught at the close of the leg, not at the departure of the next. Contracts in transit across this macro — produced by an earlier one, consumed by a later one — are checked the same way: lost luggage is a finding. This is the last cheap moment to act — the next macro is planned against this commit. These findings are explicit focus points of the review below; deep measurement (retro-fitted contract tests against the landed code) belongs to `/doctor`.

**The depth is the user's call, not a guess** (an argument on the invocation IS that call, already made). AskUserQuestion offers Extended, Light and None — one question — with the recommendation computed from what this check already knows:

- **The QA pass exercised the deliverable** (Step 2's checks cover what the workflow built and the user did them — a human eye landed on the result) → recommend **Light**. Every phase was already verified in isolation, so what nobody has seen is the diff as a whole. Light hunts exactly that residue: effort `low`, scoped to **cross-phase issues only** — one phase breaking another's assumption, helpers duplicated by sessions unaware of each other, naming or pattern drift between phases.
- **Nothing a human will exercise** (internal work, or the user declined the QA pass) → recommend **Extended**: this review is the only eye on the work. Whole diff, effort `medium` — `high` when the plan is `Mode: autonomous`.
- **`> Review:` notes on any phase, a `## Run inspection` section in `notes.md`, or roadmap findings above** → recommend **Extended** regardless (nobody read that code as it landed), effort `high`. Whatever the user picks, those notes are never dropped: Extended and Light take each one as an explicit focus point that must come out confirmed, dismissed or deferred; **None** presents them raw, for the user to judge alone.
- **None** is always on offer, its price stated in the option itself: nobody — the user included — has seen the whole diff at once, and the stamp will say so. None waives the review, never the QA answer or the stamp.

**Large autonomous diffs:** add a fourth option, **Panel**, and recommend it in place of Extended — ONE whole-diff reviewer plus **at most one** specialist for a distinct material risk the diff visibly carries (a migration, a concurrency change, a public API), each read-only over `BASE..HEAD`, each returning its findings in the `MECHANICAL:`/`JUDGMENT:` shape the shipped judges use, most severe first, or exactly `NO FINDINGS`. A finding the two disagree on is settled by the line of the diff that proves it, never by vote — and a finding that cannot be shown a line is presented as unverified, labelled so. (The 16-agent panel this replaces — four dimensions and three skeptics per finding — bought its recall at a price the final touch then paid again in corrections; one reviewer with the whole diff and one specialist where the risk is visible is the bound.)

**Where the review runs.** The plan in this root, no worktree of its own → in-session via the built-in `code-review` skill (Skill tool) at the chosen effort — never with `--fix`. The plan in another checkout, or the cwd outside its root → do not review in-session: run the shipped verify agent in a clean sub-session at the plan's root —

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/agent-session.sh" quality-check-agent
```

— and read its report (stdout; the transcript is teed beside the plan's transport as `<transport>-quality-check-agent.log`). Its prompt ships in the plugin, not composed here: that is what keeps the review independent, and that path is exempt from the depth question. Treat its FINDINGS exactly like the in-session review's and its VERIFY-NOTES as Step 2's `> Verify:` collection. The agent never touches history; every decision stays here, with the user. A **resumed** check (Step 1 found a ledger) reviews the delta since the ledger's revision plus the consumers of what it touched — the same tools, the range narrowed — never the whole-diff pass again.

**Present** the findings per `foreman.md` → *The reporting register*: the short form (verdict line, one line per finding, its consequence for the user), passed through the `wf:report-judge` comprehension probe before showing — **skip the probe when the review returns no findings**: a clean verdict line has nothing to misread — delivered as the register's report page where the session can render one.

## Step 4: One table — every finding, diagnosed, before any edit

Everything Steps 2 and 3 collected — the QA defects, the naming map, the review's confirmed findings, the roadmap findings — is checked against the real code and the contracts, grouped by root cause (one fix often answers several symptoms; grep the callers before proposing an edit), and laid out as ONE table:

| Finding (evidence) | Root cause | Fix and the consumers it touches | Verification | Road |
|---|---|---|---|---|

A defect needs a reproduction, a violated `Done:` or contract, or the line of code that shows it; a preference or a new requirement is labelled as such, never dressed as a defect. **Road** is one of three: *final touch* (the fix applies a decision already taken — the user's sentence, the plan's `Decisions:`, the pattern reference), *one sentence* (a decision the user has not given: ask it here, in one line, at this table — its answer moves the row to *final touch*), or *phase* (a surface the plan never built — a new table, page or migration). Rows on the *phase* road go to `/resume-workflow` as ONE phase for all of them together, never one each, and the table says so.

Then ONE question — *"The check found N problems. Fix them now, or stamp the check as it stands?"* (recommended: fix) — on the degraded chat-only path with the register's detail option folded in (*Expand the details before deciding*), never as a second question. The user's ok on the table is the approval of Step 5.

## Step 5: One final touch, one focused verification

Apply the approved rows — code fixes, renames with their call sites, marker removal — re-run the suite and the linter on the touched files after each root-cause group, and commit **once**:

```bash
git add -A && git commit -q -m "wf: final touch — <N> corrections"
```

Record the table in `notes.md` under `## Final touch` with the revision it reviewed (`REVIEW_HEAD`), the correction commit, the checks actually run and the rows left on the *phase* road: finalize's lessons pass reads it, and a later run of this skill resumes from it (Step 1). Then **the re-check, and only this one:** Light at effort `low` over the files the final touch touched plus the callers they serve, and the `verify.md` items those files serve re-exercised by the user — never Extended or Panel again on this branch: a second high-effort pass is the loop restarting. A residual defect it finds is not a fresh round: it is reported with its evidence, and the user chooses between one more bounded correction (same commit shape, `wf: final touch — +<M>`) and an explicit risk acceptance recorded in the ledger. Neither grows the plan.

This is the only whole-diff review on the "Merge into parent" and "Commit only" close-out paths — `/pull-request` adds a maintainer-grade one only on the PR path, over the delta since this check's revision.

## Step 6: Stamp the plan

Record the outcome as the stamp `/finalize-workflow` reads (`contracts.md` → *The quality-check stamp*): append to `plan.md`, under a `## Quality check` heading (created on first use, one line appended per run — the last line governs):

```
> Quality check: <ISO timestamp> — commit <short HEAD hash> — review <extended|light|panel|none|agent>, QA <done|declined|none>, findings <N confirmed, M dismissed | none>, final touch <N corrections | none>
```

The hash is HEAD at stamp time — it is what lets finalize detect a stale check when commits land after it. Residual findings and any risk the user accepted live in the ledger, not in the stamp line: finalize reads both. Commit the stamp alone:

```bash
git add .phased && git commit -q -m "wf: quality check — <review depth>"
```

Close with the stamp line repeated in chat and the next step: *"Quality check stamped. Next: `/finalize-workflow` to consolidate and close the branch."* — or, when rows took the *phase* road, `/resume-workflow` first.

## Rules

- **NO source code editing** beyond Step 5's final touch (and Step 2's blocking QA fix): corrections on a decided design, one commit. What needs a decision is asked in one sentence at the table; what needs a surface the plan never built goes to `/resume-workflow` as one phase
- A finding never blocks the stamp: the user decides to fix now or stamp as-is, and the stamp records what was found either way
- The stamp is written even when every answer was "no" — a declined QA and a `none` review are facts finalize must see, not omissions
- Every source of findings is reviewed once at one revision, fixed in one batch, verified once over its delta — never a phase per finding, never a second whole-diff review of unchanged scope
