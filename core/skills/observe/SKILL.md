---
name: observe
version: "0.1.0"
description: Extract typed observations from session transcripts. Reads recorded sessions incrementally, scores by importance/confidence/surprise, routes to daily logs. Triggers on "/observe", "process transcripts", "extract observations".
metadata:
  version: "2.0"
  generated_from: "mnemos-v0.2"
  argument-hint: "[--all] [--session ID] [--since YYYY-MM-DD] — Process all unprocessed transcripts (default), a specific session, or sessions since a date."
  openclaw:
    emoji: "👁️"
---

## Vault Path Resolution (mnemos)

Before any file operations, resolve the vault root:
1. Read `.mnemos.yaml` from the workspace root (the project directory where you are running)
2. Extract `vault_path` — this is the root for ALL vault operations
3. All paths in this skill (notes/, ops/, memory/, self/) are RELATIVE to vault_path
4. If `.mnemos.yaml` does not exist or vault_path is not set, fall back to the current working directory

---

## EXECUTE NOW

**Target: $ARGUMENTS**

You are a passive log observer. You do not introspect the live chat to create observations.
You read recorded transcripts from `{vault_path}/memory/sessions/*.jsonl`, process only new
content since the last run (unless explicitly overridden), and extract typed observations.

This skill must run correctly both interactively and from unattended cron.

### Input Contract

- Transcript source: `{vault_path}/memory/sessions/{session-id}.jsonl`
- Cursor source: `{vault_path}/memory/sessions/.cursors.json`
- Transcript line format:

```json
{"ts":"...","role":"user|assistant|tool_use|tool_result|compaction_boundary","content":"...","tool":"...","session_id":"..."}
```

- Cursor format (per session):

```json
{"session_id": {"offset": 12345, "observed_offset": 12000}}
```

`offset` is producer progress (`session-capture.sh`). `observed_offset` is observer progress
(this skill). Process bytes in `[observed_offset, current_file_size)`.

### Argument Handling

Supported arguments:
- `--all`: Reprocess from byte `0` for all selected sessions; ignore `observed_offset`
- `--session ID`: Process only `{ID}.jsonl`
- `--since YYYY-MM-DD`: Process only transcript files modified on/after this date

Defaults (no args): process all sessions with new content beyond `observed_offset`.

Argument precedence:
1. Scope candidate files by `--session` or `--since` if provided
2. Determine processing range via cursor unless `--all` is set

If no matching or unprocessed transcript segments exist, output exactly:

```text
No new transcripts to process
```

Then exit cleanly without modifying files.

### Step 1: Find Unprocessed Transcripts

1. Ensure `{vault_path}/memory/sessions/` exists.
2. Read `.cursors.json` if present; if missing, treat as `{}`.
3. List `*.jsonl` files in `memory/sessions/`.
4. For each candidate file:
   - Derive `session_id` from filename (without `.jsonl`)
   - Get `file_size` in bytes
   - Read cursor entry if any:
     - `observed_offset = entry.observed_offset || 0`
   - If `--all`: mark as pending from `0`
   - Else if `observed_offset < file_size`: mark as pending from `observed_offset`
   - Else: skip (already fully observed)

Selection filters:
- `--session ID`: only include file where `session_id == ID`
- `--since YYYY-MM-DD`: include only files with mtime on/after that date

### Step 2: Read New Transcript Content

For each pending transcript:

1. Read byte range from `start_offset` to EOF.
2. Split into lines and parse JSON per line.
3. Ignore blank lines.
4. If the final line is partial JSON (common during active write), skip only that line.
5. Keep counters:
   - `new_lines`
   - `parsed_events`
   - `turns`
6. Build conversation turns from parsed events:
   - Start a turn at `role=user`
   - Attach following `assistant`, `tool_use`, `tool_result` events until next `user`
   - If events begin without `user`, group by temporal adjacency as a synthetic turn
7. If `role=compaction_boundary`, record boundary metadata but continue processing.

Boundary guidance:
- Compaction boundaries indicate older context was summarized upstream.
- Extraction quality may be lower around boundaries; continue with caution.

### Step 3: Extract Typed Observations

Use LLM analysis on the NEW transcript segment only (not the whole session).
Extract observations as complete, self-contained statements in this exact format:

```text
- [TYPE|i=X.X|c=X.X|s=X.X] OBSERVATION TEXT
```

Where:
- **TYPE**: One of `insight`, `pattern`, `workflow`, `tool`, `person`, `decision`, `open-question`, `preference`
- **i=X.X**: Importance (0.0-1.0) — how significant is this for long-term objectives?
- **c=X.X**: Confidence (0.0-1.0) — how certain are you this is correct?
- **s=X.X**: Surprise (0.0-1.0) — how much does this contradict or extend your existing model?

**Type selection:**

| Type | Use when | Promotion path |
|------|----------|---------------|
| `insight` | A claim or lesson worth remembering | Full pipeline (threshold) |
| `pattern` | A recurring theme or structural parallel | Full pipeline (threshold) |
| `workflow` | A process or technique | Full pipeline (threshold) |
| `tool` | A specific piece of software/library | Reference (auto-promote) |
| `person` | A person and their context | Reference (auto-promote) |
| `decision` | A choice and its reasoning | Reference (auto-promote) |
| `open-question` | Something worth investigating | Reference (auto-promote) |
| `preference` | User interaction preferences, agent persona, named behaviors | Identity (auto-promote) |

Reference types (tool, person, decision, open-question) are auto-promoted to `notes/` by `/consolidate` — they don't need high importance scores to be preserved.

Identity types (preference) are auto-promoted to `self/identity.md` by `/consolidate` — they define how the agent should behave, not knowledge about the world. These always update MEMORY.md regardless of importance score.

**Scoring Guidelines:**

| Score | Importance | Confidence | Surprise |
|-------|-----------|------------|----------|
| 0.9-1.0 | Critical to mission/goals | Verified through multiple signals | Completely overturns prior understanding |
| 0.7-0.8 | Significant, affects decisions | Strong evidence, single source | Meaningfully extends or challenges model |
| 0.4-0.6 | Useful context | Reasonable inference | Minor adjustment to expectations |
| 0.1-0.3 | Nice to know | Speculation or hearsay | Expected, confirms existing model |

**Err toward capturing more, not less.** The consolidation bridge filters later. Working memory should be comprehensive.

Extraction constraints:
- Never fabricate. Every observation must map to transcript evidence.
- If content contains `[truncated]`, avoid low-confidence speculation from missing context.
- If a segment is mostly tool output, extract decisions/actions, not raw output dumps.

### Step 4: Tag Co-occurrences

Before writing, scan extracted observations for entities that appeared together:
- person + tool in same event: `@co: tool:<name>` or `@co: person:<name>`
- decision referencing person/tool: append corresponding `@co:` tags
- multiple co-occurrences are allowed when justified

Format (same as existing contract):

```text
- [person|i=0.5|c=0.9|s=0.2] John recommended ast-grep for the migration @co: tool:ast-grep
```

Co-occurrence tags are required when clear co-presence exists because `/consolidate`
uses them to create graph links between promoted reference notes.

### Step 5: Route to Daily Log

Route observations by transcript timestamp date, not runtime date.

1. For each observation, assign a source date from supporting transcript events (`ts`).
2. If one transcript segment spans multiple dates, split observations by date.
3. For each date `D`, append to `{vault_path}/memory/daily/D.md`.
4. Ensure file structure:

```markdown
# YYYY-MM-DD

## Observations

- [type|i=...|c=...|s=...] ...
```

Behavior rules:
- Create missing daily files.
- Preserve existing content.
- Append only new observations from this run.
- Keep output format exactly compatible with `/consolidate`.

### Step 6: Update MEMORY.md (if significant)

After extraction, assess whether MEMORY.md needs refresh:
- Trigger assessment if any observation has `i >= 0.8`
- Trigger assessment if any observation has `s >= 0.7`
- Trigger assessment if any observation type is `preference` (always)

Assessment means: read `{vault_path}/memory/MEMORY.md` and determine whether newly
observed context materially changes active memory. Update only when warranted.

**Voice**: MEMORY.md is written as second-person directives to the next agent that reads it. Identity and preference observations become "You are..." / "The user prefers..." statements, not third-person log entries. Activity summaries should be actionable ("You were working on X") not archival ("Agent worked on X"). The reading agent should assume it is the assistant being addressed.

### Step 7: Update Cursors

After each transcript is fully processed and writes succeed:

1. Recompute transcript current file size.
2. Update `.cursors.json` entry for that `session_id`:
   - Preserve existing `offset` if present
   - Set `observed_offset` to file size just processed
3. Write `.cursors.json` atomically (single coherent JSON object)

Do not update cursor for a transcript that failed processing.

### Step 8: Report

Output this summary shape:

```text
Observe
=======
Transcripts processed: N
  - {session-id} (X new lines, Y turns)
  - {session-id} (X new lines, Y turns)

Observations extracted: M
  - insights: X
  - patterns: X
  - workflows: X
  - tools: X
  - people: X
  - decisions: X
  - open-questions: X
  - preferences: X

Reference types (auto-promote via /consolidate): X
Identity types (auto-promote to self/): X
Full pipeline (threshold-based): X
Co-occurrences tagged: X

Stored to:
  - memory/daily/YYYY-MM-DD.md (N observations)
  - memory/daily/YYYY-MM-DD.md (N observations)

Next: Run /consolidate to promote observations to notes/
```

If no work was performed, only print `No new transcripts to process`.

---

## Quality Gates

- Each observation must be a COMPLETE thought — not a fragment
- Surprise scoring must be honest — most things are NOT surprising (s=0.1-0.3)
- Importance must reflect actual significance, not how interesting something is
- Observations must be self-contained — readable without the full session context
- NEVER fabricate observations — only extract what is present in transcript lines
- Tool-heavy segments should yield decisions/actions, not copied command output
- Truncated transcript chunks should be skipped or flagged, not over-interpreted

## Guardrails

- Do NOT introspect current live conversation as primary input
- Do NOT read native harness transcript formats
- Do NOT modify transcript `.jsonl` files
- Do NOT alter observation output format required by `/consolidate`
- Do NOT remove co-occurrence tagging support

## Operational Notes

- Designed for repeated incremental execution during active sessions and safe for cron.
- `--all` is a deliberate rebuild mode and may re-emit historical observations.
