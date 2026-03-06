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

### Step 1: Initialize the Vault

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

OpenClaw's hook system supports all mnemos lifecycle events:

| mnemos Event | OpenClaw Hook | Status |
|-------------|---------------|--------|
| SessionStart | `session_start` | Full |
| PostToolUse (Write) | `after_tool_call` (tool_filter: write) | Full |
| Transcript capture | `gateway:heartbeat` (periodic) | Full |
| Pre-compact | `compaction:memoryFlush` | Full |
| Session end | `agent_end` | Full |
| Auto-commit | `after_tool_call` (async) | Full |

### Passive Observation Pipeline

OpenClaw captures transcripts incrementally via the `gateway:heartbeat` hook (fires ~every 60s). The `compaction:memoryFlush` hook provides a safety net before context compaction. Session transcripts are stored in `{vault}/memory/sessions/{session-id}.jsonl` in standard mnemos JSONL format.

The `/observe` skill then reads these transcripts to extract typed observations — this can run manually or via the daily `openclaw cron` schedule.

## Alternative: Legacy Workspace Install

If you're using OpenClaw in a mode where it does have a visible workspace directory, you can use the standard install:

```bash
./install.sh --adapter openclaw <workspace-path> <vault-path>
```

This installs the Hook Pack format (`package.json` + `hooks.json5`) to `<workspace>/.openclaw/hooks/mnemos/`. However, the vault-only approach above is recommended for typical OpenClaw usage.

## Status

**Experimental.** The vault-only workflow is the recommended approach. Hook pack format (`hooks.json5`) is based on OpenClaw source analysis and may need adjustment for specific versions.
