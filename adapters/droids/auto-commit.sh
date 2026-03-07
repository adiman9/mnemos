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

if [[ ! "$FILE_PATH" == "$VAULT_PATH"* ]]; then
    exit 0
fi

cd "$VAULT_PATH" || exit 0

if [ ! -d ".git" ]; then
    exit 0
fi

REL_PATH="${FILE_PATH#$VAULT_PATH/}"
git add "$REL_PATH" 2>/dev/null || exit 0

if git diff --cached --quiet 2>/dev/null; then
    exit 0
fi

BASENAME=$(basename "$REL_PATH")
git commit -m "auto: update $BASENAME" --no-verify >/dev/null 2>&1 &

exit 0
