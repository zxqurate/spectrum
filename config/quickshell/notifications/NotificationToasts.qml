import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../components"
import "../state"
import "../theme"
import "../widgets"

Scope {
    Variants {
        model: Quickshell.screens

        GlassPanelWindow {
            id: toastRoot
            required property var modelData

            screen: modelData
            WlrLayershell.namespace: "quickshell"
            WlrLayershell.layer: WlrLayer.Top

            anchors.top: true
            anchors.right: true
            exclusiveZone: -1
            color: "transparent"

            readonly property bool ownsToasts:
                !AppState.lockScreenVisible || NotificationState.showOnLockScreen

            margins {
                top: Theme.sidePanelTopInset
                right: Theme.barMargin + 4
            }

            implicitWidth: Theme.notificationToastWidth
            implicitHeight: toastCol.implicitHeight

            visible: ownsToasts && NotificationState.activeToasts.length > 0

            ColumnLayout {
                id: toastCol
                width: parent.width
                spacing: 8

                Repeater {
                    model: NotificationState.activeToasts

                    delegate: AnimatedNotificationItem {
                        id: toastEntry
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        notification: modelData
                        compact: false
                        showActions: true
                        swipeEnabled: true
                        showTimestamp: true
                        enterFromRight: true
                        onDismissed: notification => {
                            if (!NotificationState.clearingAll && notification)
                                NotificationState.finalizeDismiss(notification)
                        }

                        Timer {
                            interval: NotificationState.toastTimeoutMs(toastEntry.modelData)
                            running: interval > 0 && !toastEntry.exitStarted
                            repeat: false
                            onTriggered: toastEntry.playExit(function() {
                                NotificationState.removeToast(toastEntry.modelData)
                            })
                        }
                    }
                }
            }
        }
    }
}
