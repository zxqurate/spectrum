import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../state"
import "../../theme"

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell"

    required property var screen

    anchors.top: true
    anchors.right: true

    exclusiveZone: -1

    readonly property bool ownsOsd:
        !Hyprland.focusedMonitor || !root.screen
        || root.screen.name === Hyprland.focusedMonitor.name

    readonly property int osdTopMargin: {
        const h = screen ? screen.height : 1080
        return Math.max(Theme.barMargin, Math.round((h - implicitHeight) / 2))
    }

    margins {
        right: Theme.barMargin + 4
        top: osdTopMargin
    }

    implicitWidth: Theme.volumeOsdWidth
    implicitHeight: Theme.volumeOsdHeight

    color: "transparent"
    visible: showOsd && ownsOsd

    property bool showOsd: false
    property bool cardOpen: false

    onShowOsdChanged: VolumeState.osdActive = showOsd

    function revealOsd() {
        if (AppState.volumePopupVisible || !root.ownsOsd)
            return
        root.showOsd = true
        root.cardOpen = true
        hideTimer.restart()
    }

    Connections {
        target: VolumeState
        function onOsdPulseChanged() { root.revealOsd() }
    }

    Connections {
        target: VolumeState
        function onVolumeChanged(fromExternal) {
            if (fromExternal)
                root.revealOsd()
        }
    }

    Connections {
        target: AppState
        function onVolumePopupVisibleChanged() {
            if (AppState.volumePopupVisible) {
                hideTimer.stop()
                hideDelay.stop()
                root.cardOpen = false
                root.showOsd = false
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 900
        repeat: false
        onTriggered: {
            root.cardOpen = false
            hideDelay.restart()
        }
    }

    Timer {
        id: hideDelay
        interval: 140
        repeat: false
        onTriggered: root.showOsd = false
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.barRadius + 2
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: Theme.pillBorderWidth

        property real slideX: 14
        opacity: 0
        transform: Translate { x: card.slideX }

        state: root.cardOpen ? "open" : "closed"
        states: [
            State { name: "closed"; PropertyChanges { target: card; slideX: 14;  opacity: 0.0 } },
            State { name: "open";   PropertyChanges { target: card; slideX: 0.0; opacity: 1.0 } }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation { target: card; property: "slideX"; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { target: card; property: "opacity"; duration: 90; easing.type: Easing.OutQuad }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation { target: card; property: "slideX"; duration: 140; easing.type: Easing.InCubic }
                NumberAnimation { target: card; property: "opacity"; duration: 110; easing.type: Easing.InQuad }
            }
        ]

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 16
                rightMargin: 16
                topMargin: 12
                bottomMargin: 12
            }
            spacing: 12

            Text {
                font.family: Theme.iconFontFamily
                font.pixelSize: Theme.iconSize + 4
                color: VolumeState.muted ? Theme.textMuted : Theme.textAccent
                text: VolumeState.volumeIcon()
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        text: "Громкость"
                    }

                    Text {
                        id: pctLabel
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Medium
                        color: VolumeState.muted ? Theme.textMuted : Theme.textPrimary
                        text: VolumeState.muted ? "Muted" : VolumeState.barLevel + "%"
                        scale: 1.0
                        Behavior on color { ColorAnimation { duration: 160 } }

                        NumberAnimation on scale {
                            id: pctScaleAnim
                            from: 1.12
                            to: 1.0
                            duration: 260
                            easing.type: Easing.OutBack
                        }
                    }

                    Connections {
                        target: VolumeState
                        function onRawVolumeChanged() { pctScaleAnim.restart() }
                        function onMutedChanged() { pctScaleAnim.restart() }
                    }
                }

                Item {
                    id: barHost
                    Layout.fillWidth: true
                    height: 10

                    readonly property real fillFrac: VolumeState.muted ? 0
                        : Math.min(1, VolumeState.barLevel / 100)

                    // Track background
                    Rectangle {
                        id: osdTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.rgba(Theme.barBorderColor.r, Theme.barBorderColor.g,
                                       Theme.barBorderColor.b, 0.4)
                    }

                    // Fill bar
                    Rectangle {
                        id: osdFill
                        anchors.left: osdTrack.left
                        anchors.verticalCenter: osdTrack.verticalCenter
                        height: osdTrack.height
                        radius: osdTrack.radius
                        width: osdTrack.width * barHost.fillFrac
                        color: VolumeState.muted ? Theme.textMuted : Theme.textAccent

                        Behavior on width {
                            NumberAnimation {
                                duration: 340
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        // Soft glow under fill
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: parent.color
                            opacity: 0.35
                            scale: 1.08
                            anchors.centerIn: parent
                        }
                    }

                    // Leading handle dot
                    Rectangle {
                        id: osdHandle
                        anchors.verticalCenter: osdTrack.verticalCenter
                        x: Math.max(-width / 2, barHost.width * barHost.fillFrac - width / 2)
                        width: 10
                        height: 10
                        radius: 5
                        color: VolumeState.muted ? Theme.textMuted : Theme.textAccent
                            border.color: Theme.popupBg
                        border.width: 2
                        visible: barHost.fillFrac > 0.01 && !VolumeState.muted
                        scale: 1.0

                        Behavior on x {
                            NumberAnimation {
                                duration: 340
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        SequentialAnimation {
                            id: handlePulse
                            NumberAnimation { target: osdHandle; property: "scale"; from: 1.0; to: 1.24; duration: 120; easing.type: Easing.OutQuad }
                            NumberAnimation { target: osdHandle; property: "scale"; from: 1.24; to: 1.0; duration: 220; easing.type: Easing.OutBack }
                        }
                    }

                    Connections {
                        target: VolumeState
                        function onRawVolumeChanged() { handlePulse.start() }
                    }
                }
            }
        }
    }
}
