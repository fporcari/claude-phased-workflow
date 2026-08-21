#!/bin/bash
# End-to-end test of activate_gnr_context: real git repos, real worktrees, a
# real gnr config dir, the real script. Nothing is mocked — the assertions read
# the files the activation leaves behind, which is the only thing its callers
# ever see.
#
# Four scenarios:
#   A  a genropy worktree (gnrpy/ present): .gnr/ rewritten onto the worktree,
#      per-worktree ports, Claude Code env, VS Code stamp, tracked
#      settings.json hidden from the branch
#   B  the same activation run twice: colour and ports stable, a colour the
#      user changed in between kept
#   C  a client-project worktree (no gnrpy/): no PYTHONPATH anywhere
#   D  a settings.json that is not plain JSON: left byte-identical
#
# Usage: bash plugins/genropy-worktree/tests/test_activate_gnr_context.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTIVATE="$SCRIPT_DIR/../bin/activate_gnr_context"
# Resolved: git reports resolved paths, and on macOS the temp dir is behind a
# symlink — unresolved, every path comparison below would fail on the prefix.
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# Hermetic git. The developer's own global config must not decide what these
# repos can track: a core.excludesFile ignoring .vscode/ — a common one — would
# leave settings.json untracked here and quietly skip half the assertions.
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
export GIT_CONFIG_SYSTEM=/dev/null
git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main
git config --file "$GIT_CONFIG_GLOBAL" user.email test@example.com
git config --file "$GIT_CONFIG_GLOBAL" user.name Test

failures=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; failures=$((failures + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 — expected '$3', got '$2'"; fi; }
check_has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 — '$3' not found in '$2'" ;; esac; }
check_hasnt() { case "$2" in *"$3"*) fail "$1 — '$3' present in '$2'" ;; *) pass "$1" ;; esac; }

case "$(uname -s)" in
    Darwin) TERM_KEY='terminal.integrated.env.osx' ;;
    Linux) TERM_KEY='terminal.integrated.env.linux' ;;
    *) TERM_KEY='terminal.integrated.env.windows' ;;
esac

# A gnr config dir the script can read, in place of the developer's own.
GNR_ETC="$TMP/venv/etc/gnr"
mkdir -p "$GNR_ETC/siteconfig" "$GNR_ETC/instanceconfig" "$TMP/home"
cat > "$GNR_ETC/siteconfig/default.xml" <<'XML'
<?xml version="1.0" ?>
<GenRoBag><wsgi debug="True::B" port="8080" /></GenRoBag>
XML
cat > "$GNR_ETC/instanceconfig/default.xml" <<'XML'
<?xml version="1.0" ?>
<GenRoBag><db host="localhost" user="postgres" /></GenRoBag>
XML

# A repo, with the tracked .vscode/settings.json genropy ships, and a worktree.
# $1 repo path, $2 worktree path, $3 "gnrpy" to give the repo a gnrpy/ dir.
make_repo() {
    mkdir -p "$1/projects" "$1/.vscode"
    printf '{\n    "python.testing.pytestEnabled": true\n}\n' > "$1/.vscode/settings.json"
    echo keep > "$1/projects/keep"
    [ "${3:-}" = gnrpy ] && mkdir -p "$1/gnrpy" && echo keep > "$1/gnrpy/keep"
    git -C "$1" init -q
    git -C "$1" config user.email test@example.com
    git -C "$1" config user.name Test
    git -C "$1" add -A
    git -C "$1" commit -qm init
    git -C "$1" worktree add -q -b "$(basename "$2")" "$2"
    cat > "$GNR_ETC/environment.xml" <<XML
<?xml version="1.0" ?>
<GenRoBag>
	<environment>
		<gnrhome value="$1"/>
	</environment>
	<projects>
		<genropy path="$1/projects"/>
	</projects>
	<gnrdaemon host="localhost" port="40404"/>
</GenRoBag>
XML
}

activate() { (cd "$1" && HOME="$TMP/home" VIRTUAL_ENV="$TMP/venv" bash -c "source '$ACTIVATE'" 2>&1); }

# Reads one dotted key out of a JSON file; prints nothing when absent.
json_get() { python3 -c "
import json, sys
node = json.load(open(sys.argv[1]))
for key in sys.argv[2:]:
    if not isinstance(node, dict) or key not in node:
        sys.exit(0)
    node = node[key]
print(node)
" "$@"; }

echo 'A — a genropy worktree'
MAIN="$TMP/genropy"
WT="$MAIN/.wt/alpha"
make_repo "$MAIN" "$WT" gnrpy
out_a="$(activate "$WT")"
offset=$(( $(printf '%s' alpha | cksum | cut -d' ' -f1) % 49 + 1 ))
http_port=$(( 8080 + offset ))
daemon_port=$(( 40404 + offset ))

check_has 'activation reports the worktree' "$out_a" "GenroPy activated: $WT"
check_has 'activation reports its HTTP port' "$out_a" "http://localhost:$http_port"
check_has 'activation reports the VS Code stamp' "$out_a" 'VS Code:'

env_xml="$(cat "$WT/.gnr/environment.xml")"
check_has 'environment.xml points projects at the worktree' "$env_xml" "$WT/projects"
check_hasnt 'environment.xml keeps no path into the main repo' "$env_xml" "$MAIN/projects"
check 'siteconfig carries the per-worktree HTTP port' \
    "$(python3 -c "import sys,xml.etree.ElementTree as E;print(E.parse(sys.argv[1]).getroot().find('wsgi').get('port'))" "$WT/.gnr/siteconfig/default.xml")" \
    "$http_port"
check 'environment.xml carries the per-worktree daemon port' \
    "$(python3 -c "import sys,xml.etree.ElementTree as E;print(E.parse(sys.argv[1]).getroot().find('gnrdaemon').get('port'))" "$WT/.gnr/environment.xml")" \
    "$daemon_port"
check 'the private projects dir holds one symlink to the worktree' \
    "$(cd "$WT/.gnr/projects/$(basename "$MAIN")" && pwd -P)" "$(cd "$WT" && pwd -P)"

settings_local="$WT/.claude/settings.local.json"
check 'Claude Code env: GENRO_GNRFOLDER' "$(json_get "$settings_local" env GENRO_GNRFOLDER)" "$WT/.gnr"
check 'Claude Code env: GNR_LOCAL_PROJECTS' "$(json_get "$settings_local" env GNR_LOCAL_PROJECTS)" "$WT/.gnr/projects"
check 'Claude Code env: PYTHONPATH' "$(json_get "$settings_local" env PYTHONPATH)" "$WT/gnrpy"

vscode="$WT/.vscode/settings.json"
check 'the tracked VS Code key survives the stamp' "$(json_get "$vscode" python.testing.pytestEnabled)" 'True'
colour="$(json_get "$vscode" workbench.colorCustomizations titleBar.activeBackground)"
check 'the title bar gets a hex colour' "$(printf '%s' "$colour" | wc -c | tr -d ' ')" '7'
check 'the colour in the file is the one reported' "$colour" \
    "$(printf '%s\n' "$out_a" | sed -n 's/.*title bar \(#[0-9a-f]*\).*/\1/p')"
check 'terminal env: GENRO_GNRFOLDER' "$(json_get "$vscode" "$TERM_KEY" GENRO_GNRFOLDER)" "$WT/.gnr"
check 'terminal env: PYTHONPATH' "$(json_get "$vscode" "$TERM_KEY" PYTHONPATH)" "$WT/gnrpy"
check 'the tracked settings.json is flagged skip-worktree' \
    "$(git -C "$WT" ls-files -v .vscode/settings.json | cut -c1)" 'S'
check_hasnt 'the stamp does not dirty the branch' "$(git -C "$WT" status --porcelain)" '.vscode/settings.json'

echo 'B — the same worktree, activated twice'
python3 - "$vscode" <<'PY'
import json
import sys

p = sys.argv[1]
data = json.load(open(p))
data['workbench.colorCustomizations']['titleBar.activeBackground'] = '#abcdef'
json.dump(data, open(p, 'w'), indent=4)
PY
out_b="$(activate "$WT")"
check_has 'a second activation reports the same port' "$out_b" "http://localhost:$http_port"
check_has 'a second activation says the colour was kept' "$out_b" 'own title-bar colour kept'
check 'a colour the user changed is left standing' \
    "$(json_get "$vscode" workbench.colorCustomizations titleBar.activeBackground)" '#abcdef'
check 'the terminal env is still written on the second run' \
    "$(json_get "$vscode" "$TERM_KEY" GENRO_GNRFOLDER)" "$WT/.gnr"

echo 'C — a client-project worktree, no gnrpy/'
PROJ="$TMP/clientapp"
PWT="$PROJ/.wt/beta"
make_repo "$PROJ" "$PWT"
out_c="$(activate "$PWT")"
check_has 'activation reports the project form' "$out_c" "GenroPy activated (project): $PWT"
check 'no PYTHONPATH in the Claude Code env' "$(json_get "$PWT/.claude/settings.local.json" env PYTHONPATH)" ''
check 'no PYTHONPATH in the terminal env' "$(json_get "$PWT/.vscode/settings.json" "$TERM_KEY" PYTHONPATH)" ''
check 'the terminal env still carries GENRO_GNRFOLDER' \
    "$(json_get "$PWT/.vscode/settings.json" "$TERM_KEY" GENRO_GNRFOLDER)" "$PWT/.gnr"

echo 'D — a settings.json that is not plain JSON'
JMAIN="$TMP/jsonc"
JWT="$JMAIN/.wt/gamma"
make_repo "$JMAIN" "$JWT" gnrpy
printf '{\n    // a comment VS Code allows and json.loads does not\n    "editor.tabSize": 4\n}\n' \
    > "$JWT/.vscode/settings.json"
before="$(cat "$JWT/.vscode/settings.json")"
out_d="$(activate "$JWT")"
check_has 'activation says the file was left alone' "$out_d" 'not plain JSON'
check 'the file is byte-identical afterwards' "$(cat "$JWT/.vscode/settings.json")" "$before"
check 'the Claude Code env is written anyway' \
    "$(json_get "$JWT/.claude/settings.local.json" env GENRO_GNRFOLDER)" "$JWT/.gnr"

if command -v zsh >/dev/null 2>&1; then
    echo 'E — sourced from zsh, the shell half the users are on'
    ZMAIN="$TMP/zshrepo"
    ZWT="$ZMAIN/.wt/delta"
    make_repo "$ZMAIN" "$ZWT" gnrpy
    out_e="$(cd "$ZWT" && HOME="$TMP/home" VIRTUAL_ENV="$TMP/venv" zsh -c "source '$ACTIVATE'" 2>&1)"
    check_has 'zsh activation reports the worktree' "$out_e" "GenroPy activated: $ZWT"
    check_has 'zsh activation stamps the VS Code window' "$out_e" 'title bar #'
    check 'zsh activation writes the terminal env' \
        "$(json_get "$ZWT/.vscode/settings.json" "$TERM_KEY" GENRO_GNRFOLDER)" "$ZWT/.gnr"
else
    echo 'E — skipped, no zsh on this machine'
fi

echo
if [ "$failures" -eq 0 ]; then
    echo 'PASS — activate_gnr_context'
else
    echo "FAIL — $failures assertion(s)"
fi
exit $(( failures > 0 ))
