#!/bin/bash
#===============================================================================
# Quick Start: Install D-AMS Agent Manager
# Run: source install.sh
#===============================================================================

TOOL_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
CONFIG_SHELL="${HOME}/.bashrc"

echo "=== D-AMS Agent Manager Installer ==="

# 1. Create install directory
mkdir -p "$INSTALL_DIR"

# 2. Create wrapper script
cat > "$INSTALL_DIR/agents" << 'WRAPPER'
#!/bin/bash
exec "$HOME/.local/share/d-ams/agent-manager.sh" "$@"
WRAPPER

# 3. Copy tool to share directory
mkdir -p "$HOME/.local/share/d-ams"
cp -r "$TOOL_DIR"/* "$HOME/.local/share/d-ams/"
chmod +x "$HOME/.local/share/d-ams/agent-manager.sh"

# 4. Make wrapper executable
chmod +x "$INSTALL_DIR/agents"

# 5. Add to PATH if not already
if ! grep -q '\.local/bin' "$CONFIG_SHELL" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CONFIG_SHELL"
    echo "Added ~/.local/bin to PATH in $CONFIG_SHELL"
fi

echo "=== Installation Complete ==="
echo ""
echo "Usage:"
echo "  agents              - Interactive mode"
echo "  agents --assemble   - Launch all 3 agents in Kitty tabs"
echo "  agents --launch CLAUDE - Launch a specific agent"
echo "  agents --log        - View recent session log"
echo ""
echo "Restart your terminal or run: source $CONFIG_SHELL"
