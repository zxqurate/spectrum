pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    property int _rev: 0

    function isFullscreenOnScreen(screen) {
        const _ = _rev
        if (!screen)
            return false
        const screenName = screen.name ?? screen
        const vals = Hyprland.toplevels?.values ?? []
        for (let i = 0; i < vals.length; ++i) {
            const t = vals[i]
            if (!t)
                continue
            if (!toplevelIsFullscreen(t))
                continue
            if (toplevelOnScreen(t, screenName))
                return true
        }
        return false
    }

    function toplevelIsFullscreen(t) {
        if (t.wayland?.fullscreen === true)
            return true
        const fs = t.lastIpcObject?.fullscreen
        return fs === true || fs === 1 || fs === 2
    }

    function toplevelOnScreen(t, screenName) {
        if (t.monitor?.name === screenName)
            return true
        const screens = t.wayland?.screens ?? []
        for (let i = 0; i < screens.length; ++i) {
            if (screens[i]?.name === screenName)
                return true
        }
        return false
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = event?.name ?? ""
            if (name === "fullscreen"
                || name === "activewindow"
                || name === "activewindowv2"
                || name === "openwindow"
                || name === "closewindow"
                || name === "movewindow"
                || name === "focusedmon"
                || name === "windowtitle")
                root._rev++
        }
        function onActiveToplevelChanged() {
            root._rev++
        }
    }
}
