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

## What Gets Installed

- **Hook** — Captures session transcripts automatically
- **Skills** — `/observe`, `/consolidate`, `/recall`, `/dream` for knowledge management
- **Vault** — Persistent storage at `~/.mnemos/vault/`
- **Cron** — Daily/weekly maintenance jobs (platform-dependent)

## How It Works

The install files contain step-by-step instructions written FOR your AI agent. The agent:

1. Fetches the URL
2. Reads the markdown instructions
3. Executes each step using its native tools (`write_file`, `skill_manage`, etc.)
4. Tells you to restart the gateway/agent

No npm, no CLI tools, no dependencies. Pure agent self-modification.

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
