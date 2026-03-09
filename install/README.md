# mnemos Self-Install

Point your AI agent at one of these URLs and tell it to install mnemos.

## Quick Install

Tell your agent:

> "Read [URL] and follow the instructions to install mnemos"

| Platform | Status | URL |
|----------|--------|-----|
| **Claude Code** | Stable | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/claude-code.md` |
| **Cursor** | Stable | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/cursor.md` |
| **Cline** (v3.36+) | Stable | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/claude-code.md` |
| **OpenCode** | Beta | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/opencode.md` |
| **Pi Framework** | Beta | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/pi.md` |
| **OpenClaw** | Experimental | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/openclaw.md` |
| **Graphone** | Beta | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/pi.md` |
| **FactoryAI Droids** | Beta | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/droids.md` |
| **Codex CLI** | Partial | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/codex.md` |
| **Hermes** | Stable | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/hermes.md` |
| **Auto-detect** | — | `https://raw.githubusercontent.com/adiman9/mnemos/main/install/universal.md` |

### Hook Coverage by Platform

| Platform | Session Start | Transcript | Post-write | Auto-commit |
|----------|--------------|------------|------------|-------------|
| Claude Code / Cursor / Cline | ✅ | ✅ | ✅ | ✅ |
| OpenCode | ✅ | ✅ | ✅ | ✅ |
| Pi / OpenClaw / Graphone | ✅ | ✅ | ✅ | ✅ |
| FactoryAI Droids | ✅ | ✅ | ✅ | ✅ |
| Hermes | ✅ | ✅ | — | — |
| Codex CLI | ❌ | ⚠️ Per-turn | ❌ | ⚠️ Per-turn |

## How It Works

All install guides now use the same pattern:

1. Clone the mnemos repository from GitHub
2. Run `install.sh` with the appropriate adapter
3. The installer copies files from the repo to the correct locations
4. Restart the agent to load hooks

**No more recreating files from scratch.** The agent pulls actual source files from the repository.

## What Gets Installed

- **Hooks** — Platform-specific lifecycle hooks from `adapters/`
- **Skills** — Full skill library from `core/skills/`
- **Scripts** — Shell scripts from `core/hooks/scripts/`
- **Vault** — Persistent storage at `~/.mnemos/vault/`
- **Templates** — Note schemas from `core/templates/`

## After Installation

```
/observe      — Extract insights from recent sessions
/consolidate  — Promote observations to permanent notes
/recall       — Search your knowledge vault
/dream        — Generate speculative cross-domain connections
```

The vault grows silently in the background. Your platform's native memory handles quick notes; mnemos handles deep, long-term knowledge.

## Vault Location

Default: `~/.mnemos/vault/`

Override with: `MNEMOS_VAULT` environment variable or `.mnemos.yaml` config.

## Platform Notes

### Cursor / Cline
Both use the Claude Code hooks spec. The Cursor installer is a redirect to Claude Code with Cursor-specific notes.

### Pi / OpenClaw / Graphone
All use the Pi adapter. OpenClaw and Graphone are built on Pi. Use `install/pi.md` for all three.

### Codex CLI
Partial support only. No session-start hook. Transcript capture only at turn boundaries. Skills work fully.

### Hermes
Uses Python hooks. Full skill support. Native memory system (MEMORY.md) handles boot context.
