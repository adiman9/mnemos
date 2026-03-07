#!/usr/bin/env bash

set -euo pipefail

MODE=""
VAULT_ARG=""
ADAPTER=""
WORKSPACE="$(pwd)"

usage() {
    echo "Usage: $0 (--daily | --weekly) [--vault <path>] [--adapter <name>]"
}

trim() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

to_abs_path() {
    local p="$1"
    if [[ "$p" = /* ]]; then
        echo "$p"
    else
        echo "$(pwd)/$p"
    fi
}

resolve_vault_from_config() {
    local config_path=""
    local raw=""

    if [[ -f "$(pwd)/.mnemos.yaml" ]]; then
        config_path="$(pwd)/.mnemos.yaml"
        WORKSPACE="$(pwd)"
    elif [[ -f "$HOME/.mnemos.yaml" ]]; then
        config_path="$HOME/.mnemos.yaml"
        WORKSPACE="$HOME"
    else
        echo "$HOME/.mnemos/vault"
        return 0
    fi

    raw=$(grep '^vault_path:' "$config_path" | sed 's/vault_path: *//' | tr -d '"' | tr -d "'" | head -n 1)
    raw=$(trim "$raw")
    if [[ -z "$raw" ]]; then
        echo "$HOME/.mnemos/vault"
        return 0
    fi

    if [[ "$raw" = /* ]]; then
        echo "$raw"
    else
        local config_dir
        config_dir="$(cd "$(dirname "$config_path")" && pwd)"
        echo "$config_dir/$raw"
    fi
}

detect_adapter() {
    if [[ -f "$WORKSPACE/.opencode/config.json" ]] || [[ -f "$WORKSPACE/opencode.json" ]]; then
        echo "opencode"
    elif [[ -d "$WORKSPACE/.pi" ]] || command -v pi >/dev/null 2>&1; then
        echo "pi"
    elif [[ -d "$WORKSPACE/.openclaw" ]]; then
        echo "openclaw"
    elif [[ -f "$WORKSPACE/.codex/config.toml" ]] || [[ -f "$HOME/.codex/config.toml" ]]; then
        echo "codex"

    else
        echo "claude-code"
    fi
}

read_skills_for_mode() {
    local schedule_file="$1"
    local section="$2"
    local start_line=""
    local line_no=""
    local next_line=""
    local block=""
    local in_skills=0

    skills=()

    start_line=$(grep -n "^${section}:" "$schedule_file" | head -n 1 | cut -d: -f1)
    [[ -n "$start_line" ]] || return 1

    while IFS= read -r line_no; do
        if [[ "$line_no" -gt "$start_line" ]]; then
            next_line="$line_no"
            break
        fi
    done << EOF
$(grep -n '^[a-zA-Z0-9_-][a-zA-Z0-9_-]*:' "$schedule_file" | cut -d: -f1)
EOF

    if [[ -n "$next_line" ]]; then
        block=$(sed -n "$((start_line + 1)),$((next_line - 1))p" "$schedule_file")
    else
        block=$(sed -n "$((start_line + 1)),\$p" "$schedule_file")
    fi

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*skills:[[:space:]]*$ ]]; then
            in_skills=1
            continue
        fi

        if [[ "$in_skills" -eq 1 ]]; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
                local skill
                skill=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/[[:space:]]*#.*$//')
                skill=$(trim "$skill")
                if [[ -n "$skill" ]]; then
                    skills+=("$skill")
                fi
            elif [[ "$line" =~ ^[[:space:]]*$ ]]; then
                continue
            elif [[ ! "$line" =~ ^[[:space:]]+ ]]; then
                in_skills=0
            fi
        fi
    done << EOF
$block
EOF

    [[ "${#skills[@]}" -gt 0 ]]
}

run_skill() {
    local adapter="$1"
    local skill="$2"

    case "$adapter" in
        claude-code)
            claude -p "$skill" --allowedTools "Read,Write,Edit,Bash,Grep,Glob"
            ;;
        opencode)
            opencode run "$skill"
            ;;
        pi)
            pi -p "$skill"
            ;;
        openclaw)
            openclaw run -m "$skill"
            ;;
        codex)
            codex exec "$skill" --approval never --full-auto
            ;;
        *)
            echo "Unsupported adapter: $adapter"
            return 1
            ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --daily)
            MODE="daily"
            shift
            ;;
        --weekly)
            MODE="weekly"
            shift
            ;;
        --vault)
            VAULT_ARG="$2"
            shift 2
            ;;
        --adapter)
            ADAPTER="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$MODE" ]]; then
    echo "Missing required mode flag: --daily or --weekly"
    usage
    exit 1
fi

if [[ -n "$VAULT_ARG" ]]; then
    VAULT_PATH=$(to_abs_path "$VAULT_ARG")
else
    VAULT_PATH=$(resolve_vault_from_config || true)
fi

if [[ -z "${VAULT_PATH:-}" ]]; then
    echo "Could not resolve vault path. Pass --vault <path> or create .mnemos.yaml in current dir or home dir."
    exit 1
fi

if [[ ! -d "$VAULT_PATH" ]]; then
    echo "Vault directory does not exist: $VAULT_PATH"
    exit 1
fi

if [[ -z "$ADAPTER" ]]; then
    ADAPTER=$(detect_adapter)
fi

SCHEDULE_FILE="$VAULT_PATH/ops/schedule.yaml"
if [[ ! -f "$SCHEDULE_FILE" ]]; then
    echo "Missing schedule file: $SCHEDULE_FILE"
    exit 1
fi

if ! read_skills_for_mode "$SCHEDULE_FILE" "$MODE"; then
    echo "No skills found for '$MODE' in $SCHEDULE_FILE"
    exit 1
fi

LOG_DIR="$VAULT_PATH/ops/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/scheduled-$(date +%Y-%m-%d).log"

total=0
success=0
failed=0

for skill in "${skills[@]}"; do
    total=$((total + 1))
    ts=$(date +%Y-%m-%dT%H:%M:%S)
    {
        echo "=== $skill @ $ts ==="
    } >> "$LOG_FILE"

    if (
        export MNEMOS_VAULT="$VAULT_PATH"
        export MNEMOS_SCHEDULED=1
        run_skill "$ADAPTER" "$skill"
    ) >> "$LOG_FILE" 2>&1; then
        success=$((success + 1))
    else
        failed=$((failed + 1))
    fi

    echo "" >> "$LOG_FILE"
done

summary="Ran $total skills, $success succeeded, $failed failed"
echo "$summary" | tee -a "$LOG_FILE"
