#!/usr/bin/env bash
# mnemos session-capture hook — runs at Stop
# Archives session record and triggers observation capture prompt

set -euo pipefail

# --- Resolve vault path ---
WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

# Only run if mnemos is configured
[ -f "$MNEMOS_CONFIG" ] || exit 0

VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
[ -n "$VAULT_PATH" ] || VAULT_PATH="$WORKSPACE_ROOT"

# Verify vault exists
[ -d "$VAULT_PATH" ] || exit 0

SESSIONS_DIR="$VAULT_PATH/memory/sessions"
CURRENT="$SESSIONS_DIR/current.json"

if [ ! -f "$CURRENT" ]; then
    exit 0
fi

# Archive the current session with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SESSION_ARCHIVE="$SESSIONS_DIR/${TIMESTAMP}.json"
cp "$CURRENT" "$SESSION_ARCHIVE"

echo "=== mnemos Session Capture ==="
echo "Session archived: memory/sessions/${TIMESTAMP}.json"

# Remind the agent to run /observe if it hasn't captured observations this session
OBS_COUNT=$(grep -c '"observations"' "$CURRENT" 2>/dev/null || echo "0")
TODAY=$(date +%Y-%m-%d)
DAILY_FILE="$VAULT_PATH/memory/daily/${TODAY}.md"

if [ ! -f "$DAILY_FILE" ]; then
    echo ""
    echo "No observations captured today. Consider running /observe before session ends."
fi
