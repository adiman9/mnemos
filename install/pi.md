# mnemos for Pi Framework — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly. Use your native tools as shown.

**Note**: Pi is the engine behind OpenClaw, Graphone, and other agents. This installer works for any Pi-based agent.

---

## Overview

You will install:
- **Extension** (`.pi/extensions/`) — TypeScript extension for lifecycle hooks
- **Hook Scripts** (`.mnemos/hooks/scripts/`) — Shell scripts for capture and validation
- **Skills** (`.claude/skills/`) — /observe, /consolidate, /recall for knowledge management
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **CLAUDE.md / AGENTS.md** — System instructions for mnemos awareness

Pi has full hook coverage — all 4 mnemos lifecycle events are natively supported.

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

## Step 3: Create the Hook Scripts

### 3.1 Create scripts directory

```bash
mkdir -p <workspace>/.mnemos/hooks/scripts
```

### 3.2 Create session-start.sh

**Path**: `<workspace>/.mnemos/hooks/scripts/session-start.sh`

```bash
#!/usr/bin/env bash
# mnemos session-start hook for Pi framework
# Outputs boot context to stdout for system prompt injection

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

[ -f "$MNEMOS_CONFIG" ] || exit 0

VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
[ -n "$VAULT_PATH" ] || VAULT_PATH="$HOME/.mnemos/vault"
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

[ -d "$VAULT_PATH" ] || exit 0

# Build context string
echo "=== mnemos Session Start ==="
echo "Vault: $VAULT_PATH"
echo ""

# Vault stats
NOTES_COUNT=$( (find "$VAULT_PATH/notes" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')
INBOX_COUNT=$( (find "$VAULT_PATH/inbox" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')
DAILY_COUNT=$( (find "$VAULT_PATH/memory/daily" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')

echo "--- Vault Stats ---"
echo "Notes: $NOTES_COUNT | Inbox: $INBOX_COUNT | Daily logs: $DAILY_COUNT"
echo ""

# Inject MEMORY.md
MEMORY_FILE="$VAULT_PATH/memory/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
    echo "--- Boot Context (MEMORY.md) ---"
    cat "$MEMORY_FILE"
    echo ""
fi

# Ensure session directories exist
mkdir -p "$VAULT_PATH/memory/sessions"
mkdir -p "$VAULT_PATH/memory/daily"

echo "--- Ready ---"
echo "Read self/goals.md and self/identity.md to orient."

exit 0
```

### 3.3 Create validate-note.sh

**Path**: `<workspace>/.mnemos/hooks/scripts/validate-note.sh`

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

FILE_PATH="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
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

### 3.4 Create auto-commit.sh

**Path**: `<workspace>/.mnemos/hooks/scripts/auto-commit.sh`

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

Make scripts executable:

```bash
chmod +x <workspace>/.mnemos/hooks/scripts/*.sh
```

---

## Step 4: Create the Pi Extension

### 4.1 Create extensions directory

```bash
mkdir -p <workspace>/.pi/extensions
```

### 4.2 Create mnemos-extension.ts

**Path**: `<workspace>/.pi/extensions/mnemos-extension.ts`

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-agent-core";
import { readFileSync, writeFileSync, appendFileSync, mkdirSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";

const SCRIPTS_DIR = ".mnemos/hooks/scripts";
const MAX_CONTENT = 2000;

interface CaptureState {
  vaultPath: string;
  sessionsDir: string;
  sessionId: string;
  outputFile: string;
  cursorFile: string;
  metaFile: string;
}

let capture: CaptureState | null = null;

function isoNow(): string {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function truncate(s: string, max = MAX_CONTENT): string {
  return s.length > max ? s.slice(0, max) + "[truncated]" : s;
}

function resolveVaultPath(cwd: string): string | null {
  const defaultVault = join(process.env.HOME || "", ".mnemos", "vault");
  const configPath = join(cwd, ".mnemos.yaml");
  if (!existsSync(configPath)) {
    return existsSync(defaultVault) ? defaultVault : null;
  }
  const content = readFileSync(configPath, "utf-8");
  const match = content.match(/^vault_path:\s*["']?(.+?)["']?\s*$/m);
  let vaultPath = match ? match[1].trim() : defaultVault;
  if (vaultPath.startsWith("~")) {
    vaultPath = vaultPath.replace("~", process.env.HOME || "");
  }
  if (!vaultPath.startsWith("/")) {
    vaultPath = resolve(cwd, vaultPath);
  }
  return existsSync(vaultPath) ? vaultPath : null;
}

function ensureCapture(ctx: { cwd: string; sessionManager: { getSessionId(): string } }): boolean {
  if (capture) return true;

  const vaultPath = resolveVaultPath(ctx.cwd);
  if (!vaultPath) return false;

  const sessionId = ctx.sessionManager.getSessionId();
  if (!sessionId) return false;

  const sessionsDir = join(vaultPath, "memory", "sessions");
  mkdirSync(sessionsDir, { recursive: true });

  const cursorFile = join(sessionsDir, ".cursors.json");
  if (!existsSync(cursorFile)) writeFileSync(cursorFile, "{}\n");

  const metaFile = join(sessionsDir, `${sessionId}.meta.json`);
  if (!existsSync(metaFile)) {
    writeFileSync(
      metaFile,
      JSON.stringify({
        session_id: sessionId,
        harness: "pi",
        start_time: isoNow(),
        vault_path: vaultPath,
      }) + "\n",
    );
  }

  capture = {
    vaultPath,
    sessionsDir,
    sessionId,
    outputFile: join(sessionsDir, `${sessionId}.jsonl`),
    cursorFile,
    metaFile,
  };

  return true;
}

function appendEntry(role: string, content: string, extra?: Record<string, unknown>): void {
  if (!capture) return;
  const entry: Record<string, unknown> = {
    ts: isoNow(),
    role,
    content: truncate(content),
    session_id: capture.sessionId,
    ...extra,
  };
  appendFileSync(capture.outputFile, JSON.stringify(entry) + "\n");
}

export default function mnemos(pi: ExtensionAPI) {
  // Session lifecycle
  pi.on("session_start", async (_event, ctx) => {
    ensureCapture(ctx);
  });

  // Boot context injection
  pi.on("before_agent_start", async (event, ctx) => {
    const result = await pi.exec("bash", [`${SCRIPTS_DIR}/session-start.sh`], { cwd: ctx.cwd });
    if (result.stdout) {
      return {
        systemPrompt: event.systemPrompt + "\n\n" + result.stdout,
      };
    }
  });

  // Per-turn transcript capture
  pi.on("input", async (event, ctx) => {
    if (!ensureCapture(ctx)) return;
    if (event.text) {
      appendEntry("user", event.text);
    }
  });

  pi.on("turn_end", async (event, ctx) => {
    if (!ensureCapture(ctx)) return;

    const msg = event.message;
    if (msg?.content) {
      if (Array.isArray(msg.content)) {
        const textParts = msg.content
          .filter((p: any) => p.type === "text" && p.text)
          .map((p: any) => p.text as string);

        const textContent = textParts.join("\n");
        if (textContent) {
          appendEntry("assistant", textContent);
        }

        for (const part of msg.content) {
          if ((part as any).type === "tool_use" && (part as any).name) {
            const toolInput = JSON.stringify((part as any).input || {});
            appendEntry("tool_use", truncate(toolInput), { tool: (part as any).name });
          }
        }
      } else if (typeof msg.content === "string" && msg.content) {
        appendEntry("assistant", msg.content);
      }
    }

    if (event.toolResults?.length) {
      for (const tr of event.toolResults as any[]) {
        let content = "";
        if (typeof tr.content === "string") {
          content = tr.content;
        } else if (Array.isArray(tr.content)) {
          content = tr.content
            .filter((p: any) => p.type === "text")
            .map((p: any) => p.text as string)
            .join("\n");
        }
        if (content) {
          appendEntry("tool_result", truncate(content), {
            tool: tr.name || tr.tool_use_id || "",
          });
        }
      }
    }
  });

  // Post-tool hooks (validate notes, auto-commit)
  pi.on("tool_execution_end", async (event) => {
    const toolName = (event as any).toolName?.toLowerCase();
    if (toolName !== "write" && toolName !== "edit") return;

    const filePath = (event as any).args?.filePath || (event as any).args?.file_path || "";

    await pi.exec("bash", [`${SCRIPTS_DIR}/validate-note.sh`], {
      env: { CLAUDE_TOOL_INPUT_FILE_PATH: filePath },
    });

    pi.exec("bash", [`${SCRIPTS_DIR}/auto-commit.sh`], {
      env: { CLAUDE_TOOL_INPUT_FILE_PATH: filePath },
    });
  });

  // Session shutdown
  pi.on("session_shutdown", async () => {});
}
```

---

## Step 5: Create Skills

Pi reads skills from `.claude/skills/` natively.

### 5.1 Create skills directory

```bash
mkdir -p <workspace>/.claude/skills
```

### 5.2 Create observe.md

**Path**: `<workspace>/.claude/skills/observe.md`

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

### 5.3 Create consolidate.md

**Path**: `<workspace>/.claude/skills/consolidate.md`

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

### 5.4 Create recall.md

**Path**: `<workspace>/.claude/skills/recall.md`

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

**Path**: `<workspace>/.claude/skills/dream.md`

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

## Step 6: Create System Instructions

Pi reads both CLAUDE.md and AGENTS.md. Create both for compatibility:

### 6.1 Create CLAUDE.md

**Path**: `<workspace>/CLAUDE.md`

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

At session start, boot context is injected including:
- Vault statistics
- MEMORY.md contents

Read `self/goals.md` and `self/identity.md` for full context.
```

### 6.2 Create AGENTS.md (copy of CLAUDE.md)

**Path**: `<workspace>/AGENTS.md`

Copy the same content as CLAUDE.md above.

---

## Step 7: Register the Extension

To activate the extension, either:

**Option A**: Pass via CLI when starting Pi:
```bash
pi --extension .pi/extensions/mnemos-extension.ts
```

**Option B**: Add to your Pi config file (if using one):
```json
{
  "extensions": [".pi/extensions/mnemos-extension.ts"]
}
```

---

## Step 8: Verify Installation

Run these checks:

1. **Vault exists**:
   ```bash
   ls ~/.mnemos/vault/
   ```

2. **Extension exists**:
   ```bash
   ls <workspace>/.pi/extensions/mnemos-extension.ts
   ```

3. **Hook scripts exist and are executable**:
   ```bash
   ls -la <workspace>/.mnemos/hooks/scripts/*.sh
   ```

4. **Skills exist**:
   ```bash
   ls <workspace>/.claude/skills/
   ```

5. **Test session-start script**:
   ```bash
   bash <workspace>/.mnemos/hooks/scripts/session-start.sh
   ```
   Should output boot context to stdout.

---

## Hook Coverage

Pi has full hook support:

| mnemos Event | Pi Event | Status |
|--------------|----------|--------|
| Session Start | `session_start` + `before_agent_start` | ✅ Full |
| Per-turn Capture | `input` + `turn_end` | ✅ Full |
| Post-write Validation | `tool_execution_end` | ✅ Full |
| Auto-commit | `tool_execution_end` | ✅ Full |
| Session Shutdown | `session_shutdown` | ✅ Full |

---

## For OpenClaw / Graphone Users

This same installer works for OpenClaw and Graphone since they're built on Pi.

**OpenClaw specifics**:
- OpenClaw has built-in cron. After install, set up scheduled maintenance:
  ```bash
  openclaw cron add --name "mnemos-daily" --cron "0 9 * * *" --session isolated \
    --message "/consolidate && /dream --daily"
  ```

**Graphone specifics**:
- Works identically to Pi. No special configuration needed.

---

## Done!

Tell the user: **"mnemos installed for Pi framework. Start Pi with `--extension .pi/extensions/mnemos-extension.ts` to activate."**

The vault will grow as you work. Use `/observe` periodically to extract insights, `/consolidate` to promote them, and `/recall` to search your knowledge.
