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

HARNESS="claude-code"

if [ -n "$TRANSCRIPT_PATH" ] && [[ "$TRANSCRIPT_PATH" == *"/.cursor/"* ]]; then
    HARNESS="cursor"
    CURSOR_SESSION_ID=$(basename "$TRANSCRIPT_PATH" .jsonl)
    if [ -n "$CURSOR_SESSION_ID" ]; then
        SESSION_ID="$CURSOR_SESSION_ID"
    fi
fi

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

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    ENCODED_PATH=$(printf '%s' "$WORKSPACE_ROOT" | sed 's|^/||; s|/|-|g')
    CURSOR_TRANSCRIPTS_DIR="$HOME/.cursor/projects/${ENCODED_PATH}/agent-transcripts"
    if [ -d "$CURSOR_TRANSCRIPTS_DIR" ]; then
        LATEST=$(ls -t "$CURSOR_TRANSCRIPTS_DIR/"*"/"*".jsonl" 2>/dev/null | head -1)
        if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
            TRANSCRIPT_PATH="$LATEST"
            HARNESS="cursor"
            SESSION_ID=$(basename "$LATEST" .jsonl)
        fi
    fi
fi

[ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ] || exit 0

SESSIONS_DIR="$VAULT_PATH/memory/sessions"
CURSOR_FILE="$SESSIONS_DIR/.cursors.json"
OUTPUT_FILE="$SESSIONS_DIR/${SESSION_ID}.jsonl"
META_FILE="$SESSIONS_DIR/${SESSION_ID}.meta.json"

mkdir -p "$SESSIONS_DIR"
[ -f "$CURSOR_FILE" ] || printf '{}\n' > "$CURSOR_FILE"

python3 - "$TRANSCRIPT_PATH" "$SESSIONS_DIR" "$SESSION_ID" "$CURSOR_FILE" "$META_FILE" "$HARNESS" << 'PYEOF'
import json, sys, os
from datetime import datetime, timezone

transcript_path = sys.argv[1]
sessions_dir = sys.argv[2]
session_id = sys.argv[3]
cursor_file = sys.argv[4]
meta_file = sys.argv[5]
harness = sys.argv[6]
output_file = os.path.join(sessions_dir, f"{session_id}.jsonl")
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

native_size = os.path.getsize(transcript_path)
if offset > native_size:
    offset = 0

if not os.path.isfile(meta_file):
    with open(meta_file, "w") as f:
        json.dump({"session_id": session_id, "harness": harness,
                    "start_time": iso_now(), "vault_path": sessions_dir.rsplit("/memory/sessions", 1)[0]}, f)
        f.write("\n")

if offset >= native_size:
    sys.exit(0)

with open(transcript_path, "rb") as f:
    f.seek(offset)
    new_data = f.read()

lines = new_data.decode("utf-8", errors="replace").splitlines()
output_lines = []

def truncate(s):
    return s[:max_content] + "[truncated]" if len(s) > max_content else s

def extract_text(content_raw):
    if isinstance(content_raw, str):
        return content_raw
    if isinstance(content_raw, list):
        parts = [p.get("text", "") for p in content_raw if isinstance(p, dict) and p.get("type") == "text"]
        return "\n".join(p for p in parts if p)
    return ""

for raw_line in lines:
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

    top_role = obj.get("role", "")
    msg_role = msg.get("role", "")
    content_raw = msg.get("content", "")

    if line_type:
        role = msg_role
        is_user = line_type == "user" and role == "user"
        is_assistant = line_type == "assistant" and role == "assistant"
        is_tool_result = line_type == "tool_result"
    else:
        role = top_role
        is_user = role == "user"
        is_assistant = role == "assistant"
        is_tool_result = role == "tool_result"

    if is_user:
        content = extract_text(content_raw)
        if not content:
            continue
        output_lines.append(json.dumps({"ts": ts, "role": "user", "content": truncate(content), "session_id": session_id}))

    elif is_assistant:
        if isinstance(content_raw, list):
            text_parts = [p.get("text", "") for p in content_raw if isinstance(p, dict) and p.get("type") == "text"]
            tool_parts = [p for p in content_raw if isinstance(p, dict) and p.get("type") == "tool_use"]
        elif isinstance(content_raw, str):
            text_parts = [content_raw] if content_raw else []
            tool_parts = []
        else:
            continue

        text_content = "\n".join(t for t in text_parts if t)
        if text_content:
            output_lines.append(json.dumps({"ts": ts, "role": "assistant", "content": truncate(text_content), "session_id": session_id}))

        for tp in tool_parts:
            tool_name = tp.get("name", "unknown")
            tool_input = json.dumps(tp.get("input", {}))
            output_lines.append(json.dumps({"ts": ts, "role": "tool_use", "content": truncate(tool_input), "tool": tool_name, "session_id": session_id}))

    elif is_tool_result:
        content = extract_text(content_raw)
        if not content:
            continue
        tool_name = obj.get("tool_name", msg.get("name", ""))
        out = {"ts": ts, "role": "tool_result", "content": truncate(content), "session_id": session_id}
        if tool_name:
            out["tool"] = tool_name
        output_lines.append(json.dumps(out))

if output_lines:
    with open(output_file, "a") as f:
        for ol in output_lines:
            f.write(ol + "\n")

entry["offset"] = native_size
entry["last_capture"] = iso_now()
if "observed_offset" not in entry:
    entry["observed_offset"] = 0
cursors[session_id] = entry

with open(cursor_file, "w") as f:
    json.dump(cursors, f)
    f.write("\n")
PYEOF

exit 0
