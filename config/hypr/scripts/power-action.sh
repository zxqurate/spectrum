#!/usr/bin/env bash
# Power actions for Quickshell Control Center.
set -euo pipefail

action="${1:-}"

case "$action" in
    shutdown)
        systemctl poweroff
        ;;
    reboot)
        systemctl reboot
        ;;
    hibernate)
        systemctl hibernate
        ;;
    uefi)
        systemctl reboot --firmware-setup
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
