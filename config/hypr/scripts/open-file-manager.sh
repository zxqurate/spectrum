#!/usr/bin/env bash
# Open a file manager — Spectrum defaults to Thunar, not the XDG inode/directory handler
# (editors like VSCodium/Cursor are often wrongly registered there).
set -euo pipefail

TARGET="${1:-$HOME}"

is_terminal_handler() {
    case "${1,,}" in
        kitty-open.desktop|org.kitty.*|alacritty.desktop|foot.desktop|wezterm.desktop)
            return 0 ;;
    esac
    case "${1,,}" in
        *kitty*|*alacritty*|*foot*|*wezterm*|*terminal*)
            return 0 ;;
    esac
    return 1
}

is_editor_handler() {
    case "${1,,}" in
        *code*|*codium*|*cursor*|*vscode*|*vscodium*|*neovide*|*zed*)
            return 0 ;;
    esac
    return 1
}

is_file_manager_handler() {
    case "${1,,}" in
        thunar.desktop|org.xfce.thunar|dolphin.desktop|nemo.desktop|nautilus.desktop|pcmanfm*.desktop|org.kde.dolphin|org.gnome.nautilus*)
            return 0 ;;
    esac
    case "${1,,}" in
        *thunar*|*dolphin*|*nemo*|*nautilus*|*pcmanfm*|*nemo*|*caja*|*deepin-file-manager*)
            return 0 ;;
    esac
    return 1
}

desktop_exec() {
    local desktop="$1"
    local dir file line cmd
    for dir in \
        "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
        /usr/local/share/applications \
        /usr/share/applications; do
        file="$dir/$desktop"
        [[ -f "$file" ]] || continue
        while IFS= read -r line; do
            [[ "$line" == Exec=* ]] || continue
            cmd="${line#Exec=}"
            cmd="${cmd%% %*}"
            cmd="${cmd//\\ / }"
            printf '%s\n' "$cmd"
            return 0
        done < "$file"
    done
    return 1
}

open_with() {
    local cmd="$1"
    shift
    if [[ -n "$cmd" ]]; then
        exec bash -lc "$(printf '%q ' "$cmd")$(printf '%q ' "$@")"
    fi
}

for cmd in thunar dolphin nemo nautilus pcmanfm-qt pcmanfm; do
    if command -v "$cmd" >/dev/null 2>&1; then
        exec "$cmd" "$TARGET"
    fi
done

desktop="$(xdg-mime query default inode/directory 2>/dev/null || true)"
if [[ -n "$desktop" ]] \
    && ! is_terminal_handler "$desktop" \
    && ! is_editor_handler "$desktop" \
    && is_file_manager_handler "$desktop"; then
    if cmd="$(desktop_exec "$desktop")"; then
        open_with "$cmd" "$TARGET"
    fi
fi

exec xdg-open "$TARGET"
