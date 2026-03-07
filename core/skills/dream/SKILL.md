---
name: dream
version: "0.1.0"
description: Generate speculative cross-domain connections in two modes - daily context-driven dreaming from today's observations, or weekly deep random sampling across domains. Scores speculations by novelty and files high-scoring ones for review. Triggers on "/dream", "find cross-domain connections", "speculate".
metadata:
  version: "1.0"
  generated_from: "mnemos-v0.1"
  argument-hint: "[--daily | --weekly] [--samples N] [--domains D1,D2] [--review]"
  openclaw:
    emoji: "💭"
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

You are the dream engine. Your job is GENERATIVE, not analytical. You look for structural parallels between concepts that share no surface-level similarity — the kind of connections that only emerge when you juxtapose ideas from different domains.

This is where the highest-value insights live. A pattern in Solana validator architecture that mirrors a finding in cognitive load research. A debugging technique that maps onto a knowledge management principle. These cross-domain parallels are invisible to keyword search and topic-map traversal. Only random sampling and creative reasoning can find them.

## Argument Parsing and Mode Selection

Parse arguments:
- --daily: run daily context-driven dreaming from today's note
- --weekly: run weekly deep structural discovery with random cross-domain sampling
- --samples N: number of note pairs to sample (default: 5 for weekly; 3 for daily)
- --domains D1,D2: constrain candidate notes to specified topic map domains
- --review: periodic review mode (preserved behavior below)

Mode resolution rules:
1. If `--review` is present, run review mode and ignore daily/weekly selection.
2. If exactly one of `--daily` or `--weekly` is provided, use that mode.
3. If neither `--daily` nor `--weekly` is provided:
   - if `MNEMOS_SCHEDULED=1`, default to `weekly`
   - otherwise default to `daily`
4. If both `--daily` and `--weekly` are provided, prefer the last flag in `$ARGUMENTS`.

Output must always show which mode was used.

---

## Daily Mode (Context-Driven, Fast)

### Step 1: Read Today's Daily Note

Compute today's date as `YYYY-MM-DD` and read:
`{vault_path}/memory/daily/YYYY-MM-DD.md`

If the file does not exist, report exactly:
`No daily note for today — run /observe first or use --weekly`
and exit without creating dream files.

From today's note, extract:
- dominant topics and categories
- key entities (people, tools, systems, projects)
- repeated themes, tensions, decisions, or open questions

### Step 2: Find Disparate Counterparts in Notes

For each extracted theme/entity, find 2-3 notes in `{vault_path}/notes/` that may contain structural parallels.

Selection requirements:
- Prefer notes from DIFFERENT topic maps than the originating daily context
- Maximize conceptual distance while preserving plausible mechanism overlap
- If `--domains` is provided, only search within those domains
- Use title + description first, then read full bodies for shortlisted candidates

Target sample count: default daily sample size is 3 pairs, or `--samples N` when provided.

### Step 3: Read and Compare

For each pair, read both source notes fully (daily-derived concept + candidate note). Then ask:

**"What structural parallel exists between these two ideas?"**

Think beyond surface similarity. Look for:
- **Shared mechanisms**: Do both describe the same underlying dynamic (even in different vocabulary)?
- **Analogous trade-offs**: Do both navigate the same fundamental tension?
- **Transferable solutions**: Could a technique from one domain solve a problem in the other?
- **Shared failure modes**: Do they fail in the same ways for the same reasons?
- **Scale invariance**: Does the same pattern repeat at different scales?

Not every pair will yield a connection. That's expected. Skip pairs where you can't find a genuine parallel — don't force connections.

### Step 4: Score by Novelty (Daily Threshold)

For each potential connection found, score its novelty (0.0-1.0):

| Score | Meaning |
|-------|---------|
| 0.9-1.0 | This connection does NOT exist in the graph. The two notes have no shared links or topic maps. |
| 0.7-0.8 | A weak indirect connection exists (shared topic map but no direct link). The parallel adds new meaning. |
| 0.4-0.6 | Some connection exists but this specific structural parallel is not articulated. |
| 0.1-0.3 | This connection is already captured — the notes link to each other or share analysis. |

**Only file speculations with novelty >= 0.5 in daily mode.**

### Step 5: File and Report

For each high-novelty speculation, create a file in `{vault_path}/memory/.dreams/`.
Use the same template format as weekly mode, but set `mode: daily`.

Report format (include mode line):

```
Mode used: daily
Dream Session
=============
Daily source: memory/daily/YYYY-MM-DD.md
Pairs sampled: N
Connections found: M
Filed (novelty >= 0.5): F
Skipped (low novelty): S
No connection: X

Speculations filed:
  - [brief description] (novelty: X.X) — [[note1]] <-> [[note2]]
  - ...

Pending dreams awaiting review: [total count in memory/.dreams/]
```

---

## Weekly Mode (Deep Structural Discovery)

### Step 1: Sample Notes

List all notes in `{vault_path}/notes/` (excluding topic maps / index files). Read their titles and descriptions (YAML frontmatter only — don't read full bodies yet).

If --domains specified, filter to notes whose `topics:` field includes the specified domains.

Randomly sample N pairs of notes, where each pair draws from DIFFERENT topic maps. Maximize domain distance — prefer pairing notes that share NO topic maps.

### Step 2: Read and Compare

For each pair, read both notes fully. Then ask:

**"What structural parallel exists between these two ideas?"**

Think beyond surface similarity. Look for:
- **Shared mechanisms**: Do both describe the same underlying dynamic (even in different vocabulary)?
- **Analogous trade-offs**: Do both navigate the same fundamental tension?
- **Transferable solutions**: Could a technique from one domain solve a problem in the other?
- **Shared failure modes**: Do they fail in the same ways for the same reasons?
- **Scale invariance**: Does the same pattern repeat at different scales?

Not every pair will yield a connection. That's expected. Skip pairs where you can't find a genuine parallel — don't force connections.

### Step 3: Score by Novelty

For each potential connection found, score its novelty (0.0-1.0):

| Score | Meaning |
|-------|---------|
| 0.9-1.0 | This connection does NOT exist in the graph. The two notes have no shared links or topic maps. |
| 0.7-0.8 | A weak indirect connection exists (shared topic map but no direct link). The parallel adds new meaning. |
| 0.4-0.6 | Some connection exists but this specific structural parallel is not articulated. |
| 0.1-0.3 | This connection is already captured — the notes link to each other or share analysis. |

**Only file speculations with novelty >= 0.6.**

### Step 4: File Speculations

For each high-novelty speculation, create a file in `{vault_path}/memory/.dreams/`:

Filename: `YYYY-MM-DD--brief-description.md`

```markdown
---
date: YYYY-MM-DD
mode: weekly
novelty: X.X
source_notes:
  - "[[note title 1]]"
  - "[[note title 2]]"
status: speculative
---

## Structural Parallel

[Describe the connection in 2-4 sentences. Be specific about the shared mechanism, trade-off, or pattern.]

## Why This Matters

[One sentence on what this connection enables or reveals that neither note captures alone.]

## If Validated

[One sentence on what insight this would become if promoted to notes/.]
```

### Step 5: Report

```
Mode used: weekly
Dream Session
=============
Pairs sampled: N
Connections found: M
Filed (novelty >= 0.6): F
Skipped (low novelty): S
No connection: X

Speculations filed:
  - [brief description] (novelty: X.X) — [[note1]] <-> [[note2]]
  - ...

Pending dreams awaiting review: [total count in memory/.dreams/]
```

---

Storage location is always: `{vault_path}/memory/.dreams/`.

---

## Periodic Review

When invoked with `--review`, instead of generating new speculations:

1. List all files in `{vault_path}/memory/.dreams/` with status: speculative
2. For each, re-evaluate in light of current knowledge graph
3. Mark as:
   - **promote** — create an inbox entry for /reduce processing
   - **keep** — still speculative, worth revisiting later
   - **discard** — no longer interesting or already captured

---

## Quality Gates

- Never force a connection — genuine parallels only
- Novelty scoring must check the actual graph (search for existing links between the two notes)
- Speculations must be specific enough to be testable — "these are kind of similar" is not a speculation
- The "If Validated" field must describe a concrete insight, not a vague observation
