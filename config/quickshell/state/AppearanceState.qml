pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string appearanceConfPath:
        Quickshell.env("HOME") + "/.config/hypr/appearance.conf"

    // Glass = semi-transparent QML surfaces (+ Hyprland layerrule blur when enabled).
    // glassActive — panel alpha in QML; layerBlurActive — also requires Hyprland decoration blur.
    property bool systemBlurPreferred: true
    property bool hyprBlurEnabled: true

    property real panelOpacity: 0.72
    property real panelCardOpacity: 0.78

    readonly property bool glassActive: !ThemeState.lightTheme

    readonly property bool layerBlurActive:
        systemBlurPreferred && hyprBlurEnabled && !ThemeState.lightTheme

    function asColor(c) {
        if (!c)
            return c
        if (typeof c === "string")
            return Qt.color(c)
        return c
    }

    function solidColor(c) {
        const col = asColor(c)
        if (!col)
            return col
        return Qt.rgba(col.r, col.g, col.b, 1.0)
    }

    // Tint + alpha on the panel surface itself — Hyprland blurs what's behind it.
    function panelColor(base, opacity, card) {
        const col = asColor(base)
        if (!col)
            return col
        if (!glassActive)
            return solidColor(col)

        const a = card === true ? panelCardOpacity : opacity
        return Qt.rgba(
            Math.min(1, col.r * 0.92 + 0.04),
            Math.min(1, col.g * 0.92 + 0.04),
            Math.min(1, col.b * 0.94 + 0.05),
            a)
    }

    function glass(base, opacity, card) {
        return panelColor(base, opacity, card)
    }

    // Lock screen scrim only — not used for system panels.
    function dimOverlay(strength) {
        if (ThemeState.lightTheme)
            return Qt.rgba(0, 0, 0, strength * 0.36)
        return Qt.rgba(0, 0, 0, layerBlurActive ? Math.max(0.12, strength * 0.38) : strength)
    }

    function applyFromSettings(enabled, opacity, cardOpacity) {
        if (enabled !== undefined)
            systemBlurPreferred = enabled
        if (opacity !== undefined && !isNaN(opacity))
            panelOpacity = Math.max(0.28, Math.min(0.88, opacity))
        if (cardOpacity !== undefined && !isNaN(cardOpacity))
            panelCardOpacity = Math.max(0.28, Math.min(0.92, cardOpacity))
    }

    function applySystemBlur(enabled, opacity, cardOpacity) {
        applyFromSettings(enabled, opacity, cardOpacity)
    }

    function setHyprBlurEnabled(enabled) {
        hyprBlurEnabled = enabled
    }

    function parseConfText(text) {
        let enabled = systemBlurPreferred
        let opacity = panelOpacity
        let cardOpacity = panelCardOpacity

        const lines = text.split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim()
            if (line.startsWith("# quickshell-system-blur=")) {
                const v = line.substring("# quickshell-system-blur=".length).trim()
                enabled = v === "true" || v === "1"
            } else if (line.startsWith("# quickshell-panel-opacity=")) {
                const f = parseFloat(line.substring("# quickshell-panel-opacity=".length).trim())
                if (!isNaN(f))
                    opacity = f
            } else if (line.startsWith("# quickshell-panel-card-opacity=")) {
                const f = parseFloat(line.substring("# quickshell-panel-card-opacity=".length).trim())
                if (!isNaN(f))
                    cardOpacity = f
            }
        }

        applyFromSettings(enabled, opacity, cardOpacity)
    }

    function reload() {
        readProc.running = true
    }

    // Re-read quickshell panel prefs from disk without touching live Hyprland blur state.
    function reloadFromDisk() {
        readConfProc.running = true
    }

    Process {
        id: readProc
        command: ["bash", "-c",
            "cat \"$HOME/.config/hypr/appearance.conf\"; " +
            "be=$(hyprctl getoption decoration:blur:enabled 2>/dev/null | awk '/int:/{print $2}'); " +
            "printf 'hypr_blur_enabled=%s\\n' \"${be:-1}\""]
        running: false
        stdout: SplitParser {
            property string _buf: ""
            onRead: data => { _buf += data + "\n" }
        }
        onExited: {
            const text = stdout._buf
            for (const line of text.split("\n")) {
                if (line.startsWith("hypr_blur_enabled=")) {
                    const v = line.substring("hypr_blur_enabled=".length).trim()
                    if (v === "1")
                        root.hyprBlurEnabled = true
                    else if (v === "0")
                        root.hyprBlurEnabled = false
                    break
                }
            }
            const confEnd = text.indexOf("hypr_blur_enabled=")
            const confText = confEnd >= 0 ? text.substring(0, confEnd) : text
            if (confText.trim())
                root.parseConfText(confText)
            stdout._buf = ""
        }
    }

    Process {
        id: readConfProc
        command: ["cat", root.appearanceConfPath]
        running: false
        stdout: SplitParser {
            property string _buf: ""
            onRead: data => { _buf += data }
        }
        onExited: {
            if (stdout._buf.trim())
                root.parseConfText(stdout._buf)
            stdout._buf = ""
        }
    }

    Connections {
        target: ThemeState
        function onLightThemeChanged() { reload() }
    }

    Component.onCompleted: reload()
}
