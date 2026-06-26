#!/usr/bin/env bash
# Regenerate matugen themes with exclusive lock and Quickshell colors reload.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
WP="${1:-$(cat "$STATE_DIR/current_wallpaper" 2>/dev/null || echo "$HOME/wallpapers/default.jpg")}"
MODE="${THEME_MODE:-${2:-$(cat "$STATE_DIR/theme_mode" 2>/dev/null || echo dark)}}"
LOCK="$STATE_DIR/matugen.lock"
COLORS="$STATE_DIR/generated/colors.json"

[[ -f "$WP" ]] || WP="$HOME/wallpapers/default.jpg"
mkdir -p "$(dirname "$LOCK")" "$(dirname "$COLORS")"

exec 9>"$LOCK"
if ! flock -n 9; then
    flock 9
fi

matugen image "$WP" --mode "$MODE" --source-color-index 0 -q

# Matugen writes atomically (rename); Quickshell FileView needs IN_MODIFY.
if [[ -f "$COLORS" ]]; then
    tmp=$(mktemp)
    cp "$COLORS" "$tmp"
    cat "$tmp" > "$COLORS"
    rm -f "$tmp"
fi
