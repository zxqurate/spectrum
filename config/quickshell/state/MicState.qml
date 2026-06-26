pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string sourceTarget: "@DEFAULT_AUDIO_SOURCE@"

    property bool muted: false
    property string sourceName: "Microphone"
    property bool _muteBusy: false

    readonly property bool fastPoll: AppState.sidePanelVisible

    function micIcon() {
        return muted ? "󰍭" : "󰍬"
    }

    function applyParsed(data) {
        if (!data)
            return
        muted = data.includes("[MUTED]")
    }

    function toggleMute() {
        if (_muteBusy)
            return
        muted = !muted
        muteProc.running = false
        muteProc.running = true
    }

    function refresh() {
        if (!getVolProc.running)
            getVolProc.running = true
        if (!nameProc.running)
            nameProc.running = true
    }

    Process {
        id: getVolProc
        command: ["wpctl", "get-volume", root.sourceTarget]
        running: false
        stdout: SplitParser {
            onRead: data => root.applyParsed(data)
        }
    }

    Process {
        id: muteProc
        command: ["wpctl", "set-mute", root.sourceTarget, "toggle"]
        running: false
        onRunningChanged: root._muteBusy = running
        onExited: Qt.callLater(() => getVolProc.running = true)
    }

    Process {
        id: nameProc
        command: ["bash", "-c",
            "wpctl inspect " + root.sourceTarget + " 2>/dev/null | awk -F' = ' '/node.description/{gsub(/\"/,\"\",$2); print $2; exit}'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const name = (data || "").trim()
                if (name)
                    root.sourceName = name
            }
        }
    }

    Timer {
        id: pollTimer
        interval: root.fastPoll ? 120 : 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: eventRefreshDebounce
        interval: 25
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: sourceEventProc
        running: true
        command: ["bash", "-c",
            "pactl subscribe 2>/dev/null | stdbuf -oL grep --line-buffered \"on source\""]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.includes("on source"))
                    eventRefreshDebounce.restart()
            }
        }
    }

    Component.onCompleted: refresh()
}
