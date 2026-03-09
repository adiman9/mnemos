# mnemos for OpenCode — Agent Installation Guide

You are installing mnemos, a 3-layer memory system that grows a persistent knowledge vault from your conversations.

**Important**: Follow these steps exactly using your file editing capabilities.

---

## Overview

You will install:
- **Plugin** (`.opencode/plugins/mnemos-plugin.ts`) — TypeScript plugin for hooks
- **Scripts** (`.mnemos/hooks/scripts/`) — Shell scripts for hook execution
- **Skills** (`AGENTS.md`) — Instructions for /observe, /consolidate, /recall
- **Vault** (`~/.mnemos/vault/`) — Persistent knowledge storage
- **Config** (`.mnemos.yaml`) — Points workspace to vault

OpenCode's conversation context handles recent messages. mnemos handles deep, long-term knowledge synthesis.

---

## Step 1: Create the Plugin

Create file `.opencode/plugins/mnemos-plugin.ts`:

```typescript
/**
 * mnemos adapter for OpenCode
 * 
 * Captures session transcripts and integrates with mnemos vault.
 */

import type { Plugin } from "@opencode-ai/plugin";

const TRUNCATE_LIMIT = 2000;

function truncate(value: string): string {
  if (value.length <= TRUNCATE_LIMIT) return value;
  return `${value.slice(0, TRUNCATE_LIMIT)}[truncated]`;
}

type TranscriptLine = {
  ts: string;
  role: "user" | "assistant" | "tool_use" | "tool_result" | "compaction_boundary";
  content: string;
  session_id: string;
  tool?: string;
};

export default (async (input) => {
  const { $, directory } = input;
  const scriptsDir = `${directory}/.mnemos/hooks/scripts`;
  const configPath = `${directory}/.mnemos.yaml`;

  const configExists = await Bun.file(configPath).exists();
  if (!configExists) {
    console.log("[mnemos] No .mnemos.yaml found, plugin inactive");
    return {};
  }

  const configText = await Bun.file(configPath).text();
  const vaultMatch = configText.match(/^\s*vault_path:\s*(.+)\s*$/m);
  const defaultVault = `${process.env.HOME}/.mnemos/vault`;
  const vaultPath = vaultMatch
    ? vaultMatch[1].trim().replace(/^['"]|['"]$/g, "")
    : defaultVault;

  if (!vaultPath) {
    console.error("[mnemos] No vault_path in .mnemos.yaml");
    return {};
  }

  const sessionsDir = `${vaultPath}/memory/sessions`;
  const cursorsPath = `${sessionsDir}/.cursors.json`;
  await $`mkdir -p ${sessionsDir}`.quiet();

  type CursorEntry = { offset: number; observed_offset: number; last_capture: string };
  type Cursors = Record<string, CursorEntry>;

  async function readCursors(): Promise<Cursors> {
    try {
      const f = Bun.file(cursorsPath);
      if (!(await f.exists())) return {};
      const text = await f.text();
      if (!text.trim()) return {};
      return JSON.parse(text) as Cursors;
    } catch {
      return {};
    }
  }

  async function writeCursors(cursors: Cursors) {
    await Bun.write(cursorsPath, JSON.stringify(cursors));
  }

  async function readExistingLines(sessionID: string): Promise<TranscriptLine[]> {
    try {
      const f = Bun.file(`${sessionsDir}/${sessionID}.jsonl`);
      if (!(await f.exists())) return [];
      const text = await f.text();
      return text
        .split("\n")
        .filter((l) => l.trim())
        .map((l) => JSON.parse(l) as TranscriptLine);
    } catch {
      return [];
    }
  }

  async function appendLines(sessionID: string, lines: TranscriptLine[]) {
    if (lines.length === 0) return;
    const path = `${sessionsDir}/${sessionID}.jsonl`;
    const existing = await (async () => {
      try {
        const f = Bun.file(path);
        if (await f.exists()) return await f.text();
        return "";
      } catch {
        return "";
      }
    })();
    const payload = existing + lines.map((l) => JSON.stringify(l)).join("\n") + "\n";
    await Bun.write(path, payload);
  }

  async function ensureMeta(sessionID: string) {
    const metaPath = `${sessionsDir}/${sessionID}.meta.json`;
    if (await Bun.file(metaPath).exists()) return;
    await Bun.write(
      metaPath,
      JSON.stringify({
        session_id: sessionID,
        harness: "opencode",
        start_time: new Date().toISOString(),
        vault_path: vaultPath,
      }) + "\n"
    );
  }

  function lineFingerprint(line: TranscriptLine): string {
    return `${line.role}|${line.tool ?? ""}|${line.content.slice(0, 200)}`;
  }

  const writeQueues = new Map<string, Promise<void>>();

  function enqueue(sessionID: string, work: () => Promise<void>): void {
    const prev = writeQueues.get(sessionID) ?? Promise.resolve();
    const next = prev.catch(() => {}).then(work).catch((e) => {
      console.error("[mnemos] transcript write failed:", e);
    });
    writeQueues.set(sessionID, next);
  }

  async function processMessages(sessionID: string, messages: Array<{ info: any; parts: any[] }>): Promise<number> {
    await ensureMeta(sessionID);
    const existing = await readExistingLines(sessionID);
    const existingFPs = new Set(existing.map(lineFingerprint));
    const newLines: TranscriptLine[] = [];

    for (const msg of messages) {
      if (!msg || typeof msg !== "object") continue;
      const info = msg.info ?? msg;
      const parts: any[] = Array.isArray(msg.parts) ? msg.parts : [];
      const role = String(info?.role ?? "").toLowerCase();
      const msgTime = info?.time?.created
        ? new Date(info.time.created).toISOString()
        : new Date().toISOString();

      if (role === "user" || role === "assistant") {
        const textParts = parts
          .filter((p: any) => p?.type === "text" && typeof p?.text === "string")
          .map((p: any) => p.text as string);
        const content = textParts.join("\n");
        if (!content) continue;

        const line: TranscriptLine = {
          ts: msgTime,
          role: role as "user" | "assistant",
          content: truncate(content),
          session_id: sessionID,
        };
        if (!existingFPs.has(lineFingerprint(line))) {
          newLines.push(line);
          existingFPs.add(lineFingerprint(line));
        }
      }

      for (const part of parts) {
        if (part?.type !== "tool" || !part?.tool) continue;
        const state = part.state;
        if (!state) continue;
        const toolName = String(part.tool);

        const inputContent = (() => {
          if (state.input && typeof state.input === "object") {
            try { return JSON.stringify(state.input); } catch { return ""; }
          }
          return state.raw ?? "";
        })();
        if (inputContent) {
          const useLine: TranscriptLine = {
            ts: state.time?.start ? new Date(state.time.start).toISOString() : msgTime,
            role: "tool_use",
            content: truncate(inputContent),
            tool: toolName,
            session_id: sessionID,
          };
          if (!existingFPs.has(lineFingerprint(useLine))) {
            newLines.push(useLine);
            existingFPs.add(lineFingerprint(useLine));
          }
        }

        if ((state.status === "completed" || state.status === "error") && (state.output || state.error)) {
          const outputContent = state.output ?? state.error ?? "";
          const resultLine: TranscriptLine = {
            ts: state.time?.end ? new Date(state.time.end).toISOString() : msgTime,
            role: "tool_result",
            content: truncate(outputContent),
            tool: toolName,
            session_id: sessionID,
          };
          if (!existingFPs.has(lineFingerprint(resultLine))) {
            newLines.push(resultLine);
            existingFPs.add(lineFingerprint(resultLine));
          }
        }
      }
    }

    if (newLines.length > 0) {
      await appendLines(sessionID, newLines);
      const cursors = await readCursors();
      const cur = cursors[sessionID] ?? { offset: 0, observed_offset: 0, last_capture: "" };
      cursors[sessionID] = {
        offset: existing.length + newLines.length,
        observed_offset: cur.observed_offset,
        last_capture: new Date().toISOString(),
      };
      await writeCursors(cursors);
    }

    return newLines.length;
  }

  let lastSessionID = "";

  return {
    "experimental.chat.system.transform": async (_input, output) => {
      try {
        const result = await $`bash ${scriptsDir}/session-start.sh`.quiet();
        if (result.stdout.toString().trim()) {
          output.system.push(
            `\n\n<!-- mnemos boot context -->\n${result.stdout.toString()}\n<!-- /mnemos boot context -->`
          );
        }
      } catch (e) {
        console.error("[mnemos] session-start hook failed:", e);
      }
    },

    "experimental.chat.messages.transform": async (_input, output) => {
      const messages = output?.messages;
      if (!Array.isArray(messages) || messages.length === 0) return;

      const firstMsg = messages[0];
      const sessionID = firstMsg?.info?.sessionID ?? firstMsg?.parts?.[0]?.sessionID ?? "";
      if (!sessionID) return;

      lastSessionID = sessionID;
      enqueue(sessionID, () => processMessages(sessionID, messages));
    },

    "chat.message": async (messageInput, _output) => {
      lastSessionID = messageInput.sessionID ?? lastSessionID;
    },

    "tool.execute.after": async (toolInput, _output) => {
      if (toolInput.tool !== "write" && toolInput.tool !== "edit") return;
      const filePath = toolInput.args?.filePath || toolInput.args?.file_path;
      if (!filePath) return;

      try {
        const result = await $`CLAUDE_TOOL_INPUT_FILE_PATH=${filePath} bash ${scriptsDir}/validate-note.sh`.quiet();
        if (result.stdout.toString().trim()) {
          console.log("[mnemos] validate:", result.stdout.toString().trim());
        }
      } catch {
        // non-fatal
      }
    },

    "experimental.session.compacting": async (compactingInput, _output) => {
      const sessionID = compactingInput.sessionID;
      if (!sessionID) return;

      try {
        const boundary: TranscriptLine = {
          ts: new Date().toISOString(),
          role: "compaction_boundary",
          content: "Context compacted by harness",
          session_id: sessionID,
        };
        await appendLines(sessionID, [boundary]);
        const cursors = await readCursors();
        cursors[sessionID] = {
          offset: 0,
          observed_offset: 0,
          last_capture: new Date().toISOString(),
        };
        await writeCursors(cursors);
      } catch (e) {
        console.error("[mnemos] pre-compaction flush failed:", e);
      }
    },
  };
}) satisfies Plugin;
```

---

## Step 2: Create Hook Scripts

### 2.1 Create session-start.sh

Create file `.mnemos/hooks/scripts/session-start.sh`:

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

# Show boot context
if [ -f "$VAULT/memory/MEMORY.md" ]; then
  echo ""
  cat "$VAULT/memory/MEMORY.md"
fi
```

### 2.2 Create validate-note.sh

Create file `.mnemos/hooks/scripts/validate-note.sh`:

```bash
#!/bin/bash
# Validate note files match mnemos schema

set -euo pipefail

FILE_PATH="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
VAULT="${MNEMOS_VAULT:-$HOME/.mnemos/vault}"

# Only validate files in notes/
if [[ ! "$FILE_PATH" =~ /notes/ ]]; then
  exit 0
fi

# Check frontmatter exists
if ! head -1 "$FILE_PATH" | grep -q "^---"; then
  echo "Warning: Note missing frontmatter: $FILE_PATH"
fi
```

Make scripts executable:

```bash
chmod +x .mnemos/hooks/scripts/*.sh
```

---

## Step 3: Create Configuration

### 3.1 Create .mnemos.yaml in workspace root

```yaml
# mnemos configuration
vault_path: ~/.mnemos/vault
```

### 3.2 Update opencode.json

Add the plugin to your `opencode.json`:

```json
{
  "plugin": ["./.opencode/plugins/mnemos-plugin.ts"]
}
```

If you already have plugins, add to the existing array.

---

## Step 4: Initialize the Vault

Create the vault structure:

```bash
VAULT="$HOME/.mnemos/vault"
mkdir -p "$VAULT"/{self,notes,memory/{daily,sessions,.dreams},ops/{queue,logs},inbox,templates}
```

### 4.1 Create identity.md

Create file `~/.mnemos/vault/self/identity.md`:

```markdown
# Identity

Who you are and how you work. Update as you develop preferences.

## Core Identity

[Describe your role and working style]

## Working Preferences

[Capture preferences discovered through experience]
```

### 4.2 Create goals.md

Create file `~/.mnemos/vault/self/goals.md`:

```markdown
# Goals

## Active

[Current objectives]

## Completed

[Recently finished]

## Parked

[On hold — with reason]
```

### 4.3 Create MEMORY.md

Create file `~/.mnemos/vault/memory/MEMORY.md`:

```markdown
# Memory Boot Context

No observations yet. Run /observe after a few sessions to begin capturing insights.
```

### 4.4 Create config.yaml

Create file `~/.mnemos/vault/ops/config.yaml`:

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

## Step 5: Add Skills to AGENTS.md

Create or append to `AGENTS.md` in the workspace root:

```markdown
# mnemos Skills

## /observe — Extract Learning from Sessions

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

## /consolidate — Promote Observations to Notes

Move observations from daily logs to permanent notes.

**Reference types** (person, tool, decision, open-question): Auto-promote all.
**Pipeline types** (insight, pattern, workflow): Promote when importance >= 0.8 OR surprise >= 0.7.

**Output:** Create notes in `~/.mnemos/vault/notes/` with wiki-links.

## /recall [topic] — Search Knowledge Vault

Search `~/.mnemos/vault/notes/` and `~/.mnemos/vault/memory/daily/` for relevant knowledge.

Return excerpts with source attribution.

## /dream — Speculative Connections

Find cross-domain parallels between vault notes. Output to `~/.mnemos/vault/memory/.dreams/`.
```

---

## Step 6: Set Up Scheduled Maintenance (Optional)

Use system scheduler for background maintenance.

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
        <string>cd ~/.mnemos/vault && opencode --print "Run /observe && /consolidate" 2>/dev/null || true</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.mnemos.daily.plist
```

### Linux (cron)

```bash
(crontab -l 2>/dev/null; echo "0 9 * * * cd ~/.mnemos/vault && opencode --print '/observe && /consolidate' >> ~/.mnemos/vault/ops/logs/daily.log 2>&1") | crontab -
```

---

## Step 7: Verify Installation

Check these exist:

```
<workspace>/
├── .opencode/
│   └── plugins/
│       └── mnemos-plugin.ts
├── .mnemos/
│   ├── hooks/
│   │   └── scripts/
│   │       ├── session-start.sh
│   │       └── validate-note.sh
│   └── .mnemos.yaml
├── opencode.json (with plugin reference)
└── AGENTS.md (with mnemos skills)

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

## Step 8: Tell the User

**Say this to the user:**

---

**mnemos installed successfully!**

I've set up:
- Plugin at `.opencode/plugins/mnemos-plugin.ts`
- Hook scripts at `.mnemos/hooks/scripts/`
- Vault at `~/.mnemos/vault/`
- Skills documented in `AGENTS.md`

**Restart OpenCode to load the plugin.**

**Quick commands:**
- `/observe` — Extract insights from recent sessions
- `/consolidate` — Promote observations to permanent notes
- `/recall [topic]` — Search your knowledge vault

The vault grows silently in the background as we work together.

---

## Installation Complete

The plugin will begin capturing automatically after restart.
