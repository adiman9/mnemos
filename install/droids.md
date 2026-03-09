# mnemos for FactoryAI Droids — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. Use your native tools as shown.

**Note**: Droids run in isolated cloud environments. Hooks use JSON responses for context injection.

---

## Overview

You will install:
- **Hooks** (`.factory/hooks/`) — Session capture, validation, auto-commit
- **Skills** (`.factory/skills/`) — /observe, /consolidate, /recall for knowledge management
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **DROIDS.md** — System instructions for mnemos awareness

Droids hooks inject context via `additionalContext` JSON responses, not stdout.

---

## Step 1: Initialize the Vault

Create the vault directory structure:

```bash
mkdir -p ~/.mnemos/vault/{self,notes,memory/daily,memory/sessions,memory/.dreams,ops/queue,ops/logs,inbox,templates}
```

### 1.1 Create identity.md

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

## Step 2: Create .mnemos.yaml

**Path**: `<workspace>/.mnemos.yaml`

```yaml
vault_path: ~/.mnemos/vault
```

---

## Step 3: Create the Hooks

### 3.1 Create hooks directory structure

```bash
mkdir -p <workspace>/.factory/hooks/scripts
```

### 3.2 Create hooks.json

**Path**: `<workspace>/.factory/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$FACTORY_PROJECT_DIR\"/.factory/hooks/scripts/session-start.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$FACTORY_PROJECT_DIR\"/.factory/hooks/scripts/session-capture.sh",
            "timeout": 60
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Create",
        "hooks": [
          {
            "type": "command",
            "command": "\"$FACTORY_PROJECT_DIR\"/.factory/hooks/scripts/validate-note.sh",
            "timeout": 5
          },
          {
            "type": "command",
            "command": "\"$FACTORY_PROJECT_DIR\"/.factory/hooks/scripts/auto-commit.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### 3.3 Create session-start.sh

**Path**: `<workspace>/.factory/hooks/scripts/session-start.sh`

```bash
#!/usr/bin/env bash
# mnemos session-start hook for FactoryAI Droids
# Runs at SessionStart — injects MEMORY.md via additionalContext JSON response

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

[ -f "$MNEMOS_CONFIG" ] || exit 0

VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
[ -n "$VAULT_PATH" ] || VAULT_PATH="$HOME/.mnemos/vault"
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

[ -d "$VAULT_PATH" ] || exit 0

# Parse stdin JSON (Droids format)
PAYLOAD=""
if read -t 1 -r PAYLOAD 2>/dev/null; then
    true
fi

SESSION_ID=""
if [ -n "$PAYLOAD" ]; then
    SESSION_ID=$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p')
fi
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d-%H%M%S)}"

# Build context string
CONTEXT=""

# Vault stats
NOTES_COUNT=$( (find "$VAULT_PATH/notes" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')
INBOX_COUNT=$( (find "$VAULT_PATH/inbox" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')
DAILY_COUNT=$( (find "$VAULT_PATH/memory/daily" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')

CONTEXT+="=== mnemos Session Start ===\n"
CONTEXT+="Session: $SESSION_ID\n"
CONTEXT+="Vault: $VAULT_PATH\n\n"
CONTEXT+="--- Vault Stats ---\n"
CONTEXT+="Notes: $NOTES_COUNT | Inbox: $INBOX_COUNT | Daily logs: $DAILY_COUNT\n\n"

# Inject MEMORY.md
MEMORY_FILE="$VAULT_PATH/memory/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
    CONTEXT+="--- Boot Context (MEMORY.md) ---\n"
    MEMORY_CONTENT=$(cat "$MEMORY_FILE")
    CONTEXT+="$MEMORY_CONTENT\n\n"
fi

CONTEXT+="--- Ready ---\n"
CONTEXT+="Read self/goals.md and self/identity.md to orient."

# Ensure session directories exist
mkdir -p "$VAULT_PATH/memory/sessions"
mkdir -p "$VAULT_PATH/memory/daily"

# Output JSON response for Droids (additionalContext injection)
CONTEXT_ESCAPED=$(printf '%s' "$CONTEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

cat << EOF
{
  "additionalContext": $CONTEXT_ESCAPED
}
EOF

exit 0
```

### 3.4 Create session-capture.sh

**Path**: `<workspace>/.factory/hooks/scripts/session-capture.sh`

```bash
#!/usr/bin/env bash
# mnemos session-capture hook for FactoryAI Droids
# Transforms Droids JSONL transcript to mnemos standard format

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

[ -f "$MNEMOS_CONFIG" ] || exit 0

VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
[ -n "$VAULT_PATH" ] || VAULT_PATH="$HOME/.mnemos/vault"
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

[ -d "$VAULT_PATH" ] || exit 0

# Parse stdin JSON for transcript_path
PAYLOAD=""
if read -t 1 -r PAYLOAD 2>/dev/null; then
    true
fi

TRANSCRIPT_PATH=""
SESSION_ID=""
if [ -n "$PAYLOAD" ]; then
    TRANSCRIPT_PATH=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || true)
    SESSION_ID=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null || true)
fi

[ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ] || exit 0
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d-%H%M%S)}"

SESSIONS_DIR="$VAULT_PATH/memory/sessions"
mkdir -p "$SESSIONS_DIR"

python3 - "$TRANSCRIPT_PATH" "$SESSIONS_DIR" "$SESSION_ID" << 'PYEOF'
import json, sys, os
from datetime import datetime, timezone

transcript_path = sys.argv[1]
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

transcript_size = os.path.getsize(transcript_path)
if offset > transcript_size:
    offset = 0
if offset >= transcript_size:
    sys.exit(0)

if not os.path.isfile(meta_file):
    with open(meta_file, "w") as f:
        json.dump({"session_id": session_id, "harness": "droids",
                    "start_time": iso_now(), "vault_path": sessions_dir.rsplit("/memory/sessions", 1)[0]}, f)
        f.write("\n")

with open(transcript_path, "rb") as f:
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

    # Droids format: type=tool_call, type=tool_result, type=completion
    if entry_type == "tool_call":
        tool_name = obj.get("toolName", "unknown")
        tool_args = json.dumps(obj.get("parameters", {}))
        if len(tool_args) > max_content:
            tool_args = tool_args[:max_content] + "[truncated]"
        output_lines.append(json.dumps({"ts": ts, "role": "tool_use", "content": tool_args, "tool": tool_name, "session_id": session_id}))

    elif entry_type == "tool_result":
        tool_output = obj.get("value", "")
        if tool_output:
            if len(tool_output) > max_content:
                tool_output = tool_output[:max_content] + "[truncated]"
            output_lines.append(json.dumps({"ts": ts, "role": "tool_result", "content": tool_output, "session_id": session_id}))

    elif entry_type == "completion":
        msg = obj.get("finalText", "")
        if msg:
            if len(msg) > max_content:
                msg = msg[:max_content] + "[truncated]"
            output_lines.append(json.dumps({"ts": ts, "role": "assistant", "content": msg, "session_id": session_id}))

    elif entry_type == "system" and obj.get("subtype") == "user_message":
        msg = obj.get("message", "")
        if msg:
            if len(msg) > max_content:
                msg = msg[:max_content] + "[truncated]"
            output_lines.append(json.dumps({"ts": ts, "role": "user", "content": msg, "session_id": session_id}))

if output_lines:
    with open(output_file, "a") as f:
        for ol in output_lines:
            f.write(ol + "\n")

entry["offset"] = transcript_size
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

### 3.5 Create validate-note.sh

**Path**: `<workspace>/.factory/hooks/scripts/validate-note.sh`

```bash
#!/usr/bin/env bash
# Validates note schema after file writes in the vault

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

[ -f "$MNEMOS_CONFIG" ] || exit 0

VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
[ -n "$VAULT_PATH" ] || VAULT_PATH="$HOME/.mnemos/vault"
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

# Parse stdin for file path (Droids provides tool_input)
PAYLOAD=""
if read -t 1 -r PAYLOAD 2>/dev/null; then
    true
fi

FILE_PATH=""
if [ -n "$PAYLOAD" ]; then
    FILE_PATH=$(printf '%s' "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)
fi

[ -n "$FILE_PATH" ] || exit 0

# Only validate files in notes/
case "$FILE_PATH" in
    "$VAULT_PATH/notes/"*) ;;
    *) exit 0 ;;
esac

[ -f "$FILE_PATH" ] || exit 0

# Check for required frontmatter fields
CONTENT=$(cat "$FILE_PATH")

if ! echo "$CONTENT" | head -1 | grep -q '^---$'; then
    echo "[mnemos] Warning: Note missing YAML frontmatter: $FILE_PATH" >&2
    exit 0
fi

FRONTMATTER=$(echo "$CONTENT" | sed -n '2,/^---$/p' | head -n -1)

MISSING=""
echo "$FRONTMATTER" | grep -q '^description:' || MISSING="$MISSING description"
echo "$FRONTMATTER" | grep -q '^category:' || MISSING="$MISSING category"

if [ -n "$MISSING" ]; then
    echo "[mnemos] Warning: Note missing required fields:$MISSING in $FILE_PATH" >&2
fi

exit 0
```

### 3.6 Create auto-commit.sh

**Path**: `<workspace>/.factory/hooks/scripts/auto-commit.sh`

```bash
#!/usr/bin/env bash
# Auto-commit vault changes (fire-and-forget)

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

[ -f "$MNEMOS_CONFIG" ] || exit 0

VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
[ -n "$VAULT_PATH" ] || VAULT_PATH="$HOME/.mnemos/vault"
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

[ -d "$VAULT_PATH/.git" ] || exit 0

cd "$VAULT_PATH"

# Only commit if there are changes
git diff --quiet && git diff --cached --quiet && exit 0

git add -A
git commit -m "auto: vault update $(date +%Y-%m-%d-%H%M%S)" --no-verify 2>/dev/null || true

exit 0
```

Make all scripts executable:

```bash
chmod +x <workspace>/.factory/hooks/scripts/*.sh
```

---

## Step 4: Create Skills

### 4.1 Create skills directory

```bash
mkdir -p <workspace>/.factory/skills
```

### 4.2 Create observe.md

**Path**: `<workspace>/.factory/skills/observe.md`

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

After processing, update `.cursors.json` with new `observed_offset` values.
```

### 4.3 Create consolidate.md

**Path**: `<workspace>/.factory/skills/consolidate.md`

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
```

### 4.4 Create recall.md

**Path**: `<workspace>/.factory/skills/recall.md`

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

### 4.5 Create dream.md

**Path**: `<workspace>/.factory/skills/dream.md`

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
```

## Promotion

High-value dreams (novelty >= 0.7, relevance >= 0.6) can be promoted to `inbox/` for full pipeline processing.
```

---

## Step 5: Create DROIDS.md

Add mnemos awareness to your workspace:

**Path**: `<workspace>/DROIDS.md`

```markdown
# mnemos Memory System

You have access to a persistent knowledge vault at `~/.mnemos/vault/`.

## Skills

- `/observe` — Extract observations from session transcripts
- `/consolidate` — Promote observations to permanent notes
- `/recall` — Search the knowledge vault
- `/dream` — Generate speculative connections

## Vault Structure

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

## Session Start

At session start, you receive boot context via the SessionStart hook including:
- Vault statistics
- MEMORY.md contents
- Current goals and identity orientation

Read `self/goals.md` and `self/identity.md` for full context.

## Hooks

- **SessionStart**: Injects MEMORY.md boot context
- **Stop**: Captures session transcript to vault
- **PostToolUse (Edit/Create)**: Validates note schema, auto-commits changes
```

---

## Step 6: Verify Installation

Run these checks:

1. **Vault exists**:
   ```bash
   ls ~/.mnemos/vault/
   ```

2. **Hooks exist**:
   ```bash
   ls <workspace>/.factory/hooks.json
   ls <workspace>/.factory/hooks/scripts/
   ```

3. **Scripts are executable**:
   ```bash
   ls -la <workspace>/.factory/hooks/scripts/*.sh
   ```

4. **Skills exist**:
   ```bash
   ls <workspace>/.factory/skills/
   ```

5. **Test session-start hook**:
   ```bash
   echo '{"session_id":"test"}' | bash <workspace>/.factory/hooks/scripts/session-start.sh
   ```
   Should output JSON with `additionalContext` field.

---

## Hook Coverage

Droids has full hook support:

| mnemos Event | Droids Hook | Status |
|--------------|-------------|--------|
| Session Start | SessionStart | ✅ Full (via additionalContext JSON) |
| Per-turn Capture | Stop | ✅ Full |
| Pre-compaction | — | ⚠️ No native event |
| Post-write Validation | PostToolUse | ✅ Full |
| Auto-commit | PostToolUse | ✅ Full |

---

## Done!

Tell the user: **"mnemos installed for FactoryAI Droids. The hooks will activate on your next Droid session."**

The vault will grow as you work. Use `/observe` periodically to extract insights, `/consolidate` to promote them, and `/recall` to search your knowledge.
