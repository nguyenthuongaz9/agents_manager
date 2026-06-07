<div align="center">
  <h1>D-AMS Agent Manager</h1>
  <p><strong>Dynamic Agent Management System</strong></p>
  <p>Orchestrate Claude Code · Gemini · OpenCode in Kitty Terminal</p>
  <p>
    <img src="https://img.shields.io/badge/platform-linux-blue?style=flat-square" />
    <img src="https://img.shields.io/badge/terminal-kitty-orange?style=flat-square" />
    <img src="https://img.shields.io/badge/version-1.1.0-purple?style=flat-square" />
    <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" />
  </p>
</div>

---

## Overview

**D-AMS** is a terminal orchestration tool that coordinates multiple AI coding agents as a team. It launches each agent in its own [Kitty](https://sw.kovidgoyal.net/kitty/) tab, tracks project progress, and automatically handles interruptions — including token/rate limit pauses with timed auto-resume.

### Managed Agents

| Agent | Role | Command |
|-------|------|---------|
| 🟣 **Claude Code** | Backend Developer / Systems Programmer | `claude` |
| 🔵 **Gemini** | Leader Agent / Tech Lead | `gemini` |
| 🟢 **OpenCode** | QA/QC Engineer / Frontend Developer | `opencode` |

---

## Features

| Feature | Description |
|---------|-------------|
| **Interactive TUI** | Menu-driven interface — no flags needed for daily use |
| **Team Assembly** | Launch all agents at once, each with a role-specific prompt |
| **Project State** | Progress saved to `project-state.conf` — survives restarts |
| **Continue Project** | Resume any saved project; agents pick up from their checkpoint |
| **Token Auto-retry** | Agents auto-pause on rate/token limit, countdown, then resume |
| **Agent Checkpoints** | Agents write `checkpoint-<AGENT>.md`; used as context on resume |
| **Session Management** | Delete logs, specific workspaces, or full clean — from the menu |
| **6-Phase Workflow** | Structured lifecycle from intake to delivery |

---

## Requirements

- Linux with [Kitty terminal](https://sw.kovidgoyal.net/kitty/) (`listen_on` enabled for remote control)
- At least one of: `claude`, `gemini`, `opencode` in `$PATH`
- `bash` 4.0+, `sed`, `find`, `python3` (for Kitty window lookup)

---

## Install

```bash
git clone https://github.com/nguyenthuongaz9/agents_manager.git
cd agents_manager/d-ams
bash install.sh
```

Then restart your terminal or run `source ~/.bashrc`.

The installer copies files to `~/.local/share/d-ams/` and creates two symlinks:

```
~/.local/bin/d-ams    ← main command
~/.local/bin/agents   ← backward-compatible alias
```

To reinstall after updates:

```bash
cd agents_manager/d-ams
bash install.sh   # cleans old files, re-copies, re-links
```

---

## Usage

```bash
d-ams                      # Interactive mode (recommended)
d-ams --assemble           # Launch all agents immediately
d-ams --launch CLAUDE      # Launch a single agent (CLAUDE | GEMINI | OPENCODE)
d-ams --log                # Tail the most recent session log
d-ams --version
d-ams --help

agents                     # Same as d-ams (alias)
```

### Kitty Session Layout

Launch the full multi-tab layout in one command:

```bash
kitty --session d-ams/config/kitty.session
```

---

## Menu Reference

```
 1  Start New Project & Assemble Team
 2  Continue Existing Project
 3  Launch Agent (Kitty tab)
 4  Assign Task to Agent
 5  Update Agent Progress / Checkpoint
 6  View Session Log
 7  Manage Sessions
 8  Workflow Status
 9  Configure Settings
10  Help / About
 0  Quit
```

---

## Workflow

The 6-phase lifecycle guided by the interactive menu:

| Phase | Name | What happens |
|-------|------|-------------|
| 1 | Intake & Analysis | Define project name, type, requirements |
| 2 | Team Assembly | Launch agents in Kitty tabs with role prompts |
| 3 | Planning & Tasking | Tech Lead designs architecture, assigns work |
| 4 | Execution & Review | Agents implement their assigned components |
| 5 | Domain-Specific QA | Test, review, fix issues |
| 6 | Delivery | Package and ship the final product |

---

## Project State & Checkpoints

When you start a project, D-AMS creates a workspace directory:

```
sessions/
└── <project-name>_workspace/
    ├── requirements.md          ← project requirements
    ├── CLAUDE.md                ← auto-read by Claude Code on startup
    ├── project-state.conf       ← agent statuses, tasks, retry counts
    ├── checkpoint-CLAUDE.md     ← written by Claude when milestones complete
    ├── checkpoint-GEMINI.md
    └── checkpoint-OPENCODE.md
```

`project-state.conf` tracks per-agent state:

```
AGENT_CLAUDE_STATUS=running       # pending|running|paused_token|completed|failed
AGENT_CLAUDE_TASK=Build REST API
AGENT_CLAUDE_CHECKPOINT=Auth module done. Next: products and cart endpoints.
AGENT_CLAUDE_RETRY_COUNT=0
```

**To resume a project:** choose option `2 → Continue Existing Project`. D-AMS reads each agent's checkpoint and builds a "resume from where you left off" prompt automatically.

---

## Token Auto-retry

When an agent hits a rate or token limit, its Kitty tab:

1. Detects the error — checks Claude's project JSONL logs for `rate_limit` / `usage_limit` / `overloaded`, plus a fast-exit heuristic (exit ≠ 0 and elapsed < 30 s)
2. Updates `project-state.conf` → `paused_token`
3. Shows a live countdown to the next retry
4. Resumes automatically — reads `checkpoint-<AGENT>.md` and continues

```
⏸  Token/rate limit — auto-pausing 60 min
   Retry 1/24  |  Ctrl+C to cancel auto-retry
   Resuming in 59:47...
```

Configure the wait time in `config/agents.conf`:

```bash
TOKEN_RETRY_WAIT=3600   # seconds (default: 1 hour)
TOKEN_RETRY_WAIT=300    # 5 min — for short API rate limits
```

---

## Session Management (menu option 7)

```
Manage Sessions
  1  Delete session logs only (*.log)
  2  Delete a project workspace
  3  Delete ALL session data (full clean)
```

- **Delete logs** — removes `*.log` files, reinitializes the active log
- **Delete workspace** — pick a project by name; clears its workspace dir and state; confirms before acting; resets the active project if it was the one deleted
- **Delete all** — wipes everything under `sessions/`; shows counts and warns before proceeding

---

## Configuration

All configuration lives in `config/agents.conf`:

```bash
# Agent definitions
AGENT_CLAUDE_NAME="Claude Code"
AGENT_CLAUDE_COMMAND="claude"
AGENT_CLAUDE_ROLE="Backend Developer / Systems Programmer"

# Default team leader
DEFAULT_LEADER="GEMINI"

# Token/rate-limit auto-retry wait (seconds)
TOKEN_RETRY_WAIT=3600
```

---

## Project Structure

```
d-ams/
├── bin/
│   └── d-ams               # Main executable (entry point)
├── lib/
│   ├── ui.sh               # Terminal UI helpers (colors, menus, prompts)
│   ├── kitty.sh            # Kitty integration — launcher scripts, tab/window control
│   ├── state.sh            # Project state read/write (project-state.conf)
│   └── logging.sh          # Session logging utilities
├── config/
│   ├── agents.conf         # Agent definitions, TOKEN_RETRY_WAIT, phases
│   └── kitty.session       # Kitty multi-tab session layout
├── prompts/                # Reference system prompts per role
│   ├── leader.md
│   ├── backend-dev.md
│   ├── tech-lead.md
│   ├── qa.md
│   └── dba.md
├── docs/                   # Architecture and design documentation
│   ├── architecture.md
│   ├── workflow.md
│   ├── agents.md
│   └── ...
├── examples/
│   └── sample-request.md   # Example project requirement format
├── sessions/               # Runtime: logs + project workspaces (git-ignored)
└── install.sh              # Installer
```

---

## How Agent Launchers Work

Each agent tab runs a self-contained bash script generated by `lib/kitty.sh`. The script:

1. Shows the agent's role brief
2. Runs the agent with its initial task prompt
3. On exit, checks for token limit (log scan + fast-exit heuristic)
4. If token-limited: updates state, countdowns, relaunches with checkpoint context
5. If normal exit: marks agent as `completed`

The generated launcher is written to `/tmp/d-ams-launcher-<AGENT>.sh` before each launch.

---

## License

MIT
