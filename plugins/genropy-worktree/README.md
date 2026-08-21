# GenroPy Worktree Support

Run GenroPy sites and CLI commands (`gnr web serve`, `gnr db setup`, etc.) from a git worktree — one created by `/write-workflow` on an autonomous plan, or by hand with `git worktree add` — and serve several worktrees side by side.

## The Problem

When working in a git worktree, GenroPy commands still use the main repo's code and paths because:

1. **Python**: `gnr` is installed as editable from the main repo
2. **environment.xml**: the system `environment.xml` (`$VIRTUAL_ENV/etc/gnr/` on virtualenv installs, `~/.gnr/` otherwise) has absolute paths to the main repo
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

## Claude Code sessions inside the worktree

Every Bash call from Claude Code starts a fresh shell, so a `source` never
carries over to the next command. Activation therefore also writes an `env`
block into the worktree's `.claude/settings.local.json` (merged, existing keys
preserved):

```json
{
  "env": {
    "GENRO_GNRFOLDER": "…/worktree/.gnr",
    "GNR_LOCAL_PROJECTS": "…/worktree/.gnr/projects",
    "GNR_DB_DSN": "postgres://…"
  }
}
```

Claude Code applies that block to every Bash invocation, so a session started in
the worktree runs `gnr` against the right code and database with nothing to
remember. Run the activation once per worktree before starting the session —
settings are read at session start.

**Deactivate** (or just close the terminal):
```bash
source deactivate_gnr_context
```

## The VS Code window

Activation also stamps the worktree's `.vscode/settings.json` (merged, existing
keys preserved):

```json
{
  "workbench.colorCustomizations": {
    "titleBar.activeBackground": "#1f6f93",
    "titleBar.activeForeground": "#ffffff"
  },
  "terminal.integrated.env.osx": {
    "GENRO_GNRFOLDER": "…/worktree/.gnr",
    "GNR_LOCAL_PROJECTS": "…/worktree/.gnr/projects",
    "PYTHONPATH": "…/worktree/gnrpy"
  }
}
```

Two jobs. The **title bar colour** — one of six hues picked by the worktree name,
so it is stable across reopenings and two windows side by side differ — is how you
tell a worktree window from the main repo before typing anything into it. The
**terminal env** makes every terminal opened in that window address the worktree
even when it never sourced the activation, which is what stops the `gnr web serve`
that runs the main checkout by mistake and shows none of the branch's changes.

Three details worth knowing:

- A colour already in the file is the user's own: it stays, and only the terminal
  env is refreshed.
- genropy **tracks** `.vscode/settings.json`, so the stamp would otherwise stand as
  a dirty tracked file — and a dirty tree is what `/finalize-workflow` gates on.
  The script flags it `--skip-worktree` in that worktree's index, which is
  per-worktree: the main checkout and every other worktree are untouched. To see it
  again: `git update-index --no-skip-worktree .vscode/settings.json`.
- A `settings.json` carrying `//` comments (VS Code allows them, `json.loads` does
  not) is left byte-identical and the activation says so, rather than rewriting the
  file and dropping what it held.

A window already open picks the colour up on `Developer: Reload Window`, and the
env only in terminals opened after that — so activate before opening the window.
`deactivate_gnr_context` does not remove the stamp: that is window identity, not
shell state.

## Two worktrees at the same time, one browser each

Each worktree gets its own HTTP port (`8080 + offset`) and its own gnrdaemon
port (`40404 + offset`), so two worktrees of the same project can be served
together: four terminals, daemon + server for each.

The GenroPy connection cookie is named after the site, and cookies are scoped by
host, not by host:port — so two tabs of the same browser on
`localhost:8083` and `localhost:8091` overwrite each other's `connection_id`
and each reload mints a new connection. Verified, not theoretical.

Two ways out, both fine:

- **One browser, two hosts.** `localhost` and `127.0.0.1` are distinct cookie
  jars: open one worktree as `http://localhost:8083` and the other as
  `http://127.0.0.1:8091` and the two sessions stay put. Works for two
  worktrees; a third needs an `/etc/hosts` alias.
- **Two different browsers** (or two profiles).

A separate gnrdaemon per worktree is not optional: the daemon indexes its site
register by site name, so two worktrees of the same site sharing one daemon
would share one register. Note the daemon reads its listening port from
`environment.xml` while the site reads it from siteconfig — the script writes
both, so `gnr web daemon` and `gnr web serve` agree.

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

The DSN scheme is `postgres`, not `postgresql`: GenroPy turns the scheme into
the implementation name (`gnrapp.dsn_to_config`) and the adapter module is
`gnrpostgres`.

## Verified on

Two worktrees of `genropy_projects/sandbox`, instance `sandboxpg`, served
together (`:8123` and `:8101`, daemons on `:40447` and `:40425`) alongside an
unrelated instance already running on `:8080`. Each server resolved the webpages
from its own worktree, each `gnr db setup` applied its own branch column
(`fatt.cliente.ddt_note` vs `royalty_perc`) to its own clone, and the shared
`sandboxpg` came out untouched.

## How It Works

`source activate_gnr_context` does everything automatically:

1. Detects the current worktree via `git rev-parse --show-toplevel`
2. Derives a stable port offset (`1..49`) from the worktree name
3. On first run, generates `.gnr/environment.xml` by copying the system `environment.xml` — looked up in `$VIRTUAL_ENV/etc/gnr/` first (virtualenv installs keep the GenroPy config there), then `~/.gnr/` — and replacing main repo paths with worktree paths
4. Symlinks `instanceconfig/` from the same config directory, and writes a **copy** of `siteconfig/default.xml` carrying the worktree's HTTP and gnrdaemon ports
5. Sets `PYTHONPATH` to the worktree's `gnrpy/` (GenroPy worktrees only)
6. Sets `GENRO_GNRFOLDER` to the worktree's `.gnr/`, and `GNR_LOCAL_PROJECTS` to a private directory holding a single symlink back to this worktree (a shared parent directory would let the resolver glob pick a sibling worktree at random)
7. With `GNR_WT_DB` set, composes `GNR_DB_DSN` for the per-branch database
8. Mirrors those variables into the worktree's `.claude/settings.local.json` `env` block for Claude Code sessions
9. Stamps the worktree's `.vscode/settings.json` with the title bar colour and the terminal env, and hides the change from git when that file is tracked

## Tests

```bash
bash plugins/genropy-worktree/tests/test_activate_gnr_context.sh
```

Real git repos, real worktrees, a real gnr config directory, the shipped script —
nothing mocked, the assertions read the files an activation leaves behind. Covers a
genropy worktree, a second activation over it (ports and a colour the user changed
both stable), a client project without `gnrpy/`, a `settings.json` that is not
plain JSON, and the same activation sourced from zsh.

### GenroPy vs Client Project Worktrees

- **GenroPy worktree** (has `gnrpy/`): sets `PYTHONPATH` + `GENRO_GNRFOLDER`
- **Client project** (no `gnrpy/`): sets `GENRO_GNRFOLDER` only — Python code stays from the main GenroPy install, only project paths (webpages, packages) point to the worktree
