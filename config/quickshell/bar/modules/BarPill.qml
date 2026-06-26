import QtQuick
import QtQuick.Layouts
import "../../theme"

Item {
    id: root

    property bool compact: false
    property int fixedWidth: -1
    property int hPad: compact ? Theme.pillPaddingHCompact : Theme.pillPaddingH

    // Interactivity: when true, the entire pill surface is clickable/hoverable
    property bool interactive: false
    readonly property bool hovered: _pillMouse.containsMouse && interactive

    default property alias content: layout.data

    implicitHeight: Theme.pillHeight
    implicitWidth: fixedWidth > 0 ? fixedWidth : layout.implicitWidth + hPad * 2

    signal clicked(var mouse)
    signal wheeled(var wheel)
    signal entered()
    signal exited()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.pillColor
        border.width: Theme.pillBorderWidth
        border.color: root.hovered ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.6)
                                   : Theme.barBorderColor

        Behavior on border.color { ColorAnimation { duration: 120 } }

        // Subtle hover glow overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b,
                           root.hovered ? 0.04 : 0)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: hPad
        anchors.rightMargin: hPad
        spacing: Theme.moduleSpacing
    }

    // Full-area overlay MouseArea — only active when interactive: true.
    // When enabled: false, mouse events pass through to inner children.
    MouseArea {
        id: _pillMouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: 100
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheeled(wheel)
        onEntered: root.entered()
        onExited: root.exited()
    }
}
