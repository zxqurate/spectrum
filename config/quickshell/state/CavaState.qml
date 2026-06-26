pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int barCount: 28
    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/cava.conf"

    property var bars: Array(barCount).fill(0.04)
    property int barsVersion: 0

    readonly property bool active:
        (AppState.mediaPopupVisible && MediaState.isPlaying)
        || AppState.lockScreenVisible

    function parseFrame(line) {
        const parts = line.trim().split(/\s+/)
        if (parts.length === 0 || (parts.length === 1 && parts[0] === ""))
            return

        const next = []
        for (let i = 0; i < barCount; ++i) {
            const raw = i < parts.length ? parseInt(parts[i], 10) : 0
            const norm = isNaN(raw) ? 0 : raw / 1000
            next.push(Math.max(0.04, Math.min(1, norm)))
        }
        bars = next
        barsVersion++
    }

    function resetBars() {
        bars = Array(barCount).fill(0.04)
        barsVersion++
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", root.configPath]
        running: root.active
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseFrame(data)
        }
    }

    Connections {
        target: AppState
        function onMediaPopupVisibleChanged() {
            if (!AppState.mediaPopupVisible)
                root.resetBars()
        }
        function onLockScreenVisibleChanged() {
            if (!AppState.lockScreenVisible)
                root.resetBars()
        }
    }

    Connections {
        target: MediaState
        function onIsPlayingChanged() {
            if (!MediaState.isPlaying)
                root.resetBars()
        }
    }
}
