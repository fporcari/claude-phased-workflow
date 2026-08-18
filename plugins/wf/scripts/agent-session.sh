#!/bin/bash
# Run a shipped skill in a fresh `claude` sub-session at the plan's root.
# One launcher, callable by any skill that needs a clean-context session
# anchored to the plan — today /finalize-workflow (its read-only verify
# agent). The sub-session's prompt is SHIPPED here, never composed by the
# calling chat: independence is structural, not a matter of the caller's
# honesty.
#
# Usage: agent-session.sh <skill-name> [--model M] [--effort E]
#
# Workspace resolution mirrors run-workflow.sh (kept self-contained there on
# purpose: the test suite runs a lone copy of that file, so it cannot source
# a shared lib). Plan in the current root -> run here; plan in another
# checkout -> run there; plan on a branch with no checkout -> create its
# worktree under .claude/worktrees/ (announced).

SKILL="$1"; shift
MODEL="opus"; EFFORT="high"
while [ $# -gt 0 ]; do
  case "$1" in
    --model)  MODEL="$2";  shift 2 ;;
    --effort) EFFORT="$2"; shift 2 ;;
    *) echo "agent-session.sh: unknown argument '$1'"; exit 2 ;;
  esac
done
if [ -z "$SKILL" ]; then
  echo "usage: agent-session.sh <skill-name> [--model M] [--effort E]"
  exit 2
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
NEXT_PHASE_PY="$SCRIPT_DIR/next-phase.py"

# The sub-session prompt is a slash command. In a headless `claude -p` session a
# bare `/<skill>` resolves only against ~/.claude/commands/; a plugin-shipped
# skill registers as `/<plugin>:<skill>`, so the namespace prefix is REQUIRED or
# the session dies at once with "Unknown command: /<skill>". Derive the plugin
# name from our own plugin.json (found via SCRIPT_DIR), never retyped — with a
# literal fallback so a failed read can never reintroduce a bare slash.
# grep -o, not a greedy sed over the whole line: on a minified single-line
# plugin.json a greedy match would return the LAST "name" (the author's),
# while -o emits matches in order and head -1 keeps the first — the plugin's.
PLUGIN_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' \
  "$SCRIPT_DIR/../.claude-plugin/plugin.json" 2>/dev/null | head -1 \
  | sed 's/.*"\([^"]*\)"$/\1/')
PLUGIN_NAME=${PLUGIN_NAME:-wf}

REPO_ROOT=$(git rev-parse --show-toplevel) || exit 1
PLAN_ROOT="$REPO_ROOT"

if ! find "$REPO_ROOT/.phased/active" -mindepth 2 -maxdepth 2 -name plan.md 2>/dev/null | grep -q . \
   && [ -f "$NEXT_PHASE_PY" ]; then
  PLANS=$(python3 "$NEXT_PHASE_PY" --plans 2>/dev/null | grep '^plan|')
  PLANS_COUNT=$(printf '%s' "$PLANS" | grep -c .)
  if [ "$PLANS_COUNT" -eq 0 ]; then
    echo "No workflow plan reachable from $REPO_ROOT — nothing to run $SKILL against."
    exit 1
  fi
  if [ "$PLANS_COUNT" -gt 1 ]; then
    echo "Several workflows reachable — relaunch from the one you mean:"
    printf '%s\n' "$PLANS"
    exit 1
  fi
  PLAN_BRANCH=$(printf '%s' "$PLANS" | awk -F'|' '{print $4}')
  PLAN_CHECKOUT=$(printf '%s' "$PLANS" | awk -F'|' '{print $6}')
  if [ "$PLAN_CHECKOUT" = "-" ]; then
    PLAN_SLUG=$(printf '%s' "$PLANS" | awk -F'|' '{print $2}' \
      | sed 's|.*/\.phased/active/||; s|^[^:]*:\.phased/active/||; s|/plan\.md$||')
    PLAN_CHECKOUT="$REPO_ROOT/.claude/worktrees/$PLAN_SLUG"
    echo "NOTE: branch $PLAN_BRANCH has no checkout — creating its worktree at $PLAN_CHECKOUT."
    git worktree add "$PLAN_CHECKOUT" "$PLAN_BRANCH" || exit 1
    mkdir -p "$PLAN_CHECKOUT/.claude"
    [ -f "$REPO_ROOT/.claude/settings.local.json" ] \
      && cp "$REPO_ROOT/.claude/settings.local.json" "$PLAN_CHECKOUT/.claude/settings.local.json"
  fi
  PLAN_ROOT="$PLAN_CHECKOUT"
fi

cd "$PLAN_ROOT" || exit 1
PLAN=$(find "$PLAN_ROOT/.phased/active" -mindepth 2 -maxdepth 2 -name plan.md 2>/dev/null | head -1)
if [ -z "$PLAN" ]; then
  echo "No active plan under $PLAN_ROOT/.phased/active/ — nothing to run $SKILL against."
  exit 1
fi
PLAN_DIR=$(dirname "$PLAN")
mkdir -p "$PLAN_DIR/log"

echo "========================================="
echo "$SKILL — model: $MODEL, effort: $EFFORT, at: $PLAN_ROOT"
echo "========================================="
# pipefail, NOT ${PIPESTATUS[0]}: this script is also run under zsh.
set -o pipefail
claude -p "/$PLUGIN_NAME:$SKILL" \
  --model "$MODEL" \
  --effort "$EFFORT" \
  --permission-mode auto 2>&1 | tee "$PLAN_DIR/log/$SKILL.txt"
AGENT_EXIT=$?
set +o pipefail
exit "$AGENT_EXIT"
