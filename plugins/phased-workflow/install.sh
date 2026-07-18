#!/bin/bash
# Install phased-workflow support files into ~/.claude
# (shared conventions, autonomous-plan addendum, deterministic phase selector)
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.claude/workflow-refs ~/.claude/scripts
cp "$SRC/refs/common.md" ~/.claude/workflow-refs/common.md
cp "$SRC/refs/write-workflow-autonomous.md" ~/.claude/workflow-refs/write-workflow-autonomous.md
cp "$SRC/scripts/next-phase.py" ~/.claude/scripts/next-phase.py
echo "Support files installed:"
echo "  ~/.claude/workflow-refs/common.md"
echo "  ~/.claude/workflow-refs/write-workflow-autonomous.md"
echo "  ~/.claude/scripts/next-phase.py"
