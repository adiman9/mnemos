# Amp Adapter

Adapter for [Amp](https://github.com/nichochar/amp) (by Sourcegraph).

## Status: Planned

Amp uses a "Toolbox" system — shell scripts in an `AMP_TOOLBOX` directory that respond to `describe` and `execute` actions. It also supports "Agent Skills" as directories with `SKILL.md` + `mcp.json`.

## Hook Coverage

| mnemos Event | Amp Equivalent | Status |
|-------------|----------------|--------|
| SessionStart | Toolbox `describe` at startup | Partial |
| PostToolUse (Write) | Subagent / Toolbox | Possible but indirect |
| Stop | None documented | Not supported |
| Auto-commit | Toolbox | Possible |

## What Works

- **Skills**: Amp reads `SKILL.md` natively — same format as mnemos core skills.
- **System prompt**: Amp reads `AGENT.md` for project rules.
- **MCP tools**: Amp supports MCP for custom tools.

## Install

```bash
./install.sh --adapter amp <workspace-path> <vault-path>
```

## TODO

- [ ] Build Toolbox scripts that wrap mnemos hook scripts
- [ ] Test SKILL.md compatibility with Amp's progressive disclosure
- [ ] Verify MCP tool name mapping
