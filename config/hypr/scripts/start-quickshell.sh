#!/usr/bin/env bash
# Start Quickshell detached from the terminal (survives shell exit).
set -euo pipefail

if ! command -v quickshell >/dev/null 2>&1; then
    echo "quickshell: not installed" >&2
    exit 1
fi

# --daemonize: detach from terminal; --no-duplicate: skip if already running
exec quickshell --daemonize --no-duplicate
