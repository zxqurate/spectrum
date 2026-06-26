import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import "../../state"
import "../../components"
import "../../theme"

GlassPanelWindow {
    id: root

    required property var screen

    WlrLayershell.namespace: "quickshell"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors.top: true
    anchors.right: true

    exclusiveZone: -1

    margins {
        top: Theme.barMargin + Theme.pillHeight + 12
        right: Theme.networkPopupRightMargin
    }

    implicitWidth: Theme.wifiPopupWidth
    implicitHeight: Theme.wifiPopupHeight

    color: "transparent"

    // ── Visibility / animation gating ─────────────────────────────────────────
    property bool showPopup: false
    property bool cardOpen: false
    property bool refreshSpinning: false

    readonly property bool ownsPopup: AppState.isSameScreen(AppState.wifiPopupScreen, root.screen)

    visible: showPopup && ownsPopup

    // ── Data ─────────────────────────────────────────────────────────────────
    property string connectedSsid: "–"
    property int    connectedSignal: 0
    property string iface: "–"
    property bool   isWifi: false
    property bool   connected: false

    ListModel { id: networksModel }

    function signalGlyph(strength) {
        if (strength >= 75) return "󰤨"
        if (strength >= 50) return "󰤥"
        if (strength >= 25) return "󰤢"
        return "󰤟"
    }

    function signalColor(strength) {
        if (strength >= 60) return Theme.textAccent
        if (strength >= 30) return Theme.workspaceOccupied
        return Theme.workspaceEmpty
    }

    function normalizeSignal(raw) {
        if (raw <= 0) return 0
        return raw <= 1 ? Math.round(raw * 100) : Math.round(raw)
    }

    function refreshConnected() {
        ConnectionState.refresh()
        root.connected = ConnectionState.connected
        root.isWifi = ConnectionState.isWifi
        root.connectedSsid = ConnectionState.label
        root.connectedSignal = ConnectionState.isWifi ? ConnectionState.wifiStrength : (ConnectionState.connected ? 100 : 0)
        root.iface = "–"

        const devices = Networking.devices?.values ?? []
        for (let i = 0; i < devices.length; ++i) {
            const dev = devices[i]
            if (!dev.connected)
                continue
            if (root.isWifi && ConnectionState.isWifiDevice(dev)) {
                root.iface = dev.name || "–"
                break
            }
            if (!root.isWifi && !ConnectionState.isWifiDevice(dev)) {
                root.iface = dev.name || "–"
                break
            }
        }
    }

    function applyScanResults(entries) {
        networksModel.clear()
        for (let i = 0; i < entries.length; ++i)
            networksModel.append(entries[i])
    }

    function beginScan() {
        scanProc._buffer = []
        scanProc.running = true
    }

    function startRefreshSpin() {
        refreshSpinning = true
        spinMinTimer.restart()
    }

    function updateRefreshSpin() {
        if (!spinMinTimer.running && !rescanProc.running && !scanProc.running)
            refreshSpinning = false
    }

    function refreshNetworks() {
        refreshConnected()
        startRefreshSpin()
        if (!rescanProc.running)
            rescanProc.running = true
        else
            beginScan()
    }

    function syncPopupState() {
        if (!AppState.wifiPopupVisible || !ownsPopup) {
            if (!AppState.wifiPopupVisible) {
                root.cardOpen = false
                hideTimer.restart()
            } else {
                root.showPopup = false
                root.cardOpen = false
            }
            return
        }
        hideTimer.stop()
        root.cardOpen = false
        root.showPopup = true
        root.refreshConnected()
        openAnimTimer.restart()
        scanDelayTimer.restart()
    }

    Timer {
        id: spinMinTimer
        interval: 700
        repeat: false
        onTriggered: root.updateRefreshSpin()
    }

    Process {
        id: scanProc
        property var _buffer: []
        command: ["bash", "-c",
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan no 2>/dev/null | sort -t: -k3 -rn"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (!data || !data.trim()) return
                const parts = data.split(":")
                if (parts.length < 3) return
                const ssid = parts[1]
                if (!ssid || ssid === "--") return
                scanProc._buffer.push({
                    ssid:     ssid,
                    signal:   parseInt(parts[2]) || 0,
                    security: parts.slice(3).join(":").trim(),
                    inUse:    parts[0].trim() === "*"
                })
            }
        }
        onRunningChanged: if (running) root.startRefreshSpin()
        onExited: {
            root.applyScanResults(_buffer)
            root.updateRefreshSpin()
        }
    }

    Process {
        id: rescanProc
        command: ["bash", "-c", "nmcli dev wifi rescan 2>/dev/null || true"]
        running: false
        onRunningChanged: if (running) root.startRefreshSpin()
        onExited: {
            root.beginScan()
            root.updateRefreshSpin()
        }
    }

    Component.onCompleted: {
        refreshConnected()
        beginScan()
        syncPopupState()
    }

    Connections {
        target: Networking
        function onWifiEnabledChanged() {
            root.refreshConnected()
            root.beginScan()
        }
    }

    Connections {
        target: AppState
        function onWifiPopupVisibleChanged() { root.syncPopupState() }
        function onWifiPopupScreenChanged() { root.syncPopupState() }
        function onMediaPopupVisibleChanged() {
            if (AppState.mediaPopupVisible) AppState.hideWifiPopup()
        }
        function onVolumePopupVisibleChanged() {
            if (AppState.volumePopupVisible) AppState.hideWifiPopup()
        }
        function onControlCenterVisibleChanged() {
            if (AppState.controlCenterVisible) AppState.hideWifiPopup()
        }
        function onSidePanelVisibleChanged() {
            if (AppState.sidePanelVisible) AppState.hideWifiPopup()
        }
    }

    Timer {
        id: openAnimTimer
        interval: 16
        repeat: false
        onTriggered: root.cardOpen = true
    }

    Timer {
        id: scanDelayTimer
        interval: 220
        repeat: false
        onTriggered: {
            root.beginScan()
            rescanProc.running = true
        }
    }

    Timer {
        interval: 5000
        running: AppState.wifiPopupVisible && ownsPopup
        repeat: true
        onTriggered: {
            root.refreshConnected()
            root.beginScan()
        }
    }

    Timer {
        id: hideTimer
        interval: 220
        repeat: false
        onTriggered: root.showPopup = false
    }

    // ── Card ─────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.barRadius + 4
        color: Theme.panelBg
        border.color: Theme.panelBorder
        border.width: Theme.pillBorderWidthEffective
        clip: true

        property real slideY: -8
        opacity: 0
        transform: Translate { y: card.slideY }

        state: root.cardOpen ? "open" : "closed"
        states: [
            State { name: "closed"; PropertyChanges { target: card; slideY: -8; opacity: 0.0 } },
            State { name: "open";   PropertyChanges { target: card; slideY: 0.0; opacity: 1.0 } }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation { target: card; property: "slideY"; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: card; property: "opacity"; duration: 160; easing.type: Easing.OutQuad }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation { target: card; property: "slideY"; duration: 180; easing.type: Easing.InCubic }
                NumberAnimation { target: card; property: "opacity"; duration: 150; easing.type: Easing.InQuad }
            }
        ]

        ColumnLayout {
            anchors {
                fill: parent
                leftMargin: 16
                rightMargin: 16
                topMargin: 14
                bottomMargin: 12
            }
            spacing: 0

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.iconSize + 2
                    color: root.connected ? Theme.textAccent : Theme.textMuted
                    text: root.isWifi
                        ? root.signalGlyph(root.connectedSignal)
                        : (root.connected ? "󰈀" : "󰤮")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Medium
                        color: root.connected ? Theme.textPrimary : Theme.textMuted
                        text: root.connectedSsid
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: root.connected && root.isWifi
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textMuted
                        text: root.connectedSignal + "%  ·  " + root.iface
                    }
                }

                Rectangle {
                    width: 26; height: 26
                    radius: 7
                    color: refreshArea.containsMouse
                        ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.12)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Item {
                        id: refreshSpinner
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        property real angle: 0

                        transform: Rotation {
                            origin.x: refreshSpinner.width / 2
                            origin.y: refreshSpinner.height / 2
                            angle: refreshSpinner.angle
                        }

                        Text {
                            anchors.centerIn: parent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 13
                            color: Theme.textMuted
                            text: "󰑐"
                        }

                        Timer {
                            interval: 16
                            running: root.refreshSpinning
                            repeat: true
                            onTriggered: refreshSpinner.angle = (refreshSpinner.angle + 10) % 360
                        }

                        Connections {
                            target: root
                            function onRefreshSpinningChanged() {
                                if (!root.refreshSpinning)
                                    refreshSpinner.angle = 0
                            }
                        }
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refreshNetworks()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.bottomMargin: 8
                height: 1
                color: Qt.rgba(Theme.barBorderColor.r,
                               Theme.barBorderColor.g,
                               Theme.barBorderColor.b, 0.5)
            }

            // ── Scrollable network list (fixed popup height) ─────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Text {
                    anchors.centerIn: parent
                    visible: networksModel.count === 0
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textMuted
                    text: "Scanning…"
                }

                ListView {
                    id: networksList
                    anchors.fill: parent
                    spacing: 2
                    clip: true
                    model: networksModel
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        required property string ssid
                        required property int    signal
                        required property string security
                        required property bool   inUse

                        width: networksList.width
                        height: 36
                        radius: 8
                        color: netArea.containsMouse
                            ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.07)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 4
                                rightMargin: 4
                            }
                            spacing: 8

                            Text {
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 15
                                color: inUse ? Theme.textAccent : root.signalColor(signal)
                                text: root.signalGlyph(signal)
                            }

                            Text {
                                Layout.fillWidth: true
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: inUse ? Font.Medium : Font.Normal
                                color: inUse ? Theme.textPrimary : Theme.textMuted
                                text: ssid
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: security !== "" && security !== "--"
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 11
                                color: Theme.textMuted
                                text: "󰌾"
                            }

                            Text {
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textMuted
                                text: signal + "%"
                            }

                            Text {
                                visible: inUse
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 13
                                color: Theme.textAccent
                                text: "󰄬"
                            }
                        }

                        MouseArea {
                            id: netArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!inUse) {
                                    connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid]
                                    connectProc.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: connectProc
        running: false
        onExited: {
            root.refreshConnected()
            root.beginScan()
        }
    }
}
