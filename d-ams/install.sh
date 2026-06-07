#!/usr/bin/env bash
# D-AMS Installer

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
SHARE_DIR="${HOME}/.local/share/d-ams"

echo "=== D-AMS Installer ==="

if [ ! -f "$TOOL_DIR/bin/d-ams" ] || [ ! -d "$TOOL_DIR/lib" ]; then
    echo "ERROR: Missing d-ams files in $TOOL_DIR"
    echo "Run from the d-ams directory: bash install.sh"
    exit 1
fi

mkdir -p "$INSTALL_DIR" "$SHARE_DIR/sessions"

# Copy tool to share dir
cp -r "$TOOL_DIR/bin" "$TOOL_DIR/lib" "$TOOL_DIR/config" "$TOOL_DIR/prompts" "$SHARE_DIR/"
chmod +x "$SHARE_DIR/bin/d-ams"

# Create symlinks (d-ams + backward-compat agents alias)
ln -sf "$SHARE_DIR/bin/d-ams" "$INSTALL_DIR/d-ams"
ln -sf "$SHARE_DIR/bin/d-ams" "$INSTALL_DIR/agents"

if ! grep -q '\.local/bin' "${HOME}/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
fi

echo "=== Done ==="
echo "Commands: d-ams  (or: agents)"
echo "Restart terminal or: source ~/.bashrc"
