import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../state"
import "."

Item {
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.pillHeight

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        BarLabel {
            text: VolumeState.volumeIcon()
            font.family: Theme.iconFontFamily
            font.weight: Font.Normal
            font.pixelSize: Theme.iconSize
            color: VolumeState.muted ? Theme.textMuted : Theme.textPrimary
        }
    }
}
