---
name: curiosity
description: Proactive research discovery — analyzes recent vault activity, generates research candidates, scores by expected information gain, auto-triggers /learn for high-value topics. Triggers on "/curiosity", "what should I research", "find research opportunities".
version: "1.0"
generated_from: "mnemos-v0.1"
user-invocable: true
context: fork
model: sonnet
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, mcp__exa__web_search_exa, mcp__exa__deep_researcher_start, mcp__exa__deep_researcher_check, WebSearch
argument-hint: "[--dry-run] [--threshold N] [--max N] — dry-run shows candidates without executing. threshold = EIG minimum (default: 0.7). max = maximum research triggers (default: 3)."
---
## Vault Path Resolution (mnemos)
Before any file operations, resolve the vault root:
1. Read `.mnemos.yaml` from the workspace root (the directory containing `.claude/`)
2. Extract `vault_path` — this is the root for ALL vault operations
3. All paths in this skill (notes/, ops/, memory/, self/) are RELATIVE to vault_path
4. If `.mnemos.yaml` does not exist or vault_path is not set, fall back to the current working directory

## EXECUTE NOW
`/curiosity` is an orchestrator.
- Finds high-value research opportunities from recent vault activity
- Scores opportunities by Expected Information Gain (EIG)
- Delegates execution to `/learn`
- Optionally fans out to config-defined extra sources

Parse `$ARGUMENTS` immediately:
- `--dry-run` (default: false)
- `--threshold N` (default: 0.7, clamp to 0.0-1.0)
- `--max N` (default: 3, clamp to 1-5)

Run this sequence:
1. Gather recent vault activity
2. Generate research candidates
3. Score by EIG
4. Execute selected queries via `/learn` (or dry-run)
5. Run `additional_sources` for top EIG candidates
6. Log to `ops/logs/curiosity-YYYY-MM-DD.md`
7. Update `self/goals.md` if new directions were discovered

START NOW.

---

## Step 0: Read Runtime Configuration
Read:
- `ops/config.yaml`
- `self/goals.md` (if exists)
- `ops/derivation-manifest.md` (optional)

Read `research` block from config:
```yaml
research:
  primary: exa-deep-research
  fallback: exa-web-search
  last_resort: web-search
  additional_sources:
    # - skill: /my-custom-search
    # - tool: mcp__reddit__search
    # - tool: mcp__github__search_repositories
```

Defaults if missing:
- `primary: exa-deep-research`
- `fallback: exa-web-search`
- `last_resort: web-search`
- `additional_sources: []`

Do not hard-depend on any single MCP source.

---

## Step 1: Gather Recent Activity
Window: last 3 days. If sparse, widen to 7 days.

Read and mine:
1. `memory/daily/` recent files
2. `notes/` recently modified files (git log preferred; mtime fallback)
3. `inbox/` pending captures
4. `self/goals.md`
5. `ops/observations/` and `ops/tensions/` if present

Extract structured signals:
- entities (tools, people, concepts)
- topics discussed
- decisions made
- open questions
- tensions/contradictions
- goal gaps (active goals with little recent supporting activity)

Signal format:
```yaml
- signal_type: entity | topic | decision | open-question | tension | goal-gap
  phrase: "literal phrase"
  canonical: "normalized lowercase key"
  source: "[[note title]]" or "memory/daily/YYYY-MM-DD.md"
  evidence: "short evidence snippet"
```

If total useful signals < 3, expand to 7 days and re-extract.

---

## Step 2: Generate Research Candidates
Generate 5-10 candidates per run.

Category patterns:
| Category | Query Pattern | Example |
|----------|---------------|---------|
| tool-deep-dive | How do others use [tool] in [context]? | ast-grep patterns for large-scale refactoring |
| alternative-discovery | Alternatives to [tool/approach] for [use case] | Alternatives to ripgrep for semantic code search |
| concept-expansion | [concept] recent developments | MCP protocol ecosystem 2026 |
| implementation-patterns | Production [technique] implementation examples | Production knowledge graph maintenance patterns |
| validation | Evidence for/against [claim] | Evidence for atomic notes improving retrieval |
| open-question | Direct research on unresolved questions | from daily or ops notes |

Candidate schema:
```yaml
query: "actual query"
category: tool-deep-dive | alternative-discovery | concept-expansion | implementation-patterns | validation | open-question
source: "[[source note]]"
rationale: "1 sentence explaining expected value"
eig_score: 0.0-1.0
novelty: 0.0-1.0
relevance: 0.0-1.0
actionability: 0.0-1.0
connectivity: 0.0-1.0
timeliness: 0.0-1.0
status: pending
```

Candidate requirements:
- each candidate must have concrete rationale
- rationale must name likely decision/process impact
- source must map to a vault item

Deduplicate candidates:
- remove exact duplicates in the same run
- remove near-duplicates with same intent
- remove queries that duplicate recent `/learn` runs in `ops/logs/` (last 7 days)

If candidates < 3 after dedup:
1. broaden activity window to 7 days
2. re-mine signals
3. regenerate to minimum 3 candidates

---

## Step 3: Score by Expected Information Gain (EIG)
Scoring factors:

| Factor | Weight | High Score (0.8-1.0) | Low Score (0.1-0.3) |
|--------|--------|----------------------|---------------------|
| Novelty | 0.3 | No existing notes on this topic | Already well-covered in vault |
| Relevance | 0.25 | Directly relates to active goals | Tangential to current work |
| Actionability | 0.2 | Would change a decision or approach | Purely academic interest |
| Connectivity | 0.15 | Would link to 3+ existing notes | Isolated topic |
| Timeliness | 0.1 | Recent development, evolving fast | Stable/settled topic |

Formula:
```text
eig_score = (novelty * 0.3) + (relevance * 0.25) + (actionability * 0.2) + (connectivity * 0.15) + (timeliness * 0.1)
```

Novelty procedure (mandatory vault check):
1. extract 2-5 keywords from candidate query
2. grep/search `notes/` for coverage
3. map rough coverage to novelty:
   - 0 hits => 0.9-1.0
   - 1-2 related notes => 0.6-0.8
   - 3-5 related notes => 0.3-0.6
   - 6+ related notes => 0.1-0.3
4. downscore if recent `/learn` covered near-identical query

Factor guidance:
- relevance: goal alignment high/medium/low
- actionability: likely decision impact
- connectivity: likely links to 3+ existing notes
- timeliness: change velocity in the ecosystem

Scoring rules:
- clamp all factors to `[0.0, 1.0]`
- round displayed `eig_score` to 2 decimals
- keep raw factor scores in log

---

## Step 4: Execute Research (or Dry Run)
If `--dry-run`:
- skip execution
- mark all candidates `status: dry-run`
- still log candidates, scores, and skip reasons

Otherwise:
1. sort by EIG descending
2. filter to `eig_score >= threshold`
3. take top `max` candidates (hard cap: 5)
4. invoke `/learn [query]` for each selected candidate
5. track execution results and inbox artifacts

Status values:
- `executed`
- `skipped-below-threshold`
- `skipped-duplicate`
- `failed-learn`
- `dry-run`

Failure behavior:
- if one `/learn` call fails, continue remaining candidates
- record failure details in log

Critical constraint:
- do not execute direct research tools in `/curiosity`
- always delegate to `/learn`

---

## Step 5: Pluggable Additional Research Sources
After `/learn`, process `research.additional_sources`.

Run only for candidates with `eig_score >= 0.85`.

Source handling:
- if entry is `skill`, invoke `[skill] [query]`
- if entry is `tool`, invoke with `{ query: "[query]" }`

Behavior constraints:
- never hardcode source/tool names
- skip unavailable source and continue
- keep `/learn` as primary orchestrated path

Provenance for additional-source outputs filed to `inbox/`:
```yaml
source_type: additional-source
source_name: "configured source id"
research_prompt: "query string"
generated: "YYYY-MM-DDTHH:MM:SSZ"
origin: "/curiosity"
linked_candidate: "query string"
```

If the additional source already files its own artifact, do not duplicate.

---

## Step 6: Log and Report
Write or append to: `ops/logs/curiosity-YYYY-MM-DD.md`

Log frontmatter:
```markdown
---
date: YYYY-MM-DD
candidates_generated: N
candidates_executed: M
candidates_skipped: S
threshold: 0.7
---
```

Required sections:
```markdown
## Candidates

| # | Query | Category | EIG | Status | Source |
|---|-------|----------|-----|--------|--------|
| 1 | ... | tool-deep-dive | 0.85 | executed | [[daily note ref]] |
| 2 | ... | concept-expansion | 0.72 | executed | [[insight ref]] |
| 3 | ... | alternative-discovery | 0.45 | skipped (below threshold) | [[goal ref]] |

## Executed Research
- [query 1] → filed to inbox/YYYY-MM-DD-slugified.md
- [query 2] → filed to inbox/YYYY-MM-DD-slugified.md

## Skipped (Below Threshold)
- [query 3] (0.45) — rationale

## Scoring Detail
| Query | novelty | relevance | actionability | connectivity | timeliness |
|-------|---------|-----------|---------------|--------------|------------|
| ...   | 0.8     | 0.7       | 0.9           | 0.6          | 0.8        |
```

Also include:
- duplicate-skipped candidates
- failed `/learn` candidates with short error reason

---

## Step 7: Update goals.md
If executed research reveals meaningful new directions:
1. read `self/goals.md`
2. preserve existing format
3. append:
```markdown
- [New direction] (discovered via /curiosity, EIG: X.X)
```

Update rules:
- append only novel, actionable directions; skip duplicates; skip silently if goals file missing

---

## Output Summary
Return:
```text
Curiosity
=========
Activity scanned: N daily notes, M recent insights
Candidates generated: X
Executed (EIG >= threshold): Y
  - [query] (EIG: 0.85) → inbox/filename.md
  - [query] (EIG: 0.72) → inbox/filename.md
Skipped (below threshold): Z
Dry run: [yes/no]

Next: Process inbox items with /seed → /reduce
```

## Quality Gates (Mandatory)
1. Never duplicate recent `/learn` research (check `ops/logs/`)
2. Generate at least 3 candidates per run
3. Never execute more than 5 research triggers per run
4. Every candidate must have clear rationale and source
5. EIG novelty must use real vault coverage checks

On gate failure, broaden window and regenerate; if still constrained, continue partial execution and log what failed.

---

## Error Handling
| Error | Behavior |
|-------|----------|
| missing `memory/daily/` | continue with other sources |
| missing `self/goals.md` | score relevance from activity only |
| missing `ops/config.yaml` | use defaults |
| missing `ops/logs/` | create log directory/file |
| `/learn` failure | mark failed, continue |
| additional source unavailable | skip source, log warning |
| no candidate passes threshold | execute none, report skipped |

Never hard-fail unless all core sources are unreadable.

---

## MUST NOT
- Do NOT implement research execution directly; delegate to `/learn`
- Do NOT duplicate `/learn` Exa/web-search cascade logic
- Do NOT create hard dependency on a specific MCP server
- Do NOT hardcode custom additional source names
- Do NOT exceed 5 research triggers per run
