#!/usr/bin/env bash
# Applies GTK light/dark mode and reloads Thunar after matugen regenerates colors.

set -euo pipefail

MODE="${1:-$(cat "$HOME/.local/state/quickshell/theme_mode" 2>/dev/null || echo dark)}"
[[ "$MODE" == "light" ]] && GTK_THEME="adw-gtk3" || GTK_THEME="adw-gtk3-dark"
PREFER_DARK=$([ "$MODE" = "dark" ] && echo true || echo false)
ICON_THEME="matugen-minimal"

write_settings() {
    local dir="$1"
    mkdir -p "$dir"
    cat > "$dir/settings.ini" <<EOF
[Settings]
gtk-theme-name=${GTK_THEME}
gtk-icon-theme-name=${ICON_THEME}
gtk-application-prefer-dark-theme=${PREFER_DARK}
gtk-font-name=Rubik 10
gtk-cursor-theme-name=default
EOF
}

write_settings "$HOME/.config/gtk-3.0"
write_settings "$HOME/.config/gtk-4.0"

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-${MODE}" 2>/dev/null || true
fi

# GTK CSS is read at startup — restart Thunar if it is open.
if pgrep -x thunar >/dev/null 2>&1; then
    thunar -q 2>/dev/null || true
    sleep 0.15
    thunar >/dev/null 2>&1 &
fi
