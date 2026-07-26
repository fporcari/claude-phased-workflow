#!/bin/bash
# Install phased-workflow support files into ~/.claude
# (shared conventions, autonomous-plan addendum, deterministic phase selector,
#  phase loop launcher, phase-verifier subagent)
#
# Also detects the legacy flat install: before the plugin existed, the skills
# were copied one file each into ~/.claude/commands/. Those files still take
# precedence over the plugin's namespaced skills for the bare `/name` form, so
# a stale copy keeps running silently after the plugin is installed. See the
# "Legacy flat commands" block at the bottom.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.claude/workflow-refs ~/.claude/scripts ~/.claude/agents
cp "$SRC/refs/common.md" ~/.claude/workflow-refs/common.md
cp "$SRC/refs/write-workflow-autonomous.md" ~/.claude/workflow-refs/write-workflow-autonomous.md
cp "$SRC/scripts/next-phase.py" ~/.claude/scripts/next-phase.py
cp "$SRC/scripts/run-all-phases.sh" ~/.claude/scripts/run-all-phases.sh
chmod +x ~/.claude/scripts/run-all-phases.sh
cp "$SRC/agents/phase-verifier.md" ~/.claude/agents/phase-verifier.md
echo "Support files installed:"
echo "  ~/.claude/workflow-refs/common.md"
echo "  ~/.claude/workflow-refs/write-workflow-autonomous.md"
echo "  ~/.claude/scripts/next-phase.py"
echo "  ~/.claude/scripts/run-all-phases.sh"
echo "  ~/.claude/agents/phase-verifier.md"

# ---------------------------------------------------------------- legacy flat
# Only the names this plugin ships or used to ship — never touch anything else
# in commands/. The retired ones matter for the same reason as the current ones:
# dropping a skill does not remove the flat file a previous install left behind,
# so it keeps answering `/<name>` with instructions for a command that is gone.
RETIRED_NAMES="create-context close-context clean-contexts clean-memories"
SKILL_NAMES=$(ls -d "$SRC"/skills/*/ | xargs -n1 basename)
STALE=""
for n in $SKILL_NAMES $RETIRED_NAMES; do
  [ -f "$HOME/.claude/commands/$n.md" ] && STALE="$STALE $n"
done

[ -z "$STALE" ] && exit 0

# The plugin's skills are namespaced (`/phased-workflow:<name>`) and cannot
# conflict — but a same-named file in commands/ still wins the bare `/<name>`.
# Superseding the flat copies is therefore only safe once the plugin is
# actually installed; otherwise they are the only working copy on this machine.
if grep -q '"phased-workflow@' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
  DEST="$HOME/.claude/phased-workflow-superseded-commands"
  mkdir -p "$DEST"
  for n in $STALE; do mv "$HOME/.claude/commands/$n.md" "$DEST/$n.md"; done
  echo ""
  echo "Legacy flat commands superseded by the plugin (moved, not deleted):"
  echo "  ~/.claude/commands/{$(echo $STALE | tr ' ' ',')}.md"
  echo "  -> $DEST/"
  echo "Use /phased-workflow:<name>, or the bare /<name> now that nothing shadows it."
  echo "Retired in 3.0.2 and NOT replaced — worktrees are plain git now:"
  echo "  $RETIRED_NAMES"
  echo "Delete that directory once you are satisfied nothing was lost."
else
  echo ""
  echo "NOTE: this machine runs the legacy flat install — the plugin is not installed, so"
  echo "these files under ~/.claude/commands/ are the only working copy and were left alone:"
  echo "  $STALE"
  echo "To move to the plugin (namespaced commands, no collisions with your other skills):"
  echo "  claude plugin marketplace add fporcari/claude-phased-workflow"
  echo "  claude plugin install phased-workflow@fporcari/claude-phased-workflow"
  echo "then re-run this script — it will supersede the flat copies for you."
fi
