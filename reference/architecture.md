# mnemos: 3-Layer Memory Architecture for AI Coding Agents

This document defines the architecture for mnemos — a portable memory skill-pack for AI coding agents. It provides a structured mechanism for an agent to capture, curate, and speculate across its experiences, transforming ephemeral session data into durable knowledge.

## Design Principles

- **Markdown-Native**: All memory is stored as human-readable, git-compatible markdown files.
- **Harness-Agnostic**: Core logic (skills, hook scripts, templates) is portable. Adapters wire it into each agent harness's extension system.
- **Zero External Dependencies**: Relies on the agent's built-in reasoning and local filesystem operations, with optional `qmd` for advanced search.
- **Container-Friendly**: Designed for stateless, ephemeral environments where persistent storage is mapped as a volume.
- **Git-Compatible**: Every change is a discrete file modification, allowing for versioning, branching, and merging of knowledge.

## Multi-Harness Support

mnemos separates portable core from harness-specific adapters:

```
core/               Portable: skills, hook scripts, templates, system prompt
adapters/           Harness-specific: Claude Code hooks.json, OpenCode TS plugin,
                    OpenClaw hook pack, Codex notify config, Amp toolboxes
install.sh          Auto-detects harness and deploys the correct adapter
```

Supported: Claude Code, Cursor, Cline, OpenCode, OpenClaw, Codex CLI.

## System Overview

mnemos organizes memory into three distinct layers of varying curation and stability, connected by a consolidation bridge.

```text
                                [ User Interaction ]
                                         |
                                         v
+--------------------------------------------------------------------------+
| Layer 1: Working Memory (memory/daily/, memory/sessions/)                |
| - High Volume, High Recency, Low Curation                                |
| - Session Hooks -> Typed Observations -> daily/YYYY-MM-DD.md             |
| - MEMORY.md: Auto-generated boot context for session injection           |
+--------------------------------------------------------------------------+
          |                                                      ^
          | [ Consolidation Bridge ]                             | [ Orient ]
          | /consolidate scans daily logs:                       |
          | - Reference types (person, tool, decision,           |
          |   open-question) → auto-promote to notes/            |
          | - Pipeline types (insight, pattern, workflow)         |
          |   → threshold-based promotion to inbox/              |
          v                                                      |
+--------------------------------------------------------------------------+
| Layer 2: Long-Term Knowledge (notes/, self/)                             |
| - Low Volume, Low Recency, High Curation                                 |
| - Atomic Insights, wiki-linked Knowledge Graph                           |
| - Pipeline: /seed -> /reduce -> /reflect -> /reweave -> /verify          |
+--------------------------------------------------------------------------+
          |                                                      ^
          | [ Cross-Domain Speculation ]                         | [ Validate ]
          | /dream samples random notes and finds parallels      |
          v                                                      |
+--------------------------------------------------------------------------+
| Layer 3: Dream (memory/.dreams/)                                         |
| - Generative, Speculative, Loosely Constrained                          |
| - High-novelty structural parallels between unrelated concepts          |
+--------------------------------------------------------------------------+
```

## Layer 1: Working Memory

Working memory handles the immediate influx of information from active sessions. It prioritizes recall and context over long-term durability.

### Transcript Capture

Observations are derived from recorded transcripts, not real-time agent introspection. This passive approach survives context compaction and captures cross-session patterns.

```text
Adapter Hook (per-turn)           /observe (batch)              /consolidate
         |                              |                            |
         v                              v                            v
Native transcript ──> session-capture.sh ──> memory/sessions/*.jsonl ──> /observe ──> memory/daily/ ──> /consolidate ──> notes/
         |                                       ^                        |
         |                                       |                        |
Pre-compact hook ──> pre-compact.sh ─────────────┘                  Typed observations
(safety flush before compaction)                                    with scores + co-tags
```

**Per-harness capture mechanisms:**

| Harness | Capture Hook | Pre-Compact | Transcript Source |
|---------|-------------|-------------|-------------------|
| Claude Code / Cursor | `Stop` (every turn) | `PreCompact` | `transcript_path` in stdin |
| OpenCode | `chat.message` + `tool.execute.after` | `experimental.session.compacting` | Native plugin API |
| OpenClaw | `gateway:heartbeat` (periodic) | `compaction:memoryFlush` | `.jsonl` on disk |
| Codex | `after_tool_use` | — | `rollouts/*.jsonl` |


All adapters produce the same standard JSONL format in `memory/sessions/`:
```jsonl
{"ts":"ISO8601","role":"user|assistant|tool_use|tool_result|compaction_boundary","content":"...","session_id":"..."}
```

Cursor tracking (`memory/sessions/.cursors.json`) enables incremental processing:
- `offset`: how far the capture hook has written
- `observed_offset`: how far `/observe` has processed

### Typed Observations
Observations are the atomic units of working memory, stored in `memory/daily/YYYY-MM-DD.md`. Each observation contains:
- **Type**: One of the unified taxonomy categories — `insight`, `pattern`, `workflow`, `tool`, `person`, `decision`, `open-question`.
- **Importance (0-1)**: Significance to the agent's long-term objectives.
- **Confidence (0-1)**: Agent's certainty in the validity of the observation.
- **Surprise (0-1)**: Degree to which the observation contradicts or extends the agent's existing model.
- **Co-occurrence tags** (optional): `@co: type:name` — entities that appeared in the same context.

### MEMORY.md (Executive Summary)
A periodically regenerated file injected at session start. It prevents context bloat by providing a concise summary instead of the entire vault.
- **Current Goals**: Active threads from `self/goals.md`.
- **Recent Observations**: Summary of top observations from the last 3 days.
- **Active Topics**: Links to relevant topic maps (MOCs).
- **Session Summaries**: Brief recaps of the last 3-5 sessions.

## Layer 2: Long-Term Knowledge

This layer is the curated knowledge graph, adapted from the arscontexta methodology. It focuses on atomic insights and dense interlinking.

### Atomic Insights
Prose-titled markdown files in `notes/` that capture exactly one idea. Titles serve as claims (e.g., `[[long context windows trade retrieval precision for breadth]]`).

### Knowledge Graph Structure
- **Wiki-Links**: Bidirectional links that form the graph edges.
- **Topic Maps (MOCs)**: Navigation hubs that manage attention across domains (e.g., `ai-research`, `solana-infrastructure`).
- **Self-Space (self/)**: Stores agent-specific identity, methodology, and goals.

### Processing Pipeline
Orchestrated by the `/ralph` skill, which spawns subagents to ensure fresh context for each phase:
1. **/seed**: Ingests source material to `inbox/`.
2. **/reduce**: Extracts structured claims from sources into atomic notes.
3. **/reflect**: Finds connections between new and existing notes.
4. **/reweave**: Updates older notes with new context or connections.
5. **/verify**: Validates schema compliance and link health.

## Layer 3: Dream

The Dream layer is where the agent generates novel, cross-domain insights through speculation.

### Dream Modes

`/dream` operates in two modes optimized for different discovery patterns:

**Daily mode** (`/dream --daily`): Context-driven discovery. Reads today's daily note (`memory/daily/YYYY-MM-DD.md`), extracts themes and entities, then finds 2-3 structural parallels between today's activity and existing vault notes from different topic maps. Novelty threshold: 0.5. Runs as part of the daily scheduled batch after `/consolidate`.

**Weekly mode** (`/dream --weekly`): Discovery-driven exploration. Randomly samples 5 note pairs across maximally distant topic maps. Deep structural parallel analysis looking for shared mechanisms, analogous trade-offs, transferable solutions, shared failure modes, and scale invariance. Novelty threshold: 0.6. This is where the highest-value cross-domain connections emerge.

Both modes share the same pipeline:
- **Structural Parallels**: The agent attempts to find deep analogies or shared principles between note pairs.
- **Novelty Scoring**: Speculations are scored (0.0-1.0) based on how unique the connection is relative to the existing knowledge graph.
- **Speculation Storage**: High-scoring speculations are filed in `memory/.dreams/`.

### Isolation Design

Dreams use a hidden directory (`memory/.dreams/`) so they are invisible to normal vault operations:
- **ripgrep** skips hidden directories by default — no dream content in keyword searches
- **qmd** filters dot-prefixed paths during indexing — dreams never enter semantic search
- **Skills** scope grep to `notes/` — dreams excluded from orphan detection, graph analysis, etc.

Only `/dream` (which knows the explicit path) and `session-start.sh` (which reports dream count in stats) access this directory. Dreams surface into the knowledge graph only through deliberate promotion to `inbox/`.

### Promotion and Decay
Periodically, the agent reviews `memory/.dreams/`. Validated speculations are promoted to the Layer 2 pipeline (`/reduce`) to become durable notes. Unproductive speculations are archived or discarded.

## Consolidation Bridge (L1 -> L2)

The consolidation process crystallizes working memory into durable knowledge. It runs periodically via the `/consolidate` skill. A unified taxonomy determines the promotion path.

### Unified Taxonomy

mnemos uses one shared category system across L1 observations and L2 notes:

| Category | Description | Promotion Path |
|----------|-------------|---------------|
| `insight` | Claims, lessons, findings | Full pipeline (threshold-based) |
| `pattern` | Recurring themes, structural parallels | Full pipeline (threshold-based) |
| `workflow` | Processes, techniques, procedures | Full pipeline (threshold-based) |
| `tool` | Software, libraries, frameworks | Reference (auto-promote) |
| `person` | People and their context | Reference (auto-promote) |
| `decision` | Choices and their reasoning | Reference (auto-promote) |
| `open-question` | Unknowns worth investigating | Reference (auto-promote) |

### Dual-Path Promotion

```text
/consolidate scans memory/daily/
    |
    ├── Reference types (person, tool, decision, open-question)
    │   ├── ALL auto-promote (no threshold)
    │   ├── Dedup against existing notes/
    │   ├── Create note directly in notes/ (skip inbox, skip /reduce)
    │   ├── Wire wiki-links from co-occurrence tags + same-session context
    │   └── Queue for /reflect (deeper connections)
    │
    └── Pipeline types (insight, pattern, workflow)
        ├── Apply thresholds: importance >= 0.8 OR surprise >= 0.7 OR (freq >= 2 AND importance >= 0.4)
        ├── Dedup against existing notes/
        ├── Create source file in inbox/
        └── Route through full pipeline: /seed → /reduce → /reflect → /reweave → /verify
```

### Why Two Paths

People, tools, and decisions are **reference data** — they don't need extraction or curation to be useful. A person's name, a tool's capabilities, a decision's rationale are already atomic facts. The observation IS the note.

But they DO need to be connected into the graph. Without connections, a tool note is invisible when you're working on a problem that tool solves. The reference path skips extraction but includes connection-finding.

### Co-occurrence Tags

`/observe` tags entities that appear together in the same context:
```
- [person|i=0.5] John recommended ast-grep for the migration @co: tool:ast-grep
```

`/consolidate` uses these tags to create wiki-links between reference notes during promotion. If John and ast-grep are both promoted in the same batch, they link to each other.

### Graph as Integration Layer

After consolidation, all note types live in `notes/` and connect through wiki-links. The graph doesn't distinguish reference notes from pipeline notes during traversal — a person note is just another node with edges. When an agent searches for "migration tools," it finds the tool note, follows a link to the person who recommended it, and follows another to the insight about structural search patterns.

## Curiosity — Proactive Research Discovery

`/curiosity` closes the loop between what the vault knows and what exists externally. It runs daily, scanning recent activity for information gaps and generating research candidates.

### Data Flow

```text
/curiosity scans recent vault activity
    |
    ├── Read last 3 days of daily notes (memory/daily/)
    ├── Read recently modified notes (notes/)
    ├── Read pending inbox items
    └── Read self/goals.md
    |
    ├── Generate 5-10 research candidates
    │   Categories: tool deep-dive, alternative discovery,
    │   concept expansion, implementation patterns, validation, open questions
    |
    ├── Score by Expected Information Gain (EIG)
    │   novelty(0.3) + relevance(0.25) + actionability(0.2) + connectivity(0.15) + timeliness(0.1)
    |
    ├── Execute top candidates (EIG >= 0.7) via /learn
    │   └── /learn handles Exa/web search → results filed to inbox/ with provenance
    |
    ├── High-EIG candidates (>= 0.85) also queried against additional_sources
    │   └── Pluggable: users configure extra MCP tools or skills in ops/config.yaml
    |
    └── Log to ops/logs/curiosity-YYYY-MM-DD.md
```

### Pluggable Research Sources

`/curiosity` delegates all actual research to `/learn` by default. Users can extend research coverage via `ops/config.yaml`:

```yaml
research:
  primary: exa-deep-research
  fallback: exa-web-search
  last_resort: web-search
  additional_sources:
    - tool: mcp__github__search_repositories
    - tool: mcp__reddit__search
    - skill: /my-custom-search
```

Additional sources are invoked only for the highest-scoring candidates to control API costs.

### Relationship to /learn

`/curiosity` is an orchestrator. `/learn` is the executor. `/curiosity` generates research queries and scores them; `/learn` handles all search tool logic, provenance metadata, and inbox filing. This separation means `/curiosity` benefits from any improvement to `/learn`'s search cascade without modification.

## Workspace vs Vault

mnemos separates two distinct locations:

**Workspace** — The directory where the agent runs. For project-based agents (Claude Code, OpenCode, Cursor), this is the user's project directory. mnemos installs hooks, adapter files, and `.mnemos.yaml` here. The workspace is transient — you might work in many different project directories over time.

**Vault** — The persistent knowledge store. Contains all memory (observations, notes, dreams), agent identity, and configuration. The vault is independent of any workspace. Multiple workspaces can point to the same vault, accumulating knowledge across projects.

```
workspace/                     vault/
├── .claude/hooks/             ├── notes/         # Knowledge graph
├── .mnemos.yaml → points to → ├── memory/        # Observations, sessions
├── CLAUDE.md                  ├── self/          # Identity, goals
└── (your code)                └── ops/           # Queue, logs, config
```

**Vault-only agents**: Some agents (OpenClaw, future cloud-native agents) don't expose a user-visible workspace. They manage their own internal directories. For these, mnemos provides a vault-only install that skips workspace setup entirely. The agent is configured to point at the vault through its native configuration system.

### Path Resolution

- **.mnemos.yaml**: Located in the workspace, containing `vault_path`. Created by `install.sh` during standard install.
- **MNEMOS_VAULT**: Environment variable that skills and scripts check as fallback.
- **--vault argument**: All mnemos scripts accept `--vault <path>` to override defaults.

Skills resolve the vault path in order: explicit argument → environment variable → `.mnemos.yaml` in current directory.

## Vault Layout

```
<vault>/
├── self/               # Agent identity, methodology, goals
├── notes/              # Knowledge graph (Layer 2 atomic notes)
├── memory/             # Working memory (Layer 1)
│   ├── daily/          # Typed observations (e.g., 2026-03-05.md)
│   ├── sessions/       # Archived session transcripts
│   ├── .dreams/        # Speculations (Layer 3, hidden from search)
│   └── MEMORY.md       # Session boot context
├── ops/                # Operational metadata
│   ├── queue/          # ralph processing queue
│   ├── logs/           # Scheduled run logs (scheduled-YYYY-MM-DD.log)
│   ├── observations/   # Friction signals for self-correction
│   ├── config.yaml     # Vault-specific configuration
│   └── schedule.yaml   # Scheduled skill execution config
├── inbox/              # Raw source material for processing
└── templates/          # YAML schemas and markdown templates
```

## Search and Retrieval

mnemos uses a tiered search strategy:
1. **Keyword**: Falls back to `ripgrep` (`rg`) for fast, exact matches in filenames and content.
2. **Semantic (Optional)**: Uses `qmd` for BM25 and vector-based search, enabling the discovery of conceptual connections that share no common keywords.
3. **Re-ranking**: When available, LLM-based re-ranking ensures the most relevant insights are surfaced for the agent's current task.

## Scheduled Execution

Some skills are metabolic — they need periodic execution independent of interactive sessions. Consolidation, dream generation, graph health checks, and observation triage all benefit from running on a schedule.

### Architecture

```text
OS Scheduler (launchd / systemd / crontab)
    |
    v
scheduled-run.sh --daily --vault <path>
    |
    ├── Reads ops/schedule.yaml for skill list
    ├── Detects agent harness (or uses --adapter)
    ├── For each skill:
    │   ├── Exports MNEMOS_VAULT=<vault_path>
    │   ├── Invokes harness CLI (claude -p, opencode run, etc.)
    │   └── Logs to ops/logs/scheduled-YYYY-MM-DD.log
    └── Reports summary: "Ran N skills, M succeeded, K failed"
```

### Schedule Configuration

`<vault>/ops/schedule.yaml` defines two batches:

```yaml
daily:
  time: "09:00"
  skills:
    - /observe           # L1: extract observations from transcripts
    - /consolidate       # L1→L2 promotion
    - /dream --daily     # L3 context-driven connections
    - /curiosity         # Proactive research discovery
    - /stats             # Vault metrics

weekly:
  day: sunday
  time: "03:00"
  skills:
    - /dream --weekly    # L3 deep cross-domain speculation
    - /graph health      # Structural analysis
    - /validate all      # Schema sweep
    - /rethink           # Observation triage
```

### Platform Mapping

| Platform | Mechanism | Install |
|----------|-----------|---------|
| macOS | LaunchAgents (plist) | `schedule.sh` generates and loads plists |
| Linux | systemd user timers | `schedule.sh` creates service+timer units |
| Linux (no systemd) | crontab | `schedule.sh` adds tagged cron entries |
| OpenClaw | Built-in `openclaw cron` | `schedule.sh` uses native cron API |

### Environment Considerations

- cron/launchd don't inherit shell environment — `schedule.sh` injects `PATH` and `ANTHROPIC_API_KEY` into scheduler config
- All paths are absolute (working directory is undefined in scheduled contexts)
- macOS LaunchAgents only fire when the user is logged in (appropriate for dev machines)
- `scheduled-run.sh` wraps each skill invocation so individual failures don't abort the batch

### Condition-Based vs Calendar-Based

mnemos philosophy prefers condition-based maintenance (run `/rethink` when 10+ observations accumulate, not every Tuesday). However, some skills genuinely benefit from periodic triggers:

- `/dream --daily` ties speculation to today's context; `/dream --weekly` needs random sampling even when no trigger exists
- `/curiosity` scans for research gaps that accumulate silently — without periodic execution, the agent only researches what's explicitly requested
- `/consolidate` should run daily regardless of observation count to catch low-importance-but-frequent patterns
- `/stats` provides trending data that requires regular snapshots

The schedule complements — not replaces — condition-based triggers in `/next` and `session-start.sh`.

## Lineage

mnemos is the synthesis of two previous systems:
- **arscontexta**: Provided the Layer 2 knowledge curation methodology, pipeline, and all 16 core skills.
- **clawvault**: Provided the Layer 1 observer pattern and the concept of session hooks for automated memory capture.
