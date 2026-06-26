-- Layer blur for Spectrum Quickshell surfaces (Hyprland 0.55+).
-- Loaded automatically when hyprland.lua is your config entry point.
-- If you still use hyprland.conf, the same rules live in windowrules.conf.

hl.layer_rule({
    name = "spectrum-rofi-blur",
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.65,
})

hl.layer_rule({
    name = "spectrum-quickshell-blur",
    match = { namespace = "quickshell" },
    blur = true,
    ignore_alpha = 0.72,
})

hl.layer_rule({
    name = "spectrum-quickshell-lock-blur",
    match = { namespace = "quickshell-lock" },
    blur = true,
    ignore_alpha = 0.72,
})
