#!/usr/bin/env bash
# Open the user's default web browser.
set -euo pipefail

URL="${1:-https://}"

if command -v xdg-settings >/dev/null 2>&1; then
    browser="$(xdg-settings get default-web-browser 2>/dev/null || true)"
    if [[ -n "$browser" && "$browser" != "kitty-open.desktop" ]]; then
        exec xdg-open "$URL"
    fi
fi

for cmd in brave-browser brave chromium google-chrome-stable firefox; do
    if command -v "$cmd" >/dev/null 2>&1; then
        exec "$cmd" "$URL"
    fi
done

exec xdg-open "$URL"
