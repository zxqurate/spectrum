import QtQuick
import QtQuick.Layouts
import "../../theme"
import "."

BarLabel {
    id: clockText
    text: Qt.formatDateTime(new Date(), "ddd HH:mm")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockText.text = Qt.formatDateTime(new Date(), "ddd HH:mm")
    }
}
