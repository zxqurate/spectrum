#!/usr/bin/env bash
# Detect GPU name — NVIDIA, AMD, Intel; works without GLX on Wayland.

trim() {
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

if command -v nvidia-smi >/dev/null 2>&1; then
    name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | trim)
    if [[ -n "$name" && "$name" != *"failed"* ]]; then
        printf '%s\n' "$name"
        exit 0
    fi
fi

if command -v glxinfo >/dev/null 2>&1; then
    name=$(glxinfo -B 2>/dev/null | grep -m1 'OpenGL renderer' | sed 's/.*: //;s/ (.*//')
    if [[ -n "$name" && "$name" != "llvmpipe" && "$name" != "softpipe" ]]; then
        printf '%s\n' "$name"
        exit 0
    fi
fi

if command -v lspci >/dev/null 2>&1; then
    name=$(lspci -mm 2>/dev/null | awk -F'"' '
        /VGA compatible controller|3D controller|Display controller/ {
            print $6; exit
        }')
    if [[ -n "$name" ]]; then
        printf '%s\n' "$name"
        exit 0
    fi
fi

for card in /sys/class/drm/card[0-9]/device/uevent; do
    [[ -f "$card" ]] || continue
    drv=$(awk -F= '/^DRIVER=/ { print $2 }' "$card")
    case "$drv" in
        nvidia) printf 'NVIDIA GPU\n'; exit 0 ;;
        amdgpu) printf 'AMD GPU\n'; exit 0 ;;
        i915)   printf 'Intel GPU\n'; exit 0 ;;
    esac
done

printf 'Unknown GPU\n'
