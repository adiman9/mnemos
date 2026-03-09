# mnemos

3-layer memory skill-pack for AI coding agents. Works with Claude Code, Cursor, Cline, OpenCode, OpenClaw, and more.

Working memory captures what happens. Long-term knowledge curates what matters. The dream layer finds connections nobody asked for.

## Concepts

**Workspace** — The directory where your agent runs. This is where you invoke the agent CLI (e.g., `claude`, `opencode`). For project-based tools like Claude Code or OpenCode, this is your project directory. mnemos installs hooks, skills, and adapter files here.

**Vault** — The persistent knowledge store. Contains all memory (observations, notes, dreams), agent identity, and configuration. The vault is independent of any workspace — you can point multiple workspaces at the same vault to accumulate knowledge across projects.

```
workspace/                     vault/
├── .claude/hooks/             ├── notes/         # Knowledge graph
├── .mnemos.yaml → points to → ├── memory/        # Observations, sessions
├── CLAUDE.md                  ├── self/          # Identity, goals
└── (your code)                └── ops/           # Queue, logs, config
```

**Vault as workspace** — For research companions or personal knowledge management, the vault can BE the workspace. Run `claude` directly from the vault directory and hooks auto-detect it. No separate project needed.

**Vault-only agents** — Some agents (like OpenClaw) don't have a traditional workspace. They manage their own internal directories. For these, mnemos provides a **vault-only** install that skips workspace setup entirely.

## Install

### Standard Install (workspace + vault)

For agents with a visible workspace (Claude Code, Cursor, OpenCode, etc.):

```bash
# Auto-detect harness (defaults to claude-code):
./install.sh <workspace-path> <vault-path>

# Specify adapter explicitly:
./install.sh --adapter opencode <workspace-path> <vault-path>

# Omit vault-path to use the default (~/.mnemos/vault, auto-created):
./install.sh <workspace-path>
```

### Vault-Only Install

For research companions or agents without a project workspace:

```bash
./install.sh --vault-only <vault-path>

# Or use the default location:
./install.sh --vault-only
```

**Default vault**: If no vault path is specified, mnemos uses `~/.mnemos/vault` and auto-creates it if needed.

**Research companion mode**: If you want to use mnemos purely for research/learning without a coding project, run the agent directly from the vault:

```bash
./install.sh --vault-only
cd ~/.mnemos/vault && claude
```

Hooks auto-detect the vault — no `.mnemos.yaml` needed. Use `/learn`, `/seed`, `/observe`, and other skills to build knowledge without any "project" code.

**OpenClaw / cloud agents**: See [OpenClaw Adapter](adapters/openclaw/README.md) for agents that manage their own internal directories.

### Supported Harnesses

| Harness | Adapter | Hook Coverage | Status |
|---------|---------|---------------|--------|
| Claude Code | `claude-code` | Full | Stable |
| Cursor | `claude-code` | Full | Stable |
| Cline (v3.36+) | `claude-code` | Full | Stable |
| OpenCode | `opencode` | Full | Beta |
| Pi framework | `pi` | Full | Beta |
| FactoryAI Droids | `droids` | Full | Beta |
| OpenClaw | `openclaw` | Full | Experimental |
| Codex CLI | `codex` | Partial (no SessionStart, no per-write hooks) | Experimental |

All adapters deploy the same core skills and vault structure. Adapters differ only in how lifecycle hooks are triggered.

## Architecture

```
mnemos/
├── core/                    # Portable (works everywhere)
│   ├── SYSTEM.md            # Harness-neutral system prompt
│   ├── skills/              # 20 SKILL.md files
│   ├── hooks/scripts/       # Shell scripts (the logic)
│   └── templates/           # Note schemas
├── adapters/                # Harness-specific glue
│   ├── claude-code/         # hooks.json (also Cursor, Cline)
│   ├── opencode/            # TypeScript plugin
│   ├── pi/                  # Pi extension (also covers OpenClaw, Graphone)
│   ├── droids/              # FactoryAI Droids hooks
│   ├── openclaw/            # Hook Pack (package.json + hooks.json5)
│   ├── codex/               # config.toml notify
│   └── cursor/              # Uses claude-code adapter
├── install.sh               # Auto-detects harness, deploys adapter
└── schedule.sh              # Sets up OS-level scheduled execution
```

## Layers

**Layer 1 — Working Memory** (`memory/`): Adapter hooks capture session transcripts incrementally to `memory/sessions/`. The `/observe` skill reads these transcripts and extracts typed observations with importance, confidence, and surprise scores. MEMORY.md provides boot context at session start.

**Layer 2 — Long-Term Knowledge** (`notes/`): Atomic prose-titled insights connected by wiki-links. Processing pipeline: `/seed` → `/reduce` → `/reflect` → `/reweave` → `/verify`. Orchestrated by `/ralph` with fresh context per phase.

**Layer 3 — Dream** (`memory/.dreams/`): `/dream` generates speculative cross-domain connections in two modes. **Daily**: reads today's observations, finds parallels with existing vault. **Weekly**: random sampling across maximally distant topic maps. Hidden directory — invisible to rg and qmd by default, so speculations never pollute normal search.

**Consolidation**: `/consolidate` bridges L1 and L2 via two paths. Reference types (person, tool, decision, open-question) auto-promote to `notes/` and get wired into the graph. Pipeline types (insight, pattern, workflow) use threshold-based promotion through the full pipeline.

## Skills

| Skill | Layer | Purpose |
|-------|-------|---------|
| `/observe` | L1 | Extract typed observations from session transcripts (passive log reader) |
| `/consolidate` | L1→L2 | Dual-path promotion: reference types auto-promote, pipeline types use thresholds |
| `/seed` | L2 | Queue source material for processing |
| `/reduce` | L2 | Extract atomic insights from sources |
| `/enrich` | L2 | Add new source content to existing notes with multi-source attribution |
| `/reflect` | L2 | Find connections between insights |
| `/reweave` | L2 | Update older insights with new context |
| `/verify` | L2 | Quality gate: description + schema + health |
| `/validate` | L2 | Schema compliance check |
| `/ralph` | L2 | Queue orchestration with subagent spawning |
| `/pipeline` | L2 | End-to-end source processing |
| `/ingest` | Ops | Auto-seed inbox files and process queue (for scheduled/unattended runs) |
| `/dream` | L3 | Cross-domain speculative connections (`--daily` context-driven, `--weekly` random sampling) |
| `/curiosity` | Ops | Proactive research discovery — generates and scores research candidates, auto-triggers `/learn` |
| `/next` | Ops | What to work on next |
| `/stats` | Ops | Vault metrics |
| `/graph` | Ops | Knowledge graph analysis |
| `/learn` | Ops | Research a topic |
| `/remember` | Ops | Capture operational friction |
| `/rethink` | Ops | Challenge system assumptions |
| `/refactor` | Ops | Vault restructuring |
| `/tasks` | Ops | Queue management |

## Vault Structure

```
<vault>/
├── self/               # Agent identity, methodology, goals
├── notes/              # Knowledge graph (Layer 2)
├── memory/             # Working memory (Layer 1)
│   ├── daily/          # Typed observations per day
│   ├── sessions/       # Archived transcripts
│   ├── .dreams/        # Speculations (Layer 3, hidden from search)
│   └── MEMORY.md       # Boot context
├── ops/                # Operations
│   ├── queue/          # Processing queue
│   ├── logs/           # Scheduled run logs
│   ├── config.yaml     # Vault configuration
│   └── schedule.yaml   # Scheduled skill execution
├── inbox/              # Raw source material
└── templates/          # Note schemas
```

## Portability Design

mnemos separates **what** happens from **how** it's triggered:

- **Core** contains all logic: skill prompts (SKILL.md), hook scripts (bash), templates, and the system prompt. These are harness-agnostic.
- **Adapters** wire core logic into each harness's extension system. An adapter is typically a single config file or small plugin.

To add support for a new harness, create an adapter that maps these lifecycle events to the harness's extension mechanism:

| Event | Purpose | Script |
|-------|---------|--------|
| Session start | Inject boot context | `session-start.sh` |
| Per-turn capture | Record transcript incrementally | `session-capture.sh` |
| Pre-compaction | Safety flush before context compaction | `pre-compact.sh` |
| File write (sync) | Validate note schema | `validate-note.sh` |
| File write (async) | Auto-commit to git | `auto-commit.sh` |

See `adapters/*/README.md` for per-harness details.

## Optional: Exa Deep Research

The `/learn` skill uses Exa for automated topic research. Without Exa, `/learn` falls back to basic web search — functional but shallower.

### Setup

1. Get an API key at [dashboard.exa.ai/api-keys](https://dashboard.exa.ai/api-keys) (free tier includes ~$10 credits)

2. Add the MCP server to your agent (Claude Code example):

```bash
claude mcp add --transport http exa \
  "https://mcp.exa.ai/mcp?exaApiKey=YOUR_KEY&tools=web_search_exa,deep_researcher_start,deep_researcher_check"
```

3. Restart your agent and verify Exa tools are available.

### Tool Cascade

`/learn` tries tools in order and falls back gracefully:

| Depth | Tool | Trigger | Cost |
|-------|------|---------|------|
| deep | `deep_researcher_start` | `/learn --deep [topic]` | ~$0.10-0.50/report |
| moderate (default) | `web_search_exa` | `/learn [topic]` | ~$0.005-0.01/search |
| light | basic `WebSearch` | `/learn --light [topic]` or Exa unavailable | free |

Research results land in `inbox/` with full provenance metadata and chain into the L2 pipeline.

## Scheduled Execution

Some skills benefit from periodic execution — daily consolidation of observations, weekly dream generation, graph health checks. mnemos includes a scheduling system that works across all platforms.

### Setup

```bash
# After install, set up OS-level scheduling:
./schedule.sh --vault <vault-path>

# Specify adapter if needed:
./schedule.sh --vault <vault-path> --adapter opencode

# Remove scheduling:
./schedule.sh --uninstall --vault <vault-path>
```

### What Gets Scheduled

Configured in `<vault>/ops/schedule.yaml`:

| Frequency | Default Time | Skills |
|-----------|-------------|--------|
| Daily | 09:00 | `/observe`, `/consolidate`, `/dream --daily`, `/curiosity`, `/stats` |
| Weekly | Sun 03:00 | `/dream --weekly`, `/graph health`, `/validate all`, `/rethink` |

Edit `ops/schedule.yaml` in your vault to customize skills and times.

### Platform Support

| Platform | Mechanism | Notes |
|----------|-----------|-------|
| macOS | LaunchAgents | `~/Library/LaunchAgents/com.mnemos.{daily,weekly}.plist` |
| Linux (systemd) | User timers | `~/.config/systemd/user/mnemos-{daily,weekly}.{service,timer}` |
| Linux (no systemd) | crontab | Tagged entries for easy uninstall |
| OpenClaw | Built-in cron | Uses `openclaw cron add` — no external scheduler needed |

**OpenClaw users**: Skip `schedule.sh` entirely. OpenClaw has built-in scheduling. After vault-only install, run:
```bash
openclaw cron add --name "mnemos-daily" --cron "0 9 * * *" --session isolated \
  --message "/consolidate && /dream --daily && /curiosity && /stats"
openclaw cron add --name "mnemos-weekly" --cron "0 3 * * 0" --session isolated \
  --message "/dream --weekly && /graph health && /validate all && /rethink"
```

See [OpenClaw Adapter](adapters/openclaw/README.md) for full setup instructions.

### How It Works

1. `schedule.sh` installs OS-level triggers that call `scheduled-run.sh` at configured times
2. `scheduled-run.sh` reads `ops/schedule.yaml`, detects the agent harness, and invokes each skill via the appropriate CLI
3. Output is logged to `<vault>/ops/logs/scheduled-YYYY-MM-DD.log`

### Environment

Scheduled runs need API keys available. `schedule.sh` captures `ANTHROPIC_API_KEY` from your current environment into the scheduler config. If it's not set at install time, you'll see a placeholder warning — edit the plist/service/crontab to add your key.

## Lineage

Layer 2 processing pipeline adapted from [arscontexta](https://github.com/agenticnotetaking/arscontexta). Layer 1 observer pattern informed by [clawvault](https://github.com/Versatly/clawvault).
