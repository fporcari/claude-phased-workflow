---
description: Locate the active phased workflow and report where it stands, then name the skill that takes it forward. The entry point of the phased-workflow plugin, and the only skill in it the agent may reach on its own. Use when the user asks where the work stands, what the next phase is, whether a workflow is running, why a phase is stuck or failed, how to resume after an interrupted session, or mentions `.phased/` or a `wf/` branch.
allowed-tools: Bash(git:*), Bash(python3:*), Read, Edit, Grep, Glob, AskUserQuestion
---

# Resume Workflow

Supervision and resume view of the work plan. **Read-only on source code** — the only files this command may modify are the plan and `notes.md`, and only on an approved edit; each such edit gets its own `wf:` commit.

A healthy workflow is a valid reason to run this: when nothing is broken it early-exits with the state report and nothing to resume.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start — language, AskUserQuestion style, plan directory, workflow branch.

## The map

Every other skill in this plugin is **user-invoked**: only the user typing its name reaches it. Naming the right one is part of this skill's job — in Step 3's *Prossimo passo*, and whenever the user asks what to run.

| Skill | Reach for it when |
|---|---|
| `/scope-workflow` | the work is still vague — settle the decisions before planning |
| `/write-workflow` | there is no plan yet, and the work was just discussed |
| `/import-workflow` | a plan or handoff document already exists outside `.phased/` |
| `/issue` | the work starts from a GitHub issue (analysis only) |
| `/execute-phase` | run the next phase in this chat, with an approval gate |
| `/run-workflow` | run every remaining phase unattended (`Mode: autonomous` plans) |
| `/repair-phase` | a phase is `[!]` and needs fresh eyes |
| `/finalize-workflow` | every phase is `[x]` — consolidate into one commit |
| `/pull-request` | the branch is ready to open a PR |

## Step 1: Find the plan and the base

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
git log -1 --diff-filter=A --format=%H -- <plan path>
```

No active plan → stop: `/write-workflow` creates one, `/import-workflow` adapts an older one. Since the plan lives on the workflow branch, check `git branch --show-current` before concluding there is no work — and check `--plans` first: the workflow may live in another checkout or on a branch with no checkout at all (`common.md` → *Plan location*); anchor every command to the plan's root with `git -C`.

The third command gives `BASE`, the commit that added the plan. Everything after it is this workflow; everything before it is not — on an adopted branch that distinction is the whole point.

## Step 2: Attribute the work

Each completed phase committed its own work, so attribution is **exact — never infer it**:

```bash
git log --oneline "$BASE"..HEAD
git show --stat <phase commit>
```

For each `[x]` phase, compare its commit's files against its own `> Files:` note. For each pending phase, there is simply no commit yet.

Then look at `git status --short`. **A clean tree is the normal state.** Uncommitted changes are legitimate only while a phase is `[>]` — anything else is a finding, not context: a session that died before committing, or hand edits nobody recorded.

Two distinct kinds of drift, and they mean different things:

1. **Unlisted files** — inside a phase's commit but absent from its `> Files:`. The work landed but the record is wrong, which silently breaks later baseline attribution and `/repair-phase`.
2. **Uncommitted leftovers** — in the tree, in no commit, with no `[>]` phase to explain them.

Flag a phase as **oversized** when its commit spans more than ~10 files, covers unrelated areas (model + UI + tests for different features), or is too large to review as one commit. **Exception:** a `vast` phase is intentionally whole — that size is by design, never propose re-phasing it for size alone. For a pending phase the same judgment is a projection from its `Files:`, not a measurement; say which one you are making.

## Step 3: Report (in Italian)

1. **Stato del piano** — every phase with its marker. For `[>]`, show the timestamp and flag anything older than 2h: *"in esecuzione da oltre 2 ore — la chat precedente potrebbe essere terminata"*.
2. **Commit del workflow** — `git log --oneline $BASE..HEAD`, one line per phase, with the files each touched.
3. **Copertura** — per `[x]` phase: does its commit match its `> Files:`? Per pending phase: still to do.
4. **Drift** — the two kinds above, kept apart.
5. **Fasi sovradimensionate** — for each, what its commit already contains, what remains, and a proposed split into sub-phases.
6. **Prossimo passo** — continue (`/execute-phase` or `/run-workflow`), repair (`/repair-phase` on a `[!]`), re-phase, finalize, or clean up drift.

**Healthy plan → stop here.** No `[!]`/`[~]`, no stale `[>]`, no drift: the report ends with the next step and nothing to resume — no questions asked.

Something needs action → propose it via AskUserQuestion: reset a stale `[>]` to `[ ]`, apply a re-phasing, or hand the `[!]` to `/repair-phase`.

## Step 4: Apply approved plan edits (only if approved)

- **Stale `[>]` reset** — back to `[ ]` with `> Execution interrupted, phase available for retry`.
- **Re-phasing** — replace the oversized phase with the split sub-phases, marking the completed ones `[x]` and leaving the rest `[ ]`.

The plan is a tracked file, so each edit needs its own commit — it belongs to no phase:

```bash
git add .phased && git commit -q -m "wf: <what changed>"
```

Leaving it uncommitted would break the clean-tree invariant the next phase's baseline check relies on.
