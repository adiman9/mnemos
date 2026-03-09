# mnemos for Claude Code / Cursor / Cline — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly using your file editing and bash capabilities.

---

## Overview

You will install:
- **Hooks** (`.claude/hooks.json`) — Captures session transcripts via shell scripts
- **Skills** (`CLAUDE.md`) — Instructions for /observe, /consolidate, /recall
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **Scripts** — Shell scripts for hook execution

Claude Code's conversation context handles recent messages. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Create the Hook Scripts Directory

First, create the scripts directory in the user's home:

```bash
mkdir -p ~/.mnemos/scripts
```

---

## Step 2: Create Hook Scripts

### 2.1 Create session-start.sh

Create file `~/.mnemos/scripts/session-start.sh`:

```bash
#!/bin/bash
# mnemos session-start hook — inject boot context and show vault stats

set -euo pipefail

VAULT="${MNEMOS_VAULT:-$HOME/.mnemos/vault}"

# Ensure vault exists
mkdir -p "$VAULT"/{self,notes,memory/{daily,sessions,.dreams},ops/{queue,logs},inbox,templates}

# Create default files if missing
if [ ! -f "$VAULT/self/identity.md" ]; then
  cat > "$VAULT/self/identity.md" << 'EOF'
# Identity

Who you are and how you work. Update as you develop preferences.

## Core Identity

[Describe your role and working style]

## Working Preferences

[Capture preferences discovered through experience]
EOF
fi

if [ ! -f "$VAULT/self/goals.md" ]; then
  cat > "$VAULT/self/goals.md" << 'EOF'
# Goals

## Active

[Current objectives]

## Completed

[Recently finished]

## Parked

[On hold — with reason]
EOF
fi

if [ ! -f "$VAULT/memory/MEMORY.md" ]; then
  cat > "$VAULT/memory/MEMORY.md" << 'EOF'
# Memory Boot Context

No observations yet. Run /observe after a few sessions.
EOF
fi

# Output vault stats
echo "=== mnemos vault ===" 
echo "Path: $VAULT"
echo "Notes: $(find "$VAULT/notes" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
echo "Sessions: $(find "$VAULT/memory/sessions" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')"
echo "Daily observations: $(find "$VAULT/memory/daily" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"

# Show recent activity summary if MEMORY.md exists
if [ -f "$VAULT/memory/MEMORY.md" ]; then
  echo ""
  echo "Boot context loaded from memory/MEMORY.md"
fi
```

Make it executable:

```bash
chmod +x ~/.mnemos/scripts/session-start.sh
```

### 2.2 Create session-capture.sh

Create file `~/.mnemos/scripts/session-capture.sh`:

```bash
#!/bin/bash
# mnemos session-capture hook — record conversation turn

set -euo pipefail

VAULT="${MNEMOS_VAULT:-$HOME/.mnemos/vault}"
SESSIONS_DIR="$VAULT/memory/sessions"

mkdir -p "$SESSIONS_DIR"

# Generate session ID from date if not provided
SESSION_ID="${CLAUDE_SESSION_ID:-claude-$(date +%Y%m%d)}"

# Read content from stdin (Claude Code pipes the transcript)
CONTENT=$(cat)

if [ -n "$CONTENT" ]; then
  # Append to session file as JSONL
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  # Escape content for JSON
  ESCAPED=$(echo "$CONTENT" | head -c 5000 | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
  
  echo "{\"ts\":\"$TIMESTAMP\",\"role\":\"assistant\",\"content\":$ESCAPED,\"session_id\":\"$SESSION_ID\"}" >> "$SESSIONS_DIR/$SESSION_ID.jsonl"
fi
```

Make it executable:

```bash
chmod +x ~/.mnemos/scripts/session-capture.sh
```

---

## Step 3: Configure Claude Code Hooks

Create or update `.claude/hooks.json` in the current project directory:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "command": "~/.mnemos/scripts/session-start.sh",
        "timeout": 5000
      }
    ],
    "Stop": [
      {
        "command": "~/.mnemos/scripts/session-capture.sh",
        "timeout": 3000
      }
    ]
  }
}
```

---

## Step 4: Initialize the Vault

Create the vault structure:

```bash
VAULT="$HOME/.mnemos/vault"
mkdir -p "$VAULT"/{self,notes,memory/{daily,sessions,.dreams},ops/{queue,logs},inbox,templates}
```

Create identity file `~/.mnemos/vault/self/identity.md`:

```markdown
# Identity

Who you are and how you work. Update as you develop preferences.

## Core Identity

[Describe your role and working style]

## Working Preferences

[Capture preferences discovered through experience]
```

Create goals file `~/.mnemos/vault/self/goals.md`:

```markdown
# Goals

## Active

[Current objectives]

## Completed

[Recently finished]

## Parked

[On hold — with reason]
```

Create boot context `~/.mnemos/vault/memory/MEMORY.md`:

```markdown
# Memory Boot Context

No observations yet. Run /observe after a few sessions to begin capturing insights.
```

Create config `~/.mnemos/vault/ops/config.yaml`:

```yaml
# mnemos vault configuration

processing:
  depth: standard
  chaining: suggested

maintenance:
  orphan_threshold: 1
  topic_map_max: 40
  inbox_stale_days: 3

promotion:
  importance_threshold: 0.8
  surprise_threshold: 0.7
  frequency_threshold: 2
```

---

## Step 5: Add Skills to CLAUDE.md

Append the following to the project's `CLAUDE.md` (or create it):

```markdown

---

## mnemos Skills

### /observe — Extract Learning from Sessions

Read recent session transcripts from `~/.mnemos/vault/memory/sessions/*.jsonl` and extract typed observations.

**Observation Schema:**
```yaml
- type: insight | pattern | workflow | tool | person | decision | open-question
  importance: 0.0-1.0
  confidence: 0.0-1.0
  surprise: 0.0-1.0
  content: "Concise description"
```

**Output:** Append to `~/.mnemos/vault/memory/daily/YYYY-MM-DD.md`

### /consolidate — Promote Observations to Notes

Move observations from daily logs to permanent notes.

**Reference types** (person, tool, decision, open-question): Auto-promote all.
**Pipeline types** (insight, pattern, workflow): Promote when importance >= 0.8 OR surprise >= 0.7.

**Output:** Create notes in `~/.mnemos/vault/notes/` with wiki-links.

### /recall [topic] — Search Knowledge Vault

Search `~/.mnemos/vault/notes/` and `~/.mnemos/vault/memory/daily/` for relevant knowledge.

Return excerpts with source attribution.

### /dream — Speculative Connections

Find cross-domain parallels between vault notes. Output to `~/.mnemos/vault/memory/.dreams/`.

---
```

---

## Step 6: Set Up Scheduled Maintenance (Optional)

For Claude Code, use the system's scheduler. Run this to set up launchd (macOS) or cron (Linux):

### macOS (launchd)

Create `~/Library/LaunchAgents/com.mnemos.daily.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.mnemos.daily</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>cd ~/.mnemos/vault && claude --print "Run /observe && /consolidate" 2>/dev/null || true</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/mnemos-daily.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/mnemos-daily.err</string>
</dict>
</plist>
```

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.mnemos.daily.plist
```

### Linux (cron)

```bash
(crontab -l 2>/dev/null; echo "0 9 * * * cd ~/.mnemos/vault && claude --print '/observe && /consolidate' >> ~/.mnemos/vault/ops/logs/daily.log 2>&1") | crontab -
```

---

## Step 7: Verify Installation

Check these exist:

```
~/.mnemos/
├── scripts/
│   ├── session-start.sh
│   └── session-capture.sh
└── vault/
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
    │   └── config.yaml
    ├── inbox/
    └── templates/

.claude/hooks.json  (in project directory)
CLAUDE.md           (with mnemos skills section)
```

Test the session-start hook:

```bash
~/.mnemos/scripts/session-start.sh
```

---

## Step 8: Tell the User

**Say this to the user:**

---

**mnemos installed successfully!**

I've set up:
- Hook scripts at `~/.mnemos/scripts/`
- Hooks configured in `.claude/hooks.json`
- Vault at `~/.mnemos/vault/`
- Skills documented in `CLAUDE.md`

**The hooks will activate on your next Claude Code session.**

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/recall [topic]` — Search your knowledge vault

**Note:** For other projects, copy `.claude/hooks.json` or run this install again.

---

## Installation Complete

The hooks will begin capturing automatically on the next session.
