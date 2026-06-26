import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "../../state"
import "../../theme"
import "../../widgets"

PanelWindow {
    id: root

    required property var screen

    WlrLayershell.namespace: "quickshell"

    anchors.top: true
    anchors.left: true

    exclusiveZone: -1

    margins {
        top: Theme.barMargin + Theme.pillHeight + 16
        left: root.screen ? Theme.mediaPopupLeftMargin(root.screen.width) : Theme.barMargin
    }

    color: "transparent"
    implicitWidth: Theme.mediaPopupWidth
    implicitHeight: Theme.mediaPopupHeight

    property bool showPopup: false
    property bool cardOpen: false
    readonly property bool ownsPopup: AppState.isSameScreen(AppState.mediaPopupScreen, root.screen)

    visible: showPopup && ownsPopup

    function syncPopupState() {
        if (!AppState.mediaPopupVisible || !ownsPopup) {
            if (!AppState.mediaPopupVisible) {
                root.cardOpen = false
                hideTimer.restart()
            } else {
                root.showPopup = false
                root.cardOpen = false
            }
            return
        }
        hideTimer.stop()
        root.showPopup = true
        root.cardOpen = false
        MediaState.refreshActivePlayer()
        openAnimTimer.restart()
    }

    Component.onCompleted: syncPopupState()

    Connections {
        target: AppState
        function onMediaPopupVisibleChanged() { root.syncPopupState() }
        function onMediaPopupScreenChanged() { root.syncPopupState() }
        function onVolumePopupVisibleChanged() {
            if (AppState.volumePopupVisible) AppState.hideMediaPopup()
        }
        function onWifiPopupVisibleChanged() {
            if (AppState.wifiPopupVisible) AppState.hideMediaPopup()
        }
        function onStatsPopupVisibleChanged() {
            if (AppState.statsPopupVisible) AppState.hideMediaPopup()
        }
        function onControlCenterVisibleChanged() {
            if (AppState.controlCenterVisible) AppState.hideMediaPopup()
        }
        function onSidePanelVisibleChanged() {
            if (AppState.sidePanelVisible) AppState.hideMediaPopup()
        }
    }

    Timer {
        id: openAnimTimer
        interval: 16
        repeat: false
        onTriggered: root.cardOpen = true
    }

    Timer {
        id: hideTimer
        interval: 260
        repeat: false
        onTriggered: root.showPopup = false
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.barRadius + 6
        color: Theme.popupBg
        border.color: Theme.popupBorder
        border.width: Theme.pillBorderWidth
        clip: true

        transformOrigin: Item.TopLeft

        property real slideY: -24
        property real cardScale: 0.92
        opacity: 0

        transform: [
            Scale {
                origin.x: 0
                origin.y: 0
                xScale: card.cardScale
                yScale: card.cardScale
            },
            Translate { y: card.slideY }
        ]

        state: root.cardOpen ? "open" : "closed"
        states: [
            State {
                name: "closed"
                PropertyChanges { target: card; slideY: -24; cardScale: 0.92; opacity: 0.0 }
            },
            State {
                name: "open"
                PropertyChanges { target: card; slideY: 0; cardScale: 1.0; opacity: 1.0 }
            }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation { target: card; property: "slideY"; duration: 320; easing.type: Easing.OutQuint }
                NumberAnimation { target: card; property: "cardScale"; duration: 320; easing.type: Easing.OutQuint }
                NumberAnimation { target: card; property: "opacity"; duration: 240; easing.type: Easing.OutQuad }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation { target: card; property: "slideY"; duration: 240; easing.type: Easing.InQuint }
                NumberAnimation { target: card; property: "cardScale"; duration: 240; easing.type: Easing.InQuint }
                NumberAnimation { target: card; property: "opacity"; duration: 200; easing.type: Easing.InQuad }
            }
        ]

        // ── Background visualizer (cava) ──────────────────────────────────────
        Item {
            anchors.fill: parent
            opacity: MediaState.isPlaying ? 0.28 : 0.08

            Repeater {
                model: CavaState.barCount
                delegate: Rectangle {
                    required property int index
                    property real norm: {
                        const _v = CavaState.barsVersion
                        return CavaState.bars[index] ?? 0.04
                    }
                    x: index / CavaState.barCount * card.width
                    width: card.width / CavaState.barCount - 2
                    height: 6 + norm * (card.height * 0.62)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    radius: 2
                    color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.38)
                    Behavior on height { NumberAnimation { duration: 7; easing.type: Easing.Linear } }
                }
            }
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 14
                topMargin: 12
                bottomMargin: 12
            }
            spacing: 12

            // Album art
            Item {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 84
                Layout.alignment: Qt.AlignVCenter
                Layout.topMargin: -4

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: MediaState.trackArtSource
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
                }

                Rectangle {
                    id: artMaskShape
                    anchors.fill: parent
                    radius: 16
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: artImg
                    maskSource: artMaskShape
                    visible: artImg.status === Image.Ready && MediaState.trackArtSource !== ""
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.06)
                    visible: MediaState.trackArtSource === "" || artImg.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        visible: MediaState.trackArtSource === ""
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 28
                        color: Theme.textMuted
                        text: "󰝚"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    text: MediaState.trackTitle
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textMuted
                    text: MediaState.trackArtist
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textMuted
                        text: {
                            const _ = MediaState.positionTick
                            return MediaState.formatTime(MediaState.displayPosition)
                        }
                    }

                    MediaSeekBar {
                        Layout.fillWidth: true
                    }

                    Text {
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textMuted
                        text: MediaState.formatTime(MediaState.trackLength)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Item { Layout.fillWidth: true }

                    MouseArea {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 28
                        enabled: MediaState.canPrev
                        opacity: enabled ? 1 : 0.35
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaState.previousTrack()
                        Text {
                            anchors.centerIn: parent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 17
                            color: Theme.textPrimary
                            text: "󰒮"
                        }
                    }

                    MouseArea {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 28
                        enabled: MediaState.hasPlayer
                        opacity: enabled ? 1 : 0.35
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaState.togglePlaying()
                        Text {
                            anchors.centerIn: parent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 19
                            color: Theme.textAccent
                            text: MediaState.isPlaying ? "󰏤" : "󰐊"
                        }
                    }

                    MouseArea {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 28
                        enabled: MediaState.canNext
                        opacity: enabled ? 1 : 0.35
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaState.nextTrack()
                        Text {
                            anchors.centerIn: parent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 17
                            color: Theme.textPrimary
                            text: "󰒭"
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
