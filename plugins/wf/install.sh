#!/bin/bash
# Migration tool for machines that ran phased-workflow 4.0.0 or earlier.
# It is NOT part of the install path any more: the plugin now ships and resolves
# its own support files (refs, scripts, phase-verifier subagent) from inside its
# own directory, so there is nothing to copy into ~/.claude.
#
# This script does two clean-up jobs for an older machine:
#   1. Supersede the orphaned support copies a previous install left under
#      ~/.claude (see the "Stale support files" block just below).
#   2. Supersede the legacy flat commands under ~/.claude/commands/ (see the
#      "Legacy flat commands" block at the bottom). Before the plugin existed,
#      the skills were copied one file each into ~/.claude/commands/, and those
#      files still win the bare `/name` form over the plugin's namespaced skills.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"

# --------------------------------------------------------- stale support files
# The five files a 4.0.0-or-earlier install copied into ~/.claude. The plugin
# carries these itself now, so the loose copies are orphans. The one that
# actually matters is agents/phase-verifier.md: it is NOT namespaced, so it wins
# over the plugin's wf:phase-verifier and keeps a stale verifier running.
# Move, never delete, and never touch anything else in those dirs.
SUPPORT_PATHS="workflow-refs/common.md workflow-refs/write-workflow-autonomous.md scripts/next-phase.py scripts/run-all-phases.sh agents/phase-verifier.md"
SUPPORT_STALE=""
for p in $SUPPORT_PATHS; do
  [ -f "$HOME/.claude/$p" ] && SUPPORT_STALE="$SUPPORT_STALE $p"
done

if [ -n "$SUPPORT_STALE" ]; then
  DEST="$HOME/.claude/phased-workflow-superseded-support"
  mkdir -p "$DEST"
  for p in $SUPPORT_STALE; do
    mkdir -p "$DEST/$(dirname "$p")"
    mv "$HOME/.claude/$p" "$DEST/$p"
  done
  echo "Stale support files superseded by the plugin (moved, not deleted):"
  for p in $SUPPORT_STALE; do echo "  ~/.claude/$p -> $DEST/$p"; done
  echo "The plugin now carries these files itself and resolves them from its own"
  echo "directory; the loose copies under ~/.claude were orphans."
  echo "agents/phase-verifier.md especially: un-namespaced, it shadowed the plugin's"
  echo "wf:phase-verifier and kept a stale verifier running."
  echo "Delete $DEST once you are satisfied nothing was lost."
else
  echo "No stale support files under ~/.claude — nothing to migrate."
fi

# ---------------------------------------------------------------- legacy flat
# Only the names this plugin ships or used to ship — never touch anything else
# in commands/. The retired ones matter for the same reason as the current ones:
# dropping a skill does not remove the flat file a previous install left behind,
# so it keeps answering `/<name>` with instructions for a command that is gone.
RETIRED_NAMES="create-context close-context clean-contexts clean-memories check-phase-context run-all-phases auto-phase"
SKILL_NAMES=$(ls -d "$SRC"/skills/*/ | xargs -n1 basename)
STALE=""
for n in $SKILL_NAMES $RETIRED_NAMES; do
  [ -f "$HOME/.claude/commands/$n.md" ] && STALE="$STALE $n"
done

[ -z "$STALE" ] && exit 0

# The plugin's skills are namespaced (`/wf:<name>`) and cannot conflict — but
# a same-named file in commands/ still wins the bare `/<name>`.
# Superseding the flat copies is therefore only safe once the plugin is
# actually installed; otherwise they are the only working copy on this machine.
# Either name counts as installed: the plugin was renamed phased-workflow -> wf
# in 6.0.0, and a machine may still carry the pre-rename entry.
if grep -qE '"(wf|phased-workflow)@' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
  DEST="$HOME/.claude/phased-workflow-superseded-commands"
  mkdir -p "$DEST"
  for n in $STALE; do mv "$HOME/.claude/commands/$n.md" "$DEST/$n.md"; done
  echo ""
  echo "Legacy flat commands superseded by the plugin (moved, not deleted):"
  echo "  ~/.claude/commands/{$(echo $STALE | tr ' ' ',')}.md"
  echo "  -> $DEST/"
  echo "Use /wf:<name>, or the bare /<name> now that nothing shadows it."
  echo "Retired names among them have no same-name successor:"
  echo "  create-context close-context clean-contexts clean-memories (3.0.2 — worktrees are plain git now)"
  echo "  check-phase-context (5.0.0 — absorbed into /resume-workflow)"
  echo "  run-all-phases (5.0.0 — renamed to /run-workflow)"
  echo "  auto-phase (5.0.0 — renamed to /execute-phase-agent)"
  echo "Delete that directory once you are satisfied nothing was lost."
else
  echo ""
  echo "NOTE: this machine runs the legacy flat install — the plugin is not installed, so"
  echo "these files under ~/.claude/commands/ are the only working copy and were left alone:"
  echo "  $STALE"
  echo "To move to the plugin (namespaced commands, no collisions with your other skills):"
  echo "  claude plugin marketplace add fporcari/claude-phased-workflow"
  echo "  claude plugin install wf@claude-phased-workflow"
  echo "then re-run this script — it will supersede the flat copies for you."
fi
