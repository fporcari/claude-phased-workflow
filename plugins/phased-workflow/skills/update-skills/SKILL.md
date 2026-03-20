---
description: Update local skills from Sourcerer KB (preserves YAML frontmatter)
allowed-tools: Read, Write, Glob, AskUserQuestion, mcp__sourcerer__kb_get_skills, mcp__sourcerer__kb_get_skill_content, mcp__sourcerer__kb_get_topic_tree
---

# Update Skills from Sourcerer KB

Synchronize local slash command files with the latest content from the Sourcerer knowledge base. The YAML frontmatter (tool permissions, description) is preserved — only the body (instructions) is updated.

**Language rule:** Conversation with the user in Italian as per global settings.

## Step 1: Fetch skill catalog from Sourcerer

1. Call `kb_get_topic_tree` to locate the topic `Crew/Workflow/Phased Workflow`
2. If the topic does not exist, inform the user and stop
3. Call `kb_get_skills` for that topic to get the list of available skills

## Step 2: Match remote skills to local files

For each skill returned by Sourcerer:
1. Derive the expected local filename from the skill name (kebab-case + `.md`)
2. Search for matching files in `~/.claude/commands/`
3. If a local file exists, read it and separate:
   - **Frontmatter**: everything between the first two `---` lines (inclusive)
   - **Body**: everything after the second `---`

If no local files match any remote skill, inform the user and stop.

## Step 3: Show diff and let user choose

Use `AskUserQuestion` with `multiSelect: true`:

- **Question:** "Quali skill vuoi aggiornare da Sourcerer?"
- **Header:** "Skills"
- For each matched skill, create an option:
  - **label:** skill name (e.g. `execute-phase`)
  - **description:** brief summary of what changed (compare first 100 chars of old vs new body)

Default: all skills pre-selected.

## Step 4: Apply updates

For each skill selected by the user:
1. Call `kb_get_skill_content` to fetch the full content
2. Reconstruct the file: local frontmatter + `\n\n` + remote body
3. Write the updated file

## Step 5: Report

Display a summary:
- How many skills were updated
- How many were skipped (no local match or not selected)
- List of updated files with their paths

## Rules

- **NEVER modify the YAML frontmatter** — it contains tool permissions that are environment-specific
- If a remote skill has no local match, report it but do not create a new file (the user may need to set up frontmatter manually)
- If the local file has no frontmatter (no `---` delimiters), skip it and warn the user
