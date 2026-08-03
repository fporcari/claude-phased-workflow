---
description: Import an existing plan or a handoff document into a .phased/ workflow
argument-hint: <path to the source, or nothing to look for one>
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(mkdir:*), Bash(python3:*), Read, Grep, Glob, Write, AskUserQuestion
---

# Import Workflow

Turn an existing plan or a handoff document into a `.phased/` workflow. This is an **adapter, not a planner**: it maps what the source already says onto the plan format and reports what is missing. It never invents phases, and it never writes source code.

**Shared conventions:** read `${CLAUDE_PLUGIN_ROOT}/refs/common.md` once at start — language, AskUserQuestion style, plan directory, workflow branch.

Typical sources: a pre-4.0 `.claude/MEMORY.md`, a parallel `memory_<name>.md` from the same era, or a free-form handoff written by a previous session or another person.

## Step 1: Find the source

`$ARGUMENTS` names it → use that. Otherwise look, in order, for `.claude/MEMORY.md`, `.claude/memory_*.md`, then any handoff-looking markdown the user points at. Several candidates → AskUserQuestion. Nothing → stop: *"Non trovo niente da importare. `/write-workflow` scrive un piano nuovo."*

`.phased/active/` already occupied → stop. One branch, one plan.

## Step 2: Classify the source

One question decides Step 4: **does the source contain phases already marked `[x]`?** Getting it wrong is the one way this skill can destroy work, so do not eyeball the markers — ask the parser that already reads them:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/next-phase.py" <source>
```

It prints one line per phase with its state, and it works unchanged on a pre-4.0 `MEMORY.md` — the phase-line format did not change. It also fails loudly if the source is not a parsable plan, which is worth knowing before touching anything.

- **No `[x]` in the table** (and always, for a handoff document, which has no phases at all) → *fresh import*. The work has not started.
- **Any `[x]`** → *mid-run import*. The work already exists in the tree and in old-style commits.

The script erroring out (an unparsable source, a handoff) is not a classification — read the source yourself and treat it as a fresh import. Genuinely ambiguous markers → mid-run, which is the conservative side: it never rewrites history.

Then read the whole source, for the mapping in Step 3.

## Step 3: Map onto the plan format

Produce the plan in the `/write-workflow` format — same `Pattern:` / `Files:` / `Decisions:` / `Details:` / `Done:` fields, same phase markers.

**Preserve, do not rewrite.** Phase states (`[x]`, `[!]`, `[~]`, `[>]`) and every note the source carries — `> Done:`, `> Files:`, `> Issue:`, `> Attempted:`, `> Repaired:`, `> Review:`, `> Verify:` — come across verbatim. They are the record of what happened; re-deriving them would be inventing history. A `## Roadmap` section in the source moves to `.phased/roadmap.md`, and a `## Suggested execution config` table comes across as-is.

A handoff document has no phases yet: derive them from what it describes, and say plainly that you did — this is the one case where the import is also an act of planning, and the user should review it as such.

**Then report the gaps, don't fill them.** Check every remaining `[ ]` phase against the autonomous-ready bar (`/run-workflow` pre-flight): concrete and verifiable, bounded scope, measurable `Done:`, decisions pre-made, `Pattern:` cited for non-trivial code. Present what is missing, per phase, in Italian:

```
Phase 3 — manca Done: misurabile ("funziona bene" non è verificabile)
Phase 5 — nessun Pattern: e il codice non è banale
```

Inventing a plausible `Done:` for a phase whose author never wrote one is worse than leaving the gap visible: it looks settled and nobody checks it again. Offer to refine them now, one at a time, or to import as-is and leave `/write-workflow` to it.

**Then settle how it will run** — the same automation fork `/write-workflow` asks. If the source already carries a `Mode:` header, keep it (it is a decision the author already made). Otherwise ask the fork question and the derivation rule from `/write-workflow`'s *Step 2: The automation fork* — do not restate them here, that skill is the one source — and write the resulting header (`Mode: autonomous` or `Mode: interactive`) into the imported plan. The autonomous answer is what the gap report above feeds: an imported plan still below the autonomous-ready bar gets its gaps flagged, not hidden by the header.

## Step 4: Land it

Show the plan and get approval. Then, depending on Step 2:

**Fresh import** → same branch rules as `/write-workflow` Step 4 (*Open the branch*): on a base branch, `git switch -c wf/<slug>`; on a feature branch, adopt it by default, with `wf/<slug>` off it as the alternative.

**Mid-run import** → **adopt the current branch, no question, no rebase, no reset.** The completed phases correspond to work already in this tree and to commits already made; a fresh branch would strand them. Say so explicitly: *"Import in place su `<branch>`: le fasi già `[x]` corrispondono a lavoro già presente qui, quindi nessun branch nuovo e nessuna riscrittura della history."*

This is safe because the workflow's base is the plan commit, not the branch point (see `common.md`): the old commits land before it and therefore outside the workflow, so `/finalize-workflow` consolidates only what comes after and leaves them for the user to deal with — which is the honest outcome, since nothing can retroactively tell which of them belonged to which phase.

Then write and commit:

```bash
mkdir -p .phased/active/<slug>
# plan.md + empty notes.md
git add .phased && git commit -m "wf: import plan for <slug>"
```

Verify the commit is not empty (`git show --stat HEAD`).

**Leave the source file alone.** Deleting it is the user's call, and on a mid-run import it may still be what other tooling is reading. Say where it is and that it is now superseded.

## Step 5: Close

```
Importato in .phased/active/<slug>/plan.md (<N> fasi: <x> completate, <y> da fare), committato su <branch>.
Sorgente lasciata in <path> — superata, cancellala quando vuoi.
<gaps, if any>
Per continuare, lancia /execute-phase.
```
