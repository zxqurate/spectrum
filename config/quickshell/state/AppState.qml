pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property bool controlCenterVisible: false
    property bool volumePopupVisible: false
    property bool wifiPopupVisible: false
    property bool statsPopupVisible: false
    property bool mediaPopupVisible: false
    property bool keybindManagerVisible: false
    property bool wallpaperPickerVisible: false
    property bool lockScreenVisible: false
    property bool sidePanelVisible: false
    property bool workspaceNumbersVisible: false
    property string currentWallpaperPath: ""

    property var mediaPopupScreen: null
    property var volumePopupScreen: null
    property var wifiPopupScreen: null
    property var sidePanelScreen: null

    function isSameScreen(a, b) {
        if (!a || !b)
            return false
        const an = a.name ?? a
        const bn = b.name ?? b
        return an === bn
    }

    function hideMediaPopup() {
        mediaPopupVisible = false
        mediaPopupScreen = null
    }

    function hideVolumePopup() {
        volumePopupVisible = false
        volumePopupScreen = null
    }

    function hideWifiPopup() {
        wifiPopupVisible = false
        wifiPopupScreen = null
    }

    function showMediaPopup(screen) {
        hideSidePanel()
        hideVolumePopup()
        hideWifiPopup()
        statsPopupVisible = false
        mediaPopupScreen = screen
        mediaPopupVisible = true
    }

    function toggleMediaPopup(screen) {
        if (mediaPopupVisible && isSameScreen(mediaPopupScreen, screen))
            hideMediaPopup()
        else
            showMediaPopup(screen)
    }

    function showVolumePopup(screen) {
        hideSidePanel()
        hideMediaPopup()
        hideWifiPopup()
        volumePopupScreen = screen
        volumePopupVisible = true
    }

    function toggleVolumePopup(screen) {
        if (volumePopupVisible && isSameScreen(volumePopupScreen, screen))
            hideVolumePopup()
        else
            showVolumePopup(screen)
    }

    function showWifiPopup(screen) {
        hideSidePanel()
        hideVolumePopup()
        hideMediaPopup()
        statsPopupVisible = false
        wifiPopupScreen = screen
        wifiPopupVisible = true
    }

    function toggleWifiPopup(screen) {
        if (wifiPopupVisible && isSameScreen(wifiPopupScreen, screen))
            hideWifiPopup()
        else
            showWifiPopup(screen)
    }

    function hideSidePanel() {
        sidePanelVisible = false
    }

    function finalizeSidePanelHide() {
        sidePanelScreen = null
    }

    function showSidePanel(screen) {
        hideMediaPopup()
        hideVolumePopup()
        hideWifiPopup()
        statsPopupVisible = false
        controlCenterVisible = false
        sidePanelScreen = screen
        sidePanelVisible = true
    }

    function toggleSidePanel(screen) {
        if (sidePanelVisible && isSameScreen(sidePanelScreen, screen))
            hideSidePanel()
        else
            showSidePanel(screen)
    }

    function hideAllOverlays() {
        controlCenterVisible = false
        hideVolumePopup()
        hideWifiPopup()
        statsPopupVisible = false
        mediaPopupVisible = false
        keybindManagerVisible = false
        wallpaperPickerVisible = false
        sidePanelVisible = false
        hideMediaPopup()
    }

    function showLockScreen() {
        hideAllOverlays()
        lockScreenVisible = true
    }

    function hideLockScreen() {
        lockScreenVisible = false
    }

    function toggleLockScreen() {
        if (lockScreenVisible)
            hideLockScreen()
        else
            showLockScreen()
    }

    readonly property string wallpaperStateFile:
        Quickshell.env("HOME") + "/.local/state/quickshell/current_wallpaper"

    Process {
        id: readWallpaperProc
        command: ["bash", "-c", "cat '" + wallpaperStateFile + "' 2>/dev/null"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const p = data.trim()
                if (p)
                    currentWallpaperPath = p
            }
        }
    }

    Component.onCompleted: readWallpaperProc.running = true
}
