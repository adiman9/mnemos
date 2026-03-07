# CLAUDE.md

## Philosophy

**If it won't exist next session, write it down now.**

You are an autonomous agent running in ephemeral sessions. Your active context resets; your vault does not. mnemos is your persistent memory subsystem: capture fast during real work, consolidate later, retrieve when needed.

Memory is not the main job. Coding, research, debugging, and delivery stay primary. mnemos exists to make those tasks compound instead of restarting from zero each session.

---

## Configuration

### The Path Invariant (Read First)

The vault is configurable and is often **not** your current working directory.

Before any memory operation:
1. Read `.mnemos.yaml` from the workspace root (the project directory where you are running)
2. Resolve `vault_path`
3. Treat **all** mnemos paths as relative to `vault_path`
4. If `.mnemos.yaml` is missing or `vault_path` is unset, fall back to current working directory

Example:
- If `vault_path: /data/vault`, then `notes/` means `/data/vault/notes/`
- If `vault_path: /data/vault`, then `memory/MEMORY.md` means `/data/vault/memory/MEMORY.md`

Never assume `./notes` in the repo checkout is the live vault unless that is the resolved `vault_path`.

---

## The Three Layers

mnemos separates memory by curation level and time horizon.

### Layer 1: Working Memory (`memory/`)
- Fast, high-volume capture while you work
- Stores typed observations, daily logs, and session transcripts
- Optimized for recency and low friction, not polish

### Layer 2: Long-Term Knowledge (`notes/`, `self/`)
- Curated, atomic, wiki-linked knowledge graph
- Optimized for retrieval, synthesis, and reuse across sessions
- Processed through the pipeline (`/seed -> /reduce -> /reflect -> /reweave -> /verify`)

### Layer 3: Dream (`memory/.dreams/`)
- Speculative cross-domain pattern generation
- Produces candidate ideas that may be promoted or discarded
- Optimized for novelty, then filtered by validation
- **Hidden directory** — invisible to rg, qmd, and all skills except `/dream`

### Data Flow
- L1 -> L2 via `/consolidate` (promote durable observations)
- L2 -> L3 via `/dream` sampling and recombination
- L3 -> L2 via promotion of validated speculations

---

## Session Rhythm

Every session follows: **Orient -> Work -> Persist**

### Orient (1-2 minutes)
- Resolve `vault_path` from `.mnemos.yaml` first
- Read `memory/MEMORY.md` for boot context
- Read `self/identity.md`, `self/methodology.md`, `self/goals.md`
- Check queue and urgent maintenance signals

### Work (primary task first)
- Do the actual assignment (code, research, analysis)
- Capture observations with minimal interruption (`/observe` or session hook)
- Defer heavy curation to batches (`/consolidate`, `/pipeline`, `/ralph`)

### Persist (end-of-session continuity)
- Session-capture hook archives transcript into `memory/sessions/`
- Daily observations updated in `memory/daily/`
- `memory/MEMORY.md` regenerated for next session boot

Low-friction rule: if memory activity starts dominating task work, scale memory down to capture-only mode and resume primary execution.

---

## Layer 1: Working Memory

Working memory stores what happened and what changed while you were executing tasks.

### Observation Format

Typed observations are the unit of capture. Each entry includes:
- `type`: one of the unified taxonomy categories (see below)
- `importance`: `0.0-1.0`
- `confidence`: `0.0-1.0`
- `surprise`: `0.0-1.0`
- timestamp and concise content
- optional co-occurrence tags: `@co: type:name`

### Unified Taxonomy

mnemos uses a single taxonomy across both layers. The type determines the promotion path from L1 to L2:

| Category | Description | Promotion Path |
|----------|-------------|---------------|
| `insight` | Claims, lessons, findings | Full pipeline (threshold-based) |
| `pattern` | Recurring themes, structural parallels | Full pipeline (threshold-based) |
| `workflow` | Processes, techniques, procedures | Full pipeline (threshold-based) |
| `tool` | Software, libraries, frameworks | Reference (auto-promote) |
| `person` | People and their context | Reference (auto-promote) |
| `decision` | Choices and their reasoning | Reference (auto-promote) |
| `open-question` | Unknowns worth investigating | Reference (auto-promote) |

**Reference path**: observation → validate → create note directly in `notes/` → wire wiki-links → trigger /reflect for deeper connections. Skips /reduce extraction (the observation IS the note).

**Full pipeline path**: observation → promotion thresholds → inbox/ → /seed → /reduce → /reflect → /reweave → /verify. Needs transformation from observation into standalone claim.

**Why two paths**: People, tools, and decisions are reference data — they don't need extraction or curation to be useful. But they DO need to be connected into the graph. An insight about "structural code search beats regex" should link to the tool note for ast-grep and the person note for whoever recommended it.

### Storage
- `memory/daily/YYYY-MM-DD.md`: observation stream for the day
- `memory/sessions/`: archived transcripts/session summaries
- `memory/MEMORY.md`: compact boot summary injected at session start

### Transcript Capture Pipeline

Observations are extracted from recorded session transcripts, not agent self-summarization:

1. **Capture** — Adapter hooks record the session incrementally to `memory/sessions/{session-id}.jsonl`
   - Claude Code/Cursor: `session-capture.sh` fires on every assistant turn (`Stop` hook)
   - OpenCode: `chat.message` and `tool.execute.after` plugin hooks capture per-turn
   - OpenClaw: `gateway:heartbeat` captures periodically (~60s)
   - All adapters include a pre-compaction hook for safety flush
2. **Observe** — `/observe` reads transcripts incrementally (cursor-based), extracts typed observations via LLM analysis, routes to `memory/daily/YYYY-MM-DD.md`
3. **Consolidate** — `/consolidate` promotes observations to L2 via dual-path (reference auto-promote, pipeline threshold-based)

Transcripts use a standard JSONL format across all harnesses:
```jsonl
{"ts":"ISO8601","role":"user|assistant|tool_use|tool_result|compaction_boundary","content":"...","session_id":"..."}
```

### Session Storage
- `memory/sessions/{session-id}.jsonl`: incremental standard transcript
- `memory/sessions/{session-id}.meta.json`: session metadata (harness, start time)
- `memory/sessions/.cursors.json`: byte-offset tracking for capture and observation

---

## Layer 2: Long-Term Knowledge

Layer 2 is the durable knowledge graph used for retrieval and reasoning across sessions.

### Atomic Insights
- One idea per file
- Prose-as-title claim format
- YAML frontmatter for structured retrieval
- Dense wiki-linking with explicit relationship semantics

### Topic Maps
- Navigation hubs, not dumping grounds
- Curate what matters, what conflicts, and what remains open
- Keep entries contextualized (no bare link lists)

### Pipeline
- `/seed`: queue source and archive path state
- `/reduce`: extract claims and structured outputs
- `/enrich`: add new source content to existing notes (multi-source attribution)
- `/reflect`: add forward connections + topic map integration
- `/reweave`: backward pass on older notes
- `/verify`: quality gate (recite + validate + review)

### Queue Orchestration
- `/ralph`: phase-execution engine over queue tasks with fresh context per phase
- `/pipeline`: end-to-end wrapper for seed -> process -> archive

### Quality Standard
- Discovery-first writing: notes must be findable by agents that do not know they exist
- No direct low-quality dumping into `notes/`
- Prioritize composability and retrieval over stylistic polish

---

## Layer 3: Dream

Layer 3 generates speculative, cross-domain hypotheses from existing memory.

### Purpose
- Surface structural parallels across distant topics
- Generate candidate hypotheses not obvious from local context
- Expand search space for future synthesis

### Dream Modes

`/dream` operates in two modes:

**Daily mode** (`/dream --daily`): Context-driven. Reads today's daily note, extracts themes and entities, finds 2-3 structural parallels between today's activity and existing vault notes. Lighter, faster, grounded in what just happened. Novelty threshold: 0.5.

**Weekly mode** (`/dream --weekly`): Discovery-driven. Randomly samples 5 note pairs across maximally distant topic maps. Deep structural parallel analysis. This is where the highest-value cross-domain connections emerge. Novelty threshold: 0.6.

Default: daily when invoked interactively, weekly when invoked by scheduled-run.sh (`MNEMOS_SCHEDULED=1`).

### Workflow
- `/dream` samples notes across domains (daily: from today's context, weekly: random)
- Generates speculative links and novel hypotheses
- Scores novelty/relevance
- Stores candidates in `memory/.dreams/`

### Isolation Design

Dreams use a **hidden directory** (`memory/.dreams/`) — the dot prefix makes them invisible to normal vault operations:

- **ripgrep** skips hidden directories by default. No dream content appears in keyword searches.
- **qmd** filters dot-prefixed paths during its file walk. Dreams never enter semantic search indexes.
- **All skills** scope their grep/rg to `notes/` or `{vocabulary.notes}/`. Dreams are excluded from orphan detection, graph analysis, reflection, and reweaving.
- **validate-note hook** only fires on files in `notes/`. Dream files skip schema validation.

Only two things access `memory/.dreams/` directly:
1. `/dream` — knows the explicit path to create and review speculation files
2. `session-start.sh` — counts dream files for vault stats (read-only)

Dreams surface into the knowledge graph **only** through deliberate promotion: `/dream --review` creates an inbox entry, which enters the normal pipeline. Until promoted, a dream is invisible to every search path in the system.

This isolation enables aggressive, speculative dream generation without polluting curated knowledge.

### Promotion and Decay
- Promote high-signal dreams into Layer 2 pipeline for curation
- Discard or archive low-yield speculation
- Dream output is provisional until verified

---

## Consolidation

Consolidation bridges volatile observations (L1) to durable knowledge (L2). It operates two paths based on observation type.

### Reference Path (auto-promote)
Types: `person`, `tool`, `decision`, `open-question`
- ALL observations of these types are promoted — no threshold needed
- Created directly in `notes/` (skips inbox/ and /reduce)
- Wiki-links wired from co-occurrence tags and same-session context
- Queued for /reflect to find deeper connections

### Full Pipeline Path (threshold-based)
Types: `insight`, `pattern`, `workflow`
- Promote when any condition holds:
  - `importance >= 0.8`
  - `surprise >= 0.7`
  - `frequency >= 2` and `importance >= 0.4`
- Routed through inbox/ → /seed → /reduce → full pipeline

### Graph as Integration Layer
Reference notes are first-class graph nodes. A person note links to the tools they recommended and the insights from your conversations. A tool note links to the decisions where it was chosen and the workflows that use it. The wiki-link graph makes everything discoverable regardless of which path created it.

### Timing
- Run periodically (daily by default via scheduled execution)
- Batch for throughput and lower interruption cost

---

## Curiosity — Proactive Research Discovery

`/curiosity` analyzes recent vault activity and generates research opportunities. It bridges the gap between what you know and what you could know by proactively discovering related work, alternative tools, validation evidence, and unexplored directions.

### How It Works
1. **Scan** recent activity: daily notes (3 days), recently modified notes, pending inbox items, goals
2. **Generate** 5-10 research candidates across categories: tool deep-dives, alternative discovery, concept expansion, implementation patterns, claim validation, open questions
3. **Score** each candidate by Expected Information Gain (EIG): novelty × 0.3 + relevance × 0.25 + actionability × 0.2 + connectivity × 0.15 + timeliness × 0.1
4. **Execute** top candidates (EIG ≥ 0.7) by invoking `/learn` — which handles all search tool logic
5. **Log** results to `ops/logs/curiosity-YYYY-MM-DD.md`

### Pluggable Research Sources

`/curiosity` uses `/learn`'s Exa cascade by default. Users can add additional research sources in `ops/config.yaml`:

```yaml
research:
  additional_sources:
    - tool: mcp__github__search_repositories
    - tool: mcp__reddit__search
    - skill: /my-custom-search
```

Additional sources are invoked only for the highest-scoring candidates (EIG ≥ 0.85).

### Safeguards
- Maximum 5 research executions per run (cost guard)
- Deduplicates against recent `/learn` runs
- `--dry-run` shows candidates without executing
- `--threshold N` adjusts the EIG cutoff

---

## Skill Invocation Table

If a skill exists, use it. Do not manually replicate the workflow.

| Trigger | Skill |
|---|---|
| New article/tweet/source to process | `/seed` -> `/pipeline` |
| Process queue items | `/ralph` |
| Add new source content to existing note | `/enrich` |
| Capture session learning while working | `/observe` (or session-capture hook) |
| Promote observations to notes (dual-path) | `/consolidate` |
| Find new connections | `/reflect` |
| Update older notes with new context | `/reweave` |
| Quality check note(s) | `/verify`, `/validate` |
| Cross-domain speculative discovery | `/dream` (`--daily` or `--weekly`) |
| Proactive research discovery | `/curiosity` |
| Decide highest-value next action | `/next` |
| Vault metrics and structural health | `/stats`, `/graph` |
| Capture friction/process failures | `/remember` |
| Challenge accumulated assumptions | `/rethink` |
| Restructure vault after config/schema shifts | `/refactor` |
| Research a topic into the system | `/learn` |

---

## Vault Structure

All paths below are relative to resolved `vault_path`.

```text
<vault_path>/
├── self/                  # Agent identity and long-lived operating context
│   ├── identity.md
│   ├── methodology.md
│   ├── goals.md
│   └── memory/
├── notes/                 # Layer 2 atomic insights and topic maps
├── memory/                # Layer 1 + Layer 3
│   ├── MEMORY.md          # Session boot summary
│   ├── daily/             # Typed observations by day
│   ├── sessions/          # Session transcript archives/summaries
│   └── .dreams/           # Layer 3 speculative outputs (hidden from search)
├── inbox/                 # Raw sources pending processing
├── ops/                   # Operational state, queue, maintenance
│   ├── queue/
│   │   ├── queue.json
│   │   └── archive/
│   ├── logs/              # Scheduled run logs (scheduled-YYYY-MM-DD.log)
│   ├── observations/      # Friction/process signals
│   ├── tensions/          # Contradictions worth resolution
│   ├── reminders.md
│   ├── tasks.md
│   ├── config.yaml
│   ├── schedule.yaml      # Scheduled skill execution config
│   └── methodology/
└── templates/             # Note templates and schema blocks
```

---

## Atomic Insights

Each insight captures exactly one claim.

### Prose-as-Title Pattern
- Title must read naturally when linked: `since [[title]], ...`
- Use claim statements, not topic labels

Good:
- `long context windows trade retrieval precision for breadth`
- `agent workflows degrade when phase boundaries are implicit`

Bad:
- `context windows`
- `agent workflows`

### Composability Test
Before saving, verify:
1. **Standalone sense**: understandable without hidden context
2. **Specificity**: possible to disagree with it
3. **Clean linking**: link does not drag unrelated claims

### YAML Schema (baseline)

```yaml
---
description: One sentence adding context beyond title
topics: [topic map links]
source: "where this came from"
confidence: supported | likely | experimental | outdated
category: insight | pattern | workflow | tool | person | decision | open-question
---
```

`description` is required and must add new information (scope, mechanism, implication), not restate the title.

---

## Wiki-Links

Wiki-links are the graph edges. They are the invariant internal reference form.

### Rules
- Use `[[note title]]` for internal references
- Link targets resolve by filename; filenames must be unique
- Every link must resolve to a real file (no dangling links)

### Relationship Semantics
State why the link exists:
- `extends`
- `foundation`
- `contradicts`
- `enables`
- `example`

Prefer inline links in prose over disconnected footers when possible.

---

## Topic Maps

Topic maps are navigation hubs that reduce retrieval cost and context switching.

### Required Structure

```markdown
# topic-name

Brief orientation.

## Key Insights
- [[insight]] -- why this matters here

## Tensions
- unresolved conflicts

## Open Questions
- unknowns worth exploration
```

Critical rule: entries in `Key Insights` must include context phrases.

### Lifecycle
- Create when ~5+ related insights need coordination
- Split when map exceeds ~40 links and has clear subclusters
- Merge when two small maps overlap heavily

---

## Search

All search paths are relative to resolved `vault_path`.

### Mode Selection
- Keyword (`rg`): exact terms, fast filters
- Semantic (`qmd`, optional): conceptual neighbors
- Hybrid: semantic candidate generation + manual judgment

### Keyword Patterns

```bash
rg '^description:' notes/
rg '^category: tool' notes/
rg '\[\[note title\]\]' --glob '*.md'
rg -L '^description:' notes/*.md
```

### Semantic Notes
- Prefer qmd/vector search for duplicate detection and cross-domain linking
- If qmd is unavailable, fall back to keyword + topic map traversal

---

## MEMORY.md Pattern

`memory/MEMORY.md` is the boot context file. It is concise by design.

### Voice

MEMORY.md is written **to the reading agent as directives**, not as a third-person log. The agent reading this file should assume it is the "assistant" being described.

- BAD: `Captured preference that user wants the assistant called Sammy`
- GOOD: `You are called Sammy. The user prefers a meek, shy, gentle tone.`

Identity and preference entries are second-person directives. Activity summaries can be factual but should still be actionable ("You were working on X" not "Agent worked on X").

### Contains
- Identity directives from `self/identity.md` (## Identity section at top — who you are, how to behave)
- Current goals from `self/goals.md`
- High-signal recent observations (typically last 3 days)
- Active topic maps
- Last session summaries (short)

### Regeneration
- Regenerated periodically and at session boundaries by hooks/scripts
- Keep it compressed; it is an index into memory, not a full dump

### Injection
- Loaded at session start to restore orientation quickly
- Purpose: reduce cold-start overhead without flooding context

---

## Maintenance

Maintenance is condition-based, not calendar-based.

### Core Checks
- orphan notes (no inbound links)
- dangling links
- queue stalls and backlog
- inbox pressure and item age
- topic map oversize
- sparse/stale notes
- observation/tension accumulation

### Trigger Examples
- Any dangling links -> repair now
- Any orphan notes -> route to connection finding
- Pending observations >= 10 -> `/rethink`
- Pending tensions >= 5 -> `/rethink`
- Inbox items aging > 3 days -> prioritize processing

Use `/next` to reconcile queue state and surface one high-value action.

---

## Self-Space

`self/` stores persistent agent identity and execution policy.

```text
self/
├── identity.md      # who you are and how you operate
├── methodology.md   # how you extract, connect, and verify
├── goals.md         # active objectives and priorities
└── memory/          # optional agent-specific durable notes
```

Read `self/identity.md`, `self/methodology.md`, and `self/goals.md` at session start. Update `self/goals.md` when priorities change.

---

## Scheduled Execution

Some skills run automatically on a schedule via OS-level triggers (launchd, systemd, crontab). This is configured in `ops/schedule.yaml` and managed by `schedule.sh`.

### Default Schedule
- **Daily** (09:00): `/observe`, `/consolidate`, `/dream --daily`, `/curiosity`, `/stats`
- **Weekly** (Sun 03:00): `/dream --weekly`, `/graph health`, `/validate all`, `/rethink`

### What This Means for You
- Don't worry about remembering to run `/consolidate`, `/dream`, or `/curiosity` — they run automatically if scheduling is set up
- Check `ops/logs/scheduled-YYYY-MM-DD.log` to see what ran and whether it succeeded
- You can still run these skills manually anytime — scheduled runs don't conflict
- Edit `ops/schedule.yaml` to customize which skills run and when

### Condition-Based Triggers Still Apply
Scheduled runs complement, not replace, the condition-based alerts in `session-start.sh`. If observations accumulate faster than daily consolidation handles, the session-start alert will still fire.

---

## Operating Rules

1. Resolve `vault_path` first. No exceptions.
2. Keep memory low-friction during primary task execution.
3. Capture fast in Layer 1, curate later into Layer 2.
4. Use skills for memory workflows; avoid manual reinvention.
5. Keep notes discoverable, composable, and linked.
