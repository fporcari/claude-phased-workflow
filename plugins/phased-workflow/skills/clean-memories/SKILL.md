# Clean Memories

Clean up memory files for the current project.

## Steps

### Step 1: Locate the project memory directory

The memory directory is at:
`~/.claude/projects/<project-slug>/memory/`

where `<project-slug>` is the current working directory path with `/` replaced by `-`
and prefixed with `-`.

Run `pwd` to get the current path, then build the memory directory path.

### Step 2: List memory files

Find all `*.md` files in the memory directory **including MEMORY.md**.

For each file, read the YAML frontmatter (lines between the two `---`) and extract:
- `name`
- `description`
- `type`

### Step 3: Present to user and ask which to delete

If no memory files exist, display:
"No memory files found for this project."
and stop.

If files exist, use **AskUserQuestion** with `multiSelect: true`.

- **Question:** "Which memories do you want to delete?"
- **Header:** "Memories"
- For each file, create an option:
  - **label:** `[type] name` (e.g. `[feedback] No old components`)
  - **description:** the `description` field from frontmatter + the filename

### Step 4: Delete selected files

For each file selected by the user:
1. Delete the file with `rm`
2. Update `MEMORY.md` by removing any line that references the deleted file

If after cleanup `MEMORY.md` contains only the `# Memory Index` header with no other content,
rewrite the file with:
```
# Memory Index

_(empty — no pending work)_
```

### Step 5: Confirm

Display a summary of how many files were deleted and how many remain.
