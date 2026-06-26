import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../state"
import "../../theme"

PanelWindow {
    id: root

    required property var screen

    WlrLayershell.namespace: "quickshell"

    anchors.top: true
    anchors.right: true

    exclusiveZone: -1

    margins {
        top: Theme.barMargin + Theme.pillHeight + 12
        right: Theme.volumePopupRightMargin
    }

    color: "transparent"
    implicitWidth: 280
    implicitHeight: 96

    property bool showPopup: false
    property bool localAdjusting: false
    readonly property bool ownsPopup: AppState.isSameScreen(AppState.volumePopupScreen, root.screen)

    visible: showPopup && ownsPopup

    Component.onCompleted: {
        VolumeState.refresh()
        syncPopupState()
    }

    function syncPopupState() {
        if (!AppState.volumePopupVisible || !ownsPopup) {
            if (!AppState.volumePopupVisible)
                hideTimer.start()
            else
                root.showPopup = false
            return
        }
        hideTimer.stop()
        root.showPopup = true
        VolumeState.refresh()
    }

    Connections {
        target: AppState
        function onVolumePopupVisibleChanged() { root.syncPopupState() }
        function onVolumePopupScreenChanged() { root.syncPopupState() }
        function onControlCenterVisibleChanged() {
            if (AppState.controlCenterVisible) AppState.hideVolumePopup()
        }
        function onMediaPopupVisibleChanged() {
            if (AppState.mediaPopupVisible) AppState.hideVolumePopup()
        }
         function onWifiPopupVisibleChanged() {
            if (AppState.wifiPopupVisible) AppState.hideVolumePopup()
        }
        function onSidePanelVisibleChanged() {
            if (AppState.sidePanelVisible) AppState.hideVolumePopup()
        }
    }

    Timer {
        id: hideTimer
        interval: 220
        repeat: false
        onTriggered: root.showPopup = false
    }

    Timer {
        id: localAdjustTimer
        interval: 120
        repeat: false
        onTriggered: root.localAdjusting = false
    }

    function setVol(pct) {
        root.localAdjusting = true
        localAdjustTimer.restart()
        VolumeState.queueSetVolumePercent(pct)
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.barRadius + 4
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: Theme.pillBorderWidth

        property real slideY: 0
        transform: Translate { y: card.slideY }

        state: root.showPopup && ownsPopup ? "open" : "closed"
        states: [
            State {
                name: "closed"
                PropertyChanges { target: card; slideY: -6; opacity: 0.0 }
            },
            State {
                name: "open"
                PropertyChanges { target: card; slideY: 0; opacity: 1.0 }
            }
        ]
        transitions: Transition {
            NumberAnimation { properties: "slideY,opacity"; duration: 200; easing.type: Easing.OutCubic }
        }

        Item {
            id: content
            anchors.fill: parent
            anchors.margins: 14

            // ── Header: mute · device · percent ─────────────────────────────
            Item {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 30

                Rectangle {
                    id: muteBtn
                    width: 30
                    height: 30
                    radius: 8
                    color: muteArea.containsMouse
                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.15)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.iconSize + 2
                        color: VolumeState.muted ? Theme.textMuted : Theme.textAccent
                        text: VolumeState.volumeIcon()
                    }

                    MouseArea {
                        id: muteArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: VolumeState.toggleMute()
                    }
                }

                Text {
                    id: pctLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.Medium
                    color: VolumeState.muted ? Theme.textMuted : Theme.textPrimary
                    text: VolumeState.muted ? "Muted" : VolumeState.percentLevel + "%"
                }

                Item {
                    anchors.left: muteBtn.right
                    anchors.leftMargin: 8
                    anchors.right: pctLabel.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30

                    Text {
                        anchors.centerIn: parent
                        width: parent.width
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: sinkArea.containsMouse ? Theme.textAccent : Theme.textMuted
                        text: VolumeState.sinkName + (VolumeState.hasMultipleSinks ? "  󰓡" : "")
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        id: sinkArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: VolumeState.cycleSink()
                    }
                }
            }

            // ── Slider row ────────────────────────────────────────────────────
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.topMargin: 10
                height: 26

                Rectangle {
                    id: decBtn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 8
                    color: decArea.containsMouse
                        ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.12)
                        : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.06)
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Text {
                        anchors.centerIn: parent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 14
                        color: Theme.textPrimary
                        text: "󰍴"
                    }

                    MouseArea {
                        id: decArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: setVol(VolumeState.percentLevel - 5)
                        onPressAndHold: stepHoldTimer.start()
                        onReleased: stepHoldTimer.stop()
                    }

                    Timer {
                        id: stepHoldTimer
                        interval: 120
                        repeat: true
                        onTriggered: setVol(VolumeState.percentLevel - 5)
                    }
                }

                Rectangle {
                    id: incBtn
                    width: 26
                    height: 26
                    radius: 8
                    anchors.right: parent.right
                    color: incArea.containsMouse
                        ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.12)
                        : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.06)
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Text {
                        anchors.centerIn: parent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 14
                        color: Theme.textPrimary
                        text: "󰐕"
                    }

                    MouseArea {
                        id: incArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: setVol(VolumeState.percentLevel + 5)
                        onPressAndHold: stepIncHoldTimer.start()
                        onReleased: stepIncHoldTimer.stop()
                    }

                    Timer {
                        id: stepIncHoldTimer
                        interval: 120
                        repeat: true
                        onTriggered: setVol(VolumeState.percentLevel + 5)
                    }
                }

                Item {
                    id: trackContainer
                    anchors.left: decBtn.right
                    anchors.leftMargin: 8
                    anchors.right: incBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26

                    readonly property real fillFraction: VolumeState.muted ? 0
                        : Math.min(1, VolumeState.barLevel / 100)

                    Rectangle {
                        id: track
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.rgba(Theme.barBorderColor.r,
                                       Theme.barBorderColor.g,
                                       Theme.barBorderColor.b, 0.45)

                        Rectangle {
                            width: track.width * trackContainer.fillFraction
                            height: parent.height
                            radius: parent.radius
                            color: VolumeState.muted ? Theme.textMuted : Theme.textAccent
                            Behavior on width {
                                enabled: root.localAdjusting
                                NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Rectangle {
                            x: (track.width * trackContainer.fillFraction) - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            radius: 7
                            color: VolumeState.muted ? Theme.textMuted : Theme.textAccent
                            border.color: Theme.popupBg
                            border.width: 2
                            Behavior on x {
                                enabled: root.localAdjusting
                                NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        propagateComposedEvents: false

                        onPressed: mouse => {
                            hideTimer.stop()
                            mouse.accepted = true
                        }
                        onReleased: mouse => mouse.accepted = true
                        onClicked: mouse => {
                            hideTimer.stop()
                            const fraction = Math.max(0, Math.min(1, mouse.x / track.width))
                            setVol(Math.round(fraction * 100))
                        }
                        onPositionChanged: mouse => {
                            if (pressed) {
                                hideTimer.stop()
                                const fraction = Math.max(0, Math.min(1, mouse.x / track.width))
                                setVol(Math.round(fraction * 100))
                            }
                        }

                        onWheel: wheel => {
                            const delta = wheel.angleDelta.y > 0 ? 5 : -5
                            setVol(VolumeState.percentLevel + delta)
                        }
                    }
                }
            }
        }
    }
}
