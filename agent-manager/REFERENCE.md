# D-AMS Quick Reference Card
# Dynamic Agent Management System
# Manage: Claude Code | Gemini | OpenCode
# =========================================

# --- CLI Commands ---
agents                # Interactive TUI mode
agents --assemble     # Launch all 3 agents in Kitty tabs
agents --launch CLAUDE # Launch specific agent (CLAUDE|GEMINI|OPENCODE)
agents --launch GEMINI
agents --launch OPENCODE
agents --log          # Tail recent session log
agents --help         # Show help
agents --version      # Show version

# --- Kitty Integration ---
# Each agent opens in its own Kitty tab:
#   Tab 1: 🟣 Claude Code  (Backend Dev)
#   Tab 2: 🔵 Gemini       (Leader / Tech Lead)
#   Tab 3: 🟢 OpenCode     (QA / Frontend)

# --- D-AMS Workflow ---
# Phase 1: Intake & Analysis     - Define project
# Phase 2: Team Assembly         - Launch agents in Kitty
# Phase 3: Planning & Tasking    - Architect solution
# Phase 4: Execution & Review    - Agents code
# Phase 5: Domain-Specific QA    - Quality check
# Phase 6: Delivery              - Ship product

# --- Config ---
# Config file:  ~/.local/share/d-ams/config/agents.conf
# Session logs: ~/.local/share/d-ams/sessions/
# Customize agent commands, roles, and Kitty settings there.

# --- Tips ---
# 1. Start with: agents
# 2. Create project → auto-assembles team
# 3. Assign tasks per agent via menu
# 4. Kitty remembers sessions - use layout for persistence
# 5. All actions logged to sessions/ directory
