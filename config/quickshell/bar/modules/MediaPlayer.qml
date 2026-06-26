import QtQuick
import "../../state"
import "../../theme"
import "."

Item {
    implicitWidth: mediaIcon.implicitWidth
    implicitHeight: Theme.pillHeight

    BarLabel {
        id: mediaIcon
        anchors.verticalCenter: parent.verticalCenter
        text: "󰝚"
        font.family: Theme.iconFontFamily
        font.weight: Font.Normal
        font.pixelSize: Theme.iconSize
        color: MediaState.isPlaying ? Theme.textAccent : Theme.textMuted
        Behavior on color { ColorAnimation { duration: 160 } }
    }
}
