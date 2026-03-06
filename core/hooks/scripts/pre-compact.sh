#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

[ -f "$MNEMOS_CONFIG" ] || exit 0

VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
[ -n "$VAULT_PATH" ] || VAULT_PATH="$WORKSPACE_ROOT"
[ -d "$VAULT_PATH" ] || exit 0

SESSION_ID="${CLAUDE_CONVERSATION_ID:-$(date +%Y%m%d-%H%M%S)}"

PAYLOAD=""
TRANSCRIPT_PATH=""
if read -t 1 -r PAYLOAD 2>/dev/null; then
    TRANSCRIPT_PATH=$(echo "$PAYLOAD" | grep -o '"transcript_path":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    TRANSCRIPT_PATH="$HOME/.claude/transcripts/${SESSION_ID}.jsonl"
fi

[ -f "$TRANSCRIPT_PATH" ] || exit 0

SESSIONS_DIR="$VAULT_PATH/memory/sessions"
CURSOR_FILE="$SESSIONS_DIR/.cursors.json"
OUTPUT_FILE="$SESSIONS_DIR/${SESSION_ID}.jsonl"
META_FILE="$SESSIONS_DIR/${SESSION_ID}.meta.json"

mkdir -p "$SESSIONS_DIR"
[ -f "$CURSOR_FILE" ] || printf '{}\n' > "$CURSOR_FILE"
[ -f "$OUTPUT_FILE" ] || : > "$OUTPUT_FILE"

iso_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

extract_json_string() {
    local key="$1"
    local line="$2"
    printf '%s\n' "$line" | awk -v key="$key" '
    {
        pat = "\"" key "\":\""
        start = index($0, pat)
        if (start == 0) {
            exit
        }
        i = start + length(pat)
        esc = 0
        out = ""
        for (; i <= length($0); i++) {
            c = substr($0, i, 1)
            if (esc == 1) {
                out = out c
                esc = 0
                continue
            }
            if (c == "\\") {
                out = out c
                esc = 1
                continue
            }
            if (c == "\"") {
                print out
                exit
            }
            out = out c
        }
    }'
}

json_escape() {
    printf '%s' "$1" | awk 'BEGIN { first = 1 }
    {
        gsub(/\\/, "\\\\")
        gsub(/"/, "\\\"")
        gsub(/\r/, "\\r")
        gsub(/\t/, "\\t")
        if (first == 1) {
            printf "%s", $0
            first = 0
        } else {
            printf "\\n%s", $0
        }
    }
    END {
        if (NR == 0) {
            printf ""
        }
    }'
}

truncate_content() {
    local content="$1"
    local max_len=2000
    if [ "${#content}" -gt "$max_len" ]; then
        printf '%s' "${content:0:$max_len}[truncated]"
    else
        printf '%s' "$content"
    fi
}

write_cursor() {
    local sid="$1"
    local new_offset="$2"
    local now="$3"
    local raw
    raw=$(tr -d '\n' < "$CURSOR_FILE" 2>/dev/null || printf '{}')

    local new_entry
    new_entry="\"$sid\":{\"offset\":$new_offset,\"observed_offset\":0,\"last_capture\":\"$now\"}"

    local entries
    entries=$(printf '%s' "$raw" | grep -o '"[^"]*":{[^}]*}' || true)

    local out
    out="{$new_entry"

    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        local key
        key=$(printf '%s' "$entry" | sed -E 's/^"([^"]+)":.*/\1/')
        [ "$key" = "$sid" ] && continue
        out="$out,$entry"
    done <<EOF_ENTRIES
$entries
EOF_ENTRIES

    out="$out}"
    printf '%s\n' "$out" > "$CURSOR_FILE"
}

map_line() {
    local line="$1"
    local role=""
    local content=""
    local tool=""

    if printf '%s' "$line" | grep -q '"type":"human"'; then
        role="user"
        content=$(extract_json_string "content" "$line")
        [ -n "$content" ] || content=$(extract_json_string "text" "$line")
    elif printf '%s' "$line" | grep -q '"type":"assistant"'; then
        role="assistant"
        content=$(extract_json_string "content" "$line")
        [ -n "$content" ] || content=$(extract_json_string "text" "$line")
    elif printf '%s' "$line" | grep -q '"type":"tool_use"'; then
        role="tool_use"
        tool=$(extract_json_string "name" "$line")
        content=$(extract_json_string "input" "$line")
        [ -n "$content" ] || content=$(extract_json_string "content" "$line")
    elif printf '%s' "$line" | grep -q '"type":"tool_result"'; then
        role="tool_result"
        content=$(extract_json_string "content" "$line")
        [ -n "$content" ] || content=$(extract_json_string "text" "$line")
    else
        return 0
    fi

    content=$(truncate_content "$content")

    local ts
    ts=$(iso_now)

    if [ -n "$tool" ]; then
        printf '{"ts":"%s","role":"%s","content":"%s","tool":"%s","session_id":"%s"}\n' \
            "$ts" "$role" "$(json_escape "$content")" "$(json_escape "$tool")" "$SESSION_ID"
    else
        printf '{"ts":"%s","role":"%s","content":"%s","session_id":"%s"}\n' \
            "$ts" "$role" "$(json_escape "$content")" "$SESSION_ID"
    fi
}

if [ ! -f "$META_FILE" ]; then
    START_TIME=$(iso_now)
    printf '{"session_id":"%s","harness":"claude-code","start_time":"%s","vault_path":"%s"}\n' \
        "$SESSION_ID" "$START_TIME" "$(json_escape "$VAULT_PATH")" > "$META_FILE"
fi

tmp_all=$(mktemp)
tmp_new=$(mktemp)
tmp_existing_norm=$(mktemp)
cleanup() {
    rm -f "$tmp_all" "$tmp_new" "$tmp_existing_norm"
}
trap cleanup EXIT

cat "$TRANSCRIPT_PATH" > "$tmp_all"
if [ -s "$OUTPUT_FILE" ]; then
    sed -E 's/"ts":"[^"]*",//' "$OUTPUT_FILE" > "$tmp_existing_norm" || : > "$tmp_existing_norm"
else
    : > "$tmp_existing_norm"
fi

if [ -s "$tmp_all" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        mapped=$(map_line "$line") || true
        [ -n "${mapped:-}" ] || continue
        mapped_norm=$(printf '%s' "$mapped" | sed -E 's/"ts":"[^"]*",//')
        if ! grep -Fqx "$mapped_norm" "$tmp_existing_norm" 2>/dev/null; then
            printf '%s\n' "$mapped" >> "$tmp_new"
            printf '%s\n' "$mapped_norm" >> "$tmp_existing_norm"
        fi
    done < "$tmp_all"
fi

if [ -s "$tmp_new" ]; then
    cat "$tmp_new" >> "$OUTPUT_FILE"
fi

boundary_ts=$(iso_now)
printf '{"ts":"%s","role":"compaction_boundary","content":"Context compacted by harness","session_id":"%s"}\n' \
    "$boundary_ts" "$SESSION_ID" >> "$OUTPUT_FILE"

write_cursor "$SESSION_ID" 0 "$boundary_ts"

exit 0
