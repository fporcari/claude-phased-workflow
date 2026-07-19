# GenroPy Worktree Support

Run GenroPy sites and CLI commands (`gnr web serve`, `gnr db migrate`, etc.) from worktrees created by `/create-context`.

## The Problem

When working in a git worktree, GenroPy commands still use the main repo's code and paths because:

1. **Python**: `gnr` is installed as editable from the main repo
2. **environment.xml**: `~/.gnr/environment.xml` has absolute paths to the main repo
3. **git**: you cannot `git switch` to a branch already checked out in a worktree

## Installation

```bash
bash plugins/genropy-worktree/install.sh
```

This installs two scripts in `~/.local/bin/`.

## Usage

After `/create-context` creates a worktree, open terminals from VS Code (which opens in the worktree directory):

**Terminal 1 — daemon:**
```bash
source activate_gnr_context
gnr web daemon
```

**Terminal 2 — server:**
```bash
source activate_gnr_context
gnr web serve sandboxpg --debug
```

**Deactivate** (or just close the terminal):
```bash
source deactivate_gnr_context
```

## How It Works

`source activate_gnr_context` does everything automatically:

1. Detects the current worktree via `git rev-parse --show-toplevel`
2. On first run, generates `.gnr/environment.xml` by copying `~/.gnr/environment.xml` and replacing main repo paths with worktree paths
3. Symlinks `instanceconfig/` and `siteconfig/` from `~/.gnr/`
4. Sets `PYTHONPATH` to the worktree's `gnrpy/` (GenroPy worktrees only)
5. Sets `GENRO_GNRFOLDER` to the worktree's `.gnr/`

### GenroPy vs Client Project Worktrees

- **GenroPy worktree** (has `gnrpy/`): sets `PYTHONPATH` + `GENRO_GNRFOLDER`
- **Client project** (no `gnrpy/`): sets `GENRO_GNRFOLDER` only — Python code stays from the main GenroPy install, only project paths (webpages, packages) point to the worktree
