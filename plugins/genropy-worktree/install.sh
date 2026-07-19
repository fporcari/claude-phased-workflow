#!/bin/bash
# Install activate_gnr_context and deactivate_gnr_context into ~/.local/bin
#
# Usage: bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"

mkdir -p "$INSTALL_DIR"

cp "$SCRIPT_DIR/bin/activate_gnr_context" "$INSTALL_DIR/activate_gnr_context"
cp "$SCRIPT_DIR/bin/deactivate_gnr_context" "$INSTALL_DIR/deactivate_gnr_context"
chmod +x "$INSTALL_DIR/activate_gnr_context" "$INSTALL_DIR/deactivate_gnr_context"

# Check if ~/.local/bin is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "$INSTALL_DIR"; then
    echo "Warning: $INSTALL_DIR is not in your PATH."
    echo "Add this to your ~/.zshrc or ~/.bashrc:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo "Installed:"
echo "  $INSTALL_DIR/activate_gnr_context"
echo "  $INSTALL_DIR/deactivate_gnr_context"
echo ""
echo "Usage (from inside a worktree):"
echo "  source activate_gnr_context"
echo "  source deactivate_gnr_context"
