# mnemos Universal Installer — Auto-Detect Your Platform

You are installing mnemos, a 3-layer memory system. This guide will help you detect your platform and route to the correct installation.

---

## Step 0: Detect Your Platform

Check which agent environment you're running in:

### Check 1: Do you have `skill_manage` tool?

If yes → You are **Hermes**. 

**Go to**: https://raw.githubusercontent.com/adiman9/mnemos/main/install/hermes.md

---

### Check 2: Do you have access to `openclaw` CLI commands?

Check if you can run `openclaw cron list` or similar.

If yes → You are **OpenClaw**.

**Go to**: https://raw.githubusercontent.com/adiman9/mnemos/main/install/openclaw.md

---

### Check 3: Is there a `.pi/` directory or are you using Pi framework?

Check if you can create `.pi/extensions/*.ts` files.

If yes → You are **Pi Framework** (also covers Graphone).

**Go to**: https://raw.githubusercontent.com/adiman9/mnemos/main/install/pi.md

---

### Check 4: Is there a `.factory/` directory or are you using FactoryAI Droids?

Check if you can create `.factory/hooks.json` files.

If yes → You are **FactoryAI Droids**.

**Go to**: https://raw.githubusercontent.com/adiman9/mnemos/main/install/droids.md

---

### Check 5: Is there a `.codex/` directory or do you have Codex CLI?

Check if `~/.codex/` exists or you can configure `config.toml`.

If yes → You are **Codex CLI**.

**Go to**: https://raw.githubusercontent.com/adiman9/mnemos/main/install/codex.md

⚠️ Note: Codex has partial hook support only.

---

### Check 6: Is there a `.claude/` directory in the project?

Check if `.claude/hooks.json` exists or can be created.

If yes → You are **Claude Code / Cursor / Cline**.

**Go to**: https://raw.githubusercontent.com/adiman9/mnemos/main/install/claude-code.md

For **Cursor** specifically: https://raw.githubusercontent.com/adiman9/mnemos/main/install/cursor.md

---

### Check 7: Do you have access to OpenCode plugin system?

Check if you can create `.opencode/plugins/*.ts` files and have a `opencode.json`.

If yes → You are **OpenCode**.

**Go to**: https://raw.githubusercontent.com/adiman9/mnemos/main/install/opencode.md

---

### Still unsure?

Check what tools you have available:
- `skill_manage`, `cronjob_manage` → Hermes
- `openclaw` CLI → OpenClaw
- `.pi/extensions/` + TypeScript → Pi Framework
- `.factory/hooks.json` → FactoryAI Droids
- `.codex/config.toml` → Codex CLI
- Bash + file editing, `.claude/` → Claude Code
- TypeScript plugin API, `.opencode/` → OpenCode

Pick the closest match and proceed.

---

# Platform Quick Reference

| Platform | Install URL | Hook Coverage |
|----------|-------------|---------------|
| Claude Code | `install/claude-code.md` | Full |
| Cursor | `install/cursor.md` | Full |
| Cline | `install/claude-code.md` | Full |
| OpenCode | `install/opencode.md` | Full |
| Pi Framework | `install/pi.md` | Full |
| OpenClaw | `install/openclaw.md` | Full |
| Graphone | `install/pi.md` | Full |
| FactoryAI Droids | `install/droids.md` | Full |
| Codex CLI | `install/codex.md` | **Partial** |
| Hermes | `install/hermes.md` | Full |

---

# Section H: Hermes Installation

*Full instructions at: hermes.md*

## Quick Summary

1. **Create hook** at `~/.hermes/hooks/mnemos/` with `HOOK.yaml` and `handler.py`
2. **Create skills** using `skill_manage(action='create', name='observe', category='mnemos', ...)`
3. **Initialize vault** at `~/.mnemos/vault/`
4. **Set up cron** using `cronjob_manage()`
5. **Tell user** to run `hermes gateway restart`

**Key tools**: `write_file()`, `skill_manage()`, `cronjob_manage()`

---

# Section O: OpenClaw Installation

*Full instructions at: openclaw.md*

## Quick Summary

1. **Create hook** at `~/.openclaw/hooks/mnemos/` with `HOOK.yaml` and `handler.js`
2. **Create skills** at `~/.openclaw/skills/mnemos/*/SKILL.md`
3. **Initialize vault** at `~/.mnemos/vault/`
4. **Set up cron** using `openclaw cron add`
5. **Tell user** to run `openclaw gateway restart`

**Key tools**: File writing, `openclaw cron add`

---

# Section P: Pi Framework Installation

*Full instructions at: pi.md*

## Quick Summary

1. **Create extension** at `.pi/extensions/mnemos-extension.ts`
2. **Create scripts** at `.mnemos/hooks/scripts/` (session-start.sh, validate-note.sh)
3. **Create skills** at `.claude/skills/` (Pi reads these natively)
4. **Initialize vault** at `~/.mnemos/vault/`
5. **Create config** `.mnemos.yaml` pointing to vault
6. **Tell user** to start Pi with `--extension .pi/extensions/mnemos-extension.ts`

**Key tools**: TypeScript extension, shell scripts

---

# Section D: FactoryAI Droids Installation

*Full instructions at: droids.md*

## Quick Summary

1. **Create hooks** at `.factory/hooks.json` and `.factory/hooks/scripts/`
2. **Create skills** at `.factory/skills/`
3. **Initialize vault** at `~/.mnemos/vault/`
4. **Create config** `.mnemos.yaml` pointing to vault
5. **Create DROIDS.md** with mnemos instructions

**Key tools**: JSON hooks, shell scripts

**Droids-specific**: Context injection uses `additionalContext` JSON response, not stdout.

---

# Section X: Codex CLI Installation

*Full instructions at: codex.md*

## Quick Summary

1. **Create notify hook** at `.codex/hooks/codex-notify.sh`
2. **Configure** `.codex/config.toml` with notify hook
3. **Create skills** at `<workspace>/skills/`
4. **Initialize vault** at `~/.mnemos/vault/`
5. **Update AGENTS.md** with mnemos instructions

**Key tools**: Shell script, TOML config

**⚠️ Limitations**: No session-start hook. Transcript capture only at turn boundaries.

---

# Section C: Claude Code / Cursor / Cline Installation

*Full instructions at: claude-code.md*

## Quick Summary

1. **Create scripts** at `~/.mnemos/scripts/` (session-start.sh, session-capture.sh)
2. **Configure hooks** in `.claude/hooks.json`
3. **Initialize vault** at `~/.mnemos/vault/`
4. **Add skills** to `CLAUDE.md`
5. **Optional**: Set up launchd/cron for scheduled maintenance

**Key tools**: Bash, file editing

**For Cursor**: Copy hooks to `.cursor/hooks.json` after install.

---

# Section OC: OpenCode Installation

*Full instructions at: opencode.md*

## Quick Summary

1. **Create plugin** at `.opencode/plugins/mnemos-plugin.ts`
2. **Create scripts** at `.mnemos/hooks/scripts/` (session-start.sh, validate-note.sh)
3. **Create config** `.mnemos.yaml` pointing to vault
4. **Update** `opencode.json` with plugin reference
5. **Initialize vault** at `~/.mnemos/vault/`
6. **Add skills** to `AGENTS.md`
7. **Restart** OpenCode to load plugin

**Key tools**: File editing, TypeScript plugin

---

# Common Elements (All Platforms)

## Vault Structure

All platforms use the same vault at `~/.mnemos/vault/`:

```
~/.mnemos/vault/
├── self/                  # Identity, methodology, goals
│   ├── identity.md
│   └── goals.md
├── notes/                 # Knowledge graph (Layer 2)
├── memory/                # Working memory (Layer 1)
│   ├── MEMORY.md          # Boot context
│   ├── daily/             # Typed observations per day
│   ├── sessions/          # Transcript archives
│   └── .dreams/           # Speculations (Layer 3)
├── ops/                   # Operations
│   ├── config.yaml
│   ├── queue/
│   └── logs/
├── inbox/                 # Raw source material
└── templates/             # Note schemas
```

## Core Skills

All platforms get these skills:

| Skill | Purpose |
|-------|---------|
| `/observe` | Extract typed observations from session transcripts |
| `/consolidate` | Promote observations to permanent notes |
| `/recall` | Search vault for relevant knowledge |
| `/dream` | Generate speculative cross-domain connections |

## Observation Types

When running `/observe`, extract these types:

| Type | Description |
|------|-------------|
| `insight` | A claim or lesson learned |
| `pattern` | A recurring theme or structure |
| `workflow` | A process or technique |
| `tool` | Software, library, framework |
| `person` | Someone and their context |
| `decision` | A choice and its reasoning |
| `open-question` | An unknown worth investigating |

## Promotion Rules

When running `/consolidate`:

- **Reference types** (person, tool, decision, open-question): Auto-promote all
- **Pipeline types** (insight, pattern, workflow): Promote when importance >= 0.8 OR surprise >= 0.7

---

# After Installation

## Verify

Check these exist:
- Hook/plugin in platform's hook directory
- Skills accessible via `/observe`, `/consolidate`, `/recall`
- Vault at `~/.mnemos/vault/` with `self/`, `notes/`, `memory/`

## First Steps

1. **Restart** your agent/gateway to load hooks
2. **Have some conversations** to generate transcripts
3. **Run `/observe`** to extract first observations
4. **Run `/consolidate`** to create first notes
5. **Try `/recall [topic]`** to search your vault

## Maintenance

Daily (automatic if cron configured):
- `/observe` — Extract observations from sessions
- `/consolidate` — Promote to notes

Weekly:
- `/dream --weekly` — Find cross-domain connections

---

# Troubleshooting

## Hook not firing
- Did you restart the gateway/agent?
- Check hook file locations match platform expectations
- Check for syntax errors in hook files

## Vault empty
- Hooks may not be capturing — check hook logs
- Try running `/observe` manually after a few conversations

## Skills not found
- Check skill files are in correct location
- For Hermes: `~/.hermes/skills/mnemos/`
- For OpenClaw: `~/.openclaw/skills/mnemos/`
- For Claude Code: Check `CLAUDE.md` has skills section
- For Pi: Check `.claude/skills/` directory
- For Droids: Check `.factory/skills/` directory
- For Codex: Check `<workspace>/skills/` directory

## Permission errors
- Ensure scripts are executable: `chmod +x *.sh`
- Check vault directory is writable

---

# Getting Help

- Repository: https://github.com/adiman9/mnemos
- Issues: https://github.com/adiman9/mnemos/issues
- Platform-specific docs in `install/` directory
