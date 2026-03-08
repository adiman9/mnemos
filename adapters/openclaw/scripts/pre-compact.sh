#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

# Support MNEMOS_VAULT env var for vault-only mode (e.g. OpenClaw, no .mnemos.yaml)
if [ -n "${MNEMOS_VAULT:-}" ]; then
    VAULT_PATH="$MNEMOS_VAULT"
else
    [ -f "$MNEMOS_CONFIG" ] || exit 0
    VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
    [ -n "$VAULT_PATH" ] || VAULT_PATH="$HOME/.mnemos/vault"
fi
[ -d "$VAULT_PATH" ] || exit 0

PAYLOAD=""
if read -t 1 -r PAYLOAD 2>/dev/null; then
    true
fi

TRANSCRIPT_PATH=""
STDIN_SESSION_ID=""
if [ -n "$PAYLOAD" ]; then
    TRANSCRIPT_PATH=$(printf '%s' "$PAYLOAD" | sed -n 's/.*"transcript_path" *: *"\([^"]*\)".*/\1/p')
    STDIN_SESSION_ID=$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p')
fi

SESSION_ID="${STDIN_SESSION_ID:-${CLAUDE_SESSION_ID:-${CLAUDE_CONVERSATION_ID:-$(date +%Y%m%d-%H%M%S)}}}"

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    for candidate in \
        "$HOME/.claude/projects/"*"/sessions/${SESSION_ID}.jsonl" \
        "$HOME/.claude/projects/"*"/transcript.jsonl"; do
        if [ -f "$candidate" ]; then
            TRANSCRIPT_PATH="$candidate"
            break
        fi
    done
fi

[ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ] || exit 0

SESSIONS_DIR="$VAULT_PATH/memory/sessions"
CURSOR_FILE="$SESSIONS_DIR/.cursors.json"
OUTPUT_FILE="$SESSIONS_DIR/${SESSION_ID}.jsonl"
META_FILE="$SESSIONS_DIR/${SESSION_ID}.meta.json"

mkdir -p "$SESSIONS_DIR"
[ -f "$CURSOR_FILE" ] || printf '{}\n' > "$CURSOR_FILE"

python3 - "$TRANSCRIPT_PATH" "$SESSIONS_DIR" "$SESSION_ID" "$CURSOR_FILE" "$META_FILE" "$OUTPUT_FILE" << 'PYEOF'
import json, sys, os, hashlib
from datetime import datetime, timezone

transcript_path = sys.argv[1]
sessions_dir = sys.argv[2]
session_id = sys.argv[3]
cursor_file = sys.argv[4]
meta_file = sys.argv[5]
output_file = sys.argv[6]
max_content = 2000

def iso_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def content_hash(line_dict):
    d = {k: v for k, v in line_dict.items() if k != "ts"}
    return hashlib.md5(json.dumps(d, sort_keys=True).encode()).hexdigest()

if not os.path.isfile(meta_file):
    with open(meta_file, "w") as f:
        json.dump({"session_id": session_id, "harness": "claude-code",
                    "start_time": iso_now(), "vault_path": sessions_dir.rsplit("/memory/sessions", 1)[0]}, f)
        f.write("\n")

existing_hashes = set()
if os.path.isfile(output_file):
    with open(output_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                existing_hashes.add(content_hash(json.loads(line)))
            except (json.JSONDecodeError, TypeError):
                pass

with open(transcript_path) as f:
    raw_lines = f.readlines()

new_lines = []
for raw_line in raw_lines:
    raw_line = raw_line.strip()
    if not raw_line:
        continue
    try:
        obj = json.loads(raw_line)
    except json.JSONDecodeError:
        continue

    line_type = obj.get("type", "")
    ts = obj.get("timestamp", iso_now())
    msg = obj.get("message", {})
    if not isinstance(msg, dict):
        continue

    role = msg.get("role", "")
    content_raw = msg.get("content", "")

    if line_type == "user" and role == "user":
        content = content_raw if isinstance(content_raw, str) else ""
        if isinstance(content_raw, list):
            parts = [p.get("text", "") for p in content_raw if isinstance(p, dict) and p.get("type") == "text"]
            content = "\n".join(parts)
        if not content:
            continue
        if len(content) > max_content:
            content = content[:max_content] + "[truncated]"
        entry = {"ts": ts, "role": "user", "content": content, "session_id": session_id}
        h = content_hash(entry)
        if h not in existing_hashes:
            new_lines.append(json.dumps(entry))
            existing_hashes.add(h)

    elif line_type == "assistant" and role == "assistant":
        if not isinstance(content_raw, list):
            continue
        text_parts = [p.get("text", "") for p in content_raw if isinstance(p, dict) and p.get("type") == "text"]
        tool_parts = [p for p in content_raw if isinstance(p, dict) and p.get("type") == "tool_use"]

        text_content = "\n".join(t for t in text_parts if t)
        if text_content:
            if len(text_content) > max_content:
                text_content = text_content[:max_content] + "[truncated]"
            entry = {"ts": ts, "role": "assistant", "content": text_content, "session_id": session_id}
            h = content_hash(entry)
            if h not in existing_hashes:
                new_lines.append(json.dumps(entry))
                existing_hashes.add(h)

        for tp in tool_parts:
            tool_name = tp.get("name", "unknown")
            tool_input = json.dumps(tp.get("input", {}))
            if len(tool_input) > max_content:
                tool_input = tool_input[:max_content] + "[truncated]"
            entry = {"ts": ts, "role": "tool_use", "content": tool_input, "tool": tool_name, "session_id": session_id}
            h = content_hash(entry)
            if h not in existing_hashes:
                new_lines.append(json.dumps(entry))
                existing_hashes.add(h)

    elif line_type == "tool_result":
        content = ""
        if isinstance(content_raw, str):
            content = content_raw
        elif isinstance(content_raw, list):
            parts = [p.get("text", "") for p in content_raw if isinstance(p, dict)]
            content = "\n".join(parts)
        if not content:
            continue
        if len(content) > max_content:
            content = content[:max_content] + "[truncated]"
        tool_name = obj.get("tool_name", msg.get("name", ""))
        entry = {"ts": ts, "role": "tool_result", "content": content, "session_id": session_id}
        if tool_name:
            entry["tool"] = tool_name
        h = content_hash(entry)
        if h not in existing_hashes:
            new_lines.append(json.dumps(entry))
            existing_hashes.add(h)

if new_lines:
    with open(output_file, "a") as f:
        for nl in new_lines:
            f.write(nl + "\n")

boundary = json.dumps({"ts": iso_now(), "role": "compaction_boundary",
                        "content": "Context compacted by harness", "session_id": session_id})
with open(output_file, "a") as f:
    f.write(boundary + "\n")

cursors = {}
if os.path.isfile(cursor_file):
    try:
        with open(cursor_file) as f:
            cursors = json.load(f)
    except (json.JSONDecodeError, IOError):
        cursors = {}

cursors[session_id] = {"offset": 0, "observed_offset": 0, "last_capture": iso_now()}
with open(cursor_file, "w") as f:
    json.dump(cursors, f)
    f.write("\n")
PYEOF

exit 0
