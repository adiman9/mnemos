# Cursor Adapter

Cursor supports the [Claude Code hooks.json spec](https://docs.anthropic.com/en/docs/claude-code/hooks). **Use the `claude-code` adapter directly.**

## Install

```bash
./install.sh --adapter claude-code <workspace-path> <vault-path>
```

Cursor reads hooks from `.cursor/hooks.json` (project) or `~/.cursor/hooks.json` (global). The Claude Code adapter's `hooks.json` is compatible — just copy to the Cursor location if needed:

```bash
cp <workspace>/.claude/hooks/hooks.json <workspace>/.cursor/hooks.json
```

## Hook Coverage

Same as Claude Code — full coverage of all 4 mnemos lifecycle events.

## Notes

- Cursor also supports **prompt-based hooks** (natural language conditions evaluated by the LLM). Not used by mnemos but available for custom extensions.
- Cursor reads `.cursorrules` for system prompt. The installer copies `SYSTEM.md` as `CLAUDE.md` which Cursor also reads.
