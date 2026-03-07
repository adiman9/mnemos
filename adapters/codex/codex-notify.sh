#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
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
