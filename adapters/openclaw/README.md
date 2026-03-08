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

# Enable the hooks (required — install alone doesn't activate them)
openclaw hooks enable mnemos

# Optional: Configure custom vault path (defaults to ~/.mnemos/vault, auto-initialized)
openclaw config set plugins.entries.mnemos.config.vaultPath ~/my-vault

# Restart gateway to load everything
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

### Events

| OpenClaw Hook | Purpose | Handler |
|---------------|---------|---------|
| `gateway:startup` | Inject boot context on startup | `session-start.sh` |
| `message:received` | Capture inbound user messages | Inline capture |
| `message:sent` | Capture outbound assistant messages | Inline capture |
| `agent:bootstrap` | Initialize session and identity | `session-start.sh` |
| `command:new` | Capture transcript before session reset | `session-capture.sh` |
| `session:compact:before` | Safety flush before context compaction | `pre-compact.sh` |

### Transcript Capture Pipeline

The `message:received` and `message:sent` events fire on each message and capture to `{vault}/memory/sessions/{session-id}.jsonl` in standard mnemos JSONL format. This uses inline capture logic in the handler (not shell scripts) to avoid path resolution issues in managed hook installs.

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
# Should show: mnemos (0.1.3) - loaded

# Check hooks are enabled (not just installed)
openclaw hooks list --verbose
# Should show: mnemos - enabled

# Check vault is initialized
ls ~/.mnemos/vault
# Should show: self/ notes/ memory/ ops/ inbox/ templates/

# Test a hook fires
openclaw gateway restart
# Should see "[mnemos] Initialized default vault" or session-start.sh output
```

**Troubleshooting:**

| Symptom | Fix |
|---------|-----|
| Hooks not firing | Run `openclaw hooks enable mnemos && openclaw gateway restart` |
| No session files created | Check `openclaw hooks list --verbose` shows mnemos enabled, then restart gateway |
| Empty vault directory | Restart gateway — auto-initialization runs on first event |
| "No vault path configured" | Set path or let it default: `openclaw gateway restart` |
| Script not found errors | Set `MNEMOS_SCRIPTS_DIR` to point to the scripts directory, or use vault-only mode |

**Debug mode:** Set `MNEMOS_DEBUG=1` in your environment to enable verbose logging from the hook handler.

**Critical:** After any hook install/enable/disable operation, you **must restart the gateway** for changes to take effect:
```bash
openclaw gateway restart
```

## Status

**Beta.** The npm install and vault-only workflows are the recommended approaches. Verified for OpenClaw v0.8.0+.
