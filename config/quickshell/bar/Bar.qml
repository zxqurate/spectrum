import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../components"
import "../theme"
import "../state"
import "./modules"
import "./popups"
import "../sidepanel"

Scope {
    Variants {
        model: Quickshell.screens

        Item {
            id: barScreen
            required property var modelData

            readonly property bool lockHidden: AppState.lockScreenVisible
            readonly property bool fullscreenHidden:
                BarState.isFullscreenOnScreen(modelData)
            readonly property bool barExpanded: !lockHidden && !fullscreenHidden
            readonly property real barHideDistance: Theme.pillHeight + Theme.barMargin

            property real barSlideY: 0
            property real barOpacity: 1

            states: [
                State {
                    name: "barExpanded"
                    when: barScreen.barExpanded
                    PropertyChanges {
                        target: barScreen
                        barSlideY: 0
                        barOpacity: 1
                    }
                },
                State {
                    name: "barCollapsed"
                    when: !barScreen.barExpanded
                    PropertyChanges {
                        target: barScreen
                        barSlideY: -barScreen.barHideDistance
                        barOpacity: 0
                    }
                }
            ]

            transitions: [
                Transition {
                    NumberAnimation {
                        properties: "barSlideY,barOpacity"
                        duration: Theme.barHideAnimMs
                        easing.type: Easing.InOutCubic
                    }
                }
            ]

            function hideScreenPopups() {
                if (AppState.isSameScreen(AppState.mediaPopupScreen, modelData))
                    AppState.hideMediaPopup()
                if (AppState.isSameScreen(AppState.volumePopupScreen, modelData))
                    AppState.hideVolumePopup()
                if (AppState.isSameScreen(AppState.wifiPopupScreen, modelData))
                    AppState.hideWifiPopup()
                if (AppState.isSameScreen(AppState.sidePanelScreen, modelData))
                    AppState.hideSidePanel()
                if (AppState.statsPopupVisible)
                    AppState.statsPopupVisible = false
            }

            onFullscreenHiddenChanged: {
                if (fullscreenHidden)
                    barScreen.hideScreenPopups()
            }

            GlassPanelWindow {
                id: barWindow
                screen: barScreen.modelData
                visible: !barScreen.lockHidden

                WlrLayershell.namespace: "quickshell"
                WlrLayershell.layer: WlrLayer.Overlay

                anchors {
                    top: true
                    left: true
                    right: true
                }

                margins {
                    top: Theme.barMargin
                    left: Theme.barMargin
                    right: Theme.barMargin
                }

                implicitHeight: Theme.pillHeight + Theme.barMargin
                exclusiveZone: barScreen.barExpanded ? Theme.pillHeight + Theme.barMargin : -1
                color: "transparent"

                Item {
                    id: barContent
                    anchors.fill: parent
                    transform: Translate { y: barScreen.barSlideY }
                    opacity: barScreen.barOpacity

                    // ── Left: workspaces ──────────────────────────────────────────
                    BarPill {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        fixedWidth: Theme.workspacePillWidth
                        Workspaces {
                            screen: barScreen.modelData
                        }
                    }

                    // ── Center: screen-true center ────────────────────────────────
                    Item {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Theme.pillHeight

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.pillGap

                            BarPill {
                                compact: true
                                interactive: true
                                onClicked: launcherPane.launch()
                                Launcher {
                                    id: launcherPane
                                }
                            }

                            BarPill {
                                id: statsPill
                                interactive: true
                                onEntered: AppState.statsPopupVisible = true
                                onExited: statsHideTimer.restart()
                                SystemStats { id: sysStats; polling: barScreen.barExpanded }
                            }

                            BarPill {
                                id: mediaPill
                                compact: true
                                interactive: true
                                onClicked: AppState.toggleMediaPopup(barScreen.modelData)
                                MediaPlayer {}
                            }
                        }
                    }

                    Timer {
                        id: statsHideTimer
                        interval: 350
                        onTriggered: AppState.statsPopupVisible = false
                    }

                    // ── Right: volume · network · clock ───────────────────────────
                    RowLayout {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        height: Theme.pillHeight
                        spacing: Theme.pillGap

                        BarPill {
                            id: volumePill
                            compact: true
                            interactive: true
                            onClicked: AppState.toggleVolumePopup(barScreen.modelData)
                            onWheeled: wheel => {
                                const delta = wheel.angleDelta.y > 0 ? 5 : -5
                                VolumeState.adjustVolume(delta)
                            }
                            Volume {}
                        }

                        BarPill {
                            compact: true
                            interactive: true
                            onClicked: AppState.toggleWifiPopup(barScreen.modelData)
                            NetworkStatus {}
                        }

                        BarPill {
                            interactive: true
                            onClicked: AppState.toggleSidePanel(barScreen.modelData)
                            BatteryClock {}
                        }
                    }
                }
            }

            SidePanel {
                screen: barScreen.modelData
            }

            MediaPopup {
                screen: barScreen.modelData
            }

            VolumePopup {
                screen: barScreen.modelData
            }

            WifiPopup {
                screen: barScreen.modelData
            }

            VolumeOsd {
                screen: barScreen.modelData
            }
        }
    }
}
