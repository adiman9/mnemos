#!/usr/bin/env bash
# mnemos auto-commit hook — runs PostToolUse on Write (async)
# Commits vault changes to git after write operations
# Operates on vault_path, NOT the workspace directory

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

# Verify vault exists
[ -d "$VAULT_PATH" ] || exit 0

# Only act if the written file is inside the vault
FILE_PATH="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
if [ -n "$FILE_PATH" ] && [[ ! "$FILE_PATH" == "$VAULT_PATH"* ]]; then
    exit 0
fi

cd "$VAULT_PATH"

# Only proceed if vault is a git repo
[ -d .git ] || exit 0

# Only commit if there are actual changes
if git diff --quiet HEAD 2>/dev/null && git diff --cached --quiet 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    exit 0
fi

# Stage and commit
git add -A
git commit -m "mnemos: vault update $(date +%Y-%m-%d\ %H:%M:%S)" --no-verify 2>/dev/null || true
