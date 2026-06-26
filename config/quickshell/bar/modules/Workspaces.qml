import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../theme"
import "../../state"

Item {
    id: root

    required property var screen

    implicitWidth: Theme.workspaceSlot * 10 + Theme.workspaceGap * 9
    implicitHeight: Theme.workspaceSlot

    property bool showNumbers: AppState.workspaceNumbersVisible
    readonly property int slot: Theme.workspaceSlot
    readonly property int gap: Theme.workspaceGap

    readonly property var hyprMonitor: {
        const values = Hyprland.monitors?.values ?? []
        const name = root.screen?.name ?? ""
        for (let i = 0; i < values.length; ++i) {
            if (values[i].name === name)
                return values[i]
        }
        return null
    }

    // Active workspace shown on this monitor (not global keyboard focus).
    readonly property int activeIndex: Math.max(0, (root.hyprMonitor?.activeWorkspace?.id ?? 1) - 1)

    // ── Workspace slots ───────────────────────────────────────────────────────
    Repeater {
        model: 10

        Item {
            x: index * (root.slot + root.gap)
            y: 0
            width: root.slot
            height: root.slot

            property var workspace: {
                const values = Hyprland.workspaces?.values ?? []
                for (let i = 0; i < values.length; ++i) {
                    if (values[i].id === index + 1)
                        return values[i]
                }
                return null
            }
            property bool isActive:    root.hyprMonitor?.activeWorkspace?.id === (index + 1)
            property bool hasWindows:  workspace !== null

            // Dot
            Rectangle {
                visible: !root.showNumbers
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: parent.hasWindows ? Theme.textPrimary : "transparent"
                border.width: Theme.workspaceDotBorder
                border.color: parent.hasWindows
                    ? Theme.textPrimary
                    : Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.55)
                opacity: parent.isActive ? 1.0 : (parent.hasWindows ? 0.75 : 0.5)

                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on color   { ColorAnimation  { duration: 150 } }
            }

            // Number mode (Super held)
            Text {
                visible: root.showNumbers
                z: 2
                width: 22
                height: 22
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: index + 1
                font.family: Theme.fontFamily
                font.weight: Font.Medium
                font.pixelSize: Theme.fontSize
                font.bold: false
                color: parent.isActive ? Theme.textAccent : Theme.textPrimary
                opacity: parent.isActive || parent.hasWindows ? 1 : 0.5
                transform: Translate {
                    x: (index + 1) === 1 ? 0.5 : 0
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    AppState.workspaceNumbersVisible = false
                    const mon = root.hyprMonitor
                    if (mon?.name)
                        Hyprland.dispatch("focusmonitor " + mon.name)
                    Hyprland.dispatch("workspace " + (index + 1))
                }
            }
        }
    }

    // ── Animated active ring (slides between slots in both modes) ─────────────
    Item {
        id: activeRingHost
        z: root.showNumbers ? 1 : 10
        width: root.slot
        height: root.slot
        x: root.activeIndex * (root.slot + root.gap)
        y: 0

        Behavior on x {
            NumberAnimation {
                duration: root.showNumbers ? 260 : 280
                easing.type: Easing.OutQuint
            }
        }

        Rectangle {
            id: activeRing
            anchors.centerIn: parent
            width: root.showNumbers ? 24 : 22
            height: root.showNumbers ? 24 : 22
            radius: width / 2
            color: "transparent"
            border.width: Theme.workspaceDotBorder + 0.5
            border.color: root.showNumbers ? Theme.textAccent : Theme.textPrimary
            opacity: root.showNumbers ? 1.0 : 0.65

            readonly property real dotScale: 18 / 22
            scale: root.showNumbers ? 1.0 : dotScale
            transformOrigin: Item.Center

            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 160 }
            }
        }
    }
}
