import QtQuick
import Quickshell
import "./bar"
import "./bar/popups"
import "./theme"
import "./state"
import "./controlcenter"
import "./keybindmanager"
import "./wallpaper"
import "./lockscreen"
import "./notifications"

ShellRoot {
    BarShortcuts {}
    ControlCenter {}
    KeybindManager {}
    WallpaperPicker {}
    Bar {}
    StatsPopup {}
    NotificationToasts {}
    LockScreen {}
}
