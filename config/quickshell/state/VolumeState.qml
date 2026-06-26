pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property real maxVolume: 1.0
    readonly property string preferredSinkFile:
        Quickshell.env("HOME") + "/.local/state/quickshell/preferred_sink_id"
    readonly property string volumeTarget: "@DEFAULT_AUDIO_SINK@"

    property real rawVolume: 0
    property bool muted: false
    property bool osdActive: false
    property string sinkName: "Audio output"
    property var sinks: []
    property int activeSinkId: 0
    property int _queuedPct: 0
    property int _preferredSinkId: 0
    property bool _headsetRecoverAttempted: false
    property bool _preferredEnforced: false

    readonly property int percentLevel: Math.min(100, Math.round(rawVolume * 100))
    readonly property int barLevel: percentLevel
    readonly property bool fastPoll: osdActive || AppState.volumePopupVisible
    readonly property bool hasMultipleSinks: sinks.length > 1

    property int osdPulse: 0

    signal volumeChanged(bool fromExternal)

    function volumeIcon() {
        if (muted)              return "󰖁"
        if (percentLevel <= 0)  return "󰝟"
        if (percentLevel < 35)  return "󰕿"
        if (percentLevel < 70)  return "󰖀"
        return "󰕾"
    }

    function isUiBusy() {
        return setDebounce.running || setVolProc.running || muteProc.running
    }

    function isHdmiSink(name) {
        const n = (name || "").toLowerCase()
        return n.includes("hdmi") || n.includes("displayport") || n.includes("dp audio")
    }

    function isHeadphoneSink(name) {
        const n = (name || "").toLowerCase()
        return n.includes("headset") || n.includes("headphone") || n.includes("usb")
            || n.includes("науш") || n.includes("fifine")
    }

    function maybePulseOsd() {
        if (!AppState.volumePopupVisible)
            osdPulse++
    }

    function applyParsed(data) {
        if (!data) return

        const wasMuted = muted
        muted = data.includes("[MUTED]")

        const m = data.match(/([\d.]+)/)
        if (!m) return

        let raw = Math.max(0, parseFloat(m[1]))

        if (raw > maxVolume) {
            raw = maxVolume
            if (!isUiBusy() && !clampProc.running)
                clampProc.running = true
        }

        if (isUiBusy()) {
            if (Math.abs(raw - rawVolume) < 0.02)
                rawVolume = raw
            return
        }

        const changed = Math.abs(raw - rawVolume) > 0.004 || wasMuted !== muted
        rawVolume = raw

        if (changed) {
            volumeChanged(true)
            maybePulseOsd()
        }
    }

    function parseSinks(data) {
        const lines = (data || "").trim().split("\n")
        const next = []
        let defaultId = 0

        for (let i = 0; i < lines.length; ++i) {
            const parts = lines[i].split("\t")
            if (parts.length < 3)
                continue

            const id = parseInt(parts[0], 10)
            const name = parts[1].trim()
            const isDefault = parts[2] === "1"
            if (!id || !name)
                continue

            next.push({ id: id, name: name, isDefault: isDefault })
            if (isDefault)
                defaultId = id
        }

        sinks = next
        if (defaultId > 0)
            activeSinkId = defaultId

        maybeEnforcePreferredSink()
    }

    function savePreferredSink(id) {
        _preferredSinkId = id
        saveSinkProc.running = true
    }

    function loadPreferredSink(id) {
        _preferredSinkId = id
    }

    function setDefaultSink(id, persist) {
        if (!id || setDefaultProc.running)
            return
        setDefaultProc.sinkId = id
        setDefaultProc.running = true
        activeSinkId = id
        if (persist !== false)
            savePreferredSink(id)
    }

    function maybeEnforcePreferredSink() {
        if (_preferredEnforced || sinks.length === 0 || setDefaultProc.running)
            return

        let targetId = _preferredSinkId
        if (targetId > 0 && !sinks.some(s => s.id === targetId))
            targetId = 0

        if (targetId <= 0) {
            for (let i = 0; i < sinks.length; ++i) {
                if (isHeadphoneSink(sinks[i].name) && !isHdmiSink(sinks[i].name)) {
                    targetId = sinks[i].id
                    break
                }
            }
        }

        const current = sinks.find(s => s.isDefault)
        if (targetId > 0 && current && current.id !== targetId)
            setDefaultSink(targetId, false)

        if (!_headsetRecoverAttempted && sinks.length === 1 && isHdmiSink(sinks[0].name)) {
            _headsetRecoverAttempted = true
            recoverHeadsetProc.running = true
        }

        _preferredEnforced = true
    }

    function cycleSink() {
        if (sinks.length <= 1) {
            recoverHeadsetProc.running = true
            Qt.callLater(root.refreshSinks)
            return
        }

        let idx = sinks.findIndex(s => s.id === activeSinkId)
        if (idx < 0)
            idx = 0
        const next = sinks[(idx + 1) % sinks.length]
        setDefaultSink(next.id, true)
        _preferredEnforced = true
        Qt.callLater(root.refreshVolume)
    }

    function setVolumePercent(pct) {
        const clamped = Math.max(0, Math.min(Math.round(pct), 100))
        rawVolume = clamped / 100.0
        setVolProc.command = ["wpctl", "set-volume", "-l", "1.0", volumeTarget, clamped + "%"]
        setVolProc.running = true
    }

    function queueSetVolumePercent(pct) {
        const clamped = Math.max(0, Math.min(Math.round(pct), 100))
        _queuedPct = clamped
        rawVolume = clamped / 100.0
        setDebounce.restart()
    }

    function adjustVolume(deltaPercent) {
        setVolumePercent(percentLevel + deltaPercent)
        maybePulseOsd()
    }

    function toggleMute() {
        muteProc.running = true
    }

    function refreshVolume() {
        if (!getVolProc.running)
            getVolProc.running = true
        if (!sinkNameProc.running)
            sinkNameProc.running = true
    }

    function refreshSinks() {
        if (!sinksProc.running)
            sinksProc.running = true
    }

    function refresh() {
        refreshVolume()
        refreshSinks()
    }

    Component.onCompleted: loadSinkProc.running = true

    Timer {
        id: setDebounce
        interval: 40
        repeat: false
        onTriggered: root.setVolumePercent(root._queuedPct)
    }

    Timer {
        id: pollTimer
        interval: root.fastPoll ? 80 : 250
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!getVolProc.running && !setVolProc.running)
                getVolProc.running = true
        }
    }

    Timer {
        id: eventRefreshDebounce
        interval: 25
        repeat: false
        onTriggered: root.refreshVolume()
    }

    Process {
        id: volEventProc
        running: true
        command: ["bash", "-c",
            "pactl subscribe 2>/dev/null | stdbuf -oL grep --line-buffered \"on sink\""]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.includes("on sink"))
                    eventRefreshDebounce.restart()
            }
        }
    }

    Timer {
        id: sinkPollTimer
        interval: root.fastPoll ? 2000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshSinks()
    }

    Process {
        id: clampProc
        running: false
        command: ["wpctl", "set-volume", "-l", "1.0", root.volumeTarget, "100%"]
        onExited: Qt.callLater(() => getVolProc.running = true)
    }

    Process {
        id: getVolProc
        command: ["wpctl", "get-volume", root.volumeTarget]
        running: false
        stdout: SplitParser {
            onRead: data => root.applyParsed(data)
        }
    }

    Process {
        id: setVolProc
        running: false
        onExited: Qt.callLater(() => getVolProc.running = true)
    }

    Process {
        id: muteProc
        command: ["wpctl", "set-mute", root.volumeTarget, "toggle"]
        running: false
        onExited: Qt.callLater(() => getVolProc.running = true)
    }

    Process {
        id: sinkNameProc
        command: ["bash", "-c",
            "wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F' = ' '/node.description/{gsub(/\"/,\"\",$2); print $2; exit}'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const name = (data || "").trim()
                if (name)
                    root.sinkName = name
            }
        }
    }

    Process {
        id: sinksProc
        running: false
        command: ["bash", "-c",
            "wpctl status 2>/dev/null | awk '" +
            "/Sinks:/{in_sinks=1;next} /Sources:/{in_sinks=0} " +
            "in_sinks && match($0, /[ *]*([0-9]+)\\. ([^[]+)/, m) { " +
            "def=index($0, \"*\")>0; gsub(/^[ \\t]+|[ \\t]+$/, \"\", m[2]); " +
            "print m[1] \"\\t\" m[2] \"\\t\" (def?1:0) " +
            "}'"
        ]
        stdout: SplitParser {
            onRead: data => root.parseSinks(data)
        }
    }

    Process {
        id: setDefaultProc
        property int sinkId: 0
        running: false
        command: ["wpctl", "set-default", String(setDefaultProc.sinkId)]
        onExited: Qt.callLater(() => {
            root.refreshSinks()
            root.refreshVolume()
        })
    }

    Process {
        id: loadSinkProc
        running: false
        command: ["bash", "-c", "mkdir -p \"$(dirname '" + preferredSinkFile + "')\"; cat '" + preferredSinkFile + "' 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const id = parseInt((data || "").trim(), 10)
                if (id > 0)
                    root.loadPreferredSink(id)
            }
        }
        onExited: Qt.callLater(() => root.refreshSinks())
    }

    Process {
        id: saveSinkProc
        running: false
        environment: ({
            "SINK_ID": String(root._preferredSinkId),
            "DEST": root.preferredSinkFile
        })
        command: ["bash", "-c",
            "mkdir -p \"$(dirname \"$DEST\")\"; printf '%s' \"$SINK_ID\" > \"$DEST\""
        ]
    }

    Process {
        id: recoverHeadsetProc
        running: false
        command: ["bash", "-c",
            "CARD=$(pactl list cards short 2>/dev/null | awk '/[Hh]eadset|[Ff]ifine/{print $2; exit}'); " +
            "[ -z \"$CARD\" ] && exit 0; " +
            "HAS=$(pactl list sinks short 2>/dev/null | grep -Eic 'headset|fifine|Headset'); " +
            "[ \"$HAS\" -gt 0 ] && exit 0; " +
            "pactl set-card-profile \"$CARD\" off 2>/dev/null; sleep 0.15; " +
            "pactl set-card-profile \"$CARD\" output:analog-stereo+input:mono-fallback 2>/dev/null"
        ]
        onExited: Qt.callLater(() => {
            root._preferredEnforced = false
            root.refreshSinks()
            root.refreshVolume()
        })
    }
}
