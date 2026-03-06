#!/usr/bin/env bash
# mnemos session-start hook — runs at SessionStart
# Resolves vault_path, injects MEMORY.md, shows vault stats and maintenance alerts

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

# --- Session ID ---
SESSION_ID="${CLAUDE_CONVERSATION_ID:-$(date +%Y%m%d-%H%M%S)}"

echo "=== mnemos Session Start ==="
echo ""
echo "Session: $SESSION_ID"
echo "Vault:   $VAULT_PATH"
echo ""

# --- Vault Stats ---
echo "--- Vault ---"
NOTES_COUNT=$(find "$VAULT_PATH/notes" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
INBOX_COUNT=$(find "$VAULT_PATH/inbox" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
DAILY_COUNT=$(find "$VAULT_PATH/memory/daily" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
DREAMS_COUNT=$(find "$VAULT_PATH/memory/.dreams" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
OBS_COUNT=$(find "$VAULT_PATH/ops/observations" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
echo "Notes: $NOTES_COUNT | Inbox: $INBOX_COUNT | Daily logs: $DAILY_COUNT | Dreams: $DREAMS_COUNT | Observations: $OBS_COUNT"
echo ""

# --- Inject MEMORY.md ---
MEMORY_FILE="$VAULT_PATH/memory/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
    echo "--- Boot Context (MEMORY.md) ---"
    cat "$MEMORY_FILE"
    echo ""
fi

# --- Condition-based alerts ---
ALERTS=""

if [ "$INBOX_COUNT" -gt 20 ] 2>/dev/null; then
    ALERTS="${ALERTS}  - Inbox overflow: ${INBOX_COUNT} items (threshold: 20). Run /seed or /pipeline.\n"
fi

if [ "$OBS_COUNT" -gt 10 ] 2>/dev/null; then
    ALERTS="${ALERTS}  - Observation accumulation: ${OBS_COUNT} pending (threshold: 10). Run /rethink.\n"
fi

TENSION_COUNT=$(find "$VAULT_PATH/ops/tensions" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [ "$TENSION_COUNT" -gt 5 ] 2>/dev/null; then
    ALERTS="${ALERTS}  - Tension accumulation: ${TENSION_COUNT} pending (threshold: 5). Run /rethink.\n"
fi

# Check for stale inbox items (older than 3 days)
if [ "$INBOX_COUNT" -gt 0 ] 2>/dev/null; then
    if command -v find >/dev/null 2>&1; then
        STALE_INBOX=$(find "$VAULT_PATH/inbox" -name '*.md' -mtime +3 2>/dev/null | wc -l | tr -d ' ')
        if [ "$STALE_INBOX" -gt 0 ] 2>/dev/null; then
            ALERTS="${ALERTS}  - Stale inbox: ${STALE_INBOX} items older than 3 days. Prioritize processing.\n"
        fi
    fi
fi

if [ -n "$ALERTS" ]; then
    echo "--- Maintenance Alerts ---"
    echo -e "$ALERTS"
fi

# --- Recent observations (last 3 days) ---
if [ -d "$VAULT_PATH/memory/daily" ]; then
    RECENT=""
    for i in 0 1 2; do
        if date -v-${i}d +%Y-%m-%d >/dev/null 2>&1; then
            DAY=$(date -v-${i}d +%Y-%m-%d)
        else
            DAY=$(date -d "-${i} days" +%Y-%m-%d 2>/dev/null || true)
        fi
        [ -z "$DAY" ] && continue
        DAY_FILE="$VAULT_PATH/memory/daily/${DAY}.md"
        if [ -f "$DAY_FILE" ]; then
            # Extract high-importance observations (i>=0.7)
            HIGH=$(grep -E '\|i=(0\.[7-9]|1\.0)' "$DAY_FILE" 2>/dev/null | head -5)
            if [ -n "$HIGH" ]; then
                RECENT="${RECENT}${DAY}:\n${HIGH}\n"
            fi
        fi
    done
    if [ -n "$RECENT" ]; then
        echo "--- Recent High-Importance Observations ---"
        echo -e "$RECENT"
    fi
fi

# --- Reminders ---
if [ -f "$VAULT_PATH/ops/reminders.md" ]; then
    OVERDUE=$(grep -E '^\- \[ \]' "$VAULT_PATH/ops/reminders.md" 2>/dev/null | head -5)
    if [ -n "$OVERDUE" ]; then
        echo "--- Reminders ---"
        echo "$OVERDUE"
        echo ""
    fi
fi

# --- Initialize session tracking ---
mkdir -p "$VAULT_PATH/memory/sessions"
cat > "$VAULT_PATH/memory/sessions/current.json" << EOF
{
  "session_id": "$SESSION_ID",
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "vault_path": "$VAULT_PATH",
  "notes_created": [],
  "notes_modified": [],
  "observations": [],
  "last_activity": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "--- Ready ---"
echo "Read self/goals.md and self/identity.md to orient."
