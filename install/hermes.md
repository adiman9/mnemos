# mnemos for Hermes — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. Use the tool calls as shown.

---

## Overview

You will install:
- **Hook** (`~/.hermes/hooks/mnemos/`) — Captures session transcripts
- **Skills** — /observe, /consolidate, /recall for knowledge management  
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **Cron** — Daily maintenance jobs

Hermes's native memory (MEMORY.md/USER.md) handles quick notes. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Create the Hook

### 1.1 Create the hook directory and HOOK.yaml

```python
write_file(
    path=os.path.expanduser("~/.hermes/hooks/mnemos/HOOK.yaml"),
    content="""name: mnemos
description: Capture sessions for long-term knowledge synthesis
events:
  - gateway:startup
  - agent:end
  - session:reset
"""
)
```

### 1.2 Create handler.py

```python
write_file(
    path=os.path.expanduser("~/.hermes/hooks/mnemos/handler.py"),
    content='''"""
mnemos hook handler — captures session transcripts to vault.

Events:
  gateway:startup  → Initialize vault structure
  agent:end        → Capture assistant response
  session:reset    → Mark session boundary
"""

import json
import os
from pathlib import Path
from datetime import datetime

VAULT = Path(os.getenv("MNEMOS_VAULT", Path.home() / ".mnemos" / "vault"))


async def handle(event_type: str, context: dict):
    """Route Hermes events to mnemos operations."""
    try:
        if event_type == "gateway:startup":
            _ensure_vault()
            print("[mnemos] Vault initialized at", VAULT)
        elif event_type == "agent:end":
            _capture_turn(context)
        elif event_type == "session:reset":
            _mark_session_boundary(context)
    except Exception as e:
        print(f"[mnemos] Hook error: {e}")


def _ensure_vault():
    """Initialize vault directory structure."""
    dirs = [
        "self",
        "notes", 
        "memory/daily",
        "memory/sessions",
        "memory/.dreams",
        "ops/queue",
        "ops/logs",
        "inbox",
        "templates",
    ]
    for d in dirs:
        (VAULT / d).mkdir(parents=True, exist_ok=True)
    
    # Create default identity file
    identity = VAULT / "self/identity.md"
    if not identity.exists():
        identity.write_text("""# Identity

Who you are and how you work. Update as you develop preferences.

## Core Identity

[Describe your role and working style]

## Working Preferences

[Capture preferences discovered through experience]
""")
    
    # Create default goals file
    goals = VAULT / "self/goals.md"
    if not goals.exists():
        goals.write_text("""# Goals

## Active

[Current objectives]

## Completed

[Recently finished]

## Parked

[On hold — with reason]
""")
    
    # Create boot context file
    memory = VAULT / "memory/MEMORY.md"
    if not memory.exists():
        memory.write_text("""# Memory Boot Context

No observations yet. Run /observe after a few sessions to begin capturing insights.
""")


def _capture_turn(context: dict):
    """Append assistant turn to session transcript."""
    session_id = context.get("session_id", f"hermes-{datetime.now().strftime('%Y%m%d')}")
    response = context.get("response", "")
    
    if not response:
        return
    
    sessions_dir = VAULT / "memory/sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)
    
    output = sessions_dir / f"{session_id}.jsonl"
    
    entry = {
        "ts": datetime.utcnow().isoformat() + "Z",
        "role": "assistant",
        "content": response[:5000],  # Truncate very long responses
        "session_id": session_id,
    }
    
    with open(output, "a") as f:
        f.write(json.dumps(entry) + "\\n")


def _mark_session_boundary(context: dict):
    """Mark session boundary for observation extraction."""
    session_key = context.get("session_key", "")
    sessions_dir = VAULT / "memory/sessions"
    
    if session_key:
        boundary_file = sessions_dir / ".boundaries"
        with open(boundary_file, "a") as f:
            f.write(f"{datetime.utcnow().isoformat()}Z {session_key}\\n")
'''
)
```

---

## Step 2: Initialize the Vault

Create the vault directory structure:

```python
import os
from pathlib import Path

vault = Path(os.path.expanduser("~/.mnemos/vault"))

# Create all directories
for subdir in ["self", "notes", "memory/daily", "memory/sessions", 
               "memory/.dreams", "ops/queue", "ops/logs", "inbox", "templates"]:
    (vault / subdir).mkdir(parents=True, exist_ok=True)
```

### 2.1 Create identity.md

```python
write_file(
    path=os.path.expanduser("~/.mnemos/vault/self/identity.md"),
    content="""# Identity

Who you are and how you work. Update as you develop preferences.

## Core Identity

[Describe your role and working style]

## Working Preferences

[Capture preferences discovered through experience]
"""
)
```

### 2.2 Create goals.md

```python
write_file(
    path=os.path.expanduser("~/.mnemos/vault/self/goals.md"),
    content="""# Goals

## Active

[Current objectives]

## Completed

[Recently finished]

## Parked

[On hold — with reason]
"""
)
```

### 2.3 Create MEMORY.md

```python
write_file(
    path=os.path.expanduser("~/.mnemos/vault/memory/MEMORY.md"),
    content="""# Memory Boot Context

No observations yet. Run /observe after a few sessions to begin capturing insights.

## Recent Activity

[Will be populated by /observe]

## Active Topics

[Will emerge as notes/ grows]
"""
)
```

### 2.4 Create config.yaml

```python
write_file(
    path=os.path.expanduser("~/.mnemos/vault/ops/config.yaml"),
    content="""# mnemos vault configuration

processing:
  depth: standard
  chaining: suggested
  extraction:
    selectivity: moderate

maintenance:
  orphan_threshold: 1
  topic_map_max: 40
  inbox_stale_days: 3

# Observation thresholds for promotion
promotion:
  importance_threshold: 0.8
  surprise_threshold: 0.7
  frequency_threshold: 2
"""
)
```

---

## Step 3: Create Core Skills

### 3.1 Create /observe skill

```python
skill_manage(
    action="create",
    name="observe",
    category="mnemos",
    content='''---
name: observe
description: Extract typed observations from recent session transcripts
triggers:
  - /observe
  - extract observations
  - what did I learn today
---

# Observe — Extract Learning from Sessions

Read recent session transcripts and extract typed observations.

## When to Run

- After significant work sessions
- Daily via cron job
- When asked "what did I learn?"

## Process

1. **Find transcripts**: Read `~/.mnemos/vault/memory/sessions/*.jsonl`
2. **Identify sessions**: Focus on files modified in last 24 hours (or since last /observe)
3. **Extract observations**: For each significant exchange, create an observation

## Observation Schema

For each insight worth remembering, extract:

```yaml
- type: insight | pattern | workflow | tool | person | decision | open-question
  importance: 0.0-1.0   # How valuable is this knowledge?
  confidence: 0.0-1.0   # How certain are you?
  surprise: 0.0-1.0     # How unexpected was this?
  content: "Concise description of the observation"
  co: ["type:name"]     # Co-occurring entities (optional)
```

### Type Definitions

| Type | Description | Example |
|------|-------------|---------|
| `insight` | A claim or lesson learned | "Hermes hooks cannot return data to modify prompts" |
| `pattern` | A recurring theme or structure | "Users often ask for X before Y" |
| `workflow` | A process or technique | "Debug by checking logs first, then state" |
| `tool` | Software, library, framework | "ast-grep supports 25 languages" |
| `person` | Someone and their context | "Adrian prefers terse communication" |
| `decision` | A choice and its reasoning | "Chose SQLite over Postgres for simplicity" |
| `open-question` | An unknown worth investigating | "Why does context compression lose tool results?" |

## Output

Append observations to `~/.mnemos/vault/memory/daily/YYYY-MM-DD.md`:

```markdown
# Observations — 2024-01-15

## Session: hermes-20240115-abc123

- type: insight
  importance: 0.8
  confidence: 0.9
  surprise: 0.6
  content: "Hermes hooks fire async and cannot inject into system prompts"
  co: ["tool:hermes", "pattern:fire-and-forget"]

- type: tool
  importance: 0.7
  confidence: 1.0
  surprise: 0.3
  content: "skill_manage tool can create skills programmatically"
  co: ["tool:hermes"]
```

## Skip

- Trivial Q&A exchanges
- Information you already captured
- Temporary/session-specific details
'''
)
```

### 3.2 Create /consolidate skill

```python
skill_manage(
    action="create",
    name="consolidate",
    category="mnemos",
    content='''---
name: consolidate
description: Promote observations to permanent notes via dual-path routing
triggers:
  - /consolidate
  - promote observations
  - process daily notes
---

# Consolidate — Observation to Knowledge

Promote observations from daily logs to permanent notes in the knowledge graph.

## When to Run

- Daily via cron (after /observe)
- When daily logs accumulate
- Before weekly synthesis

## Dual-Path Routing

### Reference Path (auto-promote)

**Types**: `person`, `tool`, `decision`, `open-question`

These are reference data — promote ALL of them directly:

1. Create note in `~/.mnemos/vault/notes/` with filename from content
2. Wire wiki-links from co-occurrence tags
3. No threshold filtering — if observed, it's worth noting

### Pipeline Path (threshold-based)

**Types**: `insight`, `pattern`, `workflow`

These need filtering — promote when ANY condition holds:
- `importance >= 0.8`
- `surprise >= 0.7`  
- `frequency >= 2` AND `importance >= 0.4`

## Note Format

Create files in `~/.mnemos/vault/notes/`:

```markdown
---
description: One sentence expanding on the title
topics: []  # Will be filled by /reflect
source: "observation 2024-01-15"
confidence: supported | likely | experimental
category: insight | pattern | workflow | tool | person | decision | open-question
created: 2024-01-15
---

The actual content of the note. Use [[wiki-links]] to connect to related notes.

## Context

Where this came from and why it matters.

## Related

- [[other-note]] — how it relates
```

## Filename Convention

Use the observation content as a prose title:
- "hermes hooks cannot inject into prompts.md"
- "adrian prefers terse communication.md"
- "ast-grep supports 25 languages.md"

Lowercase, hyphens for spaces, `.md` extension.

## Process

1. Read `~/.mnemos/vault/memory/daily/*.md` for unprocessed observations
2. Route each observation by type (reference vs pipeline path)
3. Check promotion thresholds for pipeline types
4. Create note files with proper frontmatter
5. Mark observations as processed (add `promoted: true`)
'''
)
```

### 3.3 Create /recall skill

```python
skill_manage(
    action="create",
    name="recall",
    category="mnemos",
    content='''---
name: recall
description: Search vault for relevant knowledge
triggers:
  - /recall
  - what do I know about
  - search memory
  - remember
---

# Recall — Query the Knowledge Vault

Search mnemos vault for relevant knowledge on a topic.

## Usage

```
/recall [topic or question]
```

## Search Strategy

### 1. Notes Search (Primary)

Search `~/.mnemos/vault/notes/` for matching content:
- Filename/title match (highest weight)
- Content match
- Wiki-link traversal from matches

### 2. Recent Observations

Search `~/.mnemos/vault/memory/daily/` for last 7 days:
- Observations that haven't been promoted yet
- May contain fresher information

### 3. Topic Maps

If notes exist, check for topic map files that cluster related knowledge.

## Output Format

Return relevant excerpts with source attribution:

```
## Found in vault:

### From notes/hermes-hooks-cannot-inject.md
> Hermes hooks fire async and cannot return data. Use file-based 
> injection (SOUL.md, AGENTS.md) instead.

### From memory/daily/2024-01-15.md (not yet promoted)
> - type: insight
>   content: "skill_manage can create skills programmatically"

### Related notes (via wiki-links):
- [[hermes-skill-system]]
- [[agent-self-modification]]
```

## No Results

If nothing found:
1. Suggest related searches
2. Offer to research the topic (if /learn skill exists)
3. Note the gap for future capture
'''
)
```

### 3.4 Create /dream skill (optional but recommended)

```python
skill_manage(
    action="create",
    name="dream",
    category="mnemos",
    content='''---
name: dream
description: Generate speculative cross-domain connections
triggers:
  - /dream
  - find connections
  - what patterns do you see
---

# Dream — Speculative Pattern Discovery

Generate hypothetical connections between distant topics in the vault.

## Modes

### Daily Mode (`/dream --daily`)

Context-driven speculation:
1. Read today's observations from `~/.mnemos/vault/memory/daily/`
2. Find 2-3 structural parallels with existing notes
3. Generate hypotheses connecting today's work to past knowledge

### Weekly Mode (`/dream --weekly`)

Discovery-driven speculation:
1. Randomly sample 5 note pairs from different topic areas
2. Look for structural parallels (not surface similarity)
3. Generate novel hypotheses

## Output

Write speculations to `~/.mnemos/vault/memory/.dreams/`:

```markdown
# Dream — 2024-01-15

## Speculation 1

**Parallel**: The "frozen snapshot" pattern in Hermes memory resembles 
immutable infrastructure principles.

**Hypothesis**: Memory systems benefit from treating context as immutable 
deployments rather than mutable state.

**Novelty**: 0.7
**Relevance**: 0.8
**Action**: Consider applying blue-green deployment thinking to context management.

## Speculation 2
...
```

## Promotion

High-value speculations (novelty > 0.6, relevance > 0.7) can be promoted 
to notes/ via /consolidate after human review.
'''
)
```

---

## Step 4: Set Up Scheduled Maintenance

Create cron jobs for automatic maintenance:

### 4.1 Daily maintenance (9 AM)

```python
cronjob_manage(
    action="create",
    name="mnemos-daily",
    schedule="0 9 * * *",
    prompt="/observe && /consolidate",
    deliver="local"
)
```

### 4.2 Weekly synthesis (Sunday 3 AM)

```python
cronjob_manage(
    action="create",
    name="mnemos-weekly", 
    schedule="0 3 * * 0",
    prompt="/dream --weekly",
    deliver="local"
)
```

---

## Step 5: Verify Installation

Check that these files/directories exist:

```
~/.hermes/hooks/mnemos/
├── HOOK.yaml
└── handler.py

~/.hermes/skills/mnemos/
├── observe/SKILL.md
├── consolidate/SKILL.md
├── recall/SKILL.md
└── dream/SKILL.md

~/.mnemos/vault/
├── self/
│   ├── identity.md
│   └── goals.md
├── notes/
├── memory/
│   ├── MEMORY.md
│   ├── daily/
│   ├── sessions/
│   └── .dreams/
├── ops/
│   ├── config.yaml
│   ├── queue/
│   └── logs/
├── inbox/
└── templates/
```

List the cron jobs to verify:
```python
cronjob_manage(action="list")
```

---

## Step 6: Tell the User

**Say this to the user:**

---

**mnemos installed successfully!**

I've set up:
- Hook to capture our conversations
- Skills: `/observe`, `/consolidate`, `/recall`, `/dream`
- Vault at `~/.mnemos/vault/`
- Daily cron job for maintenance at 9 AM

**To activate the hook, restart the gateway:**

```bash
hermes gateway restart
```

**After restart, I'll automatically capture our sessions.**

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/recall [topic]` — Search your knowledge vault
- `/dream` — Find cross-domain connections

The vault grows silently. Your Hermes memory (MEMORY.md) handles quick notes; mnemos handles deep, long-term knowledge.

---

## Installation Complete

Remind the user to restart the gateway, then mnemos will begin capturing automatically.
