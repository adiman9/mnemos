#!/usr/bin/env bash
# mnemos session-start hook for FactoryAI Droids
# Runs at SessionStart — injects MEMORY.md via additionalContext JSON response
# Droids receive session_id via stdin JSON payload

set -euo pipefail

# --- Resolve vault path ---
WORKSPACE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
MNEMOS_CONFIG="$WORKSPACE_ROOT/.mnemos.yaml"

# Only run if mnemos is configured
[ -f "$MNEMOS_CONFIG" ] || exit 0

VAULT_PATH=$(grep '^vault_path:' "$MNEMOS_CONFIG" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'")
[ -n "$VAULT_PATH" ] || VAULT_PATH="$HOME/.mnemos/vault"

# Verify vault exists
[ -d "$VAULT_PATH" ] || exit 0

# --- Parse stdin JSON (Droids format) ---
PAYLOAD=""
if read -t 1 -r PAYLOAD 2>/dev/null; then
    true
fi

SESSION_ID=""
if [ -n "$PAYLOAD" ]; then
    SESSION_ID=$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p')
fi
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d-%H%M%S)}"

# --- Build context string ---
CONTEXT=""

# Vault stats
NOTES_COUNT=$( (find "$VAULT_PATH/notes" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')
INBOX_COUNT=$( (find "$VAULT_PATH/inbox" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')
DAILY_COUNT=$( (find "$VAULT_PATH/memory/daily" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')
DREAMS_COUNT=$( (find "$VAULT_PATH/memory/.dreams" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')
OBS_COUNT=$( (find "$VAULT_PATH/ops/observations" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')

CONTEXT+="=== mnemos Session Start ===\n"
CONTEXT+="Session: $SESSION_ID\n"
CONTEXT+="Vault: $VAULT_PATH\n\n"
CONTEXT+="--- Vault ---\n"
CONTEXT+="Notes: $NOTES_COUNT | Inbox: $INBOX_COUNT | Daily logs: $DAILY_COUNT | Dreams: $DREAMS_COUNT | Observations: $OBS_COUNT\n\n"

# Inject MEMORY.md
MEMORY_FILE="$VAULT_PATH/memory/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
    CONTEXT+="--- Boot Context (MEMORY.md) ---\n"
    MEMORY_CONTENT=$(cat "$MEMORY_FILE")
    CONTEXT+="$MEMORY_CONTENT\n\n"
fi

# Condition-based alerts
ALERTS=""

if [ "$INBOX_COUNT" -gt 20 ] 2>/dev/null; then
    ALERTS+="  - Inbox overflow: ${INBOX_COUNT} items (threshold: 20). Run /seed or /pipeline.\n"
fi

if [ "$OBS_COUNT" -gt 10 ] 2>/dev/null; then
    ALERTS+="  - Observation accumulation: ${OBS_COUNT} pending (threshold: 10). Run /rethink.\n"
fi

TENSION_COUNT=$( (find "$VAULT_PATH/ops/tensions" -name '*.md' 2>/dev/null || true) | wc -l | tr -d ' ')
if [ "$TENSION_COUNT" -gt 5 ] 2>/dev/null; then
    ALERTS+="  - Tension accumulation: ${TENSION_COUNT} pending (threshold: 5). Run /rethink.\n"
fi

# Check for stale inbox items
if [ "$INBOX_COUNT" -gt 0 ] 2>/dev/null; then
    if command -v find >/dev/null 2>&1; then
        STALE_INBOX=$( (find "$VAULT_PATH/inbox" -name '*.md' -mtime +3 2>/dev/null || true) | wc -l | tr -d ' ')
        if [ "$STALE_INBOX" -gt 0 ] 2>/dev/null; then
            ALERTS+="  - Stale inbox: ${STALE_INBOX} items older than 3 days. Prioritize processing.\n"
        fi
    fi
fi

if [ -n "$ALERTS" ]; then
    CONTEXT+="--- Maintenance Alerts ---\n"
    CONTEXT+="$ALERTS\n"
fi

# Recent high-importance observations (last 3 days)
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
            HIGH=$(grep -E '\|i=(0\.[7-9]|1\.0)' "$DAY_FILE" 2>/dev/null | head -5 || true)
            if [ -n "$HIGH" ]; then
                RECENT+="${DAY}:\n${HIGH}\n"
            fi
        fi
    done
    if [ -n "$RECENT" ]; then
        CONTEXT+="--- Recent High-Importance Observations ---\n"
        CONTEXT+="$RECENT\n"
    fi
fi

# Reminders
if [ -f "$VAULT_PATH/ops/reminders.md" ]; then
    OVERDUE=$(grep -E '^\- \[ \]' "$VAULT_PATH/ops/reminders.md" 2>/dev/null | head -5 || true)
    if [ -n "$OVERDUE" ]; then
        CONTEXT+="--- Reminders ---\n"
        CONTEXT+="$OVERDUE\n\n"
    fi
fi

CONTEXT+="--- Ready ---\n"
CONTEXT+="Read self/goals.md and self/identity.md to orient."

# --- Ensure session directories exist ---
mkdir -p "$VAULT_PATH/memory/sessions"
mkdir -p "$VAULT_PATH/memory/daily"

# --- Output JSON response for Droids ---
# Droids hooks can inject context via additionalContext field
# Escape for JSON
CONTEXT_ESCAPED=$(printf '%s' "$CONTEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

cat << EOF
{
  "additionalContext": $CONTEXT_ESCAPED
}
EOF

exit 0
