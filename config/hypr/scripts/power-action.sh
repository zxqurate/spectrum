#!/usr/bin/env bash
# Power actions for Quickshell Control Center.
set -euo pipefail

action="${1:-}"

run_power() {
    local loginctl_cmd="$1"
    shift
    if command -v loginctl >/dev/null 2>&1; then
        loginctl "$loginctl_cmd" "$@" && return 0
    fi
    if command -v systemctl >/dev/null 2>&1; then
        systemctl "$loginctl_cmd" "$@" && return 0
    fi
    return 1
}

case "$action" in
    shutdown)
        run_power poweroff || shutdown -h now
        ;;
    reboot)
        run_power reboot || shutdown -r now
        ;;
    hibernate)
        run_power hibernate || systemctl hibernate
        ;;
    uefi)
        if command -v systemctl >/dev/null 2>&1; then
            systemctl reboot --firmware-setup && exit 0
        fi
        if command -v loginctl >/dev/null 2>&1; then
            loginctl reboot --firmware-setup && exit 0
        fi
        exit 1
        ;;
    logout)
        if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
            hyprctl dispatch exit
        elif command -v loginctl >/dev/null 2>&1; then
            loginctl terminate-user "${USER:-$(whoami)}"
        else
            exit 1
        fi
        ;;
    *)
        echo "Unknown action: $action" >&2
        exit 1
        ;;
esac
