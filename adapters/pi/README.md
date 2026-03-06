# Pi Agent Framework Adapter

Adapter for [Pi](https://github.com/badlogic/pi-mono) (`@mariozechner/pi-coding-agent`) and any agent built on the Pi runtime.

This is the recommended adapter for the Pi ecosystem, including OpenClaw, Graphone, and custom Pi-based agents.

## What It Does

- Registers a Pi extension that executes mnemos hook scripts at lifecycle events
- Injects MEMORY.md boot context via the `context` event
- Validates notes after write/edit tool execution
- Archives sessions on shutdown
- Skills loaded via `AGENTS.md` / `CLAUDE.md` (Pi reads both natively)

## Hook Coverage

| mnemos Event | Pi Event | Status |
|-------------|----------|--------|
| SessionStart | `session_start` + `context` | Full |
| PostToolUse (Write) | `tool_execution_end` | Full |
| Stop | `session_shutdown` | Full |
| Auto-commit | `tool_execution_end` (fire-and-forget) | Full |

**Full coverage.** All 4 mnemos lifecycle events are natively supported.

## Install

```bash
./install.sh --adapter pi <workspace-path> <vault-path>
```

This will:
1. Copy skills to `<workspace>/.claude/skills/` (Pi reads `.claude/skills/` natively)
2. Copy hook scripts to `<workspace>/.mnemos/hooks/scripts/`
3. Copy extension to `<workspace>/.pi/extensions/mnemos-extension.ts`
4. Copy `SYSTEM.md` as both `CLAUDE.md` and `AGENTS.md` at workspace root

## Manual Setup

If you prefer manual installation:

1. Copy `mnemos-extension.ts` to your Pi extensions directory
2. Register in your Pi config or pass via CLI: `pi --extension .pi/extensions/mnemos-extension.ts`

## Relationship to OpenClaw

Pi is the engine; OpenClaw is one distribution built on Pi. This adapter works with bare Pi, OpenClaw, Graphone, and any other Pi-based agent. If you're using OpenClaw specifically, this adapter is still the right choice — the OpenClaw adapter exists as a convenience for OpenClaw's Hook Pack format but this extension approach is cleaner.
