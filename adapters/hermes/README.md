# Hermes Adapter

Adapter for [Hermes](https://github.com/anthropics/hermes) agent framework.

## Files

- `HOOK.yaml` — Hook registration (events: gateway:startup, agent:end, session:reset)
- `handler.py` — Python event handler for transcript capture

## Installation

```bash
./install.sh --adapter hermes <workspace-path> [vault-path]
```

Or let the installer auto-detect if you have `.hermes/` in your workspace.

## Hook Events

| Event | Purpose |
|-------|---------|
| `gateway:startup` | Initialize vault structure |
| `agent:end` | Capture assistant response to transcript |
| `session:reset` | Mark session boundary |

## Skills

Hermes uses its native `skill_manage` tool. The installer copies skill definitions to `~/.hermes/skills/mnemos/`.

## Notes

- Hermes has native memory (MEMORY.md/USER.md) for quick notes
- mnemos handles deep, long-term knowledge synthesis
- Skills are registered via `skill_manage(action="create", ...)` during install
- Cron jobs use `cronjob_manage()` for scheduled maintenance
