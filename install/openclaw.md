# mnemos for OpenClaw — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. This uses the mnemos plugin from npm.

---

## Overview

You will install:
- **Plugin** — Hooks + skills bundled together
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage (auto-initialized)
- **Cron** — Daily maintenance jobs (built into the plugin)

OpenClaw's native conversation history handles recent context. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Install the Plugin

Install mnemos from npm:

```bash
openclaw plugins install mnemos-openclaw
```

This installs:
- Lifecycle hooks (transcript capture, session start)
- All 23 skills (`/observe`, `/consolidate`, `/dream`, etc.)
- Background maintenance scheduler

---

## Step 2: Enable the Hooks

The plugin is installed but hooks need to be enabled:

```bash
openclaw hooks enable mnemos
```

---

## Step 3: Restart the Gateway

Restart OpenClaw to load everything:

```bash
openclaw gateway restart
```

---

## Step 4: Verify Installation

Check the plugin is loaded:

```bash
openclaw plugins list
# Should show: mnemos-openclaw (0.2.0) - loaded

openclaw hooks list --verbose
# Should show: mnemos - enabled
```

The vault is auto-initialized at `~/.mnemos/vault/` on first gateway startup.

---

## Step 5: Tell the User

**Say this to the user:**

---

**mnemos installed successfully!**

I've set up:
- Plugin with hooks and skills
- Vault at `~/.mnemos/vault/` (auto-initialized)
- Built-in maintenance scheduler (daily @ 9am, weekly @ Sunday 3am)

**To activate, restart the gateway:**

```bash
openclaw gateway restart
```

**After restart, I'll automatically capture our sessions.**

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/learn [topic]` — Research a topic into the vault
- `/dream` — Find cross-domain connections

**The plugin includes built-in scheduling** — no manual cron setup needed. Daily maintenance runs at 9am, weekly synthesis at Sunday 3am.

---

## Optional: Custom Vault Path

By default, the vault is at `~/.mnemos/vault/`. To use a different location:

```bash
openclaw config set plugins.entries.mnemos.config.vaultPath ~/my-vault
openclaw gateway restart
```

---

## Optional: Manual Cron (Override Built-in)

The plugin includes automatic scheduling. If you prefer manual control:

### Daily maintenance (9 AM)

```bash
openclaw cron add \
  --name "mnemos-daily" \
  --cron "0 9 * * *" \
  --session isolated \
  --message "/observe && /consolidate && /dream --daily && /curiosity && /stats"
```

### Weekly synthesis (Sunday 3 AM)

```bash
openclaw cron add \
  --name "mnemos-weekly" \
  --cron "0 3 * * 0" \
  --session isolated \
  --message "/dream --weekly && /graph health && /validate all && /rethink"
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Skills not found | Run `openclaw plugins list` — verify mnemos-openclaw is loaded |
| Hooks not firing | Run `openclaw hooks enable mnemos && openclaw gateway restart` |
| No session files | Check `~/.mnemos/vault/memory/sessions/` after a conversation |
| Custom vault not used | Verify config: `openclaw config get plugins.entries.mnemos.config.vaultPath` |

---

## Installation Complete

The gateway restart activates everything. mnemos will begin capturing automatically.
