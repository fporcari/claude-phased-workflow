---
description: Create a new GitHub issue following genropy templates
argument-hint: <type: feature|bug|task>
allowed-tools: Bash(gh *), AskUserQuestion
---

# Create New GitHub Issue

Requested type: **$1**

**Language rule:** Issue content (title, body) must be in English. Conversation with the user remains in Italian as per global settings.

## Instructions

Create an issue on the current repository. Based on the specified type ($1), ask appropriate questions using AskUserQuestion, then create the issue with `gh issue create`.

### Supported types:

**feature** (or feature-request):
- Summary (required): Brief feature description
- Problem or Need (required): Problem or need this feature solves
- Proposed Solution (required): Proposed behavior
- Considered Alternatives (optional): Alternatives considered
- Impact and Scope (required): Who benefits and where it applies
- Additional Information (optional)

Label: `enhancement`
Title: `[FEATURE] {summary}`

**bug** (or bug-report):
- Problem Description (required): Problem description and expected behavior
- Reproduction Steps (required): Steps to reproduce
- If Cannot Be Reproduced Externally (optional): Details if not reproducible
- Environment (required): Version, OS, browser
- Additional Material (optional): Screenshots, logs

Title: `[BUG] {summary}`

**task**:
- Summary (required): Brief task description
- Objective (required): Purpose and expected result
- Scope (optional): What is included/excluded
- Technical Details (optional): Technical notes
- Dependencies (optional): Related issues, dependencies
- Acceptance Criteria (optional): Completion criteria
- Additional Information (optional)

Label: `task`
Title: `[TASK] {summary}`

## Process

1. Verify the type is valid (feature, bug, task)
2. Use AskUserQuestion to collect required information from the template
3. Compose the issue body in markdown
4. Create the issue with:
   ```
   gh issue create --title "[TYPE] summary" --body "..." --label "label"
   ```
5. Show the created issue link

## Notes

- Ask required questions first, then optional ones
- If the user does not specify a valid type, ask which type they want
- Target repository is the current one (working directory)
