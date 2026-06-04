<div align="center">
  <h1>🤖 D-AMS Agent Manager</h1>
  <p><strong>Dynamic Agent Management System</strong></p>
  <p>Orchestrate Claude Code · Gemini · OpenCode in Kitty Terminal</p>
  <p>
    <img src="https://img.shields.io/badge/platform-linux-blue?style=flat-square" />
    <img src="https://img.shields.io/badge/terminal-kitty-orange?style=flat-square" />
    <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" />
  </p>
</div>

---

## Overview

**D-AMS Agent Manager** is a terminal-based orchestration tool that turns your AI coding agents into a coordinated team. Built for the [Kitty terminal](https://sw.kovidgoyal.net/kitty/) on Linux, it launches each agent in its own tab/window and follows a structured 6-phase workflow from planning to delivery.

### Managed Agents

| Agent | Role | Command |
|-------|------|---------|
| 🟣 **Claude Code** | Backend Developer / Systems Programmer | `claude` |
| 🔵 **Gemini** | Leader Agent / Tech Lead | `gemini` |
| 🟢 **OpenCode** | QA/QC Engineer / Frontend Developer | `opencode` |

---

## Features

- **Interactive TUI** — Menu-driven interface to manage projects, agents, and tasks
- **Kitty Integration** — Each agent gets its own Kitty tab or window with auto-launch
- **Team Assembly** — Assemble all 3 agents with a single command
- **Task Assignment** — Assign tasks to specific agents with full logging
- **Session Logging** — Every action is timestamped and saved to `sessions/`
- **Workflow Tracking** — Follow the 6-phase D-AMS lifecycle
- **Single CLI Entry** — Use the `agents` command from anywhere

---

## Quick Start

### Prerequisites

- Linux with [Kitty terminal](https://sw.kovidgoyal.net/kitty/)
- At least one of: `claude`, `gemini`, `opencode` available in `$PATH`

### Install

```bash
git clone https://github.com/nguyenthuongaz9/agents_manager.git
cd agents_manager
chmod +x install.sh agent-manager.sh
./install.sh
```

Restart your terminal or run `source ~/.bashrc`, then use the `agents` command.

### Usage

```bash
agents                    # Interactive mode (recommended)
agents --assemble         # Launch all 3 agents in Kitty tabs
agents --launch CLAUDE    # Launch a specific agent
agents --launch GEMINI
agents --launch OPENCODE
agents --log              # View recent session log
agents --help             # Show help
agents --version          # Show version
```

### Kitty Session File

Launch the full layout (manager + 3 agents) directly:

```bash
kitty --session config/d-ams.kitty.session
```

---

## Workflow

The tool follows the **D-AMS lifecycle** — 6 phases guided by the interactive menu:

| Phase | Description |
|-------|-------------|
| 1. Intake & Analysis | Define project scope & requirements |
| 2. Team Assembly | Launch agents in Kitty tabs |
| 3. Planning & Tasking | Create task breakdown & architecture |
| 4. Execution & Review | Agents execute assigned tasks |
| 5. Domain-Specific QA | Quality assurance & testing |
| 6. Delivery | Package & deliver final product |

---

## Configuration

Edit `config/agents.conf` to customize:

- Agent names, commands, and icons
- Default leader agent
- Kitty session paths
- Workflow phases

```bash
# Example: change OpenCode command
AGENT_OPENCODE_COMMAND="opencode-v2"
```

---

## Project Structure

```
agent-manager/
├── agent-manager.sh        # Main orchestrator
├── install.sh              # Installation script
├── REFERENCE.md            # Quick reference card
├── config/
│   ├── agents.conf         # Agent definitions
│   └── d-ams.kitty.session # Kitty session layout
├── lib/
│   ├── ui.sh               # Terminal UI helpers
│   ├── kitty.sh            # Kitty terminal integration
│   └── logging.sh          # Session logging utilities
└── sessions/               # Session log storage
```

---

## License

MIT
