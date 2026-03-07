#!/usr/bin/env bash
# mnemos validate-note hook — runs PostToolUse on Write
# Checks that notes written to notes/ have required schema fields
# Uses vault_path to determine if the written file is inside the vault's notes/

set -euo pipefail

# --- Resolve vault path ---
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

# Get the file that was written
FILE_PATH="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
[ -n "$FILE_PATH" ] || exit 0

# Only validate files inside the vault's notes/ directory
NOTES_DIR="$VAULT_PATH/notes"
if [[ ! "$FILE_PATH" == "$NOTES_DIR"* ]]; then
    exit 0
fi

# Skip non-markdown files
if [[ ! "$FILE_PATH" == *.md ]]; then
    exit 0
fi

# --- Schema validation ---
WARNINGS=""

# Check required fields
if ! grep -q '^description:' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}WARN: Missing 'description' field in ${FILE_PATH}\n"
fi

if ! grep -q 'topics:' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}WARN: Missing 'topics' field in ${FILE_PATH}\n"
fi

# Check description quality — should not be empty or too short
DESC=$(grep '^description:' "$FILE_PATH" 2>/dev/null | sed 's/^description: *//' | tr -d '"' || true)
if [ -n "$DESC" ] && [ ${#DESC} -lt 10 ]; then
    WARNINGS="${WARNINGS}WARN: Description too short in ${FILE_PATH} — must add context beyond the title\n"
fi

# Check that description doesn't just restate the filename
BASENAME=$(basename "$FILE_PATH" .md)
if [ -n "$DESC" ]; then
    # Normalize both for comparison (lowercase, strip punctuation)
    NORM_DESC=$(echo "$DESC" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr -s ' ')
    NORM_TITLE=$(echo "$BASENAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr -s ' ')
    if [ "$NORM_DESC" = "$NORM_TITLE" ]; then
        WARNINGS="${WARNINGS}WARN: Description restates the title in ${FILE_PATH} — must add NEW information\n"
    fi
fi

# Check for source attribution (Source: or Sources:)
if ! grep -qE '^(Source:|Sources:)' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}WARN: Missing source attribution in ${FILE_PATH}\n"
fi

# Check for frontmatter delimiters
if ! head -1 "$FILE_PATH" | grep -q '^---$' 2>/dev/null; then
    WARNINGS="${WARNINGS}WARN: Missing YAML frontmatter in ${FILE_PATH}\n"
fi

if [ -n "$WARNINGS" ]; then
    echo -e "$WARNINGS"
fi
