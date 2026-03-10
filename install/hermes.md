# mnemos for Hermes — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. This uses the mnemos installer from GitHub.

---

## Overview

You will install:
- **Hook** (`~/.hermes/hooks/mnemos/`) — Captures session transcripts
- **Skills** (`~/.hermes/skills/mnemos/`) — /observe, /consolidate, /recall for knowledge management  
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage

Hermes's native memory (MEMORY.md/USER.md) handles quick notes. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Clone the Repository

Clone mnemos to a temporary location:

```bash
git clone https://github.com/adiman9/mnemos.git /tmp/mnemos
```

---

## Step 2: Run the Installer

Run the installer with the Hermes adapter:

```bash
/tmp/mnemos/install.sh --adapter hermes ~/.hermes ~/.mnemos/vault
```

This will:
- Initialize the vault at `~/.mnemos/vault/`
- Copy hook files to `~/.hermes/hooks/mnemos/`
- Copy skill definitions to `~/.hermes/skills/mnemos/`
- Create `.mnemos.yaml` configuration

---

## Step 3: Set Up Scheduled Maintenance

Set up cron jobs for automated maintenance. These run via Hermes's built-in scheduler.

**Hourly** — extract observations from session transcripts, process inbox items:

```python
cronjob_manage(
    action="create",
    name="mnemos-hourly",
    schedule="0 * * * *",
    prompt="/observe && /ingest",
    deliver="local"
)
```

**Daily** (9 AM) — consolidate to knowledge graph, generate daily connections, discover research opportunities, vault stats:

```python
cronjob_manage(
    action="create",
    name="mnemos-daily",
    schedule="0 9 * * *",
    prompt="/consolidate && /dream --daily && /curiosity && /stats",
    deliver="local"
)
```

**Weekly** (Sunday 3 AM) — deep cross-domain dream connections, graph health analysis, schema validation, review accumulated tensions:

```python
cronjob_manage(
    action="create",
    name="mnemos-weekly",
    schedule="0 3 * * 0",
    prompt="/dream --weekly && /graph health && /validate all && /rethink",
    deliver="local"
)
```

Verify all three are registered:

```python
cronjob_manage(action="list")
```

---

## Step 4: Restart the Gateway

Restart Hermes to load the new hook:

```bash
hermes gateway restart
```

---

## Step 5: Verify Installation

Check these files exist:

```
~/.hermes/hooks/mnemos/
├── HOOK.yaml
└── handler.py

~/.hermes/skills/mnemos/
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

Verify cron jobs are running:

```python
cronjob_manage(action="list")
```

You should see `mnemos-hourly`, `mnemos-daily`, and `mnemos-weekly` in the list.

---

## Step 6: Tell the User

**Say this to the user:**

---

**mnemos installed successfully!**

I've set up:
- Hook to capture conversations at `~/.hermes/hooks/mnemos/`
- Skills at `~/.hermes/skills/mnemos/`
- Vault at `~/.mnemos/vault/`
- Hourly cron: `/observe`, `/ingest`
- Daily cron (9 AM): `/consolidate`, `/dream --daily`, `/curiosity`, `/stats`
- Weekly cron (Sunday 3 AM): `/dream --weekly`, `/graph health`, `/validate all`, `/rethink`

**To activate the hook, restart the gateway:**

```bash
hermes gateway restart
```

**After restart, I'll automatically capture our sessions and run scheduled maintenance.**

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/learn [topic]` — Research a topic into the vault
- `/dream` — Find cross-domain connections
- `/fetch [url]` — Save a URL to inbox for processing

The vault grows silently. Your Hermes memory (MEMORY.md) handles quick notes; mnemos handles deep, long-term knowledge.

---

## Cleanup (Optional)

Remove the temporary clone:

```bash
rm -rf /tmp/mnemos
```

---

## Installation Complete

Remind the user to restart the gateway, then mnemos will begin capturing automatically.
