---
name: mnemos-openclaw
description: "3-layer memory system - working memory capture, long-term knowledge curation, and cross-domain dream generation"
metadata:
  openclaw:
    emoji: "🧠"
    events:
      - gateway:startup
      - message:received
      - message:sent
      - command:new
      - agent:bootstrap
      - session:compact:before
    requires:
      - bash
---

# mnemos Hook

Integrates mnemos memory system into OpenClaw for persistent knowledge capture and synthesis across sessions.

## What It Does

### On Gateway Startup (`gateway:startup`)
- Runs `session-start.sh`
- Injects boot context from `memory/MEMORY.md` into the initial session
- Initializes vault state and loads agent identity from `self/identity.md`
- Prepares working memory for the session

### On Message Received (`message:received`)
- Fires when an inbound message arrives from any channel
- Captures user message to `memory/sessions/{session-id}.jsonl`
- Uses inline capture logic for reliability in managed hook installs

### On Message Sent (`message:sent`)
- Fires when an outbound message is sent to the user
- Captures assistant response to `memory/sessions/{session-id}.jsonl`
- Uses inline capture logic for reliability in managed hook installs

### On Command: /new (`command:new`)
- Runs `session-capture.sh`
- Creates a pre-reset checkpoint before session context is cleared
- Captures current session transcript to `memory/sessions/`
- Ensures continuity across command resets

### On Agent Bootstrap (`agent:bootstrap`)
- Runs `session-start.sh`
- Equivalent to gateway startup for session initialization
- Injects MEMORY.md context and loads agent identity
- Prepares vault for the session

### On Session Compact Before (`session:compact:before`)
- Runs `pre-compact.sh`
- Safety flush of working memory before context compaction
- Ensures no observations are lost during context cleanup
- Writes incremental session state to disk

## Installation

```bash
openclaw hooks install mnemos-openclaw
openclaw hooks enable mnemos-openclaw

# Verify
openclaw hooks list --verbose
openclaw hooks info mnemos-openclaw
openclaw hooks check
```

After enabling, restart your OpenClaw gateway process so hook registration reloads.

## Requirements

- Bash shell
- mnemos vault initialized (via `./install.sh --vault-only`)
- `.mnemos.yaml` configured in workspace or vault root

## Vault Integration

mnemos stores memory in three layers:

- **Layer 1 (Working Memory)**: Session transcripts and daily observations in `memory/`
- **Layer 2 (Long-Term Knowledge)**: Curated atomic insights in `notes/` connected by wiki-links
- **Layer 3 (Dream)**: Speculative cross-domain connections in `memory/.dreams/`

Hook events trigger capture and consolidation of these layers. Use skills like `/observe`, `/consolidate`, `/reflect`, and `/dream` to process and synthesize memory.

## Configuration

Configure mnemos via `ops/config.yaml` in your vault:

```yaml
vault_path: ~/.mnemos/vault
capture:
  enabled: true
  transcript_format: jsonl
consolidation:
  enabled: true
  daily_schedule: "09:00"
```

## Troubleshooting

If `openclaw hooks enable mnemos-openclaw` fails with hook-not-found, run `openclaw hooks install mnemos-openclaw` first and verify discovery with `openclaw hooks list --verbose`.

For vault path resolution issues, ensure `.mnemos.yaml` exists in your workspace or vault root with `vault_path` set.
