# mnemos Universal Installer — Auto-Detect Your Platform

You are installing mnemos, a 3-layer memory system. This guide helps you detect your platform and run the correct installation.

---

## Recommended: Use install.sh

The simplest approach is to clone the repo and run the installer, which auto-detects your platform:

```bash
git clone https://github.com/adiman9/mnemos.git /tmp/mnemos
cd <workspace>
/tmp/mnemos/install.sh . ~/.mnemos/vault
```

The installer will auto-detect:
- Claude Code / Cursor / Cline
- OpenCode
- Pi Framework
- OpenClaw
- Codex CLI
- FactoryAI Droids
- Hermes

To force a specific adapter:

```bash
/tmp/mnemos/install.sh --adapter <adapter-name> <workspace> <vault-path>
```

Available adapters: `claude-code`, `opencode`, `pi`, `openclaw`, `codex`, `droids`, `hermes`

---

## Platform-Specific Install Guides

If you prefer step-by-step guidance, use the platform-specific guides:

| Platform | Install Guide |
|----------|---------------|
| **Claude Code** | [claude-code.md](https://raw.githubusercontent.com/adiman9/mnemos/main/install/claude-code.md) |
| **Cursor** | [cursor.md](https://raw.githubusercontent.com/adiman9/mnemos/main/install/cursor.md) |
| **Cline** (v3.36+) | [claude-code.md](https://raw.githubusercontent.com/adiman9/mnemos/main/install/claude-code.md) |
| **OpenCode** | [opencode.md](https://raw.githubusercontent.com/adiman9/mnemos/main/install/opencode.md) |
| **Pi Framework** | [pi.md](https://raw.githubusercontent.com/adiman9/mnemos/main/install/pi.md) |
| **OpenClaw** | [openclaw.md](https://raw.githubusercontent.com/adiman9/mnemos/main/install/openclaw.md) |
| **Graphone** | [pi.md](https://raw.githubusercontent.com/adiman9/mnemos/main/install/pi.md) |
| **FactoryAI Droids** | [droids.md](https://raw.githubusercontent.com/adiman9/mnemos/main/install/droids.md) |
| **Codex CLI** | [codex.md](https://raw.githubusercontent.com/adiman9/mnemos/main/install/codex.md) |
| **Hermes** | [hermes.md](https://raw.githubusercontent.com/adiman9/mnemos/main/install/hermes.md) |

---

## Manual Platform Detection

If you need to determine which platform you're on:

### Check 1: Is there a `.claude/` directory in the project?
→ **Claude Code / Cursor / Cline**

### Check 2: Is there `.opencode/` or `opencode.json`?
→ **OpenCode**

### Check 3: Is there a `.pi/` directory?
→ **Pi Framework** (also covers Graphone)

### Check 4: Is there a `.openclaw/` directory or `openclaw` CLI?
→ **OpenClaw**

### Check 5: Is there a `.factory/` directory?
→ **FactoryAI Droids**

### Check 6: Is there a `.codex/` directory?
→ **Codex CLI** (partial hook support)

### Check 7: Is there a `.hermes/` directory or `skill_manage` tool?
→ **Hermes**

---

## Hook Coverage by Platform

| Platform | Session Start | Transcript | Post-write | Auto-commit |
|----------|--------------|------------|------------|-------------|
| Claude Code / Cursor / Cline | ✅ | ✅ | ✅ | ✅ |
| OpenCode | ✅ | ✅ | ✅ | ✅ |
| Pi / OpenClaw / Graphone | ✅ | ✅ | ✅ | ✅ |
| FactoryAI Droids | ✅ | ✅ | ✅ | ✅ |
| Hermes | ✅ | ✅ | — | — |
| Codex CLI | ❌ | ⚠️ Per-turn | ❌ | ⚠️ Per-turn |

---

## What Gets Installed

All platforms get:

### Vault Structure
```
~/.mnemos/vault/
├── self/           # Identity, methodology, goals
├── notes/          # Permanent knowledge (Layer 2)
├── memory/
│   ├── daily/      # Observations by day (Layer 1)
│   ├── sessions/   # Transcript archives
│   └── .dreams/    # Speculative connections (Layer 3)
├── inbox/          # Items pending processing
└── ops/            # Operational state
```

### Core Skills
- `/observe` — Extract typed observations from session transcripts
- `/consolidate` — Promote observations to permanent notes
- `/recall` — Search vault for relevant knowledge
- `/dream` — Generate speculative cross-domain connections
- `/seed`, `/reduce`, `/reflect`, `/reweave`, `/verify` — Full processing pipeline
- `/learn`, `/fetch`, `/curiosity` — Research and discovery
- `/stats`, `/graph`, `/next` — Maintenance and navigation

---

## After Installation

1. **Restart** your agent/gateway to load hooks
2. **Have some conversations** to generate transcripts
3. **Run `/observe`** to extract first observations
4. **Run `/consolidate`** to create first notes
5. **Try `/recall [topic]`** to search your vault

---

## Troubleshooting

### Hook not firing
- Did you restart the gateway/agent?
- Check hook file locations match platform expectations

### Vault empty
- Hooks may not be capturing — check hook logs
- Try running `/observe` manually after a few conversations

### Skills not found
- Check skill files are in correct location for your platform
- For Claude Code: `.claude/skills/`
- For OpenCode: `.opencode/skills/`
- For OpenClaw: `~/.openclaw/skills/mnemos/`
- For Hermes: `~/.hermes/skills/mnemos/`

---

## Getting Help

- Repository: https://github.com/adiman9/mnemos
- Issues: https://github.com/adiman9/mnemos/issues
