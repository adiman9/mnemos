# mnemos for OpenClaw — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. This uses the mnemos installer from GitHub.

---

## Overview

You will install:
- **Hook** (`~/.openclaw/hooks/mnemos/`) — Captures session transcripts
- **Skills** (`~/.openclaw/skills/mnemos/`) — Full skill library
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **Cron** — Daily maintenance jobs via `openclaw cron`

OpenClaw's native conversation history handles recent context. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Clone the Repository

Clone mnemos to a temporary location:

```bash
git clone https://github.com/adiman9/mnemos.git /tmp/mnemos
```

---

## Step 2: Run the Installer

Run the installer with the OpenClaw adapter:

```bash
/tmp/mnemos/install.sh --adapter openclaw ~/.openclaw ~/.mnemos/vault
```

This will:
- Initialize the vault at `~/.mnemos/vault/`
- Copy hook files to `~/.openclaw/hooks/mnemos/`
- Copy all skills to `~/.openclaw/skills/`
- Create `.mnemos.yaml` configuration

---

## Step 3: Set Up Scheduled Maintenance

OpenClaw has built-in cron. Set up scheduled maintenance:

### Daily maintenance (9 AM)

```bash
openclaw cron add \
  --name "mnemos-daily" \
  --cron "0 9 * * *" \
  --session isolated \
  --message "/observe && /consolidate && /dream --daily"
```

### Weekly synthesis (Sunday 3 AM)

```bash
openclaw cron add \
  --name "mnemos-weekly" \
  --cron "0 3 * * 0" \
  --session isolated \
  --message "/dream --weekly && /graph health && /validate all"
```

To verify cron jobs:

```bash
openclaw cron list
```

---

## Step 4: Restart the Gateway

Restart OpenClaw to load the new hook:

```bash
openclaw gateway restart
```

---

## Step 5: Verify Installation

Check these files exist:

```
~/.openclaw/hooks/mnemos/
├── HOOK.yaml (or hooks.json5)
├── handler.js (or index.js)
└── package.json

~/.openclaw/skills/mnemos/
├── observe/SKILL.md
├── consolidate/SKILL.md
├── recall/SKILL.md
├── dream/SKILL.md
└── ... (other skills)

~/.mnemos/vault/
├── self/
│   ├── identity.md
│   ├── methodology.md
│   └── goals.md
├── notes/
├── memory/
│   ├── MEMORY.md
│   ├── daily/
│   ├── sessions/
│   └── .dreams/
├── ops/
│   ├── config.yaml
│   └── schedule.yaml
├── inbox/
└── templates/
```

---

## Step 6: Tell the User

**Say this to the user:**

---

**mnemos installed successfully!**

I've set up:
- Hook to capture conversations at `~/.openclaw/hooks/mnemos/`
- Skills at `~/.openclaw/skills/mnemos/`
- Vault at `~/.mnemos/vault/`
- Daily/weekly cron jobs for maintenance

**To activate the hook, restart the gateway:**

```bash
openclaw gateway restart
```

**After restart, I'll automatically capture our sessions.**

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/recall [topic]` — Search your knowledge vault
- `/dream` — Find cross-domain connections

**Manage cron jobs:**
```bash
openclaw cron list
openclaw cron run mnemos-daily  # Run now
```

---

## Cleanup (Optional)

Remove the temporary clone:

```bash
rm -rf /tmp/mnemos
```

---

## Installation Complete

Remind the user to restart the gateway, then mnemos will begin capturing automatically.
