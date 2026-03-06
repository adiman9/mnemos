#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/core/hooks/scripts/scheduled-run.sh"

VAULT_PATH=""
ADAPTER=""
UNINSTALL=0
API_KEY_PLACEHOLDER_USED=0

usage() {
    echo "Usage: $0 --vault <path> [--adapter <name>] [--uninstall]"
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

get_section_block() {
    local file="$1"
    local section="$2"
    local start_line=""
    local line_no=""
    local next_line=""

    start_line=$(grep -n "^${section}:" "$file" | head -n 1 | cut -d: -f1)
    [[ -n "$start_line" ]] || return 1

    while IFS= read -r line_no; do
        if [[ "$line_no" -gt "$start_line" ]]; then
            next_line="$line_no"
            break
        fi
    done << EOF
$(grep -n '^[a-zA-Z0-9_-][a-zA-Z0-9_-]*:' "$file" | cut -d: -f1)
EOF

    if [[ -n "$next_line" ]]; then
        sed -n "$((start_line + 1)),$((next_line - 1))p" "$file"
    else
        sed -n "$((start_line + 1)),\$p" "$file"
    fi
}

get_field_from_section() {
    local file="$1"
    local section="$2"
    local field="$3"
    local block=""
    local line=""

    block=$(get_section_block "$file" "$section" || true)
    line=$(printf '%s\n' "$block" | grep "^[[:space:]]*${field}:" | head -n 1 || true)
    line=$(echo "$line" | sed "s/^[[:space:]]*${field}:[[:space:]]*//" | sed 's/[[:space:]]*#.*$//' | tr -d '"' | tr -d "'")
    trim "$line"
}

split_time() {
    local t="$1"
    local default_h="$2"
    local default_m="$3"

    if [[ "$t" =~ ^[0-9][0-9]:[0-9][0-9]$ ]]; then
        echo "${t%:*} ${t#*:}"
    else
        echo "$default_h $default_m"
    fi
}

weekday_to_cron_num() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        sunday) echo "0" ;;
        monday) echo "1" ;;
        tuesday) echo "2" ;;
        wednesday) echo "3" ;;
        thursday) echo "4" ;;
        friday) echo "5" ;;
        saturday) echo "6" ;;
        *) echo "0" ;;
    esac
}

weekday_to_systemd() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        sunday) echo "Sun" ;;
        monday) echo "Mon" ;;
        tuesday) echo "Tue" ;;
        wednesday) echo "Wed" ;;
        thursday) echo "Thu" ;;
        friday) echo "Fri" ;;
        saturday) echo "Sat" ;;
        *) echo "Sun" ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vault)
            VAULT_PATH=$(to_abs_path "$2")
            shift 2
            ;;
        --adapter)
            ADAPTER="$2"
            shift 2
            ;;
        --uninstall)
            UNINSTALL=1
            shift
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

if [[ -z "$VAULT_PATH" ]]; then
    echo "--vault is required"
    usage
    exit 1
fi

if [[ ! -d "$VAULT_PATH" ]]; then
    echo "Vault path not found: $VAULT_PATH"
    exit 1
fi

if [[ ! -f "$RUNNER" ]]; then
    echo "Runner script not found: $RUNNER"
    exit 1
fi

SCHEDULE_FILE="$VAULT_PATH/ops/schedule.yaml"
if [[ ! -f "$SCHEDULE_FILE" ]]; then
    echo "Schedule file not found: $SCHEDULE_FILE"
    exit 1
fi

DAILY_TIME=$(get_field_from_section "$SCHEDULE_FILE" "daily" "time")
WEEKLY_TIME=$(get_field_from_section "$SCHEDULE_FILE" "weekly" "time")
WEEKLY_DAY=$(get_field_from_section "$SCHEDULE_FILE" "weekly" "day")

read -r DAILY_H DAILY_M << EOF
$(split_time "$DAILY_TIME" "09" "00")
EOF

read -r WEEKLY_H WEEKLY_M << EOF
$(split_time "$WEEKLY_TIME" "03" "00")
EOF

WEEKLY_DOW_CRON=$(weekday_to_cron_num "${WEEKLY_DAY:-sunday}")
WEEKLY_DOW_SYSTEMD=$(weekday_to_systemd "${WEEKLY_DAY:-sunday}")

DAILY_CMD="\"$RUNNER\" --daily --vault \"$VAULT_PATH\""
WEEKLY_CMD="\"$RUNNER\" --weekly --vault \"$VAULT_PATH\""
if [[ -n "$ADAPTER" ]]; then
    DAILY_CMD="$DAILY_CMD --adapter \"$ADAPTER\""
    WEEKLY_CMD="$WEEKLY_CMD --adapter \"$ADAPTER\""
fi

install_openclaw_cron() {
    if [[ "$UNINSTALL" -eq 1 ]]; then
        openclaw cron remove || true
        echo "Removed OpenClaw cron jobs"
        return
    fi

    openclaw cron add --cron "0 9 * * *" --message "/consolidate && /stats"
    openclaw cron add --cron "0 3 * * 0" --message "/dream && /graph health && /validate all && /rethink"
    echo "Installed OpenClaw cron jobs"
    echo "  Daily:   0 9 * * *"
    echo "  Weekly:  0 3 * * 0"
}

install_launchd() {
    local launch_dir="$HOME/Library/LaunchAgents"
    local daily_plist="$launch_dir/com.mnemos.daily.plist"
    local weekly_plist="$launch_dir/com.mnemos.weekly.plist"
    local api_key_value=""

    mkdir -p "$launch_dir"

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        api_key_value="$ANTHROPIC_API_KEY"
    else
        api_key_value="YOUR_ANTHROPIC_API_KEY"
        API_KEY_PLACEHOLDER_USED=1
    fi

    if [[ "$UNINSTALL" -eq 1 ]]; then
        launchctl unload "$daily_plist" >/dev/null 2>&1 || true
        launchctl unload "$weekly_plist" >/dev/null 2>&1 || true
        rm -f "$daily_plist" "$weekly_plist"
        echo "Removed launchd jobs:"
        echo "  $daily_plist"
        echo "  $weekly_plist"
        return
    fi

    cat > "$daily_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.mnemos.daily</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>$DAILY_CMD</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>$((10#$DAILY_H))</integer>
    <key>Minute</key>
    <integer>$((10#$DAILY_M))</integer>
  </dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>ANTHROPIC_API_KEY</key>
    <string>$api_key_value</string>
  </dict>
</dict>
</plist>
EOF

    cat > "$weekly_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.mnemos.weekly</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>$WEEKLY_CMD</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>$WEEKLY_DOW_CRON</integer>
    <key>Hour</key>
    <integer>$((10#$WEEKLY_H))</integer>
    <key>Minute</key>
    <integer>$((10#$WEEKLY_M))</integer>
  </dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>ANTHROPIC_API_KEY</key>
    <string>$api_key_value</string>
  </dict>
</dict>
</plist>
EOF

    launchctl unload "$daily_plist" >/dev/null 2>&1 || true
    launchctl unload "$weekly_plist" >/dev/null 2>&1 || true
    launchctl load "$daily_plist"
    launchctl load "$weekly_plist"

    echo "Installed launchd jobs:"
    echo "  $daily_plist"
    echo "  $weekly_plist"
}

install_systemd() {
    local user_dir="$HOME/.config/systemd/user"
    local daily_service="$user_dir/mnemos-daily.service"
    local daily_timer="$user_dir/mnemos-daily.timer"
    local weekly_service="$user_dir/mnemos-weekly.service"
    local weekly_timer="$user_dir/mnemos-weekly.timer"

    mkdir -p "$user_dir"

    if [[ "$UNINSTALL" -eq 1 ]]; then
        systemctl --user disable --now mnemos-daily.timer >/dev/null 2>&1 || true
        systemctl --user disable --now mnemos-weekly.timer >/dev/null 2>&1 || true
        rm -f "$daily_service" "$daily_timer" "$weekly_service" "$weekly_timer"
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        echo "Removed systemd user timers and services"
        return
    fi

    cat > "$daily_service" << EOF
[Unit]
Description=mnemos daily scheduled run

[Service]
Type=oneshot
Environment=PATH=/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin
ExecStart=/bin/bash -lc '$DAILY_CMD'
EOF

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        echo "Environment=ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" >> "$daily_service"
    fi

    cat > "$weekly_service" << EOF
[Unit]
Description=mnemos weekly scheduled run

[Service]
Type=oneshot
Environment=PATH=/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin
ExecStart=/bin/bash -lc '$WEEKLY_CMD'
EOF

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        echo "Environment=ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" >> "$weekly_service"
    fi

    cat > "$daily_timer" << EOF
[Unit]
Description=mnemos daily timer

[Timer]
OnCalendar=*-*-* $DAILY_H:$DAILY_M:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    cat > "$weekly_timer" << EOF
[Unit]
Description=mnemos weekly timer

[Timer]
OnCalendar=$WEEKLY_DOW_SYSTEMD *-*-* $WEEKLY_H:$WEEKLY_M:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now mnemos-daily.timer
    systemctl --user enable --now mnemos-weekly.timer

    echo "Installed systemd user timers:"
    echo "  $daily_timer"
    echo "  $weekly_timer"
}

install_crontab() {
    local cron_daily="$DAILY_M $DAILY_H * * * PATH=/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin $DAILY_CMD # mnemos-daily"
    local cron_weekly="$WEEKLY_M $WEEKLY_H * * $WEEKLY_DOW_CRON PATH=/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin $WEEKLY_CMD # mnemos-weekly"
    local current=""
    local updated=""

    current=$(crontab -l 2>/dev/null || true)
    updated=$(printf '%s\n' "$current" | grep -v '# mnemos-daily' | grep -v '# mnemos-weekly' || true)

    if [[ "$UNINSTALL" -eq 1 ]]; then
        if [[ -n "$(trim "$updated")" ]]; then
            printf '%s\n' "$updated" | crontab -
        else
            crontab -r 2>/dev/null || true
        fi
        echo "Removed crontab entries tagged mnemos-daily/mnemos-weekly"
        return
    fi

    {
        printf '%s\n' "$updated"
        echo "$cron_daily"
        echo "$cron_weekly"
    } | crontab -

    echo "Installed crontab entries:"
    echo "  # mnemos-daily"
    echo "  # mnemos-weekly"
}

if [[ -n "$ADAPTER" ]] && [[ "$ADAPTER" = "openclaw" ]]; then
    install_openclaw_cron
else
    uname_s="$(uname -s)"
    if [[ "$uname_s" = "Darwin" ]]; then
        install_launchd
    elif [[ "$uname_s" = "Linux" ]]; then
        if command -v systemctl >/dev/null 2>&1 && systemctl --user list-unit-files >/dev/null 2>&1; then
            install_systemd
        else
            install_crontab
        fi
    else
        install_crontab
    fi
fi

if [[ "$UNINSTALL" -eq 0 ]]; then
    echo ""
    if [[ "$API_KEY_PLACEHOLDER_USED" -eq 1 ]]; then
        echo "Warning: ANTHROPIC_API_KEY placeholder was written in launchd plist. Set your API key in the plist or shell environment."
    fi
    echo "Logs: cat $VAULT_PATH/ops/logs/scheduled-YYYY-MM-DD.log"
    echo "Uninstall: ./schedule.sh --uninstall --vault $VAULT_PATH"
fi
