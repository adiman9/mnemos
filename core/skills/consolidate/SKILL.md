---
name: consolidate
description: Promote high-value working memory observations to the long-term knowledge pipeline. Scans recent daily logs, applies promotion criteria, and batches promoted items through /reduce. Triggers on "/consolidate", "promote observations", "crystallize memory".
version: "1.0"
generated_from: "mnemos-v0.1"
user-invocable: true
context: fork
model: sonnet
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
argument-hint: "[--days N] [--dry-run] — N = number of days to scan (default: 7). --dry-run shows what would be promoted without acting."
---

## Vault Path Resolution (mnemos)

Before any file operations, resolve the vault root:
1. Read `.mnemos.yaml` from the workspace root (the directory containing `.claude/`)
2. Extract `vault_path` — this is the root for ALL vault operations
3. All paths in this skill (notes/, ops/, memory/, self/) are RELATIVE to vault_path
4. If `.mnemos.yaml` does not exist or vault_path is not set, fall back to the current working directory

---

## EXECUTE NOW

**Target: $ARGUMENTS**

Parse arguments:
- --days N: scan the last N days of observations (default: 7)
- --dry-run: show what would be promoted without creating any files

You are the consolidation bridge between working memory (Layer 1) and long-term knowledge (Layer 2). Route observations through a dual-path promotion model with a unified taxonomy.

### Step 1: Scan Daily Logs

Read all files in `{vault_path}/memory/daily/` from the last N days. Parse each observation entry:

```
- [TYPE|i=X.X|c=X.X|s=X.X] OBSERVATION TEXT @co: type:name @co: type:name
```

Extract for every observation:
- type
- importance
- confidence
- surprise
- text
- co-occurrences (`@co: type:name` tags)
- source daily file/date

Also compute frequency by searching across ALL daily logs (not just the scanned window) for semantically similar observations. Use keyword matching and semantic similarity (qmd if available).

### Step 2: Classify by Promotion Path

Split observations into two promotion groups using unified taxonomy:

| Path | Types | Rule |
|------|-------|------|
| Reference | person, tool, decision, open-question | AUTO-promote all (no threshold) |
| Full pipeline | insight, pattern, workflow | Promote only if importance >= 0.8 OR surprise >= 0.7 OR (frequency >= 2 AND importance >= 0.4) |

Track which criterion promoted each full-pipeline observation (importance, surprise, or frequency+importance) for reporting.

### Step 3: Deduplicate Against Existing Notes (Both Paths)

For each candidate in BOTH paths, search `{vault_path}/notes/` for notes that already capture the same entity/claim:
- Use keyword search first
- If semantic search (qmd) is available, use it to catch paraphrased matches
- Person notes: search for the person name and context
- Tool notes: search for the tool name and core capability
- Decision/open-question/insight/pattern/workflow: search for the same claim or equivalent proposition

Dedup outcomes:
- If already captured and no meaningful new information: SKIP
- If already captured but new information exists: mark for UPDATE in Step 5 (reference path enrichment)
- If no match: eligible for create (Step 4A or Step 4B)

### Step 4A: Reference Path - Create Notes Directly

If --dry-run: list what would be created/updated/linked and do not write files.

Otherwise, for each dedup-passed reference observation (person/tool/decision/open-question):

1. Generate a prose-as-title that captures the claim (not a bare label):
   - Person: `john chen recommends ast-grep and prefers async communication`
   - Tool: `ast-grep supports structural code search across 25 languages`
   - Decision: `chose postgres over sqlite for concurrent write support`
   - Open question: `can wasm components replace microservices for plugin architectures`

2. Create `{vault_path}/notes/{title}.md` using this schema:
   ```markdown
   ---
   description: [one sentence adding context beyond title]
   topics: []
   source: "consolidated from daily/YYYY-MM-DD"
   confidence: supported
   category: [person|tool|decision|open-question]
   ---

   [Body: expand observation text into a useful durable reference note]

   ---

   Source: consolidated from daily/YYYY-MM-DD

   Relevant Notes:
   [wiki-links from co-occurrence tags and same-session relationships]

   Topics:
   [leave empty if no obvious topic map; /reflect can populate]
   ```

3. Wire co-occurrence links:
   - For each `@co: type:name`, find an existing note in `{vault_path}/notes/` and add a bidirectional wiki-link when relationship is genuine
   - If target note does not exist yet but is in the current promotion batch, link to that to-be-created note
   - Verify each wiki-link target exists before finalizing links

4. Wire same-session links:
   - For promoted observations from the same daily file, add links where a real semantic relationship exists (supports, extends, enables, contradicts, etc.)
   - Do not link purely because entries are adjacent in time

5. Queue connection-finding:
   - After creating reference notes, recommend running `/reflect` on each new note
   - If pipeline chaining mode is `suggested` or `automatic`, add reflect tasks to queue entries for these notes

### Step 4B: Full Pipeline Path - Route Through Inbox

This path remains threshold-based and uses the existing pipeline behavior.

If --dry-run: report what would be routed to inbox and stop.

Otherwise, for each full-pipeline observation (insight/pattern/workflow) that passed thresholds and dedup:

1. Create a source file in `{vault_path}/inbox/` with observation metadata:
   ```markdown
   ---
   source_type: consolidated-observation
   original_date: YYYY-MM-DD
   observation_type: TYPE
   importance: X.X
   surprise: X.X
   frequency: N
   promotion_reason: [importance|surprise|frequency+importance]
   ---

   ## Observation

   OBSERVATION TEXT

   ## Context

   [Additional context from the daily log entry, if available]
   ```

2. Queue via `/seed` (or explicitly mark ready for `/pipeline`/`/ralph`)

### Step 5: Update Existing Notes (Reference Enrichment)

For reference-path dedup matches with new information:
- Read the existing note
- Append the new information to the body (integrated, not duplicated)
- Add source attribution line:
  - `- consolidated from daily/YYYY-MM-DD -- [what was added]`
- Preserve existing structure and links while enriching content

### Step 6: Report

```
Consolidation Report
====================
Period scanned: YYYY-MM-DD to YYYY-MM-DD
Observations found: N

Reference path (auto-promoted to notes/):
  - person: X created, Y updated, Z skipped (already exists)
  - tool: X created, Y updated, Z skipped
  - decision: X created, Y updated, Z skipped
  - open-question: X created, Y updated, Z skipped
  Wiki-links added: N (from co-occurrences and same-session context)

Full pipeline path (threshold-based -> inbox/):
  - insight: X promoted (Y by importance, Z by surprise, W by frequency)
  - pattern: X promoted
  - workflow: X promoted
  Skipped (below threshold): N

Deduplicated (already in notes/): D
Updated with new info: U

Files created:
  notes/: [list of reference notes created]
  inbox/: [list of pipeline items created]

Next:
  - Run `/reflect` on new reference notes to find deeper connections
  - Run `/pipeline` or `/ralph` to process inbox items
```

### Step 7: Regenerate MEMORY.md

After consolidation, regenerate `{vault_path}/memory/MEMORY.md` to reflect the current state:
- Read `{vault_path}/self/goals.md` for current objectives
- Summarize recent observations (last 3 days)
- List active topic maps from `{vault_path}/notes/`
- Summarize last 3-5 session summaries from `{vault_path}/memory/sessions/`

---

## Quality Gates

- Never create a reference note that duplicates an existing note; dedup is mandatory before creation
- Reference notes MUST be prose-as-title claims, not bare names or labels
- Co-occurrence and same-session links must be genuine semantic relationships, not temporal adjacency
- Wiki-link targets must exist before linking; verify target files before writing links
- Reference notes must include valid frontmatter fields: description, topics (can be empty), source, confidence, category
- Full-pipeline promotions must preserve threshold logic and track promotion reason
- The inbox files must remain well-formed for /seed and downstream pipeline processing
- MEMORY.md regeneration must not lose any manually-added content
