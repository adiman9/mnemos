# mnemos for Claude Code / Cursor / Cline — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. This uses the mnemos installer from GitHub.

---

## Overview

You will install:
- **Hooks** (`.claude/settings.json`) — Captures session transcripts via shell scripts
- **Scripts** (`.claude/hooks/scripts/`) — Shell scripts for hook execution
- **Skills** (`.claude/skills/`) — Full skill library
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **CLAUDE.md** — System instructions for mnemos awareness

Claude Code's conversation context handles recent messages. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Clone the Repository

Clone mnemos to a temporary location:

```bash
git clone https://github.com/adiman9/mnemos.git /tmp/mnemos
```

---

## Step 2: Run the Installer

Run the installer from the workspace directory:

```bash
cd <workspace>
/tmp/mnemos/install.sh . ~/.mnemos/vault
```

The installer auto-detects Claude Code. This will:
- Initialize the vault at `~/.mnemos/vault/`
- Copy hook scripts to `.claude/hooks/scripts/`
- Configure hooks in `.claude/settings.json`
- Copy all skills to `.claude/skills/`
- Create `.mnemos.yaml` configuration
- Create `CLAUDE.md` with system instructions

---

## Step 3: Set Up Scheduled Maintenance (Optional)

For daily maintenance, use OS-level scheduling:

```bash
/tmp/mnemos/schedule.sh --vault ~/.mnemos/vault
```

This sets up:
- **Daily (9 AM)**: `/observe`, `/consolidate`, `/dream --daily`, `/curiosity`, `/stats`
- **Weekly (Sun 3 AM)**: `/dream --weekly`, `/graph health`, `/validate all`, `/rethink`

---

## Step 4: Restart Claude Code

Exit and restart Claude Code to load the new hooks.

The hooks will activate on your next session.

---

## Step 5: Verify Installation

Check these files exist:

```
<workspace>/
├── .claude/
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
└── CLAUDE.md

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
bash .claude/hooks/scripts/session-start.sh
```

Should output vault stats and boot context.

---

## Step 6: Tell the User

**Say this to the user:**

---

**mnemos installed successfully!**

I've set up:
- Hook scripts at `.claude/hooks/scripts/`
- Hooks configured in `.claude/settings.json`
- Skills at `.claude/skills/`
- Vault at `~/.mnemos/vault/`
- System instructions in `CLAUDE.md`

**The hooks will activate on your next Claude Code session.**

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/recall [topic]` — Search your knowledge vault
- `/dream` — Generate cross-domain connections

**Note:** For other projects, run the installer again or copy `.claude/` and `.mnemos.yaml`.

---

## Cleanup (Optional)

Remove the temporary clone:

```bash
rm -rf /tmp/mnemos
```

---

## For Cursor / Cline Users

This same installer works for Cursor and Cline since they use the same hooks spec.

- **Cursor**: The installer works identically. Cursor reads `.claude/` configuration.
- **Cline (v3.36+)**: Same as Claude Code. Earlier versions have limited hook support.

---

## Installation Complete

The hooks will begin capturing automatically on the next session.
