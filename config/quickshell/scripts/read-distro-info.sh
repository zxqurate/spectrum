#!/usr/bin/env bash
# Outputs distro metadata for Control Center → System Info.

. /etc/os-release 2>/dev/null || true

ID="${ID:-unknown}"
PRETTY="${PRETTY_NAME:-Linux}"
HOME_U="${HOME_URL:-}"
DOC="${DOCUMENTATION_URL:-}"
SUP="${SUPPORT_URL:-}"
BUG="${BUG_REPORT_URL:-}"
PRIV="${PRIVACY_POLICY_URL:-}"

icon="tux"
case "$ID" in
    arch) icon="/usr/share/pixmaps/archlinux-logo.png" ;;
    debian) icon="/usr/share/pixmaps/debian-logo.png" ;;
    ubuntu) icon="/usr/share/pixmaps/ubuntu-logo.png" ;;
    pop) icon="/usr/share/pixmaps/pop-logo.png" ;;
    fedora) icon="/usr/share/fedora/media/fedora-logo-icon.png" ;;
    manjaro) icon="/usr/share/pixmaps/manjaro-logo.png" ;;
    endeavouros) icon="/usr/share/pixmaps/endeavouros.png" ;;
    opensuse*|suse) icon="/usr/share/pixmaps/distributor-logo-Geeko-Leap.png" ;;
    nixos) icon="/usr/share/icons/hicolor/scalable/apps/nix-snowflake.svg" ;;
    gentoo) icon="/usr/share/icons/hicolor/scalable/apps/gentoo.svg" ;;
    void) icon="/usr/share/pixmaps/void-logo.png" ;;
    alpine) icon="/usr/share/icons/hicolor/scalable/apps/alpine-logo.svg" ;;
    *)
        if [ -n "${LOGO:-}" ] && [ -f "/usr/share/pixmaps/${LOGO}.png" ]; then
            icon="/usr/share/pixmaps/${LOGO}.png"
        elif [ -n "${LOGO:-}" ] && [ -f "/usr/share/pixmaps/${LOGO}.svg" ]; then
            icon="/usr/share/pixmaps/${LOGO}.svg"
        elif [ -n "${LOGO:-}" ] && [ -f "/usr/share/icons/hicolor/scalable/apps/${LOGO}.svg" ]; then
            icon="/usr/share/icons/hicolor/scalable/apps/${LOGO}.svg"
        else
            for candidate in \
                "/usr/share/pixmaps/distributor-logo-${ID}.png" \
                "/usr/share/pixmaps/${ID}-logo.png" \
                "/usr/share/pixmaps/${ID}.png" \
                "/usr/share/icons/hicolor/scalable/apps/${ID}.svg" \
                "/usr/share/icons/hicolor/scalable/apps/distributor-logo-${ID}.svg"; do
                if [ -f "$candidate" ]; then
                    icon="$candidate"
                    break
                fi
            done
        fi
        ;;
esac

[ -f "$icon" ] || icon="tux"

printf 'distro_id=%s\n' "$ID"
printf 'distro_name=%s\n' "$PRETTY"
printf 'distro_home=%s\n' "$HOME_U"
printf 'distro_doc=%s\n' "$DOC"
printf 'distro_support=%s\n' "$SUP"
printf 'distro_bug=%s\n' "$BUG"
printf 'distro_privacy=%s\n' "$PRIV"
printf 'distro_logo=%s\n' "$icon"
