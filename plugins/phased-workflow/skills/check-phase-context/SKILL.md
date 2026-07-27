---
description: Check the current status of the work plan phases
allowed-tools: Bash(git:*), Bash(python3:*), Read, Edit, Grep, Glob, AskUserQuestion
---

# Check Phase Context

Supervision view of the work plan. **Read-only on source code** — the only file this command may modify is the plan, and only on an approved re-phasing.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start — language, AskUserQuestion style, plan directory, workflow branch.

## Step 1: Find the plan and the base

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" --resolve
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py"
git log -1 --diff-filter=A --format=%H -- <plan path>
```

No active plan → stop: `/write-workflow` creates one, `/import-workflow` adapts an older one. Since the plan lives on the workflow branch, check `git branch --show-current` before concluding there is no work.

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

Flag a phase as **oversized** when its commit spans more than ~10 files, covers unrelated areas (model + UI + tests for different features), or is too large to review as one commit. **Exception:** a `vast` phase or a `group:N` unit is intentionally whole — that size is by design, never propose re-phasing it for size alone. For a pending phase the same judgment is a projection from its `Files:`, not a measurement; say which one you are making.

## Step 3: Report (in Italian)

1. **Stato del piano** — every phase with its marker. For `[>]`, show the timestamp and flag anything older than 2h: *"in esecuzione da oltre 2 ore — la chat precedente potrebbe essere terminata"*.
2. **Commit del workflow** — `git log --oneline $BASE..HEAD`, one line per phase, with the files each touched.
3. **Copertura** — per `[x]` phase: does its commit match its `> Files:`? Per pending phase: still to do.
4. **Drift** — the two kinds above, kept apart.
5. **Fasi sovradimensionate** — for each, what its commit already contains, what remains, and a proposed split into sub-phases. Ask via AskUserQuestion whether to apply it.
6. **Parallel groups** — which `parallel:N` groups exist and their state.
7. **Prossimo passo** — continue, re-phase, finalize, or clean up drift.

## Step 4: Apply the re-phasing (only if approved)

Replace the oversized phase in the plan with the split sub-phases, marking the completed ones `[x]` and leaving the rest `[ ]`.

The plan is a tracked file, so this edit needs its own commit — it belongs to no phase:

```bash
git add .phased && git commit -q -m "wf: re-phase Phase N into <M> sub-phases"
```

Leaving it uncommitted would break the clean-tree invariant the next phase's baseline check relies on.
