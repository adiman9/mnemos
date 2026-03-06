---
name: enrich
description: Add content from a new source to an existing note. Updates the note body with new evidence, examples, or framing, and maintains multi-source attribution in the footer. Triggers on "/enrich", "/enrich [note]", "enrich this note".
version: "1.0"
generated_from: "mnemos-v0.1"
user-invocable: true
context: fork
model: sonnet
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
argument-hint: "[note] [--handoff] — note to enrich (or task file context provides this)"
---

## Vault Path Resolution (mnemos)

Before any file operations, resolve the vault root:
1. Read `.mnemos.yaml` from the workspace root (the directory containing `.claude/`)
2. Extract `vault_path` — this is the root for ALL vault operations
3. All paths in this skill (notes/, ops/, inbox/, self/, memory/, templates/) are RELATIVE to vault_path
4. If `.mnemos.yaml` does not exist or vault_path is not set, fall back to the current working directory

Example: if vault_path is `/data/vault`, then `ops/queue/queue.json` resolves to `/data/vault/ops/queue/queue.json`.

---

## EXECUTE NOW

**Target: $ARGUMENTS**

Parse immediately:
- If invoked via `/ralph` with a task file: read the task file for `target_note`, `addition`, `source_task`, and `source_lines`
- If invoked directly with a note name: ask what to add and from which source
- If `--handoff` present: output RALPH HANDOFF block at end

**Steps:**

1. Read the enrichment task file (if pipeline) or identify the target note and source
2. Read the existing note fully — understand its current claim, body, sources
3. Read the source material at the specified lines
4. Integrate new content into the existing note
5. Update the source attribution footer (singular → plural if needed)
6. Detect post-enrich structural issues (title drift, split candidates, merge candidates)
7. Update the task file's `## Enrich` section
8. Report what changed

**START NOW.** Reference below explains methodology.

---

## Step 1: Read Context

### Pipeline invocation (via /ralph)

The task file at `ops/queue/{FILE}` contains:

```yaml
---
type: enrichment
target_note: "[[existing note title]]"
source_task: [source-basename]
addition: "what to add from source"
source_lines: "NNN-NNN"
---
```

Extract:
- **target_note**: the note to enrich (resolve to `{vault_path}/notes/{title}.md`)
- **source_task**: which source batch this enrichment came from
- **addition**: what /reduce determined should be added
- **source_lines**: where in the source the enrichment content lives
- **source file**: find via `ops/queue/{source_task}.md` → read its `source:` field

### Direct invocation

If invoked as `/enrich [[note title]]`:
1. Read the target note
2. Ask: "What should be added? From which source?"
3. Proceed with the provided context

---

## Step 2: Read the Existing Note

Read `notes/{target_note}.md` fully. Understand:

- **Current claim** (title): what the note argues
- **Current body**: reasoning, evidence, examples
- **Current sources**: check the footer for `Source:` (singular) or `Sources:` (plural)
- **Current connections**: wiki-links in body and Relevant Notes footer

**Parse the existing source attribution:**

| Footer pattern | State | Meaning |
|----------------|-------|---------|
| `Source: [[article-a]]` | single source | Note created from one source |
| `Sources:` with bullet list | multiple sources | Note already enriched before |
| No source line | missing | Legacy note or manual creation |

---

## Step 3: Read the Source Material

Locate the source file:
1. Read the enrichment task file's `source_task` field
2. Find the extract task file: `ops/queue/{source_task}.md`
3. Read its `source:` field to get the source file path
4. Read the source file at the specified `source_lines` range

If source_lines is not specified, read the full source and find the relevant content based on the `addition` description.

---

## Step 4: Integrate Content

This is the core judgment step. You are adding value to an existing note, not appending raw text.

### Integration Strategies

| What the source adds | How to integrate |
|----------------------|-----------------|
| New examples | Add to body where the relevant argument is made |
| Deeper framing | Strengthen the reasoning section |
| Citations/evidence | Add as supporting evidence with inline source reference |
| Different angle | Add a new paragraph that extends the argument |
| Concrete implementation details | Add specifics that ground the abstract claim |
| Counterargument or nuance | Add acknowledgment of the limitation or condition |

### Integration Rules

**DO:**
- Weave new content into the existing argument flow
- Use inline wiki-links to the source: `as [[source-article]] demonstrates, ...`
- Preserve the original claim — enrichment adds depth, not direction change
- Maintain the note's voice and style
- Keep body length reasonable (aim for 150-600 words total after enrichment)

**DO NOT:**
- Append a raw "Additional from source B" section (this is not integration)
- Change the title claim (flag for title-sharpen instead)
- Rewrite the entire note (enrichment is additive, not replacement)
- Duplicate content already present (check before adding)

### When Content Doesn't Fit

Sometimes the enrichment task was created by /reduce but the content doesn't actually improve the note. This is fine.

| Situation | Action |
|-----------|--------|
| Content is truly redundant | Skip integration, note in task file: "No new content to add" |
| Content contradicts the claim | Don't integrate — create a tension note instead, flag for /reweave |
| Content belongs in a different note | Redirect: note which note should receive it |
| Content suggests the note should split | Flag `post_enrich_action: split-recommended` |

---

## Step 5: Update Source Attribution

This is the critical provenance step. After integrating content, update the footer to reflect all sources.

### Transition: Singular → Plural

**Before enrichment (single source):**
```markdown
---

Source: [[article-a]]

Relevant Notes:
...
```

**After enrichment (multiple sources):**
```markdown
---

Sources:
- [[article-a]] -- original extraction
- [[article-b]] -- enriched with deeper framing on X

Relevant Notes:
...
```

### Rules

1. **First enrichment**: Convert `Source: [[X]]` to `Sources:` list with two entries
2. **Subsequent enrichments**: Append to existing `Sources:` list
3. **Each entry must have a context phrase**: what the source contributed (not just the link)
4. **Original source is always first**: mark with `-- original extraction`
5. **YAML `source` field**: keep as the original/primary source (don't change it)
6. **If no existing Source line**: create the `Sources:` list with only the new source

### Context Phrases for Source Entries

Use specific descriptions of what each source contributed:

Good:
- `-- original extraction`
- `-- enriched with empirical evidence on latency thresholds`
- `-- added cross-chain comparison examples`
- `-- provided counterargument about scale limits`

Bad:
- `-- enriched` (what was enriched?)
- `-- related` (not a description of contribution)
- `-- see also` (not a provenance record)

---

## Step 6: Detect Structural Issues

After integration, evaluate whether the note still holds together structurally.

### Title Drift

Does the note's claim (title) still accurately represent the body after enrichment?

| Check | Signal | Action |
|-------|--------|--------|
| Title still matches body | No drift | Continue |
| Title is now too narrow | Enrichment broadened scope | Set `post_enrich_action: title-sharpen` |
| Title is now too broad | Enrichment added specifics that narrow the real claim | Set `post_enrich_action: title-sharpen` |

### Split Detection

Does the note now cover multiple distinct claims?

| Check | Signal | Action |
|-------|--------|--------|
| One coherent argument | No split needed | Continue |
| Two distinct claims | Body has two separable arguments | Set `post_enrich_action: split-recommended` |
| Significant overlap with another note | Enrichment made them converge | Set `post_enrich_action: merge-candidate` |

### Setting Post-Enrich Actions

Write these to the task file so /reweave can act on them:

```yaml
post_enrich_action: title-sharpen | split-recommended | merge-candidate | none
post_enrich_detail: "[specific recommendation]"
```

---

## Step 7: Update Task File

Fill in the `## Enrich` section of the task file:

```markdown
## Enrich

**Target:** [[note title]]
**Source:** [[source file]] (lines NNN-NNN)

**Integration:**
- Added: [what was integrated and where in the body]
- Source attribution: updated to multi-source format (N sources total)

**Structural Assessment:**
- Title drift: none | detected (post_enrich_action set)
- Split candidate: no | yes (post_enrich_action set)
- Merge candidate: no | yes (post_enrich_action set)

**Post-enrich actions:** none | title-sharpen | split-recommended | merge-candidate
```

---

## Step 8: Report

```
--=={ enrich }==--

Target: [[note title]]
Source: [[source file]] (lines NNN-NNN)

Integration:
  Added: [brief description of what was integrated]
  Body: [word count before] -> [word count after]
  Sources: [count] (was [previous count])

Structural flags:
  [post_enrich_action or "none"]

Next: /reflect [[note title]] (find connections for enriched content)
```

---

## Handoff Mode (--handoff flag)

When invoked with `--handoff`, output this at the END:

```
=== RALPH HANDOFF: enrich ===
Target: [[note title]]

Work Done:
- Enriched [[note title]] with content from [[source file]]
- Source attribution: [singular -> plural | added to existing plural] ([N] sources total)
- Body: [word count before] -> [word count after] words
- Post-enrich actions: [action or NONE]

Files Modified:
- notes/[note title].md (body updated, source footer updated)
- ops/queue/[task file] (Enrich section filled)

Learnings:
- [Friction]: [description] | NONE
- [Surprise]: [description] | NONE
- [Methodology]: [description] | NONE
- [Process gap]: [description] | NONE

Queue Updates:
- Advance phase: enrich -> reflect
- Post-enrich signals: [action] for /reweave | NONE
=== END HANDOFF ===
```

---

## Quality Gates

### Gate 1: Content Actually Integrated

The note body must have changed. If the enrichment adds nothing new, document why in the task file but don't force content in.

### Gate 2: Source Attribution Updated

After enrichment, the footer MUST reflect all contributing sources. A note enriched from two articles must list both. This is the provenance guarantee — every source that contributed content is traceable.

### Gate 3: No Claim Drift Without Flag

If the enrichment changed what the note argues (not just how deeply), a `post_enrich_action` must be set. The title should still be accurate after enrichment.

### Gate 4: Integration Quality

New content must be woven into the argument, not bolted on. Read the full note after editing — does it flow as a coherent piece? Would a reader know where the original ends and enrichment begins? They shouldn't.

---

## Critical Constraints

**Never:**
- Change the note's title claim without setting post_enrich_action
- Append raw source text without integration
- Remove existing source attribution (always additive)
- Skip the source footer update (provenance is non-negotiable)
- Auto-merge or auto-delete notes (flag for human review)

**Always:**
- Read the full existing note before modifying
- Integrate content into the argument flow
- Update source attribution with context phrases
- Detect and flag structural issues
- Preserve the original source as first in the list
