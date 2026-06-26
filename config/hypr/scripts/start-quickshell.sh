#!/usr/bin/env bash
# Start Quickshell detached from the terminal (survives shell exit).
set -euo pipefail

if ! command -v quickshell >/dev/null 2>&1; then
    echo "quickshell: not installed" >&2
    exit 1
fi

# systemd user units may start before the session bus is exported — needed for
# polkit-backed power actions from the Control Center.
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && command -v systemctl >/dev/null 2>&1; then
    # shellcheck disable=SC2046
    export $(systemctl --user show-environment 2>/dev/null \
        | grep -E '^(DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR)=' || true)
fi

# --daemonize: detach from terminal; --no-duplicate: skip if already running
exec quickshell --daemonize --no-duplicate
