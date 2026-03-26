---
description: Load a GitHub issue and create an operational context to solve it
argument-hint: <issue-number>
allowed-tools: Bash(gh:*)
---

# GitHub Issue #$1

**Language rule:** All written artifacts (issue title, body, labels) must be in English. Conversation with the user follows the language they initiated the conversation in.

## Issue Details

Fetch issue details using GitHub CLI:

```
gh issue view $1
```

## Instructions

After reading the issue:

1. **Analyze the issue**: Understand the described problem, any reported errors, and expected behavior

2. **Explore the codebase**: Find relevant files by searching for:
   - Code mentioned in the issue
   - Files related to the affected component/feature
   - Existing related tests

3. **Create a work plan**: Use TodoWrite to create a task list with:
   - Files to modify
   - Required changes
   - Tests to add or update

4. **Implement the solution**:
   - Follow project conventions
   - Keep changes minimal and focused
   - Add tests if needed

5. **Prepare the commit**: When requested, create a commit with message:
   ```
   Fix #$1: [brief fix description]
   ```

## Additional Context

- Issue number: $1
- Full arguments: $ARGUMENTS
