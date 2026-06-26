import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../state"
import "../../theme"

// Hover popup for SystemStats — appears below the center pill.
// Anchored top-only → LayerShell centers it horizontally automatically.
PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell"

    anchors.top: true
    // no left/right → centered horizontally by wlr-layer-shell

    exclusiveZone: -1

    margins {
        top: Theme.barMargin + Theme.pillHeight + 12
    }

    implicitWidth: 380
    implicitHeight: 148

    color: "transparent"

    // ── Visibility gating ─────────────────────────────────────────────────────
    property bool showPopup: false
    visible: showPopup

    Connections {
        target: AppState
        function onStatsPopupVisibleChanged() {
            if (AppState.statsPopupVisible) {
                root.showPopup = true
            } else {
                hideTimer.start()
            }
        }
        function onMediaPopupVisibleChanged() {
            if (AppState.mediaPopupVisible) AppState.statsPopupVisible = false
        }
    }

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: {
            root.showPopup = false
            // Reset usage values to 0 while hidden — ensures the fill
            // animation plays from scratch on every subsequent open
            root.ramUsedGb  = 0
            root.swapUsedGb = 0
            root.cpuUsage   = 0
        }
    }

    // Keep popup open while mouse is over it
    MouseArea {
        anchors.fill: card
        hoverEnabled: true
        onEntered: {
            hideTimer.stop()
            AppState.statsPopupVisible = true
        }
        onExited: hideTimer.restart()
    }

    // ── Data (polled independently so popup has fresh data) ───────────────────
    property real ramUsedGb:   0
    property real ramTotalGb:  1
    property real swapUsedGb:  0
    property real swapTotalGb: 1
    property int  cpuUsage:    0
    property string cpuTemp:   "--"

    property real lastIdle:  0
    property real lastTotal: 0

    function usageColor(pct) {
        if (pct >= 85) return "#e57373"   // red-ish
        if (pct >= 65) return "#ffb74d"   // amber
        return Theme.textAccent            // normal accent
    }

    Process {
        id: memProc2
        command: ["sh", "-c",
            "free -b | awk '/Mem:/{printf \"%.2f,%.2f\", $3/1e9,$2/1e9} /Swap:/{printf \",%.2f,%.2f\", $3/1e9,$2/1e9}'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                const p = data.trim().split(",")
                if (p.length < 4) return
                // RAM: immediate
                root.ramUsedGb  = parseFloat(p[0]) || 0
                root.ramTotalGb = Math.max(parseFloat(p[1]) || 1, 0.1)
                // Swap: staggered by 90 ms for cascade fill effect
                swapStagger.pendingUsed  = parseFloat(p[2]) || 0
                swapStagger.pendingTotal = Math.max(parseFloat(p[3]) || 1, 0.1)
                swapStagger.restart()
            }
        }
    }

    // Delays Swap assignment so bars cascade (RAM → Swap → CPU)
    Timer {
        id: swapStagger
        interval: 90
        property real pendingUsed:  0
        property real pendingTotal: 1
        onTriggered: {
            root.swapUsedGb  = pendingUsed
            root.swapTotalGb = pendingTotal
        }
    }

    Process {
        id: cpuStat2
        command: ["sh", "-c", "head -1 /proc/stat"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                const p = data.trim().split(/\s+/)
                const user = parseInt(p[1])||0; const nice = parseInt(p[2])||0
                const sys  = parseInt(p[3])||0; const idle = parseInt(p[4])||0
                const iow  = parseInt(p[5])||0; const irq  = parseInt(p[6])||0
                const sirq = parseInt(p[7])||0
                const total = user+nice+sys+idle+iow+irq+sirq
                const idleT = idle+iow
                if (root.lastTotal > 0) {
                    const dt = total - root.lastTotal
                    const di = idleT - root.lastIdle
                    if (dt > 0) {
                        // CPU: staggered by 180 ms for cascade fill effect
                        cpuStagger.pendingVal = Math.round(100*(dt-di)/dt)
                        cpuStagger.restart()
                    }
                }
                root.lastTotal = total; root.lastIdle = idleT
            }
        }
    }

    // Delays CPU assignment so it's the last bar to fill
    Timer {
        id: cpuStagger
        interval: 180
        property int pendingVal: 0
        onTriggered: root.cpuUsage = pendingVal
    }

    Process {
        id: temp2
        command: ["sh", "-c",
            "sensors 2>/dev/null | grep -m1 -E 'Tctl|Tdie|Package id' | awk '{print $2}' | tr -d '+°C'" +
            " || awk '{printf \"%d\",$1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null"]
        running: false
        stdout: SplitParser {
            onRead: data => { if (data && data.trim()) root.cpuTemp = data.trim() }
        }
    }

    Timer {
        interval: 1800
        running: AppState.statsPopupVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            memProc2.running  = true
            cpuStat2.running  = true
            temp2.running     = true
        }
    }

    // ── Card ─────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.barRadius + 4
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: Theme.pillBorderWidth

        property real slideY: 0
        transform: Translate { y: card.slideY }

        state: AppState.statsPopupVisible ? "open" : "closed"
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
                leftMargin: 18
                rightMargin: 18
                topMargin: 14
                bottomMargin: 14
            }
            spacing: 9

            // ── RAM row ───────────────────────────────────────────────────────
            StatRow {
                icon: "󰍛"
                label: "RAM"
                used: root.ramUsedGb
                total: root.ramTotalGb
                pct: root.ramTotalGb > 0 ? root.ramUsedGb / root.ramTotalGb : 0
                barColor: root.usageColor(root.ramTotalGb > 0
                    ? Math.round(root.ramUsedGb / root.ramTotalGb * 100) : 0)
            }

            // ── Swap row ──────────────────────────────────────────────────────
            StatRow {
                icon: "󰾷"
                label: "Swap"
                used: root.swapUsedGb
                total: root.swapTotalGb
                pct: root.swapTotalGb > 0 ? root.swapUsedGb / root.swapTotalGb : 0
                barColor: root.usageColor(root.swapTotalGb > 0
                    ? Math.round(root.swapUsedGb / root.swapTotalGb * 100) : 0)
            }

            // ── CPU row ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Icon
                Text {
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 15
                    color: root.usageColor(root.cpuUsage)
                    text: "\uf4bc"
                }

                // Label
                Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.textMuted
                    text: "CPU"
                    Layout.preferredWidth: 36
                }

                // Progress bar
                Rectangle {
                    id: cpuTrack
                    Layout.fillWidth: true
                    height: 5
                    radius: 3
                    color: Qt.rgba(Theme.barBorderColor.r,
                                   Theme.barBorderColor.g,
                                   Theme.barBorderColor.b, 0.4)

                    Rectangle {
                        width: cpuTrack.width * (root.cpuUsage / 100)
                        height: parent.height
                        radius: parent.radius
                        color: root.usageColor(root.cpuUsage)
                        Behavior on width { NumberAnimation { duration: 560; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                // Values
                Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textPrimary
                    text: root.cpuUsage + "%"
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                }

                Text {
                    visible: root.cpuTemp !== "--"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textMuted
                    text: root.cpuTemp + "°C"
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    // ── Reusable stat row component ───────────────────────────────────────────
    component StatRow: RowLayout {
        id: sRow
        Layout.fillWidth: true
        spacing: 8

        required property string icon
        required property string label
        required property real   used
        required property real   total
        required property real   pct
        required property color  barColor

        readonly property int pctInt: Math.round(pct * 100)

        Text {
            font.family: Theme.iconFontFamily
            font.pixelSize: 15
            color: sRow.barColor
            text: sRow.icon
        }

        Text {
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Theme.textMuted
            text: sRow.label
            Layout.preferredWidth: 36
        }

        Rectangle {
            id: sTrack
            Layout.fillWidth: true
            height: 5
            radius: 3
            color: Qt.rgba(Theme.barBorderColor.r,
                           Theme.barBorderColor.g,
                           Theme.barBorderColor.b, 0.4)

            Rectangle {
                width: sTrack.width * Math.min(1, Math.max(0, sRow.pct))
                height: parent.height
                radius: parent.radius
                color: sRow.barColor
                Behavior on width { NumberAnimation { duration: 560; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        Text {
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Theme.textPrimary
            text: sRow.used.toFixed(1) + " / " + sRow.total.toFixed(1) + " GB"
            Layout.preferredWidth: 100
            horizontalAlignment: Text.AlignRight
        }
    }
}
