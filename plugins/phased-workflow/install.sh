#!/bin/bash
# Install phased-workflow support files into ~/.claude
# (shared conventions, autonomous-plan addendum, deterministic phase selector,
#  phase-verifier subagent)
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.claude/workflow-refs ~/.claude/scripts ~/.claude/agents
cp "$SRC/refs/common.md" ~/.claude/workflow-refs/common.md
cp "$SRC/refs/write-workflow-autonomous.md" ~/.claude/workflow-refs/write-workflow-autonomous.md
cp "$SRC/scripts/next-phase.py" ~/.claude/scripts/next-phase.py
cp "$SRC/agents/phase-verifier.md" ~/.claude/agents/phase-verifier.md
echo "Support files installed:"
echo "  ~/.claude/workflow-refs/common.md"
echo "  ~/.claude/workflow-refs/write-workflow-autonomous.md"
echo "  ~/.claude/scripts/next-phase.py"
echo "  ~/.claude/agents/phase-verifier.md"
