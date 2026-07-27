# How I Structured a Workflow for Claude Code That Scales Beyond a Single Session

Claude Code is incredibly capable — until you hit the context window wall. On a simple bug fix, it's perfect. On a multi-file, multi-phase feature? The conversation gets long, quality degrades, and eventually Claude forgets what it was doing three steps ago.

I built a system of slash commands that solves this. It's open source, works with any project, and turns Claude Code into something closer to a structured development partner.

## The Problem

If you've used Claude Code for anything non-trivial, you know the pattern:

1. You start describing the feature
2. Claude explores the codebase, reads files, asks questions
3. You start implementing together
4. Around phase 3 of 5, Claude starts losing context
5. You end up re-explaining decisions from earlier in the conversation
6. Context compaction kicks in and wipes important details

The root cause is simple: a single chat session is the wrong abstraction for complex development work. You need **multiple sessions** with **shared state**.

## The Solution: File-Based State, Disposable Sessions

The core idea: use a Markdown file (`MEMORY.md`) as the coordination point between independent Claude Code sessions. Each session starts fresh with full context, reads the plan, executes one phase, updates the plan, and exits.

The workflow has six commands:

```
/create-context <topic>   -- create branch + worktree + VS Code
[free conversation]       -- discuss the work naturally
/write-workflow           -- crystallize the conversation into a plan
/execute-phase            -- execute one phase per session
/check-phase-context      -- verify state (optional supervision)
/finalize-workflow        -- single clean commit + PR or merge
/close-context            -- remove worktree + close VS Code (branch stays)
/clean-contexts           -- bulk cleanup of old worktrees
```

## A Typical Session

Let's say I need to add PDF export to an invoicing system.

**Step 1: Create the workspace**

```
/create-context add PDF export for invoices
```

Claude creates a branch (`feat-add-pdf-export`), a git worktree in `.claude/worktrees/feat-add-pdf-export/`, and opens VS Code. The worktree is an isolated copy of the repo on its own branch — nothing I do here affects any other work.

**Step 2: Talk it through**

I open a terminal in the worktree and start a Claude session. No special commands — just a conversation:

"I need to generate PDF invoices. The data comes from the invoice model. The PDF should have a header with the company logo, line items as a table, and totals at the bottom. We already use ReportLab for other reports."

Claude explores the codebase, asks about the existing ReportLab patterns, and we converge on an approach.

**Step 3: Crystallize the plan**

```
/write-workflow
```

Claude synthesizes our conversation into a structured `MEMORY.md`:

```markdown
# Context: feat-add-pdf-export
Parent: develop | Issue: #42

## Objective
Add PDF export for invoices using the existing ReportLab setup.

## Work Plan
- [ ] **Phase 1**: Create InvoicePDFRenderer service
  - Details: New class based on existing BaseRenderer pattern
  - Files: src/services/invoice_pdf.py
- [ ] **Phase 2**: Add /api/invoices/{id}/pdf endpoint
  - Details: GET endpoint returning PDF binary
  - Files: src/api/invoices.py
- [ ] **Phase 3**: Add tests
  - Details: Unit tests for renderer, integration test for endpoint
  - Files: tests/test_invoice_pdf.py

## Suggested execution config
| Phase | Effort | Model |
|-------|--------|-------|
| Phase 1 | high | opus |
| Phase 2 | medium | sonnet |
| Phase 3 | medium | sonnet |
```

**Step 4: Execute phase by phase**

Each phase gets its own fresh session:

```
/execute-phase
```

Claude reads `MEMORY.md`, finds the first unchecked phase, implements it, asks me to verify, and updates the plan with what was done and which files were modified.

Then I close the session and start a new one for the next phase. Fresh context every time.

**Step 5: Finalize**

When all phases are done:

```
/finalize-workflow
```

Claude verifies everything is complete, stages the files, creates a single clean commit, and offers to create a PR or merge directly.

**Step 6: Clean up**

```
/close-context
```

Once the PR is created (or immediately after finalizing if you have already pushed), run `/close-context` from inside the worktree. It removes the worktree directory and closes the VS Code window. The git branch is not touched -- it stays available for the PR. Closing a context is not the same as deleting a branch. The context is the workspace; the branch is a git concern.

For bulk cleanup, `/clean-contexts` runs from the main repo and shows all worktrees with their status (last commit, plan progress, merged or not, disk usage). You check the ones to remove and it handles the rest.

## The Key Insight: Worktrees for Parallel Work

This is where it gets interesting. Git worktrees create isolated working directories, each on its own branch. Since `/create-context` works from **any branch**, you can create sub-tasks from a feature branch:

```
[on develop]
/create-context auth refactor          -- creates feat-auth-refactor branch

[on feat-auth-refactor]
/create-context refactor login flow    -- worktree A
/create-context refactor sessions      -- worktree B
/create-context refactor tokens        -- worktree C
```

Now you have three independent workspaces, each with its own `MEMORY.md`, its own VS Code window (with a unique title bar color so you can tell them apart), and its own branch.

Work on any of them. When a sub-task is done, `/finalize-workflow` offers to merge it back to the parent feature branch. When all sub-tasks are merged, the parent branch becomes a PR toward develop.

This is the same branching strategy a team of developers would use — except it's one developer with multiple Claude Code sessions.

## Why Not Just Use Cursor/Devin/Windsurf?

Those tools do similar things internally — they plan, execute, checkpoint. The difference is transparency and control.

With this workflow:

- **You see the plan** before execution starts. It's a Markdown file you can edit.
- **You verify each phase** before it's marked done. Claude waits for your confirmation.
- **You choose the model** per phase. Use Opus for the hard parts, Haiku for the easy ones.
- **You control the commit**. One clean commit per workflow, not a trail of auto-commits.
- **You can intervene**. Edit `MEMORY.md` to re-phase, skip, or reorder.

It's the difference between riding a self-driving car and flying a plane with autopilot. You're still the pilot.

## Design Decisions

**Why doesn't `/execute-phase` commit?**

Because the commit is a whole-workflow concern. `/finalize-workflow` sees everything — all phases, all files — and creates one clean commit with a proper message. The only exception is a WIP safety commit when the context window is running low, so you don't lose work between sessions.

**Why a separate `/write-workflow` instead of planning during `/create-context`?**

Because planning is a conversation, not a form. You need to explore code, ask questions, discuss trade-offs. Forcing that into a structured command felt wrong. Now you just talk to Claude naturally, and `/write-workflow` captures the result.

**Why worktrees instead of branches?**

A branch is just a pointer. A worktree is an actual separate directory with its own files. When you have two worktrees, you can have two VS Code windows open simultaneously, each showing different code. `git add -A` in a worktree is safe — everything there belongs to that workflow.

## Try It

The plugin is open source:

**GitHub:** [github.com/fporcari/claude-phased-workflow](https://github.com/fporcari/claude-phased-workflow)

**Install from Claude Code:**

```
/plugin marketplace add fporcari/claude-phased-workflow
/plugin install phased-workflow
```

Or add to your project's `.claude/settings.json`:

```json
{
  "plugins": {
    "marketplaces": ["fporcari/claude-phased-workflow"],
    "installed": ["phased-workflow@fporcari/claude-phased-workflow"]
  }
}
```

The README has full documentation, diagrams, and a FAQ.

---

*I'm Francesco Porcari, one of the main contributors to [GenroPy](https://github.com/genropy/genropy) since its first commit. I build developer tools and web applications at Softwell. If you have feedback or want to contribute, open an issue on the repo.*
