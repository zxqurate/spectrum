#!/usr/bin/env bash
# Verifies the current user's login password (used by Quickshell lock screen).

set -euo pipefail

pass="${PASS:-}"
user="${USER:-$(whoami)}"

[[ -n "$pass" ]] || exit 1

if command -v timeout >/dev/null 2>&1; then
    printf '%s\n' "$pass" | timeout 8 su -c true "$user" 2>/dev/null
else
    printf '%s\n' "$pass" | su -c true "$user" 2>/dev/null
fi
