#!/usr/bin/env bash
#
# mnemos installer — multi-harness support
#
# Usage:
#   ./install.sh [--adapter <name>] <workspace-path> <vault-path>
#
# Adapters: claude-code (default), opencode, openclaw, codex, droids
#
# Examples:
#   ./install.sh ~/projects/my-agent ~/memory/vault
#   ./install.sh --adapter opencode ~/projects/my-agent ~/memory/vault
#   ./install.sh --adapter openclaw ~/projects/my-agent ~/memory/vault

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER=""
VAULT_ONLY=0

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --adapter)
            ADAPTER="$2"
            shift 2
            ;;
        --vault-only)
            VAULT_ONLY=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--adapter <name>] <workspace-path> <vault-path>"
            echo "       $0 --vault-only <vault-path>"
            echo ""
            echo "Modes:"
            echo "  Standard:   ./install.sh <workspace-path> <vault-path>"
            echo "  Vault-only: ./install.sh --vault-only <vault-path>"
            echo ""
            echo "Adapters (for standard mode):"
            echo "  claude-code  Claude Code, Cursor, Cline (default)"
            echo "  opencode     OpenCode (sst/opencode)"
            echo "  pi           Pi agent framework (badlogic/pi-mono)"
            echo "  openclaw     OpenClaw"
            echo "  codex        OpenAI Codex CLI"
            echo "  droids       FactoryAI Droids"
            
            echo ""
            echo "Vault-only mode initializes the vault without workspace setup."
            echo "Use this for agents like OpenClaw that manage their own directories."
            echo "After vault-only install, configure your agent to point at the vault."
            echo ""
            echo "If --adapter is omitted, auto-detects from workspace contents."
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# --- Vault-only mode ---
if [[ "$VAULT_ONLY" -eq 1 ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 --vault-only <vault-path>"
        exit 1
    fi
    VAULT="$1"
    if [[ ! "$VAULT" = /* ]]; then
        VAULT="$(pwd)/$VAULT"
    fi
    WORKSPACE=""
else
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 [--adapter <name>] <workspace-path> <vault-path>"
        echo "       $0 --vault-only <vault-path>"
        echo "Run with --help for details."
        exit 1
    fi
    WORKSPACE="$(cd "$1" && pwd)"
    VAULT="$2"
    if [[ ! "$VAULT" = /* ]]; then
        VAULT="$(pwd)/$VAULT"
    fi
fi

# --- Auto-detect adapter ---
detect_adapter() {
    if [[ -f "$WORKSPACE/.opencode/config.json" ]] || [[ -f "$WORKSPACE/opencode.json" ]]; then
        echo "opencode"
    elif [[ -d "$WORKSPACE/.pi" ]] || command -v pi >/dev/null 2>&1; then
        echo "pi"
    elif [[ -d "$WORKSPACE/.openclaw" ]]; then
        echo "openclaw"
    elif [[ -f "$WORKSPACE/.codex/config.toml" ]] || [[ -f "$HOME/.codex/config.toml" ]]; then
        echo "codex"
    elif [[ -d "$WORKSPACE/.factory" ]] || [[ -d "$HOME/.factory" ]]; then
        echo "droids"
    else
        echo "claude-code"
    fi
}

if [[ "$VAULT_ONLY" -eq 1 ]]; then
    echo "Installing mnemos (vault-only mode)"
    echo "  Vault: $VAULT"
    echo ""
else
    if [[ -z "$ADAPTER" ]]; then
        ADAPTER=$(detect_adapter)
        echo "Auto-detected adapter: $ADAPTER"
    fi

    echo "Installing mnemos"
    echo "  Adapter:   $ADAPTER"
    echo "  Workspace: $WORKSPACE"
    echo "  Vault:     $VAULT"
    echo ""
fi

# =============================================================================
# Shared: vault initialization (all adapters)
# =============================================================================

install_vault() {
    echo "Initializing vault..."
    mkdir -p "$VAULT"/{self,notes,memory/{daily,sessions,.dreams},ops/{queue,observations},inbox,templates}

    if [[ ! -f "$VAULT/self/identity.md" ]]; then
        cat > "$VAULT/self/identity.md" << 'VEOF'
# Identity

Who you are and how you work. Update this as you develop preferences and patterns.

## Core Identity

[Describe your role, domain, and working style]

## Working Preferences

[Capture preferences discovered through experience]
VEOF
        echo "  Created self/identity.md"
    fi

    if [[ ! -f "$VAULT/self/methodology.md" ]]; then
        cat > "$VAULT/self/methodology.md" << 'VEOF'
# Methodology

How you process information, make decisions, and maintain knowledge. This evolves through use.

## Principles

[Capture working principles as you discover them]

## Patterns

[Note recurring patterns in your workflow]
VEOF
        echo "  Created self/methodology.md"
    fi

    if [[ ! -f "$VAULT/self/goals.md" ]]; then
        cat > "$VAULT/self/goals.md" << 'VEOF'
# Goals

Current objectives and active threads. Update at session end.

## Active

[Current work threads]

## Completed

[Recently completed objectives]

## Parked

[On hold — with reason]
VEOF
        echo "  Created self/goals.md"
    fi

    if [[ ! -f "$VAULT/memory/MEMORY.md" ]]; then
        cat > "$VAULT/memory/MEMORY.md" << 'VEOF'
# Memory Boot Context

This file is auto-generated. It provides orientation at session start.

## Current Goals

See self/goals.md

## Recent Activity

No observations yet. Run /observe to begin capturing.

## Active Topics

No topic maps yet. They will emerge as notes/ grows.
VEOF
        echo "  Created memory/MEMORY.md"
    fi

    if [[ ! -f "$VAULT/ops/config.yaml" ]]; then
        cat > "$VAULT/ops/config.yaml" << 'VEOF'
# mnemos vault configuration
processing:
  depth: standard
  chaining: suggested
  extraction:
    selectivity: moderate

maintenance:
  orphan_threshold: 1
  topic_map_max: 40
  inbox_stale_days: 3
VEOF
        echo "  Created ops/config.yaml"
    fi

    if [[ ! -f "$VAULT/ops/schedule.yaml" ]]; then
        cp "$SCRIPT_DIR/core/templates/schedule.yaml" "$VAULT/ops/schedule.yaml"
        echo "  Created ops/schedule.yaml"
    fi

    echo "Installing templates..."
    cp "$SCRIPT_DIR"/core/templates/*.md "$VAULT/templates/" 2>/dev/null || true
}

install_mnemos_yaml() {
    echo "Creating .mnemos.yaml..."
    cat > "$WORKSPACE/.mnemos.yaml" << CEOF
# mnemos configuration
vault_path: "$VAULT"

# Optional: search backend
# search:
#   backend: qmd
#   qmd_index: mnemos
CEOF
}

install_hook_scripts() {
    local target_dir="$1"
    echo "Installing hook scripts to $target_dir..."
    mkdir -p "$target_dir"
    cp "$SCRIPT_DIR"/core/hooks/scripts/* "$target_dir/" 2>/dev/null || true
    chmod +x "$target_dir/"* 2>/dev/null || true
}

# =============================================================================
# Adapter: claude-code (also works for Cursor + Cline)
# =============================================================================

install_claude_code() {
    echo "Installing skills..."
    mkdir -p "$WORKSPACE/.claude/skills"
    for skill_dir in "$SCRIPT_DIR"/core/skills/*/; do
        skill_name=$(basename "$skill_dir")
        target_dir="$WORKSPACE/.claude/skills/$skill_name"
        mkdir -p "$target_dir"
        cp -r "$skill_dir"* "$target_dir/"
        echo "  + $skill_name"
    done

    echo "Installing hooks..."
    mkdir -p "$WORKSPACE/.claude/hooks/scripts"
    install_hook_scripts "$WORKSPACE/.claude/hooks/scripts"

    # Merge hooks into .claude/settings.json (preserve existing settings)
    if [ -f "$WORKSPACE/.claude/settings.json" ]; then
        # If settings.json exists, merge hooks key using a temp file
        local tmp_settings
        tmp_settings=$(mktemp)
        # Read existing settings, inject hooks from adapter template
        python3 -c "
import json, sys
with open('$WORKSPACE/.claude/settings.json') as f:
    settings = json.load(f)
with open('$SCRIPT_DIR/adapters/claude-code/hooks.json') as f:
    hooks_config = json.load(f)
settings['hooks'] = hooks_config.get('hooks', hooks_config)
with open('$tmp_settings', 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
" 2>/dev/null && mv "$tmp_settings" "$WORKSPACE/.claude/settings.json" || {
            # Fallback: just copy the hooks config as settings.json
            rm -f "$tmp_settings"
            cp "$SCRIPT_DIR/adapters/claude-code/hooks.json" "$WORKSPACE/.claude/settings.json"
        }
    else
        cp "$SCRIPT_DIR/adapters/claude-code/hooks.json" "$WORKSPACE/.claude/settings.json"
    fi

    echo "Installing system prompt..."
    cp "$SCRIPT_DIR/core/SYSTEM.md" "$WORKSPACE/CLAUDE.md"
}

# =============================================================================
# Adapter: opencode
# =============================================================================

install_opencode() {
    echo "Installing skills..."
    mkdir -p "$WORKSPACE/.opencode/skills"
    for skill_dir in "$SCRIPT_DIR"/core/skills/*/; do
        skill_name=$(basename "$skill_dir")
        target_dir="$WORKSPACE/.opencode/skills/$skill_name"
        mkdir -p "$target_dir"
        cp -r "$skill_dir"* "$target_dir/"
        echo "  + $skill_name"
    done

    install_hook_scripts "$WORKSPACE/.mnemos/hooks/scripts"

    echo "Installing OpenCode plugin..."
    mkdir -p "$WORKSPACE/.opencode/plugins"
    cp "$SCRIPT_DIR/adapters/opencode/mnemos-plugin.ts" "$WORKSPACE/.opencode/plugins/"

    if [[ -f "$WORKSPACE/opencode.json" ]]; then
        echo "  Note: Add '.opencode/plugins/mnemos-plugin.ts' to the plugin array in opencode.json"
    else
        cat > "$WORKSPACE/opencode.json" << 'OEOF'
{
  "plugin": ["./.opencode/plugins/mnemos-plugin.ts"]
}
OEOF
        echo "  Created opencode.json"
    fi

    echo "Installing system prompt..."
    cp "$SCRIPT_DIR/core/SYSTEM.md" "$WORKSPACE/AGENTS.md"
    # OpenCode also reads CLAUDE.md — symlink to avoid duplication
    ln -sf AGENTS.md "$WORKSPACE/CLAUDE.md"
}

# =============================================================================
# Adapter: openclaw
# =============================================================================

install_openclaw() {
    echo "Installing skills..."
    mkdir -p "$WORKSPACE/.openclaw/skills"
    for skill_dir in "$SCRIPT_DIR"/core/skills/*/; do
        skill_name=$(basename "$skill_dir")
        target_dir="$WORKSPACE/.openclaw/skills/$skill_name"
        mkdir -p "$target_dir"
        cp -r "$skill_dir"* "$target_dir/"
        echo "  + $skill_name"
    done

    install_hook_scripts "$WORKSPACE/.mnemos/hooks/scripts"

    echo "Installing OpenClaw hook pack..."
    mkdir -p "$WORKSPACE/.openclaw/hooks/mnemos"
    cp "$SCRIPT_DIR/adapters/openclaw/package.json" "$WORKSPACE/.openclaw/hooks/mnemos/"
    cp "$SCRIPT_DIR/adapters/openclaw/hooks.json5" "$WORKSPACE/.openclaw/hooks/mnemos/"

    echo "Installing system prompt..."
    cp "$SCRIPT_DIR/core/SYSTEM.md" "$WORKSPACE/CLAUDE.md"
}

# =============================================================================
# Adapter: codex
# =============================================================================

install_codex() {
    echo "Installing skills..."
    mkdir -p "$WORKSPACE/.codex/skills"
    for skill_dir in "$SCRIPT_DIR"/core/skills/*/; do
        skill_name=$(basename "$skill_dir")
        target_dir="$WORKSPACE/.codex/skills/$skill_name"
        mkdir -p "$target_dir"
        cp -r "$skill_dir"* "$target_dir/"
        echo "  + $skill_name"
    done

    install_hook_scripts "$WORKSPACE/.mnemos/hooks/scripts"

    echo "Installing Codex notify hook..."
    cp "$SCRIPT_DIR/adapters/codex/codex-notify.sh" "$WORKSPACE/.mnemos/hooks/scripts/codex-notify.sh"
    chmod +x "$WORKSPACE/.mnemos/hooks/scripts/codex-notify.sh"
    echo "  + codex-notify.sh"

    echo "Installing system prompt..."
    cp "$SCRIPT_DIR/core/SYSTEM.md" "$WORKSPACE/AGENTS.md"
    cat >> "$WORKSPACE/AGENTS.md" << 'CODEX_FOOTER'

---

## Codex: Session Start

Codex does not support automatic memory injection at session start. You MUST manually orient at the beginning of every session:

1. Read `.mnemos.yaml` to resolve `vault_path`
2. Read `<vault_path>/memory/MEMORY.md` for boot context (recent observations, active threads, maintenance alerts)
3. Then proceed with the user's request

Do this BEFORE responding to the first user message. MEMORY.md is compact — this adds seconds, not minutes.
CODEX_FOOTER
    echo "  + AGENTS.md (with Codex orient instructions)"

    echo "Installing project-local Codex config..."
    cat > "$WORKSPACE/.codex/config.toml" << TOML
notify = ["$WORKSPACE/.mnemos/hooks/scripts/codex-notify.sh"]
TOML
    echo "  + .codex/config.toml (notify hook)"

    echo ""
    echo "  Manual step: Ensure the project is trusted in ~/.codex/config.toml:"
    echo ""
    echo "    [projects.\"$WORKSPACE\"]"
    echo "    trust_level = \"trusted\""
    echo ""
    echo "  If you have a custom global notify (e.g. desktop notifications),"
    echo "  chain it in .codex/config.toml to preserve it for this project."
    echo ""
    echo "  Note: Codex only supports after-turn hooks. SessionStart and"
    echo "  per-file-write hooks are not available. Skills work fully."
}



# =============================================================================
# Adapter: pi (badlogic/pi-mono — also covers OpenClaw, Graphone, etc.)
# =============================================================================

install_pi() {
    echo "Installing skills..."
    mkdir -p "$WORKSPACE/.pi/skills"
    for skill_dir in "$SCRIPT_DIR"/core/skills/*/; do
        skill_name=$(basename "$skill_dir")
        target_dir="$WORKSPACE/.pi/skills/$skill_name"
        mkdir -p "$target_dir"
        cp -r "$skill_dir"* "$target_dir/"
        echo "  + $skill_name"
    done

    install_hook_scripts "$WORKSPACE/.mnemos/hooks/scripts"

    echo "Installing Pi extension..."
    mkdir -p "$WORKSPACE/.pi/extensions"
    cp "$SCRIPT_DIR/adapters/pi/mnemos-extension.ts" "$WORKSPACE/.pi/extensions/"

    echo "Installing system prompt..."
    cp "$SCRIPT_DIR/core/SYSTEM.md" "$WORKSPACE/AGENTS.md"
    # Pi also reads CLAUDE.md — symlink to avoid duplication
    ln -sf AGENTS.md "$WORKSPACE/CLAUDE.md"
}

# =============================================================================
# Adapter: droids (FactoryAI Droids)
# =============================================================================

install_droids() {
    echo "Installing skills..."
    mkdir -p "$WORKSPACE/.factory/skills"
    for skill_dir in "$SCRIPT_DIR"/core/skills/*/; do
        skill_name=$(basename "$skill_dir")
        target_dir="$WORKSPACE/.factory/skills/$skill_name"
        mkdir -p "$target_dir"
        cp -r "$skill_dir"* "$target_dir/"
        echo "  + $skill_name"
    done

    echo "Installing hooks..."
    mkdir -p "$WORKSPACE/.factory/hooks/scripts"
    cp "$SCRIPT_DIR/adapters/droids/"*.sh "$WORKSPACE/.factory/hooks/scripts/"
    chmod +x "$WORKSPACE/.factory/hooks/scripts/"*.sh

    if [ -f "$WORKSPACE/.factory/settings.json" ]; then
        local tmp_settings
        tmp_settings=$(mktemp)
        python3 -c "
import json
with open('$WORKSPACE/.factory/settings.json') as f:
    settings = json.load(f)
with open('$SCRIPT_DIR/adapters/droids/hooks.json') as f:
    hooks_config = json.load(f)
settings['hooks'] = hooks_config.get('hooks', hooks_config)
with open('$tmp_settings', 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
" 2>/dev/null && mv "$tmp_settings" "$WORKSPACE/.factory/settings.json" || {
            rm -f "$tmp_settings"
            cp "$SCRIPT_DIR/adapters/droids/hooks.json" "$WORKSPACE/.factory/settings.json"
        }
    else
        cp "$SCRIPT_DIR/adapters/droids/hooks.json" "$WORKSPACE/.factory/settings.json"
    fi

    echo "Installing system prompt..."
    cp "$SCRIPT_DIR/core/SYSTEM.md" "$WORKSPACE/DROIDS.md"
}

# =============================================================================
# Execute
# =============================================================================

install_vault

if [[ "$VAULT_ONLY" -eq 1 ]]; then
    echo ""
    echo "Done. Vault initialized successfully."
    echo ""
    echo "  Vault: $VAULT"
    echo ""
    echo "Usage:"
    echo ""
    echo "  Research companion (vault = workspace):"
    echo "    cd $VAULT && claude"
    echo "    # Hooks auto-detect vault from cwd. No config needed."
    echo ""
    echo "  OpenClaw / vault-only agents:"
    echo "    1. Point your agent at the vault via its config or MNEMOS_VAULT env var"
    echo "    2. Load mnemos skills via your agent's skill system"
    echo "    3. Set up scheduling (see adapters/openclaw/README.md)"
    echo ""
    exit 0
fi

install_mnemos_yaml

case "$ADAPTER" in
    claude-code)
        install_claude_code
        ;;
    opencode)
        install_opencode
        ;;
    openclaw)
        install_openclaw
        ;;
    codex)
        install_codex
        ;;
    pi)
        install_pi
        ;;
    droids)
        install_droids
        ;;
    *)
        echo "Unknown adapter: $ADAPTER"
        echo "Available: claude-code, opencode, pi, openclaw, codex, droids"
        exit 1
        ;;
esac

echo ""
echo "Done. mnemos installed successfully."
echo ""
echo "  Adapter: $ADAPTER"
echo "  Vault:   $VAULT"
echo ""
echo "Next steps:"
echo "  1. Restart your agent to load new skills"
echo "  2. Run /observe to begin capturing working memory"
echo "  3. Run /seed to process articles and sources"
echo "  4. Run /next to see what needs attention"
echo ""
echo "Optional: Set up scheduled skill execution (daily consolidation, weekly dreams):"
echo "  ./schedule.sh --vault \"$VAULT\""
echo "  See schedule.sh --help for details."
