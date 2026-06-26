pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool lightTheme: false
    property bool ready: false

    readonly property string themeMode: lightTheme ? "light" : "dark"
    readonly property string matugenScript:
        Quickshell.env("HOME") + "/.config/hypr/scripts/run-matugen.sh"

    function setTheme(isLight) {
        lightTheme = isLight
        persistProc.mode = isLight ? "light" : "dark"
        persistProc.running = false
        persistProc.running = true
    }

    // Read theme_mode from disk without regenerating colors (Settings panel open).
    function reloadFromDisk() {
        readModeProc.regenerate = false
        readModeProc.running = false
        readModeProc.running = true
    }

    function runMatugen(mode) {
        syncProc.themeMode = mode || themeMode
        syncProc.running = false
        syncProc.running = true
    }

    Process {
        id: readModeProc
        property bool regenerate: true
        command: ["bash", "-c",
            "cat \"$HOME/.local/state/quickshell/theme_mode\" 2>/dev/null || echo dark"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const mode = (data || "dark").trim() || "dark"
                root.lightTheme = mode === "light"
                root.ready = true
                if (readModeProc.regenerate)
                    root.runMatugen(mode)
            }
        }
    }

    Process {
        id: persistProc
        property string mode: "dark"
        command: ["bash", "-c",
            "mkdir -p \"$HOME/.local/state/quickshell\" && " +
            "printf '%s' \"$MODE\" > \"$HOME/.local/state/quickshell/theme_mode\""]
        environment: ({ "MODE": mode })
        running: false
        onExited: {
            root.runMatugen(persistProc.mode)
        }
    }

    Process {
        id: syncProc
        property string themeMode: "dark"
        command: ["bash", root.matugenScript]
        environment: ({ "THEME_MODE": themeMode })
        running: false
    }

    Component.onCompleted: {
        readModeProc.regenerate = true
        readModeProc.running = true
    }
}
