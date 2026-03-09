---
name: ingest
version: "0.1.0"
description: Auto-seed all inbox files and process the queue. Scans inbox/, seeds each file without prompting, then runs /ralph to process pending tasks. Designed for unattended scheduled execution. Triggers on "/ingest", "process inbox", "ingest all".
metadata:
  version: "1.0"
  argument-hint: "[--dry-run] [--limit N] — dry-run shows what would happen, limit caps ralph processing"
  openclaw:
    emoji: "📥"
---
## Vault Path Resolution (mnemos)

Before any file operations, resolve the vault root:
1. Read `.mnemos.yaml` from the workspace root (the project directory where you are running)
2. Extract `vault_path` — this is the root for ALL vault operations
3. All paths in this skill (notes/, ops/, inbox/, self/, memory/, templates/) are RELATIVE to vault_path
4. If `.mnemos.yaml` does not exist or vault_path is not set, fall back to the current working directory

Example: if vault_path is `/data/vault`, then `inbox/` resolves to `/data/vault/inbox/`.



## EXECUTE NOW

**Target: $ARGUMENTS**

Parse arguments:
- `--dry-run`: show what would be seeded/processed without executing
- `--limit N`: cap /ralph processing at N tasks (default: 10)

### Step 0: Read Vocabulary

Read `ops/derivation-manifest.md` (or fall back to `ops/derivation.md`) for domain vocabulary mapping. All output must use domain-native terms. If neither file exists, use universal terms.

**START NOW.** Ingest inbox and process queue.

---

## Step 1: Scan Inbox

List all files in `inbox/` (recursively). Filter to processable files:
- Include: `.md`, `.txt`, `.json`, `.yaml` files
- Exclude: hidden files (starting with `.`), empty files, directories

```bash
find inbox/ -type f \( -name "*.md" -o -name "*.txt" -o -name "*.json" -o -name "*.yaml" \) ! -name ".*" 2>/dev/null
```

If inbox is empty or doesn't exist:
```
inbox/: empty or not found
Skipping to queue processing...
```

---

## Step 2: Seed Each File (Auto Mode)

For each file found in inbox, run the seed workflow **without prompting**:

### 2a. Duplicate Check (Silent Skip)

For each file, check if already seeded:
- Search queue for matching source name
- Search archive folders for matching batch

If duplicate found: **skip silently** (log but don't ask). This is unattended mode.

### 2b. Seed New Files

For files not already in the queue:
1. Create archive folder: `ops/queue/archive/{date}-{basename}/`
2. Move file from inbox to archive folder
3. Create task file in `ops/queue/`
4. Add extract task to queue

Track results:
- `seeded`: list of newly seeded files
- `skipped`: list of duplicates skipped
- `errors`: list of files that failed

### 2c. Seed Report

After processing all inbox files:
```
Inbox scan:
  Found: {N} files
  Seeded: {M} new sources
  Skipped: {K} (already in queue/archive)
  Errors: {E}
```

If `--dry-run`, show what WOULD be seeded and stop here.

---

## Step 3: Process Queue

After seeding, run queue processing to handle all pending tasks.

### 3a. Check Queue State

Read the queue file. Count pending tasks:
- Extract tasks (new sources to reduce)
- Claim tasks (notes to create/reflect/reweave/verify)
- Enrichment tasks

### 3b. Run Ralph

If pending tasks exist:
```
/ralph {min(pending_count, limit)} 
```

Default limit is 10. Override with `--limit N`.

If no pending tasks:
```
Queue: empty (nothing to process)
```

---

## Step 4: Final Report

```
--=={ ingest }==--

Inbox:
  Scanned: {N} files
  Seeded: {M} new sources
  Skipped: {K} duplicates

Queue:
  Pending before: {P1}
  Processed: {R} tasks
  Pending after: {P2}

{if seeded > 0}
New sources queued:
- {source1} -> ops/queue/{task1}.md
- {source2} -> ops/queue/{task2}.md
{/if}

{if processed > 0}
Tasks completed:
- {task_id}: {phase} -> {next_phase or "done"}
{/if}
```

---

## Dry Run Mode

When `--dry-run` is set:

1. Scan inbox and report what would be seeded
2. Read queue and report what would be processed
3. Make NO changes (no file moves, no queue updates, no ralph execution)

```
--=={ ingest --dry-run }==--

Would seed:
- inbox/article1.md -> ops/queue/article1.md
- inbox/research/paper.md -> ops/queue/paper.md

Would skip (duplicates):
- inbox/old-article.md (already in archive)

Would process:
- {N} pending tasks via /ralph {limit}
```

---

## Error Handling

**Seed failure for one file:** Log the error, continue with remaining files. Don't abort the entire ingest.

**Queue file missing:** Create a new queue file with schema header.

**Ralph failure:** Log and report in final output. The queue preserves state for retry.

**Empty inbox AND empty queue:** Report cleanly, not an error:
```
--=={ ingest }==--
Inbox: empty
Queue: empty
Nothing to do.
```

---

## Why This Skill Exists

The gap between `/learn` output and `/ralph` processing required manual `/seed` invocation. `/ingest` closes this gap for unattended operation:

1. `/learn "topic"` deposits research in inbox/
2. `/ingest` (scheduled hourly) auto-seeds and processes
3. Notes appear in notes/ without manual intervention

This enables a fully automated research-to-knowledge pipeline.

---

## Critical Constraints

**never:**
- Prompt for user input (this is unattended mode)
- Stop on duplicate detection (skip silently)
- Process more than `--limit` tasks in one run (cost control)
- Delete or modify files outside the normal seed workflow

**always:**
- Log what was skipped and why (for debugging)
- Continue past individual file errors
- Respect the limit parameter
- Report final state clearly
