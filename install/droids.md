# mnemos for FactoryAI Droids — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. This uses the mnemos installer from GitHub.

**Note**: Droids run in isolated cloud environments. Hooks use JSON responses for context injection.

---

## Overview

You will install:
- **Hooks** (`.factory/hooks/`) — Session capture, validation, auto-commit
- **Skills** (`.factory/skills/`) — Full skill library
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **DROIDS.md** — System instructions for mnemos awareness

Droids hooks inject context via `additionalContext` JSON responses, not stdout.

---

## Step 1: Clone the Repository

Clone mnemos to a temporary location:

```bash
git clone https://github.com/adiman9/mnemos.git /tmp/mnemos
```

---

## Step 2: Run the Installer

Run the installer with the Droids adapter from the workspace directory:

```bash
cd <workspace>
/tmp/mnemos/install.sh --adapter droids . ~/.mnemos/vault
```

This will:
- Initialize the vault at `~/.mnemos/vault/`
- Copy hook scripts to `.factory/hooks/scripts/`
- Configure hooks in `.factory/settings.json`
- Copy all skills to `.factory/skills/`
- Create `.mnemos.yaml` configuration
- Create `DROIDS.md` with system instructions

---

## Step 3: Verify Installation

Check these files exist:

```
<workspace>/
├── .factory/
│   ├── settings.json (with hooks configuration)
│   ├── hooks/
│   │   └── scripts/
│   │       ├── session-start.sh
│   │       ├── session-capture.sh
│   │       ├── validate-note.sh
│   │       └── auto-commit.sh
│   └── skills/
│       ├── observe/SKILL.md
│       ├── consolidate/SKILL.md
│       ├── recall/SKILL.md
│       └── ... (other skills)
├── .mnemos.yaml
└── DROIDS.md

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

Test the session-start hook:

```bash
echo '{"session_id":"test"}' | bash <workspace>/.factory/hooks/scripts/session-start.sh
```

Should output JSON with `additionalContext` field.

---

## Step 4: Tell the User

**Say this to the user:**

---

**mnemos installed for FactoryAI Droids!**

I've set up:
- Hook scripts at `.factory/hooks/scripts/`
- Hooks configured in `.factory/settings.json`
- Skills at `.factory/skills/`
- Vault at `~/.mnemos/vault/`
- System instructions in `DROIDS.md`

**The hooks will activate on your next Droid session.**

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/recall [topic]` — Search your knowledge vault
- `/dream` — Generate cross-domain connections

The vault grows as you work. Use `/observe` periodically to extract insights.

---

## Cleanup (Optional)

Remove the temporary clone:

```bash
rm -rf /tmp/mnemos
```

---

## Hook Coverage

Droids has full hook support:

| mnemos Event | Droids Hook | Status |
|--------------|-------------|--------|
| Session Start | SessionStart | Full (via additionalContext JSON) |
| Per-turn Capture | Stop | Full |
| Post-write Validation | PostToolUse | Full |
| Auto-commit | PostToolUse | Full |

---

## Installation Complete

The hooks will activate on your next Droid session.
