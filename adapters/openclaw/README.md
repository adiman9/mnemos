# OpenClaw Adapter

Adapter for [OpenClaw](https://github.com/openclaw/openclaw) — a vault-only agent that manages its own workspace internally.

## Key Difference: No Workspace

Unlike Claude Code or OpenCode, OpenClaw doesn't operate in a user-visible workspace directory. It manages its own internal state. This means:

- **No `.mnemos.yaml`** in a project directory
- **No hook files** to install in a workspace
- **Skills + hooks** bundled together in one npm package
- **Scheduling** built into the plugin (daily @ 9am, weekly @ Sunday 3am)

## Install

### One-Step Install via npm

```bash
openclaw plugins install mnemos-openclaw
openclaw hooks enable mnemos
openclaw gateway restart
```

**That's it.** The plugin includes:
- All 23 skills (`/observe`, `/consolidate`, `/dream`, etc.)
- Lifecycle hooks (transcript capture, session start)
- Built-in maintenance scheduler

The vault is auto-initialized at `~/.mnemos/vault/` on first gateway startup.

### Optional: Custom Vault Path

```bash
openclaw config set plugins.entries.mnemos.config.vaultPath ~/my-vault
openclaw gateway restart
```

> **Note (older OpenClaw versions):** If you're on OpenClaw <0.9, use `plugins.mnemos.config.vaultPath` instead.

### Alternative: Manual Install (No npm)

For users who prefer manual setup:

```bash
git clone https://github.com/adiman9/mnemos.git /tmp/mnemos
/tmp/mnemos/install.sh --vault-only ~/.mnemos/vault
cp -r /tmp/mnemos/core/skills/* ~/.openclaw/skills/
rm -rf /tmp/mnemos
```

Then set up manual cron jobs (see below).

### Optional: Manual Cron (Override Built-in)

The plugin includes automatic scheduling. If you prefer manual control:

```bash
openclaw cron add \
  --name "mnemos-daily" \
  --cron "0 9 * * *" \
  --session isolated \
  --message "/observe && /consolidate && /dream --daily && /curiosity && /stats"

openclaw cron add \
  --name "mnemos-weekly" \
  --cron "0 3 * * 0" \
  --session isolated \
  --message "/dream --weekly && /graph health && /validate all && /rethink"
```

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

## Verify Installation

After setup, confirm mnemos is working:

```bash
# Check plugin is loaded
openclaw plugins list
# Should show: mnemos-openclaw (0.2.0) - loaded

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

## What's in the Package

The npm package bundles everything:

```
mnemos-openclaw/
├── index.js              # Plugin entry point (hooks + scheduler)
├── openclaw.plugin.json  # Plugin manifest
├── hooks/                # Lifecycle hook handlers
├── scripts/              # Build scripts
└── skills/               # All 23 skills (bundled automatically)
    ├── observe/SKILL.md
    ├── consolidate/SKILL.md
    ├── dream/SKILL.md
    └── ... (20 more)
```

Skills are declared in `openclaw.plugin.json` via the `skills` field. OpenClaw discovers them automatically — no manual copying required.

## Development

To build the skills into the package before publishing:

```bash
cd adapters/openclaw
./scripts/build-skills.sh
npm publish
```

The `prepublishOnly` script runs `build-skills.sh` automatically.

## Status

**Stable.** The npm install is the recommended approach. Verified for OpenClaw v0.8.0+.
