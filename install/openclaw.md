# mnemos for OpenClaw — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. Use the tool calls as shown.

---

## Overview

You will install:
- **Hook** (`~/.openclaw/hooks/mnemos/`) — Captures session transcripts
- **Skills** — /observe, /consolidate, /recall for knowledge management
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **Cron** — Daily maintenance jobs via `openclaw cron`

OpenClaw's native conversation history handles recent context. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Create the Hook

### 1.1 Create HOOK.yaml

Use the file writing capability to create:

**File**: `~/.openclaw/hooks/mnemos/HOOK.yaml`

```yaml
name: mnemos
description: 3-layer memory - captures sessions for long-term knowledge synthesis
events:
  - gateway:startup
  - gateway:heartbeat
  - message:received
  - message:sent
  - command:new
  - session:compact:before
```

### 1.2 Create handler.js

**File**: `~/.openclaw/hooks/mnemos/handler.js`

```javascript
/**
 * mnemos OpenClaw Hook — Captures session transcripts to vault
 * 
 * Events:
 *   gateway:startup       → Initialize vault structure
 *   gateway:heartbeat     → Sync transcripts from OpenClaw sessions
 *   message:received      → Capture user message
 *   message:sent          → Capture assistant message
 *   command:new           → Checkpoint before /new
 *   session:compact:before → Flush before compaction
 */

import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

const VAULT = process.env.MNEMOS_VAULT || path.join(os.homedir(), '.mnemos', 'vault');
const MAX_CONTENT_LENGTH = 5000;

/**
 * Main event handler
 */
export default async function handler(event) {
  const eventType = event.type || 'unknown';
  const eventAction = event.action || '';
  
  try {
    if (eventType === 'gateway:startup' || eventType === 'gateway' && eventAction === 'startup') {
      ensureVault();
      console.log('[mnemos] Vault initialized at', VAULT);
    }
    
    if (eventType === 'gateway:heartbeat' || eventType === 'gateway' && eventAction === 'heartbeat') {
      syncTranscripts(event);
    }
    
    if (eventType === 'message:received' || eventType === 'message' && eventAction === 'received') {
      captureMessage(event, 'user');
    }
    
    if (eventType === 'message:sent' || eventType === 'message' && eventAction === 'sent') {
      captureMessage(event, 'assistant');
    }
    
    if (eventType === 'command:new' || eventType === 'command' && eventAction === 'new') {
      markSessionBoundary(event);
    }
    
    if (eventType === 'session:compact:before') {
      flushSession(event);
    }
  } catch (err) {
    console.error('[mnemos] Hook error:', err.message);
  }
}

/**
 * Initialize vault directory structure
 */
function ensureVault() {
  const dirs = [
    'self',
    'notes',
    'memory/daily',
    'memory/sessions',
    'memory/.dreams',
    'ops/queue',
    'ops/logs',
    'inbox',
    'templates',
  ];
  
  for (const dir of dirs) {
    fs.mkdirSync(path.join(VAULT, dir), { recursive: true });
  }
  
  // Create default identity
  const identity = path.join(VAULT, 'self/identity.md');
  if (!fs.existsSync(identity)) {
    fs.writeFileSync(identity, `# Identity

Who you are and how you work. Update as you develop preferences.

## Core Identity

[Describe your role and working style]

## Working Preferences

[Capture preferences discovered through experience]
`);
  }
  
  // Create default goals
  const goals = path.join(VAULT, 'self/goals.md');
  if (!fs.existsSync(goals)) {
    fs.writeFileSync(goals, `# Goals

## Active

[Current objectives]

## Completed

[Recently finished]

## Parked

[On hold — with reason]
`);
  }
  
  // Create boot context
  const memory = path.join(VAULT, 'memory/MEMORY.md');
  if (!fs.existsSync(memory)) {
    fs.writeFileSync(memory, `# Memory Boot Context

No observations yet. Run /observe after a few sessions to begin capturing insights.
`);
  }
}

/**
 * Capture a message to session transcript
 */
function captureMessage(event, role) {
  const ctx = event.context || {};
  const sessionId = event.sessionKey || ctx.conversationId || ctx.sessionId || `openclaw-${Date.now()}`;
  const content = ctx.content || ctx.body || ctx.bodyForAgent || '';
  
  if (!content) return;
  
  const sessionsDir = path.join(VAULT, 'memory/sessions');
  fs.mkdirSync(sessionsDir, { recursive: true });
  
  const outputFile = path.join(sessionsDir, `${sessionId}.jsonl`);
  
  const entry = {
    ts: new Date().toISOString(),
    role: role,
    content: content.slice(0, MAX_CONTENT_LENGTH),
    session_id: sessionId,
  };
  
  if (ctx.channelId) entry.channel = ctx.channelId;
  if (role === 'user' && ctx.from) entry.from = ctx.from;
  if (role === 'assistant' && ctx.to) entry.to = ctx.to;
  
  fs.appendFileSync(outputFile, JSON.stringify(entry) + '\n');
}

/**
 * Sync transcripts from OpenClaw's internal session storage
 */
function syncTranscripts(event) {
  const openclawAgentsDir = path.join(os.homedir(), '.openclaw', 'agents');
  if (!fs.existsSync(openclawAgentsDir)) return;
  
  const sessionsDir = path.join(VAULT, 'memory/sessions');
  fs.mkdirSync(sessionsDir, { recursive: true });
  
  // Track sync cursors
  const cursorFile = path.join(sessionsDir, '.sync-cursors.json');
  let cursors = {};
  if (fs.existsSync(cursorFile)) {
    try {
      cursors = JSON.parse(fs.readFileSync(cursorFile, 'utf-8'));
    } catch {}
  }
  
  // Scan agent directories
  const agentDirs = fs.readdirSync(openclawAgentsDir).filter(d => {
    return fs.statSync(path.join(openclawAgentsDir, d)).isDirectory();
  });
  
  for (const agentId of agentDirs) {
    const agentSessionsDir = path.join(openclawAgentsDir, agentId, 'sessions');
    if (!fs.existsSync(agentSessionsDir)) continue;
    
    const sessionFiles = fs.readdirSync(agentSessionsDir).filter(f => f.endsWith('.jsonl'));
    
    for (const sessionFile of sessionFiles) {
      const sessionPath = path.join(agentSessionsDir, sessionFile);
      const sessionId = sessionFile.replace('.jsonl', '');
      const cursorKey = `${agentId}:${sessionId}`;
      
      const stat = fs.statSync(sessionPath);
      const lastOffset = cursors[cursorKey] || 0;
      
      if (stat.size <= lastOffset) continue;
      
      // Read new content
      const fd = fs.openSync(sessionPath, 'r');
      const buffer = Buffer.alloc(stat.size - lastOffset);
      fs.readSync(fd, buffer, 0, buffer.length, lastOffset);
      fs.closeSync(fd);
      
      const outputFile = path.join(sessionsDir, `${sessionId}.jsonl`);
      const newLines = buffer.toString('utf-8').split('\n').filter(Boolean);
      
      for (const line of newLines) {
        try {
          const entry = JSON.parse(line);
          if (entry.type !== 'message') continue;
          
          const msg = entry.message;
          if (!msg || msg.role !== 'assistant') continue;
          
          // Extract text content
          let textContent = '';
          if (typeof msg.content === 'string') {
            textContent = msg.content;
          } else if (Array.isArray(msg.content)) {
            textContent = msg.content
              .filter(item => item && item.type === 'text' && item.text)
              .map(item => item.text)
              .join('\n');
          }
          
          if (!textContent) continue;
          
          const outLine = JSON.stringify({
            ts: entry.timestamp || new Date().toISOString(),
            role: 'assistant',
            content: textContent.slice(0, MAX_CONTENT_LENGTH),
            session_id: sessionId,
          });
          
          fs.appendFileSync(outputFile, outLine + '\n');
        } catch {}
      }
      
      cursors[cursorKey] = stat.size;
    }
  }
  
  fs.writeFileSync(cursorFile, JSON.stringify(cursors, null, 2));
}

/**
 * Mark session boundary before /new command
 */
function markSessionBoundary(event) {
  const sessionsDir = path.join(VAULT, 'memory/sessions');
  const boundaryFile = path.join(sessionsDir, '.boundaries');
  const sessionKey = event.context?.sessionKey || event.sessionKey || '';
  
  if (sessionKey) {
    fs.appendFileSync(boundaryFile, `${new Date().toISOString()} ${sessionKey}\n`);
  }
}

/**
 * Flush session data before compaction
 */
function flushSession(event) {
  // Trigger a sync to ensure all data is captured
  syncTranscripts(event);
}
```

---

## Step 2: Initialize the Vault

Create the vault directory structure. The hook will also do this on startup, but let's ensure it exists now.

Create these files:

### 2.1 `~/.mnemos/vault/self/identity.md`

```markdown
# Identity

Who you are and how you work. Update as you develop preferences.

## Core Identity

[Describe your role and working style]

## Working Preferences

[Capture preferences discovered through experience]
```

### 2.2 `~/.mnemos/vault/self/goals.md`

```markdown
# Goals

## Active

[Current objectives]

## Completed

[Recently finished]

## Parked

[On hold — with reason]
```

### 2.3 `~/.mnemos/vault/memory/MEMORY.md`

```markdown
# Memory Boot Context

No observations yet. Run /observe after a few sessions to begin capturing insights.

## Recent Activity

[Will be populated by /observe]

## Active Topics

[Will emerge as notes/ grows]
```

### 2.4 `~/.mnemos/vault/ops/config.yaml`

```yaml
# mnemos vault configuration

processing:
  depth: standard
  chaining: suggested
  extraction:
    selectivity: moderate

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

## Step 3: Create Core Skills

Create these skills in OpenClaw's skill directory (`~/.openclaw/skills/mnemos/`):

### 3.1 `~/.openclaw/skills/mnemos/observe/SKILL.md`

```markdown
---
name: observe
description: Extract typed observations from recent session transcripts
triggers:
  - /observe
  - extract observations
  - what did I learn today
---

# Observe — Extract Learning from Sessions

Read recent session transcripts and extract typed observations.

## Process

1. **Find transcripts**: Read `~/.mnemos/vault/memory/sessions/*.jsonl`
2. **Identify sessions**: Focus on files modified in last 24 hours
3. **Extract observations**: For each significant exchange, create an observation

## Observation Schema

```yaml
- type: insight | pattern | workflow | tool | person | decision | open-question
  importance: 0.0-1.0
  confidence: 0.0-1.0
  surprise: 0.0-1.0
  content: "Concise description"
  co: ["type:name"]  # Co-occurring entities
```

## Output

Append to `~/.mnemos/vault/memory/daily/YYYY-MM-DD.md`

## Skip

- Trivial Q&A exchanges
- Information already captured
- Temporary/session-specific details
```

### 3.2 `~/.openclaw/skills/mnemos/consolidate/SKILL.md`

```markdown
---
name: consolidate
description: Promote observations to permanent notes
triggers:
  - /consolidate
  - promote observations
---

# Consolidate — Observation to Knowledge

Promote observations from daily logs to permanent notes.

## Dual-Path Routing

### Reference Path (auto-promote)
Types: person, tool, decision, open-question
- Create note directly in `~/.mnemos/vault/notes/`
- No threshold needed

### Pipeline Path (threshold-based)
Types: insight, pattern, workflow
- Promote when: importance >= 0.8 OR surprise >= 0.7

## Note Format

```markdown
---
description: One sentence expanding on title
topics: []
source: "observation YYYY-MM-DD"
confidence: supported | likely | experimental
category: insight | pattern | workflow | tool | person | decision
---

Content with [[wiki-links]] to related notes.
```
```

### 3.3 `~/.openclaw/skills/mnemos/recall/SKILL.md`

```markdown
---
name: recall
description: Search vault for relevant knowledge
triggers:
  - /recall
  - what do I know about
  - search memory
---

# Recall — Query the Knowledge Vault

Search mnemos vault for relevant knowledge.

## Usage

/recall [topic or question]

## Search Strategy

1. Search `~/.mnemos/vault/notes/` for matches
2. Search `~/.mnemos/vault/memory/daily/` for recent observations
3. Follow wiki-links from matches

## Output

Return relevant excerpts with source attribution.
```

---

## Step 4: Set Up Scheduled Maintenance

Use OpenClaw's built-in cron system:

### 4.1 Daily maintenance (9 AM)

```bash
openclaw cron add \
  --name "mnemos-daily" \
  --cron "0 9 * * *" \
  --session isolated \
  --message "/observe && /consolidate"
```

### 4.2 Weekly synthesis (Sunday 3 AM)

```bash
openclaw cron add \
  --name "mnemos-weekly" \
  --cron "0 3 * * 0" \
  --session isolated \
  --message "/dream --weekly"
```

To verify cron jobs:

```bash
openclaw cron list
```

---

## Step 5: Verify Installation

Check these exist:

```
~/.openclaw/hooks/mnemos/
├── HOOK.yaml
└── handler.js

~/.openclaw/skills/mnemos/
├── observe/SKILL.md
├── consolidate/SKILL.md
└── recall/SKILL.md

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
│   └── config.yaml
├── inbox/
└── templates/
```

---

## Step 6: Tell the User

**Say this to the user:**

---

**mnemos installed successfully!**

I've set up:
- Hook to capture our conversations
- Skills: `/observe`, `/consolidate`, `/recall`
- Vault at `~/.mnemos/vault/`
- Daily cron job for maintenance

**To activate the hook, restart the gateway:**

```bash
openclaw gateway restart
```

**After restart, I'll automatically capture our sessions.**

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/recall [topic]` — Search your knowledge vault

**Manage cron jobs:**
```bash
openclaw cron list
openclaw cron run mnemos-daily  # Run now
```

---

## Installation Complete

Remind the user to restart the gateway.
