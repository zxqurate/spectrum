#!/usr/bin/env bash
# Reads the last applied wallpaper from Quickshell state and restores it.
# Falls back to default.jpg if no saved state exists.
# Theme regeneration is handled by Quickshell ThemeState on startup.

STATE_FILE="$HOME/.local/state/quickshell/current_wallpaper"
DEFAULT_WP="$HOME/wallpapers/default.jpg"

if [[ -f "$STATE_FILE" ]]; then
    WP=$(cat "$STATE_FILE")
    [[ -f "$WP" ]] || WP="$DEFAULT_WP"
else
    WP="$DEFAULT_WP"
fi

for i in $(seq 1 50); do
    awww query 2>/dev/null && break
    sleep 0.1
done

awww img "$WP" \
    --transition-type     grow \
    --transition-pos      center \
    --transition-duration 0.8 \
    --transition-fps      30
