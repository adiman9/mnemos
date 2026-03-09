# mnemos for Pi Framework — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. This uses the mnemos installer from GitHub.

**Note**: Pi is the engine behind OpenClaw, Graphone, and other agents. This installer works for any Pi-based agent.

---

## Overview

You will install:
- **Extension** (`.pi/extensions/`) — TypeScript extension for lifecycle hooks
- **Hook Scripts** (`.mnemos/hooks/scripts/`) — Shell scripts for capture and validation
- **Skills** (`.claude/skills/`) — Full skill library
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **CLAUDE.md / AGENTS.md** — System instructions for mnemos awareness

Pi has full hook coverage — all mnemos lifecycle events are natively supported.

---

## Step 1: Clone the Repository

Clone mnemos to a temporary location:

```bash
git clone https://github.com/adiman9/mnemos.git /tmp/mnemos
```

---

## Step 2: Run the Installer

Run the installer with the Pi adapter from the workspace directory:

```bash
cd <workspace>
/tmp/mnemos/install.sh --adapter pi . ~/.mnemos/vault
```

This will:
- Initialize the vault at `~/.mnemos/vault/`
- Copy the TypeScript extension to `.pi/extensions/`
- Copy hook scripts to `.mnemos/hooks/scripts/`
- Copy all skills to `.claude/skills/` (Pi reads these natively)
- Create `.mnemos.yaml` configuration
- Create `AGENTS.md` and `CLAUDE.md` with system instructions

---

## Step 3: Register the Extension

To activate the extension, either:

**Option A**: Pass via CLI when starting Pi:
```bash
pi --extension .pi/extensions/mnemos-extension.ts
```

**Option B**: Add to your Pi config file (if using one):
```json
{
  "extensions": [".pi/extensions/mnemos-extension.ts"]
}
```

---

## Step 4: Set Up Scheduled Maintenance (Optional)

For daily maintenance, use OS-level scheduling:

```bash
/tmp/mnemos/schedule.sh --vault ~/.mnemos/vault --adapter pi
```

### For OpenClaw users

OpenClaw has built-in cron. After install, set up scheduled maintenance:

```bash
openclaw cron add --name "mnemos-daily" --cron "0 9 * * *" --session isolated \
  --message "/observe && /consolidate && /dream --daily"
```

---

## Step 5: Verify Installation

Check these files exist:

```
<workspace>/
├── .pi/
│   └── extensions/
│       └── mnemos-extension.ts
├── .claude/
│   └── skills/
│       ├── observe/SKILL.md
│       ├── consolidate/SKILL.md
│       ├── recall/SKILL.md
│       └── ... (other skills)
├── .mnemos/
│   ├── hooks/
│   │   └── scripts/
│   │       ├── session-start.sh
│   │       ├── validate-note.sh
│   │       └── auto-commit.sh
│   └── .mnemos.yaml
├── CLAUDE.md
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

Test the session-start script:

```bash
bash <workspace>/.mnemos/hooks/scripts/session-start.sh
```

Should output boot context to stdout.

---

## Step 6: Tell the User

**Say this to the user:**

---

**mnemos installed for Pi framework!**

I've set up:
- Extension at `.pi/extensions/mnemos-extension.ts`
- Hook scripts at `.mnemos/hooks/scripts/`
- Skills at `.claude/skills/`
- Vault at `~/.mnemos/vault/`
- System instructions in `CLAUDE.md` and `AGENTS.md`

**Start Pi with the extension to activate:**

```bash
pi --extension .pi/extensions/mnemos-extension.ts
```

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/recall [topic]` — Search your knowledge vault
- `/dream` — Find cross-domain connections

The vault grows as you work. Use `/observe` periodically to extract insights.

---

## Cleanup (Optional)

Remove the temporary clone:

```bash
rm -rf /tmp/mnemos
```

---

## Hook Coverage

Pi has full hook support:

| mnemos Event | Pi Event | Status |
|--------------|----------|--------|
| Session Start | `session_start` + `before_agent_start` | Full |
| Per-turn Capture | `input` + `turn_end` | Full |
| Post-write Validation | `tool_execution_end` | Full |
| Auto-commit | `tool_execution_end` | Full |
| Session Shutdown | `session_shutdown` | Full |

---

## For OpenClaw / Graphone Users

This same installer works for OpenClaw and Graphone since they're built on Pi.

**OpenClaw specifics**: OpenClaw has built-in cron (see Step 4).

**Graphone specifics**: Works identically to Pi. No special configuration needed.

---

## Installation Complete

Tell the user to start Pi with `--extension .pi/extensions/mnemos-extension.ts` to activate.
