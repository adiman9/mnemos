# OpenClaw Adapter

Adapter for [OpenClaw](https://github.com/openclaw/openclaw) — a vault-only agent that manages its own workspace internally.

## Key Difference: No Workspace

Unlike Claude Code or OpenCode, OpenClaw doesn't operate in a user-visible workspace directory. It manages its own internal state. This means:

- **No `.mnemos.yaml`** in a project directory
- **No hook files** to install in a workspace
- **Skills** are loaded via OpenClaw's native skill system
- **Scheduling** uses OpenClaw's built-in `claw cron`, not external schedulers

mnemos provides a **vault-only** install mode for OpenClaw that initializes the vault without workspace setup.

## Install

### Primary: Install via OpenClaw CLI

The recommended way to install mnemos for OpenClaw is via npm. This installs the plugin and registers its hooks with your OpenClaw gateway.

```bash
# Install the plugin from npm
openclaw plugins install mnemos-openclaw

# Configure vault path (uses ~/.mnemos/vault by default if not set)
openclaw config set plugins.entries.mnemos.config.vaultPath ~/mnemos-vault

# Restart gateway to load the plugin
openclaw gateway restart
```

> **Note (older OpenClaw versions):** If you're on OpenClaw <0.9, use `plugins.mnemos.config.vaultPath` instead.

### Alternative: Vault-Only Install

For users who prefer a manual setup or don't want to use npm, you can initialize the vault directly.

#### Step 1: Initialize the Vault

```bash
./install.sh --vault-only ~/mnemos-vault
```

This creates the vault structure:
```
~/mnemos-vault/
├── self/           # Identity, methodology, goals
├── notes/          # Knowledge graph (Layer 2)
├── memory/         # Working memory (Layer 1)
├── ops/            # Queue, logs, config
├── inbox/          # Source material
└── templates/      # Note schemas
```

### Step 2: Configure OpenClaw

Tell OpenClaw where your vault lives. Add to your claw config:

```yaml
mnemos:
  vault_path: ~/mnemos-vault
```

Or set the environment variable:
```bash
export MNEMOS_VAULT=~/mnemos-vault
```

### Step 3: Load Skills

OpenClaw loads skills from its native skill directory. Copy mnemos skills:

```bash
cp -r mnemos/core/skills/* ~/.openclaw/skills/
```

Or point OpenClaw at the mnemos skills directory in your config.

### Step 4: Set Up Scheduling

OpenClaw has built-in scheduling via `openclaw cron`. **Do not use `schedule.sh`** — it's for external OS schedulers.

OpenClaw's scheduler runs in the Gateway process and persists jobs to `~/.openclaw/cron/jobs.json`. Jobs can run in isolated sessions (recommended for background maintenance) or inject into the main chat.

```bash
# Daily: observation extraction, consolidation, context-driven dreams, research, stats (9 AM)
openclaw cron add \
  --name "mnemos-daily" \
  --cron "0 9 * * *" \
  --session isolated \
  --message "/observe && /consolidate && /dream --daily && /curiosity && /stats"

# Weekly: deep dreams, graph health, validation (Sunday 3 AM)
openclaw cron add \
  --name "mnemos-weekly" \
  --cron "0 3 * * 0" \
  --session isolated \
  --message "/dream --weekly && /graph health && /validate all && /rethink"
```

**Options:**
- `--session isolated` — runs in a dedicated session (recommended for maintenance)
- `--session main` — injects into your active chat session
- `--announce --channel last` — posts results to your last active channel

**Manage jobs:**
```bash
openclaw cron list              # View all scheduled jobs
openclaw cron run <job-id>      # Trigger immediately
openclaw cron edit <job-id> --enabled false  # Disable
openclaw cron remove <job-id>   # Delete
```

## Hook Coverage

mnemos hooks into OpenClaw's lifecycle events to capture knowledge and maintain continuity.

### Verified Events

| OpenClaw Hook | Purpose | Script |
|---------------|---------|--------|
| `gateway:startup` | Inject boot context on startup | `session-start.sh` |
| `agent:bootstrap` | Initialize session and identity | `session-start.sh` |
| `command:new` | Capture transcript before session reset | `session-capture.sh` |
| `session:compact:before` | Safety flush before context compaction | `pre-compact.sh` |

### Passive Observation Pipeline

OpenClaw captures transcripts incrementally via these hooks. Session transcripts are stored in `{vault}/memory/sessions/{session-id}.jsonl` in standard mnemos JSONL format.

The `/observe` skill then reads these transcripts to extract typed observations — this can run manually or via the daily `openclaw cron` schedule.

## Alternative: Legacy Workspace Install

If you're using OpenClaw in a mode where it does have a visible workspace directory, you can use the standard install:

```bash
./install.sh --adapter openclaw <workspace-path> <vault-path>
```

This installs the mnemos plugin to `<workspace>/.openclaw/plugins/mnemos/`. However, the npm-based approach or vault-only approach above is recommended for typical OpenClaw usage.

## Verify Installation

After setup, confirm mnemos is working:

```bash
# Check plugin is loaded
openclaw plugins list
# Should show: mnemos (0.1.2) - loaded

# Check vault path is configured (no warnings)
openclaw status
# Should NOT show "No vault path configured"

# Test a hook fires (optional)
openclaw gateway restart && openclaw status
# Should see session-start.sh output in logs
```

If you see `[mnemos] No vault path configured`, either:
1. Set the path: `openclaw config set plugins.entries.mnemos.config.vaultPath ~/.mnemos/vault`
2. Or allow auto-create by restarting (defaults to `~/.mnemos/vault`)

## Status

**Beta.** The npm install and vault-only workflows are the recommended approaches. Verified for OpenClaw v0.8.0+.
