import QtQuick
import "../../theme"

Item {
    id: root

    required property string label
    required property string icon
    required property real value
    required property real maxValue
    required property color accentColor

    readonly property real pct: maxValue > 0 ? Math.min(1, value / maxValue) : 0
    readonly property string resolvedIcon: {
        switch (label) {
        case "CPU": return "\uf4bc"
        case "Temp": return "\uf2c9"
        case "RAM": return String.fromCodePoint(0xF035B)
        case "Disk": return "\uf0a0"
        default: return icon
        }
    }
    readonly property string displayValue: {
        if (label === "Temp")
            return value > 0 ? Math.round(value) + "°" : "--"
        return Math.round(pct * 100) + "%"
    }

    implicitWidth: Theme.lockGaugeSize
    implicitHeight: Theme.lockGaugeSize + 22

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.lockGaugeSize
        height: Theme.lockGaugeSize
        radius: width / 2
        color: Theme.panelBgCard
        border.color: Theme.panelBorder
        border.width: 1

        Canvas {
            id: ring
            anchors.fill: parent
            anchors.margins: 8
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width
                const h = height
                const cx = w / 2
                const cy = h / 2
                const r = Math.min(w, h) / 2 - 3
                const start = -Math.PI / 2
                const sweep = Math.PI * 2 * root.pct

                ctx.lineWidth = 5
                ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.22)
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.stroke()

                if (root.pct > 0.001) {
                    ctx.strokeStyle = root.accentColor
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, start, start + sweep)
                    ctx.stroke()
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: root
                function onPctChanged() { ring.requestPaint() }
                function onAccentColorChanged() { ring.requestPaint() }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6
            font.family: Theme.iconFontFamily
            font.pixelSize: 17
            color: Theme.textMuted
            text: root.resolvedIcon
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 12
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
            color: Theme.textPrimary
            text: root.displayValue
        }
    }

    Text {
        anchors.top: card.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: card.width
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pixelSize: 11
        color: Theme.textMuted
        text: root.label
    }
}
