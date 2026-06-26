pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool enabled: false
    property bool hydrated: false

    readonly property string stateFile:
        Quickshell.env("HOME") + "/.local/state/quickshell/always_on"

    function toggle() {
        setEnabled(!enabled)
    }

    function setEnabled(on) {
        enabled = on
        if (hydrated)
            persist()
        syncInhibit()
    }

    function syncInhibit() {
        if (enabled) {
            inhibitProc.running = false
            inhibitProc.running = true
        } else {
            inhibitProc.running = false
        }
    }

    function persist() {
        writeProc.running = false
        writeProc.running = true
    }

    Process {
        id: readProc
        command: ["bash", "-c",
            "cat \"" + root.stateFile + "\" 2>/dev/null || echo false"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const v = (data || "").trim().toLowerCase()
                root.enabled = v === "true" || v === "1"
                root.hydrated = true
                root.syncInhibit()
            }
        }
    }

    Process {
        id: writeProc
        command: ["bash", "-c",
            "mkdir -p \"$(dirname '" + root.stateFile + "')\" && " +
            "printf '%s' \"$VAL\" > '" + root.stateFile + "'"]
        environment: ({
            "VAL": enabled ? "true" : "false"
        })
        running: false
    }

    // Blocks idle lock (hypridle) and system sleep while enabled.
    Process {
        id: inhibitProc
        command: [
            "systemd-inhibit",
            "--what=idle:sleep:handle-lid-switch:handle-suspend-key:handle-hibernate-key:handle-power-key",
            "--mode=block",
            "--who=quickshell",
            "--why=Always On",
            "sleep", "infinity"
        ]
        running: false
        onExited: {
            if (root.enabled && root.hydrated)
                Qt.callLater(() => {
                    if (root.enabled && !inhibitProc.running)
                        inhibitProc.running = true
                })
        }
    }

    Component.onCompleted: readProc.running = true
}
