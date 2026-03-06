# OpenCode Adapter

Adapter for [OpenCode](https://github.com/sst/opencode) via its TypeScript plugin system.

## What It Does

- Registers a plugin that executes the same shell scripts as Claude Code
- Injects MEMORY.md boot context via `experimental.chat.system.transform`
- Validates notes after write/edit via `tool.execute.after`
- Archives sessions via `experimental.session.compacting`
- Skills loaded via `AGENTS.md` (OpenCode reads `CLAUDE.md` / `AGENTS.md` natively)

## Hook Coverage

| mnemos Event | OpenCode Hook | Status |
|-------------|---------------|--------|
| SessionStart | `experimental.chat.system.transform` | Full |
| PostToolUse (Write) | `tool.execute.after` | Full |
| Stop | `experimental.session.compacting` | Partial (triggers on compaction, not session end) |
| Auto-commit | `tool.execute.after` (async) | Full |

## Install

```bash
# From mnemos root:
./install.sh --adapter opencode <workspace-path> <vault-path>
```

This will:
1. Copy skills to `<workspace>/.opencode/skills/` (if supported) or rely on AGENTS.md
2. Copy hook scripts to `<workspace>/.mnemos/hooks/scripts/`
3. Copy plugin to `<workspace>/.opencode/plugins/mnemos-plugin.ts`
4. Add plugin reference to `opencode.json`
5. Copy `SYSTEM.md` as `AGENTS.md` at workspace root

## Requirements

- OpenCode with plugin support enabled
- Bun runtime (OpenCode's default)
