import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../theme"

RowLayout {
    id: trayRoot
    spacing: 4
    visible: count > 0

    property var panelWindow
    property int count: SystemTray.items?.values?.length ?? 0

    Repeater {
        model: SystemTray.items

        Item {
            required property var modelData
            implicitWidth: Theme.iconSize + 6
            implicitHeight: Theme.pillHeight

            IconImage {
                id: trayIcon
                anchors.centerIn: parent
                implicitSize: Theme.iconSize
                source: modelData?.icon ?? ""
                asynchronous: true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: event => {
                    if (!modelData)
                        return

                    if (event.button === Qt.LeftButton)
                        modelData.activate()
                    else if (event.button === Qt.MiddleButton)
                        modelData.secondaryActivate()
                    else if (event.button === Qt.RightButton && modelData.hasMenu && trayRoot.panelWindow)
                        modelData.display(trayRoot.panelWindow, trayIcon.x, trayIcon.height)
                }
            }
        }
    }
}
