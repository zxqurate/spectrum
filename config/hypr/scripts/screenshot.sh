#!/usr/bin/env bash
# Capture a screenshot with the screen frozen at keybind time (via hyprpicker).
set -euo pipefail

MODE="${1:-area}"
DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +%Y%m%d_%H%M%S).png"

LOCK="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/quickshell-screenshot.lock"
if [[ -e "$LOCK" ]]; then
    exit 0
fi

cleanup() {
    rm -f "$LOCK"
    if pidof -q hyprpicker 2>/dev/null; then
        pkill hyprpicker 2>/dev/null || true
    fi
}
trap cleanup EXIT
touch "$LOCK"

freeze_screen() {
    if pidof -q hyprpicker 2>/dev/null; then
        pkill hyprpicker 2>/dev/null || true
        sleep 0.05
    fi
    # -r: render/freeze all outputs, -z: no zoom lens
    hyprpicker -rz &
    sleep 0.2
}

freeze_screen

case "$MODE" in
    area)
        hyprctl keyword layerrule "match:namespace ^selection$, no_anim on" >/dev/null 2>&1 || true
        GEOM="$(slurp -d)" || exit 1
        [[ -n "$GEOM" ]] || exit 1
        grim -g "$GEOM" - | tee "$FILE" | wl-copy
        ;;
    full)
        grim - | tee "$FILE" | wl-copy
        ;;
    *)
        echo "Usage: $0 [area|full]" >&2
        exit 1
        ;;
esac

echo "$FILE"
