---
name: observe
description: Compress session context into typed observations with importance, confidence, and surprise scores. Routes observations to daily logs. Triggers on "/observe", "capture observations", "what did I learn".
version: "1.0"
generated_from: "mnemos-v0.1"
user-invocable: true
context: fork
model: sonnet
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
argument-hint: "[session-context] — optional: specific context to observe. Without arguments, observes the current session."
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

You are the working memory engine. Your job is to compress the current session's significant moments into typed observations — capturing not just WHAT happened but WHY it mattered and WHAT was surprising.

### Step 1: Gather Context

If arguments provided, use them as the session context to observe.

If no arguments, review the current conversation for:
- Insights — claims, lessons, findings (especially from failures or unexpected outcomes)
- Patterns — recurring themes, structural parallels across domains
- Workflows — processes, techniques, procedures discovered or refined
- Tools — software, libraries, frameworks evaluated or used
- People — collaborators, stakeholders, contacts and their preferences
- Decisions — choices made and their reasoning/tradeoffs
- Open questions — unknowns worth investigating, research directions
- Anything that contradicted your existing understanding (HIGH SURPRISE)

### Step 2: Generate Typed Observations

For each significant observation, produce a structured entry:

```
- [TYPE|i=X.X|c=X.X|s=X.X] OBSERVATION TEXT
```

Where:
- **TYPE**: One of `insight`, `pattern`, `workflow`, `tool`, `person`, `decision`, `open-question`
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

Reference types (tool, person, decision, open-question) are auto-promoted to `notes/` by `/consolidate` — they don't need high importance scores to be preserved.

**Scoring Guidelines:**

| Score | Importance | Confidence | Surprise |
|-------|-----------|------------|----------|
| 0.9-1.0 | Critical to mission/goals | Verified through multiple signals | Completely overturns prior understanding |
| 0.7-0.8 | Significant, affects decisions | Strong evidence, single source | Meaningfully extends or challenges model |
| 0.4-0.6 | Useful context | Reasonable inference | Minor adjustment to expectations |
| 0.1-0.3 | Nice to know | Speculation or hearsay | Expected, confirms existing model |

**Err toward capturing more, not less.** The consolidation bridge filters later. Working memory should be comprehensive.

### Step 3: Tag Co-occurrences

Before writing, scan your observations for entities that appeared together in the same context:
- If a person and a tool appear in the same conversation/event, note it: `@co: person, tool`
- If a decision references a specific tool or person, note it: `@co: decision, tool`

Add co-occurrence tags at the end of observations when relevant:

```
- [person|i=0.5|c=0.9|s=0.2] John recommended ast-grep for the migration @co: tool:ast-grep
- [tool|i=0.6|c=0.8|s=0.4] ast-grep supports structural search across 25 languages @co: person:John
```

These tags help `/consolidate` create wiki-links between reference notes during promotion.

### Step 4: Route to Daily Log

Append observations to `{vault_path}/memory/daily/YYYY-MM-DD.md` (today's date).

If the file doesn't exist, create it with this header:

```markdown
# YYYY-MM-DD

## Observations

```

Append each observation under the `## Observations` section. Group by type if there are 5+ observations.

### Step 5: Update MEMORY.md (if significant)

If any observation has importance >= 0.8 or surprise >= 0.7, read the current `{vault_path}/memory/MEMORY.md` and assess whether it needs updating. Only update if the new observations materially change the agent's current context.

### Step 6: Report

Output a summary:
```
Observations captured: N
  - insights: X
  - patterns: X
  - workflows: X
  - tools: X
  - people: X
  - decisions: X
  - open-questions: X

Reference types (auto-promote): X (tool, person, decision, open-question)
Full pipeline (threshold): X (insight, pattern, workflow)
Co-occurrences tagged: X

High-importance (>=0.8): [list if any]
High-surprise (>=0.7): [list if any]

Stored: {vault_path}/memory/daily/YYYY-MM-DD.md
```

---

## Quality Gates

- Each observation must be a COMPLETE thought — not a fragment
- Surprise scoring must be honest — most things are NOT surprising (s=0.1-0.3)
- Importance must reflect actual significance, not how interesting something is
- Observations must be self-contained — readable without the full session context
