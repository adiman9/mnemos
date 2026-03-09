# mnemos for Cursor — Agent Installation Guide

**Cursor uses the Claude Code hooks spec.** Follow the Claude Code installer instead.

---

## Redirect

Cursor supports the same `hooks.json` format as Claude Code. Use the Claude Code installer:

**URL**: `https://raw.githubusercontent.com/adiman9/mnemos/main/install/claude-code.md`

---

## Cursor-Specific Notes

After following the Claude Code installer, note these Cursor differences:

### Hook Location

Cursor reads hooks from:
- **Project**: `.cursor/hooks.json`
- **Global**: `~/.cursor/hooks.json`

If the Claude Code installer creates hooks at `.claude/hooks/hooks.json`, copy to Cursor's location:

```bash
mkdir -p <workspace>/.cursor
cp <workspace>/.claude/hooks/hooks.json <workspace>/.cursor/hooks.json
```

### System Prompt

Cursor reads multiple files for system context:
- `.cursorrules` — Cursor-specific rules
- `CLAUDE.md` — Claude Code instructions (also read by Cursor)

The Claude Code installer creates `CLAUDE.md`, which Cursor will read automatically.

### Prompt-Based Hooks

Cursor also supports **prompt-based hooks** — natural language conditions evaluated by the LLM. mnemos doesn't use these, but they're available for custom extensions if needed.

---

## Quick Summary

1. Follow the Claude Code installer: `https://raw.githubusercontent.com/adiman9/mnemos/main/install/claude-code.md`
2. Copy hooks to Cursor location: `cp .claude/hooks/hooks.json .cursor/hooks.json`
3. Restart Cursor

That's it. Full hook coverage, same as Claude Code.
