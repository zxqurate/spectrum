#!/usr/bin/env bash
# Sync wallpaper banner then launch rofi.
set -euo pipefail

ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/current_wallpaper"
DEFAULT_WP="$HOME/wallpapers/default.jpg"
BANNER="$ROFI_DIR/banner.jpg"

WP="$(cat "$STATE_FILE" 2>/dev/null || true)"
[[ -f "$WP" ]] || WP="$DEFAULT_WP"

ln -sf "$WP" "$BANNER"

exec rofi "$@"
