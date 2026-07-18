# GitHub Issue #$1

**Language rule:** All written content must be in English. Conversation with the user remains in Italian as per global settings.

**IMPORTANT: This command is for ANALYSIS ONLY. Do NOT edit source code or implement anything. Use `/write-workflow` to create the work plan.**

## Step 1: Fetch issue

```
gh issue view $1 --json title,body,labels,state,comments --jq '{title,body,labels: [.labels[].name],state,comments: [.comments[].body]}'
```

## Step 2: Analyze

1. **Understand the issue**: problem, expected behavior, reproduction steps
2. **Explore the codebase** to identify relevant files, components, and existing tests
3. **Assess scope**: is this a quick fix or a multi-phase task?

## Step 3: Present and hand off

Present to the user (in Italian) a summary of:
- What the issue is about
- Which files/components are involved
- Estimated complexity

Then suggest: *"Vuoi che proceda con `/write-workflow` per creare il piano di lavoro?"*

If the user confirms, inform them to run `/write-workflow` in this or a new session — this command does not create the plan itself.

## Additional Context

- Issue number: $1
- Full arguments: $ARGUMENTS
