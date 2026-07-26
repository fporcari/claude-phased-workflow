---
description: Check the current status of the work plan phases
allowed-tools: Bash(git:*), Read, Edit, Grep, Glob, AskUserQuestion
---

# Check Phase Context

Supervision view of the work plan. **Read-only on source code** — the only file this command may modify is the memory file, and only on an approved re-phasing.

**Shared conventions:** read `~/.claude/workflow-refs/common.md` once at start — language, AskUserQuestion style, MEMORY.md path resolution.

## Step 1: Find the plan

```bash
git rev-parse --show-toplevel
git worktree list --porcelain
```

In a worktree → `<repo_root>/.claude/MEMORY.md`. In the main repo → also check `memory_*.md` and `.claude/worktrees/*/`; one plan with active `- [ ]` phases → use it, several → AskUserQuestion (default `MEMORY.md`; for a worktree plan, run the git commands from that path).

## Step 2: Compare the tree against the plan

Read `git status --short`, `git diff HEAD --stat` and `git diff HEAD` (on a large diff, work from `--stat` and read the most relevant files individually).

For each phase, decide whether the uncommitted changes cover it **fully / partially / not at all**, and identify changes that match no phase (drift).

Flag a phase as **oversized** when its changes span more than ~10 files, cover unrelated areas (model + UI + tests for different features), or are too large to review as one commit. **Exception:** a `vast` phase or a `group:N` run is intentionally whole — that size is by design, never propose re-phasing it for size alone.

## Step 3: Report (in Italian)

1. **Stato del piano** — every phase with its marker. For `[>]`, show the timestamp and flag anything older than 2h: *"in esecuzione da oltre 2 ore — la chat precedente potrebbe essere terminata"*.
2. **Modifiche non committate** — changed files grouped by the phase they belong to.
3. **Copertura fasi** — fully/partially/not covered, per pending phase.
4. **Drift** — changes matching no phase.
5. **Fasi sovradimensionate** — for each, what is complete and committable now (with a proposed commit message), what remains, and a proposed split into sub-phases. Ask via AskUserQuestion whether to apply it.
6. **Parallel groups** — which `parallel:N` groups exist and their state.
7. **Prossimo passo** — commit, continue, re-phase, or update the plan.

## Step 4: Apply the re-phasing (only if approved)

Replace the oversized phase in the memory file with the split sub-phases, marking the completed ones `[x]` and leaving the rest `[ ]`.

No memory file, or all empty → tell the user to run `/write-workflow` first.
