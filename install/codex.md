# mnemos for Codex CLI — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. Use your native tools as shown.

**Note**: Codex CLI has **partial hook support** — no SessionStart or per-write hooks. Skills work fully; transcript capture fires per-turn only.

---

## Overview

You will install:
- **Skills** (`<workspace>/skills/`) — /observe, /consolidate, /recall for knowledge management
- **Notify hook** (`.codex/config.toml`) — Captures session transcripts per-turn
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **AGENTS.md** — System instructions for mnemos awareness

Codex's native AGENTS.md provides static context. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Initialize the Vault

Create the vault directory structure:

```bash
mkdir -p ~/.mnemos/vault/{self,notes,memory/daily,memory/sessions,memory/.dreams,ops/queue,ops/logs,inbox,templates}
```

### 1.1 Create identity.md

Write this file:

**Path**: `~/.mnemos/vault/self/identity.md`

```markdown
# Identity

Who you are and how you work. Update as you develop preferences.

## Core Identity

[Describe your role and working style]

## Communication Style

[How you prefer to interact]

## Working Patterns

[Your preferred approaches and methods]
```

### 1.2 Create methodology.md

**Path**: `~/.mnemos/vault/self/methodology.md`

```markdown
# Methodology

How you extract, connect, and verify knowledge.

## Observation Extraction

When capturing observations:
- Use the unified taxonomy: insight, pattern, workflow, tool, person, decision, open-question
- Score importance (0.0-1.0), confidence (0.0-1.0), surprise (0.0-1.0)
- Add co-occurrence tags for relationships

## Connection Finding

When linking knowledge:
- State relationship semantics: extends, foundation, contradicts, enables, example
- Prefer inline links in prose over disconnected footers
- Every link must resolve to a real file

## Quality Standards

- One idea per note
- Prose-as-title claim format
- Dense wiki-linking
```

### 1.3 Create goals.md

**Path**: `~/.mnemos/vault/self/goals.md`

```markdown
# Goals

Current objectives and priorities. Update as priorities shift.

## Active Goals

1. [Your primary objective]
2. [Secondary objective]

## Completed

- [Past achievements worth remembering]
```

### 1.4 Create MEMORY.md

**Path**: `~/.mnemos/vault/memory/MEMORY.md`

```markdown
# Boot Context

This file is regenerated periodically. It provides session-start orientation.

## Identity

Read self/identity.md for full context.

## Current Goals

Read self/goals.md for active objectives.

## Recent Activity

[Will be populated by /observe and /consolidate]
```

---

## Step 2: Create the Notify Hook Script

This script runs after each agent turn to capture transcripts.

### 2.1 Create the hook script directory

```bash
mkdir -p <workspace>/.codex/hooks
```

### 2.2 Create codex-notify.sh

**Path**: `<workspace>/.codex/hooks/codex-notify.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

[ -f "$MNEMOS_CONFIG" ] || exit 0

VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
[ -n "$VAULT_PATH" ] || VAULT_PATH="$HOME/.mnemos/vault"
[ -d "$VAULT_PATH" ] || exit 0

PAYLOAD="${1:-}"
[ -n "$PAYLOAD" ] || exit 0

THREAD_ID=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; print(json.load(sys.stdin).get('thread-id',''))" 2>/dev/null)
[ -n "$THREAD_ID" ] || exit 0

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
TODAY=$(date -u +%Y/%m/%d)
ROLLOUT_DIR="$CODEX_HOME/sessions/$TODAY"
ROLLOUT_FILE=""
for f in "$ROLLOUT_DIR"/rollout-*-"${THREAD_ID}".jsonl; do
    [ -f "$f" ] && ROLLOUT_FILE="$f" && break
done
[ -n "$ROLLOUT_FILE" ] && [ -f "$ROLLOUT_FILE" ] || exit 0

SESSIONS_DIR="$VAULT_PATH/memory/sessions"
mkdir -p "$SESSIONS_DIR"

python3 - "$ROLLOUT_FILE" "$SESSIONS_DIR" "$THREAD_ID" << 'PYEOF'
import json, sys, os
from datetime import datetime, timezone

rollout_path = sys.argv[1]
sessions_dir = sys.argv[2]
session_id = sys.argv[3]
output_file = os.path.join(sessions_dir, f"{session_id}.jsonl")
cursor_file = os.path.join(sessions_dir, ".cursors.json")
meta_file = os.path.join(sessions_dir, f"{session_id}.meta.json")
max_content = 2000

def iso_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

cursors = {}
if os.path.isfile(cursor_file):
    try:
        with open(cursor_file) as f:
            cursors = json.load(f)
    except (json.JSONDecodeError, IOError):
        cursors = {}

entry = cursors.get(session_id, {})
offset = entry.get("offset", 0)

rollout_size = os.path.getsize(rollout_path)
if offset > rollout_size:
    offset = 0
if offset >= rollout_size:
    sys.exit(0)

if not os.path.isfile(meta_file):
    with open(meta_file, "w") as f:
        json.dump({"session_id": session_id, "harness": "codex",
                    "start_time": iso_now(), "vault_path": sessions_dir.rsplit("/memory/sessions", 1)[0]}, f)
        f.write("\n")

with open(rollout_path, "rb") as f:
    f.seek(offset)
    new_data = f.read()

lines = new_data.decode("utf-8", errors="replace").splitlines()
output_lines = []

for raw_line in lines:
    raw_line = raw_line.strip()
    if not raw_line:
        continue
    try:
        obj = json.loads(raw_line)
    except json.JSONDecodeError:
        continue

    ts = obj.get("timestamp", iso_now())
    entry_type = obj.get("type", "")
    payload = obj.get("payload", {})
    if not isinstance(payload, dict):
        continue

    ptype = payload.get("type", "")

    if entry_type == "event_msg" and ptype == "user_message":
        msg = payload.get("message", "")
        if msg:
            if len(msg) > max_content:
                msg = msg[:max_content] + "[truncated]"
            output_lines.append(json.dumps({"ts": ts, "role": "user", "content": msg, "session_id": session_id}))

    elif entry_type == "event_msg" and ptype == "agent_message":
        msg = payload.get("message", "")
        if msg:
            if len(msg) > max_content:
                msg = msg[:max_content] + "[truncated]"
            output_lines.append(json.dumps({"ts": ts, "role": "assistant", "content": msg, "session_id": session_id}))

    elif entry_type == "response_item" and ptype == "function_call":
        tool_name = payload.get("name", "unknown")
        tool_args = payload.get("arguments", "{}")
        if len(tool_args) > max_content:
            tool_args = tool_args[:max_content] + "[truncated]"
        output_lines.append(json.dumps({"ts": ts, "role": "tool_use", "content": tool_args, "tool": tool_name, "session_id": session_id}))

    elif entry_type == "response_item" and ptype == "function_call_output":
        tool_output = payload.get("output", "")
        if tool_output:
            if len(tool_output) > max_content:
                tool_output = tool_output[:max_content] + "[truncated]"
            output_lines.append(json.dumps({"ts": ts, "role": "tool_result", "content": tool_output, "session_id": session_id}))

if output_lines:
    with open(output_file, "a") as f:
        for ol in output_lines:
            f.write(ol + "\n")

entry["offset"] = rollout_size
entry["last_capture"] = iso_now()
if "observed_offset" not in entry:
    entry["observed_offset"] = 0
cursors[session_id] = entry

with open(cursor_file, "w") as f:
    json.dump(cursors, f)
    f.write("\n")
PYEOF

exit 0
```

Make it executable:

```bash
chmod +x <workspace>/.codex/hooks/codex-notify.sh
```

---

## Step 3: Create .mnemos.yaml

**Path**: `<workspace>/.mnemos.yaml`

```yaml
vault_path: ~/.mnemos/vault
```

---

## Step 4: Configure Codex

### 4.1 Create project-local config

**Path**: `<workspace>/.codex/config.toml`

```toml
# mnemos transcript capture hook
# Fires after each agent turn

notify = ["$PROJECT_DIR/.codex/hooks/codex-notify.sh"]
```

### 4.2 Trust the project (if not already)

Ensure your workspace is trusted in `~/.codex/config.toml`:

```toml
[projects."/path/to/your/workspace"]
trust_level = "trusted"
```

Replace `/path/to/your/workspace` with your actual workspace path.

---

## Step 5: Create Skills

Codex reads skills from `<workspace>/skills/` with YAML frontmatter.

### 5.1 Create skills directory

```bash
mkdir -p <workspace>/skills
```

### 5.2 Create observe.md

**Path**: `<workspace>/skills/observe.md`

```markdown
---
name: observe
description: Extract typed observations from session transcripts
---

# /observe

Read session transcripts and extract typed observations.

## Process

1. Read `memory/sessions/*.jsonl` for recent sessions
2. Check `.cursors.json` for `observed_offset` to find unprocessed content
3. For each unprocessed segment, identify observations using the taxonomy:
   - `insight` — Claims, lessons, findings
   - `pattern` — Recurring themes, structural parallels
   - `workflow` — Processes, techniques, procedures
   - `tool` — Software, libraries, frameworks
   - `person` — People and their context
   - `decision` — Choices and their reasoning
   - `open-question` — Unknowns worth investigating

4. Score each observation:
   - `importance`: 0.0-1.0 (how much does this matter?)
   - `confidence`: 0.0-1.0 (how certain is this?)
   - `surprise`: 0.0-1.0 (how unexpected?)

5. Append to today's daily file: `memory/daily/YYYY-MM-DD.md`

## Output Format

```markdown
## Observations

- [HH:MM] **type**: content |i=0.X|c=0.X|s=0.X| @co: type:name
```

## Example

```markdown
## Observations

- [14:23] **insight**: Cursor-based incremental processing prevents duplicate extraction |i=0.8|c=0.9|s=0.3|
- [14:25] **tool**: jq for JSON processing in shell scripts |i=0.5|c=1.0|s=0.2| @co: workflow:session-capture
```

After processing, update `.cursors.json` with new `observed_offset` values.
```

### 5.3 Create consolidate.md

**Path**: `<workspace>/skills/consolidate.md`

```markdown
---
name: consolidate
description: Promote observations to permanent notes via dual-path routing
---

# /consolidate

Bridge volatile observations (Layer 1) to durable knowledge (Layer 2).

## Dual-Path Routing

### Reference Path (auto-promote)
Types: `person`, `tool`, `decision`, `open-question`
- ALL observations of these types are promoted
- Create directly in `notes/` (skip pipeline)
- Wire wiki-links from co-occurrence tags
- Queue for /reflect to find deeper connections

### Full Pipeline Path (threshold-based)
Types: `insight`, `pattern`, `workflow`
- Promote when ANY condition holds:
  - `importance >= 0.8`
  - `surprise >= 0.7`
  - `frequency >= 2` AND `importance >= 0.4`
- Route through `inbox/` for full processing

## Process

1. Read recent daily files: `memory/daily/*.md` (last 7 days)
2. Parse observations with their scores
3. Route by type:
   - Reference types → create note in `notes/`, add links
   - Pipeline types → check thresholds, create in `inbox/` if met
4. Update daily file to mark processed observations

## Note Format

```yaml
---
description: One sentence adding context beyond title
topics: []
source: "observation from YYYY-MM-DD"
confidence: supported | likely | experimental
category: insight | pattern | workflow | tool | person | decision | open-question
---

[Content expanding on the observation]

## Links

- [[related-note]] — relationship description
```

## Example

Observation: `**tool**: ast-grep for structural code search |i=0.7|c=0.9|s=0.4|`

Creates `notes/ast-grep is a structural code search tool.md`:

```markdown
---
description: Uses AST patterns instead of regex for precise code matching
topics: [developer-tools]
source: "observation from 2024-01-15"
confidence: supported
category: tool
---

ast-grep enables searching code by structure rather than text patterns.

## Use Cases

- Refactoring patterns across codebase
- Finding specific function call patterns
- Migration scripts

## Links

- [[structural search beats regex for code]] — enables
```
```

### 5.4 Create recall.md

**Path**: `<workspace>/skills/recall.md`

```markdown
---
name: recall
description: Search the knowledge vault for relevant context
---

# /recall

Search the mnemos vault to retrieve relevant knowledge.

## Search Strategy

1. **Keyword search** (fast, precise):
   ```bash
   rg "pattern" ~/.mnemos/vault/notes/
   rg "pattern" ~/.mnemos/vault/memory/daily/
   ```

2. **Category filter**:
   ```bash
   rg '^category: tool' ~/.mnemos/vault/notes/
   rg '^category: insight' ~/.mnemos/vault/notes/
   ```

3. **Topic traversal**: Read topic map files in `notes/` to find related clusters

4. **Recent context**: Check `memory/daily/` for recent observations

## Query Interpretation

When user asks to recall:
- "What do I know about X?" → keyword search + topic traversal
- "Recent work on X" → daily files + session transcripts
- "Tools for X" → category:tool filter + keyword
- "Decisions about X" → category:decision filter

## Output

Return relevant excerpts with source attribution:
- Note title and path
- Relevant content snippet
- Confidence level from frontmatter
- Related links for further exploration
```

### 5.5 Create dream.md

**Path**: `<workspace>/skills/dream.md`

```markdown
---
name: dream
description: Generate speculative cross-domain connections
---

# /dream

Surface structural parallels across distant topics in the vault.

## Modes

### Daily Mode (default)
Reads today's observations, finds 2-3 structural parallels with existing vault notes.

### Weekly Mode (`/dream --weekly`)
Randomly samples 5 note pairs across maximally distant topic maps. Deeper analysis.

## Process

1. **Sample**: Select notes based on mode
2. **Analyze**: Find structural parallels (not surface similarity)
3. **Score**: Rate novelty (0.0-1.0) and relevance (0.0-1.0)
4. **Store**: Write to `memory/.dreams/YYYY-MM-DD-HHMMSS.md`

## Output Format

```markdown
# Dream: [descriptive title]

Generated: YYYY-MM-DD HH:MM
Mode: daily | weekly
Novelty: 0.X
Relevance: 0.X

## Source Notes
- [[note-a]]
- [[note-b]]

## Structural Parallel

[Description of the non-obvious connection]

## Hypothesis

[Speculative insight that emerges from this connection]

## If Validated

[What would change if this hypothesis is confirmed]
```

## Promotion

High-value dreams (novelty >= 0.7, relevance >= 0.6) can be promoted to `inbox/` for full pipeline processing via `/dream --review`.
```

---

## Step 6: Update AGENTS.md

Add mnemos awareness to your workspace's AGENTS.md (create if it doesn't exist):

**Path**: `<workspace>/AGENTS.md`

Add this section:

```markdown
## mnemos Memory System

You have access to a persistent knowledge vault at `~/.mnemos/vault/`.

### Skills

- `/observe` — Extract observations from session transcripts
- `/consolidate` — Promote observations to permanent notes
- `/recall` — Search the knowledge vault
- `/dream` — Generate speculative connections

### Vault Structure

```
~/.mnemos/vault/
├── self/           # Identity, methodology, goals
├── notes/          # Permanent knowledge (Layer 2)
├── memory/
│   ├── daily/      # Observations by day (Layer 1)
│   ├── sessions/   # Transcript archives
│   └── .dreams/    # Speculative connections (Layer 3)
├── inbox/          # Items pending processing
└── ops/            # Operational state
```

### Session Start

At session start, read:
1. `~/.mnemos/vault/memory/MEMORY.md` — Boot context
2. `~/.mnemos/vault/self/goals.md` — Current objectives
```

---

## Step 7: Verify Installation

Run these checks:

1. **Vault exists**:
   ```bash
   ls ~/.mnemos/vault/
   ```

2. **Hook script exists and is executable**:
   ```bash
   ls -la <workspace>/.codex/hooks/codex-notify.sh
   ```

3. **Skills exist**:
   ```bash
   ls <workspace>/skills/
   ```

4. **Config exists**:
   ```bash
   cat <workspace>/.codex/config.toml
   ```

---

## Limitations

Codex CLI has partial hook support:

| Feature | Status |
|---------|--------|
| Skills | ✅ Full support |
| AGENTS.md | ✅ Full support |
| Transcript capture | ⚠️ Per-turn only (no streaming) |
| Session start context | ❌ Not supported (use AGENTS.md) |
| Per-file validation | ❌ Not supported |
| Auto-commit | ⚠️ Per-turn only |

For full hook coverage, consider Claude Code or Pi framework.

---

## Done!

Tell the user: **"mnemos installed for Codex. Restart Codex to activate the hooks."**

The vault will grow as you work. Use `/observe` periodically to extract insights, `/consolidate` to promote them, and `/recall` to search your knowledge.
