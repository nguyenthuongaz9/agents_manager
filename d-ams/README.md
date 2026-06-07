<div align="center">
  <h1>D-AMS Agent Manager</h1>
  <p><strong>Dynamic Agent Management System</strong></p>
  <p>Orchestrate Claude Code · Gemini · OpenCode in Kitty Terminal</p>
  <p>
    <img src="https://img.shields.io/badge/platform-linux-blue?style=flat-square" />
    <img src="https://img.shields.io/badge/terminal-kitty-orange?style=flat-square" />
    <img src="https://img.shields.io/badge/license-Apache%202.0-green?style=flat-square" />
    <img src="https://img.shields.io/badge/version-1.1.0-purple?style=flat-square" />
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
- **Kitty Integration** — Each agent gets its own Kitty tab with auto-launch
- **Team Assembly** — Assemble all 3 agents with a single command
- **Project State Persistence** — Resume projects from last checkpoint
- **Token Auto-retry** — Agents auto-pause on rate limit and resume automatically
- **Session Management** — Delete logs, project workspaces, or full clean from menu
- **Task Assignment** — Assign tasks to specific agents with full logging
- **Workflow Tracking** — Follow the 6-phase D-AMS lifecycle

---

## Quick Start

### Prerequisites

- Linux with [Kitty terminal](https://sw.kovidgoyal.net/kitty/)
- At least one of: `claude`, `gemini`, `opencode` available in `$PATH`

### Install

```bash
git clone https://github.com/nguyenthuongaz9/agents_manager.git
cd agents_manager/d-ams
bash install.sh
```

Restart your terminal or run `source ~/.bashrc`, then use the `d-ams` command.

### Usage

```bash
d-ams                     # Interactive mode (recommended)
d-ams --assemble          # Launch all 3 agents in Kitty tabs
d-ams --launch CLAUDE     # Launch a specific agent
d-ams --launch GEMINI
d-ams --launch OPENCODE
d-ams --log               # View recent session log
d-ams --help              # Show help
d-ams --version           # Show version

# Backward-compatible alias
agents                    # Same as d-ams
```

### Kitty Session File

Launch the full layout (manager + 3 agents) directly:

```bash
kitty --session config/kitty.session
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
- Token retry wait time (`TOKEN_RETRY_WAIT`)
- Workflow phases

```bash
# Example: change token retry wait to 5 minutes
TOKEN_RETRY_WAIT=300
```

---

## Project Structure

```
d-ams/
├── bin/
│   └── d-ams             # Main executable
├── lib/
│   ├── ui.sh             # Terminal UI helpers
│   ├── kitty.sh          # Kitty terminal integration
│   ├── state.sh          # Project state persistence
│   └── logging.sh        # Session logging utilities
├── config/
│   ├── agents.conf       # Agent definitions & settings
│   └── kitty.session     # Kitty session layout
├── prompts/              # System prompts per agent role
│   ├── leader.md
│   ├── backend-dev.md
│   ├── tech-lead.md
│   ├── qa.md
│   └── dba.md
├── docs/                 # Architecture documentation
├── examples/             # Sample project requests
├── sessions/             # Session logs & project workspaces
└── install.sh            # Installation script
```

---

## License

Apache License 2.0
