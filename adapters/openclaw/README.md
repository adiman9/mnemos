# OpenClaw Adapter

Adapter for [OpenClaw](https://github.com/openclaw/openclaw) via its Hook Pack system.

## What It Does

- Registers hooks via `package.json` + `hooks.json5` (OpenClaw's hook pack format)
- Executes the same shell scripts as other adapters
- Skills deployed to `.claude/skills/` (OpenClaw uses Claude Agent SDK conventions)

## Hook Coverage

| mnemos Event | OpenClaw Hook | Status |
|-------------|---------------|--------|
| SessionStart | `session_start` | Full |
| PostToolUse (Write) | `after_tool_call` (tool_filter: write) | Full |
| Stop | `agent_end` | Full |
| Auto-commit | `after_tool_call` (async) | Full |

**Full coverage.** All 4 mnemos lifecycle events are supported.

## Install

```bash
# From mnemos root:
./install.sh --adapter openclaw <workspace-path> <vault-path>
```

This will:
1. Copy skills to `<workspace>/.claude/skills/`
2. Copy hook scripts to `<workspace>/.mnemos/hooks/scripts/`
3. Copy hook pack files to `<workspace>/.openclaw/hooks/mnemos/`
4. Copy `SYSTEM.md` as `CLAUDE.md` at workspace root

## Status

**Experimental.** Hook event names and `hooks.json5` format based on OpenClaw source analysis. May need adjustment for specific OpenClaw versions.
