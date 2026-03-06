# Claude Code Adapter

Native adapter for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Also works with **Cursor** and **Cline** (v3.36+), which support the same `hooks.json` format.

## What It Does

- Deploys skills to `.claude/skills/`
- Deploys hooks to `.claude/hooks/` (hooks.json + shell scripts)
- Copies `SYSTEM.md` as `CLAUDE.md` at workspace root

## Hook Events Used

| Event | Script | Purpose |
|-------|--------|---------|
| `SessionStart` | `session-start.sh` | Inject MEMORY.md, vault stats, maintenance alerts |
| `Stop` | `session-capture.sh` | Archive session, prompt for observations |
| `PostToolUse` (Write, sync) | `validate-note.sh` | Schema enforcement on note writes |
| `PostToolUse` (Write, async) | `auto-commit.sh` | Non-blocking git commit on vault changes |

## Full Hook Coverage

All 4 mnemos lifecycle events are natively supported. No degradation.

## Install

```bash
# From mnemos root:
./install.sh --adapter claude-code <workspace-path> <vault-path>

# Or auto-detect (default for workspaces with .claude/):
./install.sh <workspace-path> <vault-path>
```
