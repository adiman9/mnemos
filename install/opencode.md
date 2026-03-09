# mnemos for OpenCode — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. This uses the mnemos installer from GitHub.

---

## Overview

You will install:
- **Plugin** (`.opencode/plugins/mnemos-plugin.ts`) — TypeScript plugin for hooks
- **Scripts** (`.mnemos/hooks/scripts/`) — Shell scripts for hook execution
- **Skills** (`.opencode/skills/`) — Full skill library
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **Config** (`.mnemos.yaml`) — Points workspace to vault

OpenCode's conversation context handles recent messages. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Clone the Repository

Clone mnemos to a temporary location:

```bash
git clone https://github.com/adiman9/mnemos.git /tmp/mnemos
```

---

## Step 2: Run the Installer

Run the installer with the OpenCode adapter from the workspace directory:

```bash
cd <workspace>
/tmp/mnemos/install.sh --adapter opencode . ~/.mnemos/vault
```

This will:
- Initialize the vault at `~/.mnemos/vault/`
- Copy the TypeScript plugin to `.opencode/plugins/`
- Copy hook scripts to `.mnemos/hooks/scripts/`
- Copy all skills to `.opencode/skills/`
- Create `.mnemos.yaml` configuration
- Create/update `opencode.json` with plugin reference
- Create `AGENTS.md` with system instructions

---

## Step 3: Set Up Scheduled Maintenance (Optional)

For daily maintenance, use OS-level scheduling:

### macOS (launchd)

```bash
/tmp/mnemos/schedule.sh --vault ~/.mnemos/vault --adapter opencode
```

### Linux (systemd/cron)

```bash
/tmp/mnemos/schedule.sh --vault ~/.mnemos/vault --adapter opencode
```

---

## Step 4: Restart OpenCode

Restart OpenCode to load the plugin:

```bash
# Exit and restart your OpenCode session
```

---

## Step 5: Verify Installation

Check these files exist:

```
<workspace>/
├── .opencode/
│   ├── plugins/
│   │   └── mnemos-plugin.ts
│   └── skills/
│       ├── observe/SKILL.md
│       ├── consolidate/SKILL.md
│       ├── recall/SKILL.md
│       └── ... (other skills)
├── .mnemos/
│   ├── hooks/
│   │   └── scripts/
│   │       ├── session-start.sh
│   │       ├── session-capture.sh
│   │       └── validate-note.sh
│   └── .mnemos.yaml
├── opencode.json (with plugin reference)
└── AGENTS.md

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
- Plugin at `.opencode/plugins/mnemos-plugin.ts`
- Hook scripts at `.mnemos/hooks/scripts/`
- Skills at `.opencode/skills/`
- Vault at `~/.mnemos/vault/`
- System instructions in `AGENTS.md`

**Restart OpenCode to load the plugin.**

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/recall [topic]` — Search your knowledge vault
- `/dream` — Generate cross-domain connections

The vault grows silently in the background as we work together.

---

## Cleanup (Optional)

Remove the temporary clone:

```bash
rm -rf /tmp/mnemos
```

---

## Installation Complete

The plugin will begin capturing automatically after restart.
