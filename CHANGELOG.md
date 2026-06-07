# Changelog

## v1.1.0 — 2026-06-07

### Added
- **Project state persistence** — workspace/project-state.conf tracks each agent's status, task, and checkpoint
- **Continue Project** — resume a saved project; agents receive checkpoint context automatically
- **Agent checkpoints** — agents write progress summaries to checkpoint-<AGENT>.md
- **Token auto-retry** — agents auto-pause on rate/token limit and resume after configurable wait
- **Manage Sessions** — delete logs, project workspaces, or full clean from the menu
- Update Agent Checkpoint — manually record agent progress from the manager

### Changed
- Project restructured to professional layout: `d-ams/bin/d-ams`, `d-ams/lib/`, `d-ams/config/`
- Prompts and docs consolidated into `d-ams/prompts/` and `d-ams/docs/`
- Renamed kitty session file from `d-ams.kitty.session` to `kitty.session`
- Main executable renamed from `agent-manager.sh` to `d-ams` (with `agents` backward-compat alias)
- `TOKEN_RETRY_WAIT` configurable in `config/agents.conf`

## v1.0.0 — 2026-06-06

- Initial release: D-AMS Agent Manager
- Kitty terminal integration with tab-per-agent assembly
- 6-phase workflow, session logging
- Claude Code, Gemini, OpenCode support
