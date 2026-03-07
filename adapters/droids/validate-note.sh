#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

[ -f "$MNEMOS_CONFIG" ] || exit 0

VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
[ -n "$VAULT_PATH" ] || VAULT_PATH="$WORKSPACE_ROOT"

PAYLOAD=""
if read -t 1 -r PAYLOAD 2>/dev/null; then
    true
fi

FILE_PATH=""
if [ -n "$PAYLOAD" ]; then
    FILE_PATH=$(printf '%s' "$PAYLOAD" | sed -n 's/.*"tool_input".*"file_path" *: *"\([^"]*\)".*/\1/p')
    if [ -z "$FILE_PATH" ]; then
        FILE_PATH=$(printf '%s' "$PAYLOAD" | sed -n 's/.*"parameters".*"file" *: *"\([^"]*\)".*/\1/p')
    fi
fi

[ -n "$FILE_PATH" ] || exit 0

NOTES_DIR="$VAULT_PATH/notes"
if [[ ! "$FILE_PATH" == "$NOTES_DIR"* ]]; then
    exit 0
fi

if [[ ! "$FILE_PATH" == *.md ]]; then
    exit 0
fi

WARNINGS=""

if ! grep -q '^description:' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}WARN: Missing 'description' field in ${FILE_PATH}\n"
fi

if ! grep -q 'topics:' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}WARN: Missing 'topics' field in ${FILE_PATH}\n"
fi

DESC=$(grep '^description:' "$FILE_PATH" 2>/dev/null | sed 's/^description: *//' | tr -d '"' || true)
if [ -n "$DESC" ] && [ ${#DESC} -lt 10 ]; then
    WARNINGS="${WARNINGS}WARN: Description too short in ${FILE_PATH} — must add context beyond the title\n"
fi

BASENAME=$(basename "$FILE_PATH" .md)
if [ -n "$DESC" ]; then
    NORM_DESC=$(echo "$DESC" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr -s ' ')
    NORM_TITLE=$(echo "$BASENAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr -s ' ')
    if [ "$NORM_DESC" = "$NORM_TITLE" ]; then
        WARNINGS="${WARNINGS}WARN: Description restates the title in ${FILE_PATH} — must add NEW information\n"
    fi
fi

if ! grep -qE '^(Source:|Sources:)' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}WARN: Missing source attribution in ${FILE_PATH}\n"
fi

if ! head -1 "$FILE_PATH" | grep -q '^---$' 2>/dev/null; then
    WARNINGS="${WARNINGS}WARN: Missing YAML frontmatter in ${FILE_PATH}\n"
fi

if [ -n "$WARNINGS" ]; then
    printf '{"feedback": "%s"}' "$(printf '%s' "$WARNINGS" | sed 's/"/\\"/g' | tr '\n' ' ')"
fi
