import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../state"
import "../../theme"
import "../../widgets"

Rectangle {
    id: root

    width: Theme.lockMediaWidth
    height: Theme.lockMediaHeight
    radius: Theme.lockCardRadius
    color: Theme.panelBgCard
    border.color: Theme.panelBorder
    border.width: 1
    clip: true

    readonly property bool hasMedia: MediaState.hasPlayer

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
        anchors.bottomMargin: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 88
                Layout.preferredHeight: 88
                radius: 14
                color: Theme.panelBgNested
                clip: true

                Image {
                    id: albumArt
                    anchors.fill: parent
                    anchors.margins: 1
                    source: MediaState.trackArtSource
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    visible: status === Image.Ready && source !== ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: !albumArt.visible
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 32
                    color: Theme.textMuted
                    text: "󰝚"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textMuted
                    text: hasMedia ? (MediaState.activePlayer?.identity ?? "Media") : "Media"
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    text: MediaState.trackTitle
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textMuted
                    text: MediaState.trackArtist
                    elide: Text.ElideRight
                }
            }
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
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                enabled: MediaState.hasPlayer && MediaState.canPrev
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
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                enabled: MediaState.hasPlayer
                opacity: enabled ? 1 : 0.35
                cursorShape: Qt.PointingHandCursor
                onClicked: MediaState.togglePlaying()
                Text {
                    anchors.centerIn: parent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 20
                    color: Theme.textAccent
                    text: MediaState.isPlaying ? "󰏤" : "󰐊"
                }
            }

            MouseArea {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                enabled: MediaState.hasPlayer && MediaState.canNext
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
