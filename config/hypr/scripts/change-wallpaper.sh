#!/usr/bin/env bash
# Set wallpaper from CLI and regenerate the matugen theme pipeline.
set -euo pipefail

WP="${1:?Usage: change-wallpaper.sh /path/to/image.jpg}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
STATE_FILE="$STATE_DIR/current_wallpaper"

[[ -f "$WP" ]] || { echo "File not found: $WP" >&2; exit 1; }

mkdir -p "$STATE_DIR"
printf '%s' "$WP" > "$STATE_FILE"

for i in $(seq 1 50); do
    awww query 2>/dev/null && break
    sleep 0.1
done

awww img "$WP" \
    --transition-type     grow \
    --transition-pos      center \
    --transition-duration 0.8 \
    --transition-fps      30

exec bash "$HOME/.config/hypr/scripts/run-matugen.sh" "$WP"
