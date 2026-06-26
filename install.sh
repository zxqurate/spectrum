#!/usr/bin/env bash
# Spectrum dotfiles installer
# Usage: ./install.sh [--install-deps] [--force] [--dry-run]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DEPS=false
FORCE=false
DRY_RUN=false

usage() {
    cat <<'EOF'
Spectrum installer

Usage: ./install.sh [options]

Options:
  --install-deps   Install pacman packages from packages/arch.txt (Arch only)
  --install-aur    Also install quickshell from AUR (yay/paru)
  --force          Replace existing config directories (backs up first)
  --dry-run        Show actions without changing anything
  -h, --help       Show this help

After install:
  1. Edit ~/.config/hypr/monitors.conf for your displays
  2. Log into Hyprland (or restart quickshell + hypridle)
EOF
}

INSTALL_AUR=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-deps) INSTALL_DEPS=true ;;
        --install-aur)  INSTALL_AUR=true ;;
        --force)        FORCE=true ;;
        --dry-run)      DRY_RUN=true ;;
        -h|--help)      usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

log()  { printf '\033[1;32m[spectrum]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[spectrum]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[spectrum]\033[0m %s\n' "$*" >&2; }
run()  { if $DRY_RUN; then log "DRY: $*"; else "$@"; fi; }

die() { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

backup_path() {
    local p="$1"
    [[ -e "$p" ]] || return 0
    local bak="${p}.spectrum-bak.$(date +%Y%m%d-%H%M%S)"
    if $DRY_RUN; then
        log "DRY: mv '$p' '$bak'"
    else
        mv "$p" "$bak"
        warn "Backed up: $p → $bak"
    fi
}

link_tree() {
    local src="$1" dest="$2"
    local src_real dest_real
    src_real="$(readlink -f "$src")"

    if [[ -L "$dest" ]]; then
        dest_real="$(readlink -f "$dest" 2>/dev/null || true)"
        if [[ "$dest_real" == "$src_real" ]]; then
            log "Already linked: $dest"
            return
        fi
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        if $FORCE; then
            backup_path "$dest"
        else
            die "'$dest' already exists. Re-run with --force to replace."
        fi
    fi
    run mkdir -p "$(dirname "$dest")"
    run ln -sfn "$src" "$dest"
    log "Linked $dest → $src"
}

copy_tree() {
    local src="$1" dest="$2"
    run mkdir -p "$dest"
    if $DRY_RUN; then
        log "DRY: rsync -a '$src/' '$dest/'"
    else
        rsync -a "$src/" "$dest/"
    fi
    log "Synced $dest"
}

install_pacman_deps() {
    [[ -f /etc/arch-release ]] || die "--install-deps requires Arch Linux (pacman)"
    local list="$REPO_ROOT/packages/arch.txt"
    local pkgs=()
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line// /}"
        [[ -n "$line" ]] && pkgs+=("$line")
    done < "$list"
    log "Installing ${#pkgs[@]} pacman packages..."
    run sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

install_aur_deps() {
    local list="$REPO_ROOT/packages/aur.txt"
    [[ -f "$list" ]] || { install_aur_quickshell_legacy; return; }
    local pkgs=()
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line// /}"
        [[ -n "$line" ]] && pkgs+=("$line")
    done < "$list"
    if ((${#pkgs[@]} == 0)); then
        return
    fi
    log "Installing ${#pkgs[@]} AUR packages..."
    if have yay; then
        run yay -S --needed --noconfirm "${pkgs[@]}"
    elif have paru; then
        run paru -S --needed --noconfirm "${pkgs[@]}"
    else
        warn "Install AUR packages manually: ${pkgs[*]}"
        warn "yay -S ${pkgs[*]}"
    fi
}

install_aur_quickshell_legacy() {
    have quickshell && { log "quickshell already installed"; return; }
    if have yay; then
        run yay -S --needed --noconfirm quickshell
    elif have paru; then
        run paru -S --needed --noconfirm quickshell
    else
        warn "Install quickshell manually from AUR"
    fi
}

check_dependencies() {
    local missing=()
    local required=(
        hyprland hypridle hyprpicker quickshell awww matugen
        kitty fish rofi grim slurp wl-copy wpctl brightnessctl
        systemd-inhibit flock
    )
    for cmd in "${required[@]}"; do
        have "$cmd" || missing+=("$cmd")
    done
    if ((${#missing[@]})); then
        warn "Missing commands: ${missing[*]}"
        warn "Run: ./install.sh --install-deps --install-aur"
    else
        log "All core dependencies found"
    fi
}

ensure_icon_symlinks() {
    local theme_dir="$HOME/.local/share/icons/matugen-minimal/places/symbolic"
    local adw="/usr/share/icons/Adwaita/symbolic/places"
    [[ -d "$adw" ]] || { warn "Adwaita icons not found — icon theme may be incomplete"; return; }

    declare -A links=(
        [folder-documents.svg]=folder-documents-symbolic.svg
        [folder-download.svg]=folder-download-symbolic.svg
        [folder-home.svg]=user-home-symbolic.svg
        [folder-music.svg]=folder-music-symbolic.svg
        [folder-pictures.svg]=folder-pictures-symbolic.svg
        [folder-publicshare.svg]=folder-publicshare-symbolic.svg
        [folder-remote.svg]=folder-remote-symbolic.svg
        [folder-saved-search.svg]=folder-saved-search-symbolic.svg
        [folder-templates.svg]=folder-templates-symbolic.svg
        [folder-videos.svg]=folder-videos-symbolic.svg
        [folder.svg]=folder-symbolic.svg
        [network-server.svg]=network-server-symbolic.svg
        [network-workgroup.svg]=network-workgroup-symbolic.svg
    )

    run mkdir -p "$theme_dir"
    for name in "${!links[@]}"; do
        local target="$adw/${links[$name]}"
        [[ -f "$target" ]] || continue
        if $DRY_RUN; then
            log "DRY: ln -sf '$target' '$theme_dir/$name'"
        else
            ln -sfn "$target" "$theme_dir/$name"
        fi
    done
    log "Icon theme symlinks verified"
}

init_runtime_state() {
    local state="$HOME/.local/state/quickshell"
    local wp="$HOME/wallpapers/default.jpg"

    run mkdir -p "$state/generated"
    run mkdir -p "$HOME/.config/kitty/themes"
    run mkdir -p "$HOME/Pictures/Screenshots"
    run mkdir -p "$HOME/wallpapers"

    if [[ ! -f "$state/theme_mode" ]]; then
        run bash -c "printf '%s' 'dark' > '$state/theme_mode'"
    fi

    if [[ ! -f "$state/current_wallpaper" ]]; then
        if [[ ! -f "$wp" ]]; then
            wp="$(find "$HOME/wallpapers" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | head -1)"
            wp="${wp:-$HOME/wallpapers/default.jpg}"
        fi
        if $DRY_RUN; then
            log "DRY: write current_wallpaper=$wp"
        else
            printf '%s' "$wp" > "$state/current_wallpaper"
        fi
    fi

    log "Runtime state initialized"
}

install_machine_configs() {
    local hypr="$HOME/.config/hypr"

    if [[ ! -f "$hypr/monitors.conf" ]]; then
        if $DRY_RUN; then
            log "DRY: cp monitors.conf.example → monitors.conf"
        else
            cp "$hypr/monitors.conf.example" "$hypr/monitors.conf"
            warn "Created $hypr/monitors.conf — edit for your monitors!"
        fi
    fi

    if [[ ! -f "$hypr/appearance.conf" ]]; then
        if $DRY_RUN; then
            log "DRY: cp appearance.conf.example → appearance.conf"
        else
            cp "$hypr/appearance.conf.example" "$hypr/appearance.conf"
            log "Created $hypr/appearance.conf from defaults"
        fi
    fi
}

make_scripts_executable() {
    local scripts_dir="$HOME/.config/hypr/scripts"
    [[ -d "$scripts_dir" ]] || return
    if $DRY_RUN; then
        log "DRY: chmod +x $scripts_dir/*.sh"
    else
        chmod +x "$scripts_dir"/*.sh 2>/dev/null || true
        chmod +x "$HOME/.config/quickshell/scripts"/*.sh 2>/dev/null || true
        chmod +x "$HOME/.config/rofi/launch.sh" 2>/dev/null || true
    fi
}

run_first_theme() {
    local matugen_sh="$HOME/.config/hypr/scripts/run-matugen.sh"
    local wp
    wp="$(cat "$HOME/.local/state/quickshell/current_wallpaper" 2>/dev/null || echo "$HOME/wallpapers/default.jpg")"
    [[ -f "$wp" ]] || wp="$HOME/wallpapers/default.jpg"

    if [[ ! -f "$wp" ]]; then
        warn "No wallpaper found — skipping matugen. Add images to ~/wallpapers/"
        return
    fi

    if [[ ! -x "$matugen_sh" ]]; then
        warn "run-matugen.sh not found — skip theme generation"
        return
    fi

    log "Generating initial theme from: $wp"
    if $DRY_RUN; then
        log "DRY: bash '$matugen_sh' '$wp' dark"
    else
        bash "$matugen_sh" "$wp" dark || warn "matugen failed — run manually after fixing deps"
    fi
}

deploy_configs() {
    log "Deploying configs to \$HOME/.config ..."
    for src in "$REPO_ROOT/config"/*; do
        [[ -d "$src" ]] || continue
        local name
        name="$(basename "$src")"
        link_tree "$src" "$HOME/.config/$name"
    done
}

deploy_wallpapers() {
    if [[ ! -d "$REPO_ROOT/wallpapers" ]]; then
        return
    fi
    if [[ -L "$HOME/wallpapers" ]]; then
        log "Wallpapers already linked"
        return
    fi
    if [[ -d "$HOME/wallpapers" && "$FORCE" != true ]]; then
        warn "~/wallpapers exists — copying repo wallpapers into it"
        copy_tree "$REPO_ROOT/wallpapers" "$HOME/wallpapers"
    elif [[ -d "$HOME/wallpapers" && "$FORCE" == true ]]; then
        backup_path "$HOME/wallpapers"
        link_tree "$REPO_ROOT/wallpapers" "$HOME/wallpapers"
    else
        link_tree "$REPO_ROOT/wallpapers" "$HOME/wallpapers"
    fi
}

deploy_icons() {
    local src="$REPO_ROOT/share/icons/matugen-minimal"
    local dest="$HOME/.local/share/icons/matugen-minimal"
    if [[ -L "$dest" ]]; then
        log "Icon theme already linked"
    elif [[ -d "$dest" && "$FORCE" != true ]]; then
        warn "$dest exists — merging index.theme"
        run mkdir -p "$dest"
        run cp "$src/index.theme" "$dest/"
    else
        if [[ -e "$dest" ]]; then backup_path "$dest"; fi
        run mkdir -p "$HOME/.local/share/icons"
        run ln -sfn "$src" "$dest"
        log "Linked icon theme"
    fi
    ensure_icon_symlinks
}

install_systemd_units() {
    local src="$REPO_ROOT/share/systemd/user/quickshell.service"
    local dest="$HOME/.config/systemd/user/quickshell.service"
    [[ -f "$src" ]] || return
    run mkdir -p "$HOME/.config/systemd/user"
    if [[ -L "$dest" ]] || [[ ! -e "$dest" ]]; then
        run ln -sfn "$src" "$dest"
    elif $FORCE; then
        backup_path "$dest"
        run ln -sfn "$src" "$dest"
    else
        warn "$dest exists — skip systemd unit (use --force to replace)"
        return
    fi
    if $DRY_RUN; then
        log "DRY: systemctl --user enable --now quickshell.service"
        return
    fi
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload
        systemctl --user enable quickshell.service 2>/dev/null \
            && log "Enabled quickshell.service (starts with graphical session)" \
            || warn "Could not enable quickshell.service — use start-quickshell.sh manually"
    fi
}

print_summary() {
    cat <<'EOF'

╔══════════════════════════════════════════════════════════════╗
║  Spectrum installed                                          ║
╠══════════════════════════════════════════════════════════════╣
║  Next steps:                                                 ║
║  1. Edit ~/.config/hypr/monitors.conf                        ║
║  2. Log into Hyprland (quickshell starts via autostart/systemd) ║
║  3. Super+Space — Control Center                             ║
║  4. Super+/ — Keybind menu                                   ║
║  5. Super+Ctrl+T — Wallpaper picker                          ║
╠══════════════════════════════════════════════════════════════╣
║  Change wallpaper:                                           ║
║    ~/.config/hypr/scripts/change-wallpaper.sh ~/wallpapers/x ║
╚══════════════════════════════════════════════════════════════╝

EOF
}

main() {
    log "Spectrum installer (repo: $REPO_ROOT)"

    $INSTALL_DEPS && install_pacman_deps
    $INSTALL_AUR && install_aur_deps

    deploy_configs
    deploy_wallpapers
    deploy_icons

    init_runtime_state
    install_machine_configs
    make_scripts_executable
    install_systemd_units
    run_first_theme
    check_dependencies
    print_summary
}

main "$@"
