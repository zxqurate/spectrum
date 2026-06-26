import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../theme"
import "."

Item {
    id: root

    implicitWidth: launcherIcon.implicitWidth
    implicitHeight: Theme.pillHeight

    property bool _busy: false

    function launch() {
        if (_busy)
            return
        _busy = true
        busyTimer.restart()
        Hyprland.dispatch(
            "exec bash " + Quickshell.env("HOME") + "/.config/rofi/launch.sh -show drun")
    }

    Timer {
        id: busyTimer
        interval: 350
        onTriggered: root._busy = false
    }

    BarLabel {
        id: launcherIcon
        anchors.centerIn: parent
        text: "󰍉"
        font.family: Theme.iconFontFamily
        font.weight: Font.Normal
        font.pixelSize: Theme.iconSize
        color: Theme.textAccent
    }
}
