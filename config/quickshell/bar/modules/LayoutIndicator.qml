import QtQuick
import Quickshell.Hyprland
import "../../theme"
import "."

Item {
    implicitWidth: layoutIcon.implicitWidth
    implicitHeight: Theme.pillHeight

    property string layoutGlyph: {
        const t = Hyprland.activeToplevel
        if (!t)
            return "󰒄"
        if (t.lastIpcObject?.floating)
            return "󰒆"
        return "󰒄"
    }

    BarLabel {
        id: layoutIcon
        anchors.verticalCenter: parent.verticalCenter
        text: layoutGlyph
        font.pixelSize: Theme.iconSize
        color: Theme.textMuted
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch("layoutmsg togglesplit")
    }
}
