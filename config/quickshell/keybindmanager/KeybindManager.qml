import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../state"
import "../components"
import "../theme"

GlassPanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell"
    WlrLayershell.layer: WlrLayer.Top

    property bool showWindow: false
    visible: showWindow

    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: -1
    color: "transparent"
    focusable: true

    // ── Visibility ────────────────────────────────────────────────────────────
    Connections {
        target: AppState
        function onKeybindManagerVisibleChanged() {
            if (AppState.keybindManagerVisible) {
                hideTimer.stop()          // cancel any in-flight hide
                root.showWindow = true
                root.reloadFile()
            } else {
                root.cancelEdit()
                hideTimer.restart()       // restart resets countdown even if already running
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 440
        onTriggered: {
            // Guard: only hide if manager is genuinely still closed
            if (!AppState.keybindManagerVisible)
                root.showWindow = false
        }
    }

    // ── Data model ────────────────────────────────────────────────────────────
    property var    rawLines: []
    property string _buf:     ""
    property string fileContent: ""
    readonly property string confPath: Quickshell.env("HOME") + "/.config/hypr/keybinds.conf"

    ListModel { id: bindsModel }

    function reloadFile() {
        _buf = ""
        readFileProc.running = true
    }

    function parseFile(content) {
        const lines = content.split("\n")
        root.rawLines = lines.slice()

        // Collect $VARs
        const vars = {}
        for (let i = 0; i < lines.length; ++i) {
            const vm = lines[i].trim().match(/^\$(\w+)\s*=\s*(.+)$/)
            if (vm) vars["$" + vm[1]] = vm[2].trim()
        }

        // Resolve all variable references (iterative, handles chains)
        function resolve(s) {
            let r = s, prev = "", n = 0
            while (r !== prev && n++ < 10) { prev = r; for (const k in vars) r = r.split(k).join(vars[k]) }
            return r
        }

        bindsModel.clear()
        const entries = []
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim()
            if (!line || line.startsWith("#")) continue

            const m = line.match(/^(bind(?:el|m|r)?)\s*=\s*([^,]*),\s*([^,]*),\s*([^,]+)(?:,\s*(.*))?$/)
            if (!m) continue

            const bindType = m[1]
            const modsRaw  = m[2].trim()
            const keyRaw   = m[3].trim()
            const action   = m[4].trim()
            const argsRaw  = (m[5] || "").trim()

            // ── Filter out internal / hardware-only binds ────────────────────
            const resolvedKey     = resolve(keyRaw).toLowerCase()
            const isHardwareKey   = resolvedKey.startsWith("xf86")
            const isMouseBind     = bindType === "bindm"
            const isMouseKey      = resolvedKey.includes("mouse:") ||
                                    resolvedKey === "mouse_down" || resolvedKey === "mouse_up"
            const isSuperInternal = resolvedKey === "super_l" || resolvedKey === "super_r"
            const isInternalGlobal = action === "global" &&
                (argsRaw.includes("super-down") || argsRaw.includes("super-up"))
            if (isHardwareKey || isMouseBind || isMouseKey || isSuperInternal || isInternalGlobal)
                continue

            let category = "Other"
            if (action === "exec")                                            category = "Apps"
            else if (action === "workspace" || action === "movetoworkspace")  category = "Workspaces"
            else if (["killactive","fullscreen","togglefloating","pseudo",
                       "layoutmsg","movefocus","movewindow","exit"].includes(action)) category = "Windows"
            else if (bindType === "bindel")  category = "Media"
            else if (action === "global")    category = "Shell"

            entries.push({
                entryLineIdx: i,
                bindType:     bindType,
                modsRaw:      modsRaw,
                keyRaw:       keyRaw,
                mods:         resolve(modsRaw),
                key:          resolve(keyRaw),
                action:       action,
                args:         resolve(argsRaw),
                argsRaw:      argsRaw,
                category:     category
            })
        }

        const catOrder = { Apps: 0, Shell: 1, Windows: 2, Workspaces: 3, Media: 4, Other: 5 }
        entries.sort((a, b) => {
            const ca = catOrder[a.category] ?? 9
            const cb = catOrder[b.category] ?? 9
            if (ca !== cb)
                return ca - cb
            const ka = (a.mods + " " + a.key).toUpperCase()
            const kb = (b.mods + " " + b.key).toUpperCase()
            return ka.localeCompare(kb)
        })
        for (let i = 0; i < entries.length; ++i)
            bindsModel.append(entries[i])
    }

    // ── File I/O ──────────────────────────────────────────────────────────────
    Process {
        id: readFileProc
        command: ["bash", "-c", "cat '" + root.confPath + "'"]
        running: false
        stdout: SplitParser { onRead: data => { root._buf += data + "\n" } }
        onExited: { root.fileContent = root._buf; root.parseFile(root._buf) }
        onRunningChanged: if (running) { root._buf = ""; bindsModel.clear() }
    }

    Process {
        id: writeProc
        running: false
        environment: ({ "KC": root.fileContent })
        command: ["bash", "-c", "printf '%s' \"$KC\" > '" + root.confPath + "'"]
        onExited: hyprReload.running = true
    }

    Process {
        id: hyprReload
        command: ["hyprctl", "reload"]
        running: false
    }

    function saveFile() {
        writeProc.running = true
    }

    // ── Edit state ────────────────────────────────────────────────────────────
    property int    editingIdx:   -1
    property string capturedMods: ""
    property string capturedKey:  ""
    property bool   justCaptured: false   // triggers flash animation

    readonly property bool isEditing: editingIdx >= 0
    property bool   isAdding:      false
    property string addActionText: ""
    readonly property bool isPanelOpen: isEditing || isAdding

    // Keys as display array for the capture preview
    readonly property var capturedParts: {
        const arr = []
        if (capturedMods !== "") capturedMods.split(" ").forEach(m => arr.push(m))
        if (capturedKey  !== "") arr.push(capturedKey)
        return arr
    }

    function startEdit(idx) {
        editingIdx    = idx
        capturedMods  = ""
        capturedKey   = ""
        justCaptured  = false
        keyCatcher.forceActiveFocus()
    }

    function cancelEdit() {
        editingIdx    = -1
        isAdding      = false
        addActionText = ""
        capturedMods  = ""
        capturedKey   = ""
        justCaptured  = false
    }

    function confirmEdit() {
        if (editingIdx < 0 || capturedKey === "") return

        const entry    = bindsModel.get(editingIdx)
        const lineI    = entry.entryLineIdx
        const origLine = root.rawLines[lineI] || ""

        // Reconstruct line: replace MODS and KEY fields preserving rest
        const parts = origLine.split(",")
        if (parts.length >= 3) {
            // parts[0] = "bindXXX = MODS_OR_EMPTY"
            parts[0] = parts[0].replace(/=\s*.*$/, "= " + capturedMods)
            parts[1] = " " + capturedKey
            const arr = root.rawLines.slice()
            arr[lineI] = parts.join(",")
            root.rawLines = arr
        }
        root.fileContent = root.rawLines.join("\n")

        // Update displayed model (don't re-parse whole file)
        bindsModel.setProperty(editingIdx, "mods",    capturedMods)
        bindsModel.setProperty(editingIdx, "key",     capturedKey)
        bindsModel.setProperty(editingIdx, "modsRaw", capturedMods)
        bindsModel.setProperty(editingIdx, "keyRaw",  capturedKey)

        cancelEdit()
        saveFile()
    }

    function confirmAdd() {
        if (capturedKey === "" || addActionText.trim() === "") return
        const mods    = capturedMods ? capturedMods : ""
        const newLine = "bind = " + mods + ", " + capturedKey + ", " + addActionText.trim()
        // Remove trailing empty lines, append, restore trailing newline
        let arr = root.rawLines.slice()
        while (arr.length > 0 && arr[arr.length - 1].trim() === "") arr.pop()
        arr.push(newLine)
        arr.push("")
        root.rawLines    = arr
        root.fileContent = arr.join("\n")
        isAdding      = false
        addActionText = ""
        capturedMods  = ""
        capturedKey   = ""
        justCaptured  = false
        saveFile()
        reloadFile()
    }

    function deleteBind(idx) {
        if (idx < 0 || idx >= bindsModel.count) return

        const lineI = bindsModel.get(idx).entryLineIdx
        cancelEdit()

        const arr = root.rawLines.slice()
        if (lineI < 0 || lineI >= arr.length) return
        arr.splice(lineI, 1)
        root.rawLines = arr
        root.fileContent = arr.join("\n")
        saveFile()
        reloadFile()
    }

    // ── Key name mapping Qt → Hyprland ────────────────────────────────────────
    function qtKeyToHypr(keyCode) {
        const map = {
            16777220: "Return",    16777221: "Return",
            16777219: "BackSpace", 16777217: "Tab",
            16777216: "Escape",    16777223: "Delete",
            16777234: "Left",      16777236: "Right",
            16777235: "Up",        16777237: "Down",
            16777232: "Home",      16777233: "End",
            16777238: "Prior",     16777239: "Next",
            32:  "Space",
            16777264: "F1",  16777265: "F2",  16777266: "F3",  16777267: "F4",
            16777268: "F5",  16777269: "F6",  16777270: "F7",  16777271: "F8",
            16777272: "F9",  16777273: "F10", 16777274: "F11", 16777275: "F12",
            47:  "slash",         92:  "backslash",  59: "semicolon",
            39:  "apostrophe",    91:  "bracketleft", 93: "bracketright",
            44:  "comma",         46:  "period",
            45:  "minus",         61:  "equal",       96: "grave"
        }
        return map[keyCode] || null
    }

    function captureEvent(event) {
        const mods = []
        if (event.modifiers & Qt.MetaModifier)    mods.push("SUPER")
        if (event.modifiers & Qt.ShiftModifier)   mods.push("SHIFT")
        if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
        if (event.modifiers & Qt.AltModifier)     mods.push("ALT")

        const named = qtKeyToHypr(event.key)
        const keyStr = named || (event.text.length === 1 ? event.text.toUpperCase() : "")

        return { mods: mods.join(" "), key: keyStr }
    }

    // ── Category colors ───────────────────────────────────────────────────────
    function catColor(cat) {
        switch (cat) {
            case "Apps":       return Theme.textAccent
            case "Workspaces": return "#7ec8e3"
            case "Windows":    return "#9ecf8e"
            case "Media":      return "#d4a0e0"
            case "Shell":      return "#e0c060"
            default:           return Theme.textMuted
        }
    }

    function catIcon(cat) {
        switch (cat) {
            case "Apps":       return "󰀻"
            case "Workspaces": return "󰙀"
            case "Windows":    return "󰐕"
            case "Media":      return "󰝚"
            case "Shell":      return "󰅟"
            default:           return "󰌌"
        }
    }

    function friendlyDesc(action, args) {
        const a   = (action || "").trim().toLowerCase()
        const arg = (args   || "").trim()

        if (a === "exec") {
            if (!arg) return "Run Command"
            const lower = arg.toLowerCase()

            if (lower.includes("open-file-manager.sh") || lower.includes("open-file-manager"))
                return "Open File Manager"
            if (lower.includes("open-browser.sh") || lower.includes("open-browser"))
                return "Open Browser"
            if (lower.includes("rofi/launch.sh") || (lower.includes("rofi") && lower.includes("drun")))
                return "App Launcher"
            if (lower.includes("screenshot.sh")) {
                if (/\barea\b/.test(lower)) return "Screenshot (Area)"
                if (/\bfull\b/.test(lower)) return "Screenshot (Fullscreen)"
                return "Screenshot"
            }
            if (lower.includes("xdg-open")) {
                const target = lower.replace(/^xdg-open\s*/, "").trim()
                if (target.startsWith("http") || target.includes("://"))
                    return "Open Browser"
                return "Open File Manager"
            }
            if (lower.includes("grim") && lower.includes("slurp")) return "Screenshot (Area)"
            if (lower.includes("grim"))                           return "Screenshot (Fullscreen)"
            if (lower.includes("switchxkblayout"))                return "Switch Keyboard Layout"

            const cmd = arg.split(/\s+/)[0].split("/").pop().toLowerCase()
            if (cmd === "bash" || cmd === "sh") {
                if (lower.includes("wl-copy")) return "Copy to Clipboard"
                return "Run Script"
            }
            if (cmd === "hyprctl") {
                if (lower.includes("switchxkblayout")) return "Switch Keyboard Layout"
                if (lower.includes("reload"))          return "Reload Hyprland"
                return "Hyprctl Command"
            }
            if (["kitty","alacritty","foot","wezterm"].includes(cmd)) return "Open Terminal"
            if (cmd === "rofi")
                return arg.includes("drun") ? "App Launcher" : "Command Runner"
            if (["thunar","nautilus","nemo","pcmanfm","dolphin"].includes(cmd))
                return "Open File Manager"
            if (["firefox","brave","chromium","chrome","google-chrome-stable","zen-browser","librewolf"].includes(cmd))
                return "Open Browser"
            if (cmd === "brightnessctl")
                return arg.includes("+") ? "Brightness Up" : "Brightness Down"
            if (cmd === "wpctl") {
                if (arg.includes("set-mute")) return "Mute Toggle"
                return arg.includes("+") ? "Volume Up" : "Volume Down"
            }
            return "Open " + cmd.charAt(0).toUpperCase() + cmd.slice(1)
        }
        switch (a) {
            case "killactive":      return "Close Window"
            case "exit":            return "Exit Hyprland"
            case "togglefloating":  return "Toggle Floating"
            case "fullscreen":      return "Toggle Fullscreen"
            case "pseudo":          return "Toggle Pseudo-tile"
            case "layoutmsg":
                return arg === "togglesplit" ? "Toggle Split" : "Layout: " + arg
            case "workspace":
                return arg === "e+1" ? "Next Workspace"
                     : arg === "e-1" ? "Prev Workspace"
                     : "Workspace " + arg
            case "movetoworkspace": return "Move to Workspace " + arg
            case "movefocus": {
                const d = {l:"Left",r:"Right",u:"Up",d:"Down"}
                return "Focus " + (d[arg] || arg)
            }
            case "movewindow": {
                const d = {l:"Left",r:"Right",u:"Up",d:"Down"}
                return "Move Window " + (d[arg] || arg)
            }
            case "global": {
                const gm = {
                    "quickshell:cc-toggle":       "Control Center",
                    "quickshell:keybind-manager":  "Keybind Manager",
                    "quickshell:lock-screen":      "Lock Screen",
                    "quickshell:wallpaper-picker": "Wallpaper Picker"
                }
                return gm[arg] || ("Global: " + arg)
            }
            default:
                return action + (arg ? "  " + arg : "")
        }
    }

    // ── Click-outside dismiss (no dim scrim) ───────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.isPanelOpen) root.cancelEdit()
            else AppState.keybindManagerVisible = false
        }
    }

    // ── Card ─────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        z: 1
        anchors.centerIn: parent
        width: 700
        height: 560
        radius: Theme.ccRadius
        color: Theme.panelBg
        border.color: Theme.panelBorder
        border.width: 1.5
        clip: true

        property real yOff: 0
        transform: Translate { y: card.yOff }

        state: AppState.keybindManagerVisible ? "open" : "closed"
        states: [
            State {
                name: "closed"
                PropertyChanges { target: card
                    yOff: -(root.height / 2 - Theme.barMargin - Theme.pillHeight / 2)
                    opacity: 0.0 }
            },
            State {
                name: "open"
                PropertyChanges { target: card; yOff: 0.0; opacity: 1.0 }
            }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation { target: card; property: "yOff"; duration: 380; easing.type: Easing.OutExpo }
                NumberAnimation { target: card; property: "opacity"; duration: 200; easing.type: Easing.OutQuad }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation { target: card; property: "yOff"; duration: 360; easing.type: Easing.InQuart }
                NumberAnimation { target: card; property: "opacity"; duration: 300; easing.type: Easing.InQuad }
            }
        ]

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors { fill: parent; margins: 24 }
            spacing: 14

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                spacing: 10

                Text {
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 18
                    color: Theme.textAccent
                    text: "󰌌"
                }
                Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    text: "Keybinds"
                }
                // Count badge
                Rectangle {
                    width: countLbl.implicitWidth + 10
                    height: 18
                    radius: 9
                    color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.15)
                    Text {
                        id: countLbl
                        anchors.centerIn: parent
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textAccent
                        text: bindsModel.count
                    }
                }

                // Add new keybind button
                Rectangle {
                    width: addLbl.implicitWidth + 20; height: 26; radius: 8
                    color: addBtnMa.containsMouse || root.isAdding
                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.22)
                        : Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.10)
                    border.color: root.isAdding
                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.55)
                        : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            font.family: Theme.iconFontFamily; font.pixelSize: 11
                            color: Theme.textAccent; text: "󰐕"
                        }
                        Text {
                            id: addLbl
                            font.family: Theme.fontFamily; font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.textAccent; text: "New bind"
                        }
                    }
                    MouseArea {
                        id: addBtnMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.isAdding) { root.cancelEdit(); return }
                            root.cancelEdit()
                            root.isAdding = true
                            keyCatcher.forceActiveFocus()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Search field
                Rectangle {
                    width: 210; height: 32
                    radius: 10
                    color: Theme.panelBgNested
                    border.color: searchInput.activeFocus
                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.55)
                        : Theme.panelBorder
                    border.width: 1.5
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 6
                        Text {
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 12
                            color: Theme.textMuted
                            text: "󰍉"
                        }
                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textPrimary
                            selectByMouse: true
                            clip: true
                            Keys.onEscapePressed: {
                                if (text.length > 0) { text = ""; event.accepted = true }
                                else { event.accepted = false }
                            }
                            Text {
                                anchors.fill: parent
                                visible: searchInput.text.length === 0 && !searchInput.activeFocus
                                text: "Search…"
                                font: searchInput.font
                                color: Theme.textMuted
                            }
                        }
                        Text {
                            visible: searchInput.text.length > 0
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 11
                            color: Theme.textMuted
                            text: "󰅖"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchInput.text = ""
                            }
                        }
                    }
                }

                // Close button
                Rectangle {
                    width: 32; height: 32; radius: 8
                    color: closeMa.containsMouse
                        ? Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.15)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 14
                        color: closeMa.containsMouse ? Theme.textPrimary : Theme.textMuted
                        text: "󰅖"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    MouseArea {
                        id: closeMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.keybindManagerVisible = false
                    }
                }
            }

            // ── Edit panel (clip-only slide animation, no opacity tricks) ──────────
            Rectangle {
                id: editPanelRect
                Layout.fillWidth: true
                // Layout.preferredHeight drives the slide-in/out so that ColumnLayout
                // repositions the list below in sync with the animation.
                // edit mode:  16(top) + 16(header) + 10 + 34(capRow) + 12(bot) = 88
                // add  mode:  88 + 10 + 32(input)                               = 130
                Layout.preferredHeight: root.isPanelOpen ? (root.isAdding ? 130 : 88) : 0
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                clip: true
                radius: 14
                color: Theme.panelBgNested
                border.color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b,
                                      root.isEditing ? 0.5 : 0)
                border.width: 1.5
                Behavior on border.color { ColorAnimation { duration: 200 } }

                // ── Panel content ──────────────────────────────────────────────
                ColumnLayout {
                    id: editPanel
                    anchors { left: parent.left; right: parent.right; top: parent.top
                              margins: 16 }
                    spacing: 10

                    // Header row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            font.family: Theme.iconFontFamily; font.pixelSize: 11
                            color: Theme.textAccent
                            text: root.isAdding ? "󰐕" : "󰏫"
                        }
                        Text {
                            Layout.fillWidth: true
                            font.family: Theme.fontFamily; font.pixelSize: 11
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            text: root.isAdding
                                ? "New keybind — press keys, then type the action below"
                                : (root.editingIdx >= 0
                                    ? "Rebinding: " + root.friendlyDesc(
                                        bindsModel.get(root.editingIdx).action,
                                        bindsModel.get(root.editingIdx).args)
                                    : "")
                        }
                    }

                    // Action TextInput — add mode only; height-clipped when hidden
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.isAdding ? 32 : 0
                        Behavior on Layout.preferredHeight {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                        clip: true
                        radius: 8
                        color: Theme.panelBgNested
                        border.color: addActionInput.activeFocus
                            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.5)
                            : Theme.panelBorder
                        border.width: 1.5
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8
                            Text {
                                font.family: Theme.iconFontFamily; font.pixelSize: 11
                                color: Theme.textMuted; text: "󰅟"
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                TextInput {
                                    id: addActionInput
                                    anchors { left: parent.left; right: parent.right
                                              verticalCenter: parent.verticalCenter }
                                    font.family: Theme.fontFamily; font.pixelSize: 13
                                    color: Theme.textPrimary
                                    selectByMouse: true; clip: true
                                    text: root.addActionText
                                    onTextChanged: root.addActionText = text
                                    Keys.onEscapePressed: { root.cancelEdit(); event.accepted = true }
                                    Text {
                                        anchors { left: parent.left; right: parent.right
                                                  verticalCenter: parent.verticalCenter }
                                        visible: addActionInput.text.length === 0 && !addActionInput.activeFocus
                                        text: "exec kitty  ·  killactive  ·  workspace 3…"
                                        font: addActionInput.font
                                        color: Theme.textMuted; opacity: 0.55
                                    }
                                }
                            }
                        }
                    }

                    // CaptureBox row + buttons
                    RowLayout {
                        id: captureButtonRow
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        spacing: 12

                            // Key capture display — capsules with + separator
                            Rectangle {
                                id: captureBox
                                Layout.preferredWidth: capRow.implicitWidth + 28
                                Layout.preferredHeight: 34
                                radius: 10
                                color: root.isEditing && root.capturedKey === ""
                                    ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.07)
                                    : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.05)
                                border.color: root.isEditing && root.capturedKey === ""
                                    ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.4)
                                    : Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.65)
                                border.width: 1.5
                                Behavior on color       { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                // Pulse animation while waiting for key
                                SequentialAnimation on opacity {
                                    running: root.isEditing && root.capturedKey === ""
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.55; duration: 600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
                                }

                                Row {
                                    id: capRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    // Placeholder when no key captured yet
                                    Text {
                                        visible: root.capturedKey === ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        color: Theme.textAccent
                                        text: "Press a combination…"
                                    }

                                    // Captured key capsules with + separators
                                    Repeater {
                                        model: root.capturedParts
                                        Row {
                                            required property string modelData
                                            required property int    index
                                            spacing: 4
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                visible: index > 0
                                                anchors.verticalCenter: parent.verticalCenter
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                color: Theme.textMuted
                                                text: "+"
                                            }
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: 24
                                                width: capKeyLbl.implicitWidth + 12
                                                radius: 6
                                                color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.18)
                                                border.color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.35)
                                                border.width: 1
                                                Text {
                                                    id: capKeyLbl
                                                    anchors.centerIn: parent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                    color: Theme.textAccent
                                                    text: modelData
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Hint text
                            Text {
                                visible: root.capturedKey !== ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textMuted
                                text: "Enter to save · Esc to cancel"
                            }

                            Item { Layout.fillWidth: true }

                            // Cancel button
                            Rectangle {
                                Layout.preferredWidth: 76
                                Layout.preferredHeight: 30
                                radius: 8
                                color: cxMa.containsMouse
                                    ? Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.15)
                                    : Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.07)
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text {
                                    anchors.centerIn: parent
                                    font.family: Theme.fontFamily; font.pixelSize: 13
                                    color: Theme.textMuted; text: "Cancel"
                                }
                                MouseArea {
                                    id: cxMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cancelEdit()
                                }
                            }

                            // Save / Add button
                            Rectangle {
                                id: saveBtn
                                Layout.preferredWidth: 76
                                Layout.preferredHeight: 30
                                radius: 8

                                readonly property bool canSave: root.isAdding
                                    ? (root.capturedKey !== "" && root.addActionText.trim() !== "")
                                    : (root.capturedKey !== "")

                                color: canSave
                                    ? (svMa.containsMouse
                                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.38)
                                        : Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.22))
                                    : Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.08)
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text {
                                    anchors.centerIn: parent
                                    font.family: Theme.fontFamily; font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: saveBtn.canSave ? Theme.textAccent : Theme.textMuted
                                    text: root.isAdding ? "Add" : "Save"
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }
                                MouseArea {
                                    id: svMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: saveBtn.canSave ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (!saveBtn.canSave) return
                                        if (root.isAdding) root.confirmAdd()
                                        else root.confirmEdit()
                                    }
                                }
                            }
                    }  // end RowLayout (captureButtonRow)
                }  // end ColumnLayout (editPanel)
            }  // end Rectangle (editPanelRect)

            // ── Binds list ────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: Theme.panelBgNested
                border.color: Theme.panelBorder
                border.width: 1
                clip: true

                ListView {
                    id: bindsList
                    anchors { fill: parent; margins: 6 }
                    spacing: 1
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    model: bindsModel

                    property string filter: searchInput.text.toLowerCase().trim()

                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
                    }

                    delegate: Rectangle {
                        id: bRow
                        required property string mods
                        required property string key
                        required property string action
                        required property string args
                        required property string category
                        required property int    entryLineIdx
                        required property int    index

                        readonly property var keysArr: {
                            const arr = []
                            if (mods !== "") mods.split(" ").forEach(k => arr.push(k))
                            if (key  !== "") arr.push(key)
                            return arr
                        }

                        readonly property bool matchesFilter: {
                            const f = bindsList.filter
                            if (!f) return true
                            return (mods     || "").toLowerCase().includes(f)
                                || (key      || "").toLowerCase().includes(f)
                                || (action   || "").toLowerCase().includes(f)
                                || (args     || "").toLowerCase().includes(f)
                                || (category || "").toLowerCase().includes(f)
                                || root.friendlyDesc(action, args).toLowerCase().includes(f)
                        }

                        visible: matchesFilter
                        height:  matchesFilter ? 40 : 0
                        clip: true
                        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                        width: bindsList.width
                        radius: 8
                        color: root.editingIdx === index
                            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.10)
                            : (bRowMa.containsMouse
                                ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.06)
                                : "transparent")
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                            spacing: 0

                            // ── Key capsules (fixed column) ───────────────────
                            Item {
                                Layout.preferredWidth: 208
                                Layout.maximumWidth: 208
                                Layout.minimumWidth: 208
                                Layout.alignment: Qt.AlignVCenter
                                height: parent.height
                                clip: true

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Repeater {
                                        model: bRow.keysArr
                                        Row {
                                            required property string modelData
                                            required property int    index
                                            spacing: 3
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                visible: index > 0
                                                anchors.verticalCenter: parent.verticalCenter
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Qt.rgba(Theme.textMuted.r, Theme.textMuted.g,
                                                               Theme.textMuted.b, 0.7)
                                                text: "+"
                                            }
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: 20
                                                width: kl.implicitWidth + 10
                                                radius: 5
                                                color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g,
                                                               Theme.textPrimary.b, 0.08)
                                                border.color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g,
                                                                       Theme.textPrimary.b, 0.16)
                                                border.width: 1
                                                Text {
                                                    id: kl
                                                    anchors.centerIn: parent
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.Medium
                                                    color: Theme.textPrimary
                                                    text: modelData
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Arrow (fixed column) ──────────────────────────
                            Text {
                                Layout.preferredWidth: 18
                                Layout.maximumWidth: 18
                                Layout.alignment: Qt.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 11
                                color: Qt.rgba(Theme.textMuted.r, Theme.textMuted.g,
                                               Theme.textMuted.b, 0.5)
                                text: "→"
                            }

                            // ── Friendly description ──────────────────────────
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.alignment: Qt.AlignVCenter
                                Layout.leftMargin: 4
                                Layout.rightMargin: 8
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.textPrimary
                                opacity: 0.85
                                text: root.friendlyDesc(bRow.action, bRow.args)
                                elide: Text.ElideRight
                            }

                            // ── Category chip (fixed column, right-aligned) ───
                            Item {
                                Layout.preferredWidth: 96
                                Layout.maximumWidth: 96
                                Layout.minimumWidth: 96
                                Layout.alignment: Qt.AlignVCenter
                                height: parent.height

                                RowLayout {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Text {
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: 11
                                        color: Qt.rgba(Qt.color(root.catColor(bRow.category)).r,
                                                       Qt.color(root.catColor(bRow.category)).g,
                                                       Qt.color(root.catColor(bRow.category)).b, 0.85)
                                        text: root.catIcon(bRow.category)
                                    }
                                    Text {
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        color: Qt.rgba(Qt.color(root.catColor(bRow.category)).r,
                                                       Qt.color(root.catColor(bRow.category)).g,
                                                       Qt.color(root.catColor(bRow.category)).b, 0.75)
                                        text: bRow.category
                                    }
                                }
                            }

                            // ── Row actions (edit + delete) ───────────────────
                            Item {
                                Layout.preferredWidth: 64
                                Layout.maximumWidth: 64
                                Layout.minimumWidth: 64
                                Layout.alignment: Qt.AlignVCenter
                                height: parent.height

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    opacity: (bRowMa.containsMouse || editMa.containsMouse ||
                                                deleteMa.containsMouse || root.editingIdx === index)
                                             ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                                    Rectangle {
                                        id: editBtn
                                        width: 28; height: 28; radius: 7
                                        anchors.verticalCenter: parent.verticalCenter

                                        color: editMa.containsMouse
                                            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.26)
                                            : Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.10)
                                        Behavior on color { ColorAnimation { duration: 80 } }

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: 13
                                            color: Theme.textAccent
                                            text: root.editingIdx === index ? "󰄬" : "󰏫"
                                        }
                                        MouseArea {
                                            id: editMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.editingIdx === index) root.confirmEdit()
                                                else root.startEdit(index)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: deleteBtn
                                        width: 28; height: 28; radius: 7
                                        anchors.verticalCenter: parent.verticalCenter

                                        readonly property color deleteColor: Qt.color(Colors.md3.error)

                                        color: deleteMa.containsMouse
                                            ? Qt.rgba(deleteColor.r, deleteColor.g, deleteColor.b, 0.24)
                                            : Qt.rgba(deleteColor.r, deleteColor.g, deleteColor.b, 0.10)
                                        Behavior on color { ColorAnimation { duration: 80 } }

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: Theme.iconFontFamily
                                            font.pixelSize: 13
                                            color: deleteBtn.deleteColor
                                            text: "󰆴"
                                        }
                                        MouseArea {
                                            id: deleteMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.deleteBind(index)
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: bRowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                            onClicked: {
                                if (!editMa.containsMouse && !deleteMa.containsMouse)
                                    root.startEdit(index)
                            }
                        }
                    }
                }
            }

            // ── Footer ────────────────────────────────────────────────────────
            RowLayout {
                spacing: 8
                Text {
                    font.family: Theme.iconFontFamily; font.pixelSize: 11
                    color: Theme.textMuted; opacity: 0.6; text: "󰏫"
                }
                Text {
                    font.family: Theme.fontFamily; font.pixelSize: 11
                    color: Theme.textMuted; opacity: 0.6
                    text: "Click a row to rebind  ·  󰆴 removes bind"
                }
                Item { Layout.fillWidth: true }
                Text {
                    font.family: Theme.fontFamily; font.pixelSize: 11
                    color: Theme.textMuted; opacity: 0.6
                    text: "Enter — save  ·  Esc — cancel  ·  saves automatically"
                }
            }
        }
    }

    // ── Keyboard capture ──────────────────────────────────────────────────────
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: root.isPanelOpen
        visible: root.isPanelOpen

        Keys.onPressed: event => {
            event.accepted = true

            // When action TextInput is focused (add mode typing): delegate most keys to it
            if (root.isAdding && addActionInput.activeFocus) {
                if (event.key === Qt.Key_Escape) { root.cancelEdit(); return }
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                    root.capturedKey !== "" && root.addActionText.trim() !== "") {
                    root.confirmAdd(); return
                }
                event.accepted = false  // let TextInput handle normal typing
                return
            }

            // Esc always cancels
            if (event.key === Qt.Key_Escape) {
                root.cancelEdit(); return
            }

            // Ignore bare modifier presses
            if (event.key === Qt.Key_Meta    || event.key === Qt.Key_Super_L ||
                event.key === Qt.Key_Super_R || event.key === Qt.Key_Shift   ||
                event.key === Qt.Key_Control || event.key === Qt.Key_Alt) {
                event.accepted = false; return
            }

            // Bare Enter with key captured: confirm or move to action input
            const isBareEnter = (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                             && !(event.modifiers & (Qt.MetaModifier | Qt.ShiftModifier |
                                                     Qt.ControlModifier | Qt.AltModifier))
            if (isBareEnter && root.capturedKey !== "") {
                if (root.isAdding) addActionInput.forceActiveFocus()
                else root.confirmEdit()
                return
            }

            // Otherwise: capture this combination
            const r = root.captureEvent(event)
            if (r.key !== "") {
                root.capturedMods = r.mods
                root.capturedKey  = r.key
                root.justCaptured = true
                capturedFlashTimer.restart()
                // In add mode: auto-shift focus to action field after capture
                if (root.isAdding) Qt.callLater(() => addActionInput.forceActiveFocus())
            }
        }
    }

    Timer {
        id: capturedFlashTimer
        interval: 120
        onTriggered: root.justCaptured = false
    }
}
