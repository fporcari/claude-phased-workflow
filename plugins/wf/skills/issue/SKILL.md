---
description: Load and analyze a GitHub issue — analysis only, the work plan is created via /write-workflow
argument-hint: <issue-number>
disable-model-invocation: true
allowed-tools: Bash(gh:*), Read, Grep, Glob
---

# GitHub Issue #$1

**Language rule:** All written content must be in English; the conversation follows the user's own configuration (`${CLAUDE_PLUGIN_ROOT}/refs/common.md` → *Language*).

**IMPORTANT: This command is for ANALYSIS ONLY. Do NOT edit source code or implement anything. Use `/write-workflow` to create the work plan.**

## Step 1: Fetch issue

```
gh issue view $1 --json title,body,labels,state,comments --jq '{title,body,labels: [.labels[].name],state,comments: [.comments[].body]}'
```

## Step 2: Analyze

1. **Understand the issue**: problem, expected behavior, reproduction steps
2. **Explore the codebase** to identify relevant files, components, and existing tests
3. **Assess scope — one session or a workflow?** A workflow pays only when one of three holds: the work does not fit one context; an intermediate result changes what comes next, so a human gate is owed between phases; it must run unattended, with checkpoints and repair. A fix whose decisions the issue already settles and whose diff reads in one sitting meets none: ONE fresh chat with a complete prompt (`fable` or `opus`, `high`), no plan — the same recon and the same `Done:` give it the same quality, in a context that knows the whole diff. Measured on the field: a 3-phase plan whose whole diff was 7 files ran as a relayed autonomous workflow and grew to 13 phases through two quality-check rounds; the same fix was one session.

## Step 3: Present and hand off

Present to the user a summary of:
- What the issue is about
- Which files/components are involved
- Estimated complexity, and the verdict of Step 2.3: one session, or a workflow, and why

Then close flat, with no question — this command cannot create the plan itself, so asking *"shall I go ahead?"* promises something it cannot do. The closing line follows the verdict:

- **One session** → *"Next step: one fresh chat, no workflow — here is its prompt."* and the prompt itself: the issue's decisions, the files found in Step 2, the tests to run, the Done criterion. A user who still wants a plan launches `/write-workflow` on their own.
- **Workflow** → *"Next step: launch `/write-workflow` to create the work plan (in this chat or a new one — the analysis stays readable here)."*

## Additional Context

- Issue number: $1
- Full arguments: $ARGUMENTS
