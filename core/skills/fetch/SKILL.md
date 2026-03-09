---
name: fetch
version: "0.1.0"
description: Fetch a URL, analyze its content type, and save research-worthy material to inbox with full provenance. Handles articles, papers, PDFs, git repos, tweets, and other web content. Triggers on "/fetch <url>", any URL shared in conversation, "save this link", "capture this".
metadata:
  version: "1.0"
  argument-hint: "<url> [--force] — URL to fetch; --force saves even if not research-worthy"
  openclaw:
    emoji: "🔗"
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
- URL (required): the link to fetch
- `--force`: save to inbox even if content doesn't appear research-worthy
- `--dry-run`: analyze and report without saving

If no URL provided, check conversation context for recently shared links.

**START NOW.** Fetch and analyze the URL.

---

## Step 1: Validate URL

Confirm the target is a valid URL:
- Must start with `http://` or `https://`
- Must have a valid domain

If invalid:
```
ERROR: Invalid URL: {input}
Expected format: https://example.com/path
```

Extract URL metadata:
- **Domain**: e.g., `github.com`, `arxiv.org`, `twitter.com`
- **Path**: the URL path after domain
- **Query params**: if any

---

## Step 2: Detect Content Type (Pre-fetch)

Based on URL pattern, predict content type:

| Pattern | Predicted Type |
|---------|----------------|
| `github.com/{user}/{repo}` | Git repository |
| `github.com/{user}/{repo}/blob/` | Code file |
| `github.com/{user}/{repo}/issues/` | GitHub issue |
| `github.com/{user}/{repo}/pull/` | Pull request |
| `arxiv.org/abs/` or `arxiv.org/pdf/` | Academic paper |
| `twitter.com/` or `x.com/` | Tweet/thread |
| `youtube.com/watch` or `youtu.be/` | Video |
| `*.pdf` (path ends in .pdf) | PDF document |
| `news.ycombinator.com/item` | HN discussion |
| `reddit.com/r/*/comments/` | Reddit thread |
| `medium.com/`, `substack.com/` | Blog post |
| `docs.*`, `*/docs/*`, `*/documentation/*` | Documentation |
| Other | Article/webpage (default) |

This prediction guides fetching strategy but may be refined after content analysis.

---

## Step 3: Fetch Content

Use the appropriate fetching strategy based on predicted type:

### 3a. Standard Web Content (articles, blogs, docs)

Use `webfetch` or equivalent:
```
webfetch(url, format="markdown")
```

If the page appears JS-heavy (SPA indicators, empty content), fall back to browser automation if available.

### 3b. GitHub Repositories

For repo root URLs (`github.com/{user}/{repo}`):
1. Fetch README via raw URL or API
2. Extract: description, topics, language, stars (if available)
3. Note the repo structure from the page

For code files:
1. Fetch raw file content
2. Note the file path and language

### 3c. Academic Papers (arXiv, etc.)

1. Fetch the abstract page
2. Extract: title, authors, abstract, publication date
3. Note PDF link for reference (don't fetch full PDF unless requested)

### 3d. Twitter/X

1. Fetch the tweet/thread content
2. Extract: author, text, date, engagement metrics if visible
3. For threads, attempt to get full thread

### 3e. PDFs

1. Note that content is PDF
2. If PDF analysis tools available, extract text
3. Otherwise, save URL reference with PDF indicator

### 3f. YouTube/Video

1. Fetch page metadata (title, description, channel)
2. Note video URL
3. Do NOT attempt to transcribe (too expensive for default)

---

## Step 4: Analyze Content

After fetching, analyze the content to determine:

### 4a. Research Worthiness Score

Evaluate on these dimensions (0-1 each):

| Dimension | Indicators |
|-----------|------------|
| **Substance** | Length > 500 words, technical depth, citations/references |
| **Novelty** | New concepts, unique perspective, original research |
| **Actionability** | How-to content, implementation details, code examples |
| **Durability** | Evergreen vs news, fundamentals vs trends |

**Research-worthy threshold**: Average score >= 0.5 OR any single dimension >= 0.8

### 4b. Content Classification

Classify into one of:
- `article` — blog post, news article, essay
- `paper` — academic paper, research report
- `documentation` — API docs, guides, tutorials
- `repository` — code repo, project
- `discussion` — tweet, HN thread, Reddit post
- `reference` — specification, standard, RFC
- `media` — video, podcast (metadata only)
- `other` — doesn't fit above categories

### 4c. Key Information Extraction

Extract based on content type:

**For articles/papers:**
- Title
- Author(s)
- Publication date
- Key claims (2-5 bullet points)
- Topics/tags

**For repositories:**
- Name and description
- Primary language
- Key features
- README summary

**For discussions:**
- Original poster
- Main point/question
- Notable responses (if thread)

---

## Step 5: Research Worthiness Decision

If score >= threshold OR `--force` flag:
```
Content analysis:
  Type: {classification}
  Substance: {score}
  Novelty: {score}
  Actionability: {score}
  Durability: {score}
  Average: {avg_score}
  
Decision: SAVE to inbox
```

If score < threshold AND no `--force`:
```
Content analysis:
  Type: {classification}
  Substance: {score}
  Novelty: {score}
  Actionability: {score}
  Durability: {score}
  Average: {avg_score}
  
Decision: SKIP (below threshold)
Reason: {specific reason — e.g., "appears to be transient news", "too short", "promotional content"}

Use --force to save anyway.
```

If `--dry-run`, stop here and report analysis without saving.

---

## Step 6: Create Inbox Item

Generate a filename from the content:
```
{date}-{slugified-title}.md
```

Example: `2026-03-09-react-server-components-deep-dive.md`

### Inbox File Format

```markdown
---
source: {original URL}
fetched: {UTC timestamp}
type: {classification}
author: {author if known}
published: {publication date if known}
domain: {source domain}
scores:
  substance: {score}
  novelty: {score}
  actionability: {score}
  durability: {score}
---

# {Title}

> Source: {original URL}
> Fetched: {date} via /fetch

## Summary

{2-3 sentence summary of the content}

## Key Points

{extracted key claims/points as bullet list}

---

## Original Content

{full fetched content in markdown, preserving structure}

---

## Provenance

- **Source URL**: {original URL}
- **Fetched**: {timestamp}
- **Domain**: {domain}
- **Author**: {author if known}
- **Published**: {date if known}
```

### Why This Format

1. **YAML frontmatter** — enables programmatic filtering and search
2. **Source URL at top** — immediate provenance visibility
3. **Summary + Key Points** — quick reference without reading full content
4. **Original Content** — preserved for /reduce extraction
5. **Provenance footer** — redundant but ensures link survives any processing

---

## Step 7: Report

```
--=={ fetch }==--

URL: {original URL}
Type: {classification}
Title: {extracted title}

Analysis:
  Substance: {score} | Novelty: {score}
  Actionability: {score} | Durability: {score}
  Overall: {avg} — {RESEARCH-WORTHY | BELOW THRESHOLD}

{if saved}
Saved: inbox/{filename}
Size: {word count} words

Next steps:
  /seed inbox/{filename}     (queue for processing)
  /ingest                    (auto-process, runs hourly)
{/if}

{if skipped}
Skipped: {reason}
Use: /fetch {url} --force    (to save anyway)
{/if}
```

---

## Handling Edge Cases

### Paywalled Content

If content appears paywalled (login wall, subscription required):
1. Extract whatever is visible (title, preview, metadata)
2. Mark as `paywalled: true` in frontmatter
3. Save with available content + note about paywall
4. Suggest: "Full content behind paywall. Consider accessing directly and using /seed."

### Rate Limited / Blocked

If fetch fails due to rate limiting or blocking:
```
ERROR: Could not fetch {url}
Reason: {rate limited | blocked | timeout | connection error}

Suggestions:
- Try again later
- Use browser automation: open URL manually, then /seed the content
- Check if site requires authentication
```

### Very Long Content

If content exceeds 50,000 characters:
1. Save full content to inbox (don't truncate)
2. Note in report: "Large document ({N} words). /reduce will chunk automatically."

### Non-Text Content

For images, binaries, or unsupported formats:
```
Content type: {mime type}
This content type cannot be processed as text.

{if image}
Saved reference to: inbox/{filename}.md (metadata only)
{/if}

{if other}
Skipped: binary/unsupported content
{/if}
```

---

## Auto-Trigger Behavior

When the agent detects a URL in conversation (not explicitly via /fetch):

1. **Recognize the URL** — any http/https link shared by user
2. **Ask or infer intent**:
   - If user says "check this out", "look at this", "save this" → trigger /fetch
   - If URL is incidental (e.g., "I was reading X") → ask: "Want me to fetch and save this link?"
   - If in research context → proactively offer: "I can fetch this for your vault. Want me to?"

3. **Don't auto-fetch without consent** — URLs may be sensitive, paywalled, or irrelevant

---

## Integration with Other Skills

**→ /seed**: After /fetch saves to inbox, user can `/seed inbox/{file}` to queue for full processing

**→ /ingest**: Hourly /ingest will auto-seed fetched content and process through pipeline

**→ /learn**: When /learn finds relevant URLs during research, it can invoke /fetch internally to capture them

**→ /pipeline**: Full flow: `/fetch URL` → `/seed` (via /ingest) → `/reduce` → notes/

---

## Critical Constraints

**never:**
- Fetch URLs without user awareness (no silent background fetching)
- Store credentials or session tokens from fetched pages
- Attempt to bypass paywalls or authentication
- Fetch content that appears to be private/personal
- Truncate content when saving (preserve full text for /reduce)

**always:**
- Include source URL in saved content (multiple locations for redundancy)
- Preserve original structure when converting to markdown
- Report what was analyzed even if not saved
- Respect rate limits and site restrictions
- Ask before fetching if intent is ambiguous
