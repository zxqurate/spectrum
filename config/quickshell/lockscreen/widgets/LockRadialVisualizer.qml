import QtQuick
import "../../state"
import "../../theme"

Item {
    id: root

    property color barColor: Theme.textAccent
    property real innerRadius: 72
    property real maxBarLength: 46
    property real minBarLength: 10
    property real barWidth: 3
    property bool live: MediaState.isPlaying

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property int barCount: CavaState.barCount

    z: 0
    opacity: live ? 1 : 0.55

    Repeater {
        model: root.barCount
        delegate: Item {
            required property int index
            readonly property real level: {
                const _tick = CavaState.barsVersion
                return CavaState.bars[index] ?? 0.04
            }
            readonly property real barLen: root.minBarLength + level * root.maxBarLength
            readonly property real angleDeg: (index / root.barCount) * 360

            x: root.cx
            y: root.cy
            z: 0
            transform: [
                Translate { x: -root.barWidth / 2 },
                Rotation {
                    origin.x: root.barWidth / 2
                    origin.y: 0
                    angle: angleDeg
                }
            ]

            Rectangle {
                x: 0
                y: -(root.innerRadius + barLen)
                width: root.barWidth
                height: barLen
                radius: root.barWidth / 2
                color: root.barColor
                opacity: live ? (0.45 + level * 0.55) : (0.28 + level * 0.35)
                Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 80 } }
            }
        }
    }
}
