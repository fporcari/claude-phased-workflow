# GenroPy Worktree Support

Run GenroPy sites and CLI commands (`gnr web serve`, `gnr db setup`, etc.) from a git worktree — one created by `/create-context` or by hand with `git worktree add` — and serve several worktrees side by side.

## The Problem

When working in a git worktree, GenroPy commands still use the main repo's code and paths because:

1. **Python**: `gnr` is installed as editable from the main repo
2. **environment.xml**: `~/.gnr/environment.xml` has absolute paths to the main repo
3. **git**: you cannot `git switch` to a branch already checked out in a worktree

And two worktrees of the same project cannot be served at once, because they would share port 8080, the gnrdaemon on 40404, and the database.

## Installation

```bash
bash plugins/genropy-worktree/install.sh
```

This installs two scripts in `~/.local/bin/`.

## Usage

Open terminals from VS Code (which opens in the worktree directory):

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

The activation prints the URL to open — the port is derived from the worktree
name, so it stays the same every time and a bookmark keeps working.

**Deactivate** (or just close the terminal):
```bash
source deactivate_gnr_context
```

## Two worktrees at the same time, one browser each

Each worktree gets its own HTTP port (`8080 + offset`) and its own gnrdaemon
port (`40404 + offset`), so two worktrees of the same project can be served
together: four terminals, daemon + server for each.

**Use two different browsers** (or two profiles): the GenroPy connection cookie
is named after the site, and cookies are not isolated by port — two tabs of the
same browser on `:8083` and `:8091` would overwrite each other's session.

A separate gnrdaemon per worktree is not optional: the daemon indexes its site
register by site name, so two worktrees of the same site sharing one daemon
would share one register.

## Per-worktree database (opt-in)

Only needed when the branch touches the model (`packages/*/model/*.py`); for
UI-only work the shared database is fine, and that is the default.

```bash
GNR_WT_DB=clientepippo source activate_gnr_context
```

This exports `GNR_DB_DSN` pointing at `clientepippo_<branch>` — read by the
server, `gnr db setup`, `gnr db shell` and the batches alike, so nothing in the
tracked `instanceconfig.xml` has to change. The script does not create the
database; it prints the two commands to run once:

```bash
createdb -T clientepippo clientepippo_ddt   # structure + data, main server stopped
gnr db setup <instance>                     # applies the branch delta to the clone
```

The main database is untouched and realigns at merge time, when `gnr db setup`
runs against it with the merged model.

## How It Works

`source activate_gnr_context` does everything automatically:

1. Detects the current worktree via `git rev-parse --show-toplevel`
2. Derives a stable port offset (`1..49`) from the worktree name
3. On first run, generates `.gnr/environment.xml` by copying `~/.gnr/environment.xml` and replacing main repo paths with worktree paths
4. Symlinks `instanceconfig/` from `~/.gnr/`, and writes a **copy** of `siteconfig/default.xml` carrying the worktree's HTTP and gnrdaemon ports
5. Sets `PYTHONPATH` to the worktree's `gnrpy/` (GenroPy worktrees only)
6. Sets `GENRO_GNRFOLDER` to the worktree's `.gnr/`, and `GNR_LOCAL_PROJECTS` to its parent directory (safety net for worktrees created outside the project tree listed in `environment.xml`)
7. With `GNR_WT_DB` set, composes `GNR_DB_DSN` for the per-branch database

### GenroPy vs Client Project Worktrees

- **GenroPy worktree** (has `gnrpy/`): sets `PYTHONPATH` + `GENRO_GNRFOLDER`
- **Client project** (no `gnrpy/`): sets `GENRO_GNRFOLDER` only — Python code stays from the main GenroPy install, only project paths (webpages, packages) point to the worktree
