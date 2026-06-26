import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../state"

// Registered once — must not live inside per-screen bar instances.
Scope {
    GlobalShortcut {
        name: "super-down"
        description: "Show workspace numbers"
        onPressed: AppState.workspaceNumbersVisible = true
    }

    GlobalShortcut {
        name: "super-up"
        description: "Hide workspace numbers"
        onReleased: AppState.workspaceNumbersVisible = false
    }

    GlobalShortcut {
        name: "cc-toggle"
        description: "Toggle control center"
        onPressed: {
            if (!ccDebounce.running) {
                if (!AppState.controlCenterVisible)
                    AppState.hideSidePanel()
                AppState.controlCenterVisible = !AppState.controlCenterVisible
                ccDebounce.restart()
            }
        }
    }

    Timer { id: ccDebounce; interval: 260; repeat: false }

    GlobalShortcut {
        name: "keybind-manager"
        description: "Toggle keybind manager"
        onPressed: {
            if (!kbDebounce.running) {
                AppState.keybindManagerVisible = !AppState.keybindManagerVisible
                kbDebounce.restart()
            }
        }
    }

    Timer { id: kbDebounce; interval: 260; repeat: false }

    GlobalShortcut {
        name: "wallpaper-picker"
        description: "Toggle wallpaper picker"
        onPressed: {
            if (!wpDebounce.running) {
                AppState.wallpaperPickerVisible = !AppState.wallpaperPickerVisible
                wpDebounce.restart()
            }
        }
    }

    Timer { id: wpDebounce; interval: 260; repeat: false }

    GlobalShortcut {
        name: "lock-screen"
        description: "Lock screen"
        onPressed: {
            if (!lockDebounce.running) {
                AppState.showLockScreen()
                lockDebounce.restart()
            }
        }
    }

    Timer { id: lockDebounce; interval: 260; repeat: false }
}
