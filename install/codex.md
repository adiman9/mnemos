# mnemos for Codex CLI — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. This uses the mnemos installer from GitHub.

**Note**: Codex CLI has **partial hook support** — no SessionStart or per-write hooks. Skills work fully; transcript capture fires per-turn only.

---

## Overview

You will install:
- **Skills** (`<workspace>/skills/` or `.codex/skills/`) — Full skill library
- **Notify hook** (`.codex/config.toml`) — Captures session transcripts per-turn
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **AGENTS.md** — System instructions for mnemos awareness

Codex's native AGENTS.md provides static context. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Clone the Repository

Clone mnemos to a temporary location:

```bash
git clone https://github.com/adiman9/mnemos.git /tmp/mnemos
```

---

## Step 2: Run the Installer

Run the installer with the Codex adapter from the workspace directory:

```bash
cd <workspace>
/tmp/mnemos/install.sh --adapter codex . ~/.mnemos/vault
```

This will:
- Initialize the vault at `~/.mnemos/vault/`
- Copy the notify hook script to `.mnemos/hooks/scripts/`
- Copy all skills to `.codex/skills/`
- Create `.mnemos.yaml` configuration
- Create/update `.codex/config.toml` with notify hook
- Create `AGENTS.md` with system instructions (including manual orient instructions)

---

## Step 3: Trust the Project

Ensure your workspace is trusted in `~/.codex/config.toml`:

```toml
[projects."/path/to/your/workspace"]
trust_level = "trusted"
```

Replace `/path/to/your/workspace` with your actual workspace path.

---

## Step 4: Verify Installation

Check these files exist:

```
<workspace>/
├── .codex/
│   ├── config.toml (with notify hook)
│   └── skills/
│       ├── observe/SKILL.md
│       ├── consolidate/SKILL.md
│       ├── recall/SKILL.md
│       └── ... (other skills)
├── .mnemos/
│   └── hooks/
│       └── scripts/
│           └── codex-notify.sh
├── .mnemos.yaml
└── AGENTS.md (with Codex orient instructions)

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

## Step 5: Tell the User

**Say this to the user:**

---

**mnemos installed for Codex CLI!**

I've set up:
- Notify hook at `.mnemos/hooks/scripts/codex-notify.sh`
- Hooks configured in `.codex/config.toml`
- Skills at `.codex/skills/`
- Vault at `~/.mnemos/vault/`
- System instructions in `AGENTS.md`

**Restart Codex to activate the hooks.**

**Important**: Codex doesn't support SessionStart hooks. At the start of every session, I'll read `~/.mnemos/vault/memory/MEMORY.md` for boot context.

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/recall [topic]` — Search your knowledge vault
- `/dream` — Generate cross-domain connections

---

## Cleanup (Optional)

Remove the temporary clone:

```bash
rm -rf /tmp/mnemos
```

---

## Limitations

Codex CLI has partial hook support:

| Feature | Status |
|---------|--------|
| Skills | Full support |
| AGENTS.md | Full support |
| Transcript capture | Per-turn only (no streaming) |
| Session start context | Not supported (use AGENTS.md) |
| Per-file validation | Not supported |
| Auto-commit | Per-turn only |

For full hook coverage, consider Claude Code or Pi framework.

---

## Installation Complete

Restart Codex to activate the hooks.
