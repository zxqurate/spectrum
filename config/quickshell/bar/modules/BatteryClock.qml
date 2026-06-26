import QtQuick
import "../../theme"
import "."

BarLabel {
    id: clockText
    text: Qt.formatDateTime(new Date(), "HH:mm")
    font.pixelSize: Theme.fontSize
    color: Theme.textAccent

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
    }
}
