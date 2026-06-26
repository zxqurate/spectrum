import QtQuick
import "../../theme"
import "../../state"
import "."

Item {
    implicitWidth: networkIcon.implicitWidth
    implicitHeight: Theme.pillHeight

    BarLabel {
        id: networkIcon
        anchors.verticalCenter: parent.verticalCenter
        text: ConnectionState.barGlyph
        font.family: Theme.iconFontFamily
        font.weight: Font.Normal
        font.pixelSize: Theme.iconSize
        color: ConnectionState.connected ? Theme.textAccent : Theme.textMuted
    }
}
