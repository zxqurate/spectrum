import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../components"
import "../state"
import "../theme"

// Full-screen overlay (same pattern as ControlCenter / KeybindManager)
// The visible card sits at the bottom; the rest is a dim backdrop.
GlassPanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell"

    anchors.top:    true
    anchors.bottom: true
    anchors.left:   true
    anchors.right:  true
    exclusiveZone: -1
    color: "transparent"

    // ── Visibility gating ─────────────────────────────────────────────────────
    property bool showWindow: false
    visible: showWindow

    Component.onCompleted: readStateProc.running = true

    Connections {
        target: AppState
        function onWallpaperPickerVisibleChanged() {
            if (AppState.wallpaperPickerVisible) {
                WlrLayershell.layer = WlrLayer.Overlay
                WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand
                hideTimer.stop()
                root.showWindow = true
                root.loadWallpapers()
            } else {
                WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
                hideTimer.restart()
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 340
        onTriggered: { if (!AppState.wallpaperPickerVisible) root.showWindow = false }
    }

    // ── Wallpaper data ────────────────────────────────────────────────────────
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string wallpapersDir: homeDir + "/wallpapers"
    readonly property string stateFile:     homeDir + "/.local/state/quickshell/current_wallpaper"
    property string currentWallpaper: ""
    property string scanError: ""

    ListModel { id: wallpapersModel }

    function loadWallpapers() {
        scanError = ""
        listProc.running = false
        listProc.running = true
    }

    Process {
        id: listProc
        environment: ({ "WALLPAPERS_DIR": root.wallpapersDir })
        command: ["bash", "-c",
            "if [[ ! -d \"$WALLPAPERS_DIR\" ]]; then exit 2; fi; " +
            "find -L \"$WALLPAPERS_DIR\" -maxdepth 3 -type f \\( " +
            "-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " +
            "-o -iname '*.gif'  -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' \\) " +
            "2>/dev/null | sort"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                wallpapersModel.clear()
                const text = (this.text || "").trim()
                if (!text)
                    return
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].trim()
                    if (!p)
                        continue
                    const name  = p.split("/").pop()
                    const label = name.replace(/\.[^.]+$/, "")
                    wallpapersModel.append({ filePath: p, fileName: label })
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode === 2)
                root.scanError = "Directory not found: " + root.wallpapersDir
            else if (exitCode !== 0)
                root.scanError = "Could not scan " + root.wallpapersDir
        }
    }

    // ── Apply wallpaper + update color theme ─────────────────────────────────
    function applyWallpaper(path) {
        root.currentWallpaper = path
        AppState.currentWallpaperPath = path

        // 1. Persist selected path so it survives Hyprland restarts
        saveStateProc.running = false
        saveStateProc.wpPath  = path
        saveStateProc.running = true

        // 2. Set wallpaper with animated transition
        applyProc.running = false
        applyProc.wpPath  = path
        applyProc.running = true

        // 3. Regenerate color theme after a short delay
        //    (Colors.qml watches colors.json and auto-reloads; kitty/hyprland
        //     update via their post_hooks in matugen/config.toml)
        matugenTimer.pendingPath = path
        matugenTimer.restart()
    }

    // Read persisted wallpaper path on startup to restore the active indicator
    Process {
        id: readStateProc
        command: ["bash", "-c", "cat '" + root.stateFile + "' 2>/dev/null"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const p = data.trim()
                if (p) {
                    root.currentWallpaper = p
                    AppState.currentWallpaperPath = p
                }
            }
        }
    }

    // Persist selected wallpaper path across sessions
    Process {
        id: saveStateProc
        property string wpPath: ""
        command: ["bash", "-c",
            "mkdir -p \"$(dirname '" + root.stateFile + "')\" && " +
            "printf '%s' \"$WP\" > '" + root.stateFile + "'"]
        environment: ({"WP": wpPath})
        running: false
    }

    Process {
        id: applyProc
        property string wpPath: ""
        command: ["awww", "img",
            "--transition-type",     "grow",
            "--transition-pos",      "center",
            "--transition-duration", "0.8",
            "--transition-fps",      "30",
            wpPath]
        running: false
    }

    Timer {
        id: matugenTimer
        interval: 400
        property string pendingPath: ""
        onTriggered: {
            matugenProc.running  = false
            matugenProc.wpPath   = pendingPath
            matugenProc.running  = true
        }
    }

    // matugen regenerates: quickshell colors.json, kitty theme,
    // hyprland colors.conf, rofi colors — all via config.toml templates.
    //
    // Problem: matugen writes colors.json atomically (temp→rename = IN_MOVED_TO).
    // Quickshell's FileView.watchChanges only fires on IN_MODIFY (in-place write).
    // Fix: after matugen finishes, rewrite colors.json via non-atomic `cat > file`
    //      so IN_MODIFY fires and Colors singleton reloads live — no restart needed.
    Process {
        id: matugenProc
        property string wpPath: ""
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/run-matugen.sh", wpPath, ThemeState.themeMode]
        running: false
    }

    // ── Click-outside dismiss (no dim scrim) ───────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: AppState.wallpaperPickerVisible = false
    }

    // ── Card (bottom sheet) ───────────────────────────────────────────────────
    readonly property int cardHeight: 200

    Rectangle {
        id: card
        z: 1
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.cardHeight

        color:  Theme.panelBg
        border.color: Theme.panelBorder
        border.width: 1
        radius: 18

        // Square the bottom edge (the card is flush with the screen edge)
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.radius
            color:  parent.color
        }

        // ── Slide-up / slide-down animation ──────────────────────────────────
        property real slideY: root.cardHeight
        transform: Translate { y: card.slideY }

        state: AppState.wallpaperPickerVisible ? "open" : "closed"
        states: [
            State { name: "open";
                PropertyChanges { target: card; slideY: 0;             opacity: 1 } },
            State { name: "closed"
                PropertyChanges { target: card; slideY: root.cardHeight; opacity: 0 } }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation { target: card; property: "slideY"
                    duration: 420; easing.type: Easing.OutExpo }
                NumberAnimation { target: card; property: "opacity"
                    duration: 200; easing.type: Easing.OutQuad }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation { target: card; property: "slideY"
                    duration: 300; easing.type: Easing.InQuart }
                NumberAnimation { target: card; property: "opacity"
                    duration: 250; easing.type: Easing.InQuad }
            }
        ]

        MouseArea { anchors.fill: parent }  // swallow — don't let backdrop catch card clicks

        ColumnLayout {
            anchors {
                fill: parent
                leftMargin: 22; rightMargin: 22
                topMargin: 14;  bottomMargin: 12
            }
            spacing: 10

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                spacing: 10

                Text {
                    font.family: Theme.iconFontFamily; font.pixelSize: 16
                    color: Theme.textAccent; text: "󰸉"
                }
                Text {
                    font.family: Theme.fontFamily; font.pixelSize: 15
                    font.weight: Font.Medium; color: Theme.textPrimary
                    text: "Wallpapers"
                }
                Rectangle {
                    width: cntLbl.implicitWidth + 10; height: 18; radius: 9
                    color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g,
                                   Theme.textAccent.b, 0.15)
                    Text {
                        id: cntLbl
                        anchors.centerIn: parent
                        font.family: Theme.fontFamily; font.pixelSize: 10
                        color: Theme.textAccent; text: wallpapersModel.count
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    font.family: Theme.fontFamily; font.pixelSize: 11
                    color: Theme.textMuted; opacity: 0.55
                    text: "Click thumbnail to apply"
                }

                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: wpCloseMa.containsMouse
                        ? Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.15)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        font.family: Theme.iconFontFamily; font.pixelSize: 14
                        color: wpCloseMa.containsMouse ? Theme.textPrimary : Theme.textMuted
                        text: "󰅖"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    MouseArea {
                        id: wpCloseMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.wallpaperPickerVisible = false
                    }
                }
            }

            // ── Thumbnail list ────────────────────────────────────────────────
            ListView {
                id: thumbList
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 10
                clip: true
                model: wallpapersModel

                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                Text {
                    anchors.centerIn: parent
                    visible: wallpapersModel.count === 0
                    font.family: Theme.fontFamily; font.pixelSize: 13
                    color: Theme.textMuted; opacity: 0.55
                    horizontalAlignment: Text.AlignHCenter
                    text: root.scanError !== ""
                        ? root.scanError
                        : "No images found in " + root.wallpapersDir
                }

                delegate: Item {
                    id: thumb
                    required property string filePath
                    required property string fileName
                    required property int    index

                    readonly property bool isActive: root.currentWallpaper === filePath

                    width:  148
                    height: thumbList.height

                    // Scale up slightly on hover / active
                    scale: isActive ? 0.94 : (thumbMa.containsMouse ? 0.97 : 1.0)
                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // Rounded image frame — layer clips children to the radius
                    Rectangle {
                        id: frame
                        anchors.fill: parent
                        radius: 10
                        color: Qt.rgba(Theme.textMuted.r, Theme.textMuted.g,
                                       Theme.textMuted.b, 0.08)
                        layer.enabled: true

                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            source: "file://" + filePath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }

                        // Placeholder while loading
                        Rectangle {
                            anchors.fill: parent
                            visible: thumbImg.status !== Image.Ready
                            color: Qt.rgba(Theme.textMuted.r, Theme.textMuted.g,
                                           Theme.textMuted.b, 0.10)
                            Text {
                                anchors.centerIn: parent
                                font.family: Theme.iconFontFamily; font.pixelSize: 24
                                color: Qt.rgba(Theme.textMuted.r, Theme.textMuted.g,
                                               Theme.textMuted.b, 0.3)
                                text: "󰸉"
                            }
                        }

                        // Bottom gradient + name
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 36
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.72) }
                            }
                        }
                        Text {
                            anchors {
                                bottom: parent.bottom; left: parent.left; right: parent.right
                                bottomMargin: 5; leftMargin: 7
                            }
                            font.family: Theme.fontFamily; font.pixelSize: 10
                            color: "white"; opacity: 0.9
                            text: fileName; elide: Text.ElideRight
                        }

                        // Hover tint
                        Rectangle {
                            anchors.fill: parent
                            color: thumbMa.containsMouse && !isActive
                                ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    // Active / hover border (rendered outside the clipped frame)
                    Rectangle {
                        anchors.fill: parent
                        radius: 11
                        color: "transparent"
                        border.width: isActive ? 2.5 : 1.5
                        border.color: isActive
                            ? Theme.textAccent
                            : (thumbMa.containsMouse
                                ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g,
                                          Theme.textPrimary.b, 0.35)
                                : "transparent")
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                    }

                    // Active check badge
                    Rectangle {
                        visible: isActive
                        anchors { top: parent.top; right: parent.right; margins: 7 }
                        width: 22; height: 22; radius: 11
                        color: Theme.textAccent
                        Text {
                            anchors.centerIn: parent
                            font.family: Theme.iconFontFamily; font.pixelSize: 12
                            color: "white"; text: "󰄬"
                        }
                    }

                    MouseArea {
                        id: thumbMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyWallpaper(filePath)
                    }
                }
            }
        }
    }
}
