import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../state"
import "../theme"
import "../widgets"
import "./widgets"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: root

            required property var modelData

            screen: modelData
            WlrLayershell.namespace: "quickshell-lock"

            anchors { top: true; left: true; right: true; bottom: true }
            exclusiveZone: -1
            color: "transparent"
            focusable: true

            readonly property bool ownsFocus:
                Quickshell.screens.length === 0
                || screen.name === Quickshell.screens[0].name

            readonly property string avatarPath:
                "file://" + Quickshell.env("HOME") + "/.face"
            readonly property string wallpaperPath: {
                const fromState = AppState.currentWallpaperPath
                if (fromState && fromState.length > 0)
                    return fromState.startsWith("file://") ? fromState : "file://" + fromState
                return "file://" + Quickshell.env("HOME") + "/wallpapers/default.jpg"
            }

            property bool showWindow: false
            visible: showWindow

            property string passwordDraft: ""
            property bool verifying: false
            property string authError: ""

            property int cpuUsage: 0
            property real cpuTemp: 0
            property real ramUsedGb: 0
            property real ramTotalGb: 1
            property real diskUsedGb: 0
            property real diskTotalGb: 1

            property real lastIdle: 0
            property real lastTotal: 0

            function greetingText() {
                const h = new Date().getHours()
                let part = "Добрый вечер"
                if (h < 12) part = "Доброе утро"
                else if (h < 18) part = "Добрый день"
                return part + ", " + Quickshell.env("USER")
            }

            function gaugeColor(pct) {
                if (pct >= 0.85) return "#e57373"
                if (pct >= 0.65) return "#ffb74d"
                return Theme.textAccent
            }

            function tryUnlock() {
                if (verifying || passwordDraft.length === 0)
                    return
                authError = ""
                verifying = true
                verifyProc.running = false
                verifyProc.running = true
            }

            Connections {
                target: AppState
                function onLockScreenVisibleChanged() {
                    if (AppState.lockScreenVisible) {
                        WlrLayershell.layer = WlrLayer.Overlay
                        WlrLayershell.keyboardFocus = root.ownsFocus
                            ? WlrKeyboardFocus.OnDemand
                            : WlrKeyboardFocus.None
                        hideTimer.stop()
                        root.showWindow = true
                        root.passwordDraft = ""
                        root.authError = ""
                        MediaState.refreshActivePlayer()
                        if (root.ownsFocus)
                            unlockFocusTimer.restart()
                    } else {
                        WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
                        hideTimer.restart()
                    }
                }
            }

            Timer {
                id: hideTimer
                interval: 320
                onTriggered: {
                    if (!AppState.lockScreenVisible)
                        root.showWindow = false
                }
            }

            Timer {
                id: unlockFocusTimer
                interval: 80
                repeat: false
                onTriggered: passwordField.forceActiveFocus()
            }

            // ── Backdrop ──────────────────────────────────────────────────────
            Item {
                id: backdrop
                anchors.fill: parent
                clip: true

                readonly property int blurRadius: 72
                readonly property int blurPad: blurRadius + 32

                Image {
                    id: wpImg
                    x: -backdrop.blurPad
                    y: -backdrop.blurPad
                    width: backdrop.width + backdrop.blurPad * 2
                    height: backdrop.height + backdrop.blurPad * 2
                    source: root.wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    cache: false
                    sourceSize: Qt.size(1920, 1080)
                }

                FastBlur {
                    anchors.fill: parent
                    source: wpImg
                    radius: backdrop.blurRadius
                    transparentBorder: false
                }

                Rectangle {
                    anchors.fill: parent
                    color: AppearanceState.dimOverlay(ThemeState.lightTheme ? 0.42 : 0.58)
                }
            }

            // ── Layout ────────────────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 36
                spacing: 0

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    spacing: 4

                    Text {
                        id: clockText
                        Layout.alignment: Qt.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 64
                        font.weight: Font.Light
                        color: Theme.textPrimary
                        text: Qt.formatDateTime(new Date(), "HH:mm")
                    }

                    Text {
                        id: dateText
                        Layout.alignment: Qt.AlignHCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: Theme.textMuted
                        text: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
                    }

                    Timer {
                        interval: 1000
                        running: root.showWindow
                        repeat: true
                        onTriggered: {
                            clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
                            dateText.text = Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
                        }
                    }
                }

                Item { Layout.fillHeight: true; Layout.preferredHeight: 12 }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.lockSideGap

                    Item {
                        Layout.preferredWidth: Theme.lockSideColumnWidth
                        Layout.preferredHeight: centerCol.implicitHeight

                        LockMediaPanel {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            z: 2
                        }
                    }

                    ColumnLayout {
                        id: centerCol
                        Layout.preferredWidth: 320
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 14

                        Item {
                            Layout.preferredWidth: Theme.lockAvatarOuter
                            Layout.preferredHeight: Theme.lockAvatarOuter
                            Layout.alignment: Qt.AlignHCenter

                            LockRadialVisualizer {
                                anchors.centerIn: parent
                                width: Theme.lockAvatarOuter
                                height: Theme.lockAvatarOuter
                                barColor: Theme.textAccent
                                innerRadius: Theme.lockAvatarSize / 2 + 14
                                maxBarLength: 42
                                minBarLength: 12
                                barWidth: 3
                            }

                            Item {
                                anchors.centerIn: parent
                                width: Theme.lockAvatarSize
                                height: Theme.lockAvatarSize
                                z: 1

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: Theme.panelBgCard
                                    border.color: Qt.rgba(
                                        Theme.textAccent.r, Theme.textAccent.g,
                                        Theme.textAccent.b, 0.35)
                                    border.width: 2
                                }

                                Image {
                                    id: avatarImg
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    source: root.avatarPath
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    cache: false
                                    visible: false
                                    layer.enabled: true
                                    layer.smooth: true
                                }

                                Rectangle {
                                    id: avatarMask
                                    anchors.fill: avatarImg
                                    radius: width / 2
                                    visible: false
                                    layer.enabled: true
                                }

                                OpacityMask {
                                    anchors.fill: avatarImg
                                    source: avatarImg
                                    maskSource: avatarMask
                                    visible: avatarImg.status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: avatarImg.status !== Image.Ready
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: 52
                                    color: Theme.textMuted
                                    text: "\uf007"
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredHeight: 34
                            Layout.minimumWidth: 220
                            radius: 17
                            color: Theme.panelBgCard
                            border.color: Theme.panelBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                anchors.margins: 16
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textPrimary
                                text: root.greetingText()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 300
                            Layout.preferredHeight: 46
                            Layout.alignment: Qt.AlignHCenter
                            radius: 23
                            color: Theme.panelBgCard
                            border.color: root.authError ? "#e57373" : Theme.panelBorder
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 8
                                spacing: 10

                                Text {
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: 14
                                    color: Theme.textMuted
                                    text: "\uf023"
                                }

                                TextField {
                                    id: passwordField
                                    Layout.fillWidth: true
                                    placeholderText: "Введите пароль"
                                    echoMode: TextInput.Password
                                    color: Theme.textPrimary
                                    placeholderTextColor: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    background: Item {}
                                    text: root.passwordDraft
                                    enabled: !root.verifying
                                    onTextChanged: root.passwordDraft = text
                                    onAccepted: root.tryUnlock()
                                    Keys.onEscapePressed: root.passwordDraft = ""
                                }

                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: 17
                                    color: submitMa.containsMouse
                                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g,
                                                  Theme.textAccent.b, 0.2)
                                        : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        font.family: Theme.iconFontFamily
                                        font.pixelSize: 13
                                        color: Theme.textAccent
                                        text: root.verifying ? "\uf110" : "\uf061"
                                    }

                                    MouseArea {
                                        id: submitMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.tryUnlock()
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.authError.length > 0
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: "#e57373"
                            text: root.authError
                        }
                    }

                    Item {
                        Layout.preferredWidth: Theme.lockSideColumnWidth
                        Layout.preferredHeight: centerCol.implicitHeight

                        GridLayout {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            columns: 2
                            rowSpacing: 16
                            columnSpacing: 16

                            LockGauge {
                                label: "CPU"
                                icon: "\uf4bc"
                                value: root.cpuUsage
                                maxValue: 100
                                accentColor: root.gaugeColor(root.cpuUsage / 100)
                            }
                            LockGauge {
                                label: "Temp"
                                icon: "\uf2c9"
                                value: root.cpuTemp
                                maxValue: 100
                                accentColor: root.gaugeColor(root.cpuTemp / 100)
                            }
                            LockGauge {
                                label: "RAM"
                                icon: ""
                                value: root.ramUsedGb
                                maxValue: root.ramTotalGb
                                accentColor: root.gaugeColor(
                                    root.ramTotalGb > 0 ? root.ramUsedGb / root.ramTotalGb : 0)
                            }
                            LockGauge {
                                label: "Disk"
                                icon: "\uf0a0"
                                value: root.diskUsedGb
                                maxValue: root.diskTotalGb
                                accentColor: root.gaugeColor(
                                    root.diskTotalGb > 0 ? root.diskUsedGb / root.diskTotalGb : 0)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true; Layout.preferredHeight: 12 }

                Rectangle {
                    Layout.preferredWidth: Theme.lockSideColumnWidth * 2 + Theme.lockSideGap + 320
                    Layout.preferredHeight: NotificationState.count === 0
                        ? 88
                        : Math.max(120, Math.min(lockNotifList.contentHeight + 56, 280))
                    Layout.maximumHeight: 280
                    Layout.alignment: Qt.AlignHCenter
                    radius: Theme.lockCardRadius
                    color: Theme.panelBg
                    border.color: Theme.panelBorder
                    border.width: 1
                    visible: NotificationState.showOnLockScreen
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        Text {
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                            text: "Уведомления"
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: NotificationState.count === 0
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textMuted
                            text: "Пока пусто — здесь появятся уведомления"
                        }

                        ListView {
                            id: lockNotifList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: NotificationState.count > 0
                            spacing: 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.VerticalFlick
                            interactive: NotificationState.count > 2
                            cacheBuffer: 180

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                                implicitWidth: 5
                            }

                            displaced: Transition {
                                NumberAnimation {
                                    properties: "y"
                                    duration: Theme.notificationCollapseMs
                                    easing.type: Easing.OutCubic
                                }
                            }

                            removeDisplaced: Transition {
                                NumberAnimation {
                                    properties: "y"
                                    duration: Theme.notificationCollapseMs
                                    easing.type: Easing.OutCubic
                                }
                            }

                            move: Transition {
                                NumberAnimation {
                                    properties: "y"
                                    duration: Theme.notificationCollapseMs
                                    easing.type: Easing.OutCubic
                                }
                            }

                            moveDisplaced: Transition {
                                NumberAnimation {
                                    properties: "y"
                                    duration: Theme.notificationCollapseMs
                                    easing.type: Easing.OutCubic
                                }
                            }

                            model: NotificationState.lockScreenModel

                            delegate: AnimatedNotificationItem {
                                required property var modelData
                                required property int index
                                width: lockNotifList.width
                                notification: modelData
                                compact: true
                                showActions: false
                                interactive: false
                                swipeEnabled: false
                                showTimestamp: true
                                enterFromRight: false
                                onDismissed: {}
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 4 }
            }

            // ── Stats polling ─────────────────────────────────────────────────
            Process {
                id: memProc
                command: ["sh", "-c",
                    "free -b | awk '/Mem:/{printf \"%.2f,%.2f\", $3/1e9,$2/1e9}'"]
                running: false
                stdout: SplitParser {
                    onRead: data => {
                        if (!data) return
                        const p = data.trim().split(",")
                        if (p.length < 2) return
                        root.ramUsedGb = parseFloat(p[0]) || 0
                        root.ramTotalGb = Math.max(parseFloat(p[1]) || 1, 0.1)
                    }
                }
            }

            Process {
                id: diskProc
                command: ["sh", "-c",
                    "df -B1 / | awk 'NR==2 {printf \"%.2f,%.2f\", $3/1e9,$2/1e9}'"]
                running: false
                stdout: SplitParser {
                    onRead: data => {
                        if (!data) return
                        const p = data.trim().split(",")
                        if (p.length < 2) return
                        root.diskUsedGb = parseFloat(p[0]) || 0
                        root.diskTotalGb = Math.max(parseFloat(p[1]) || 1, 0.1)
                    }
                }
            }

            Process {
                id: cpuProc
                command: ["sh", "-c", "head -1 /proc/stat"]
                running: false
                stdout: SplitParser {
                    onRead: data => {
                        if (!data) return
                        const p = data.trim().split(/\s+/)
                        const user = parseInt(p[1]) || 0
                        const nice = parseInt(p[2]) || 0
                        const sys = parseInt(p[3]) || 0
                        const idle = parseInt(p[4]) || 0
                        const iow = parseInt(p[5]) || 0
                        const irq = parseInt(p[6]) || 0
                        const sirq = parseInt(p[7]) || 0
                        const total = user + nice + sys + idle + iow + irq + sirq
                        const idleT = idle + iow
                        if (root.lastTotal > 0) {
                            const dt = total - root.lastTotal
                            const di = idleT - root.lastIdle
                            if (dt > 0)
                                root.cpuUsage = Math.round(100 * (dt - di) / dt)
                        }
                        root.lastTotal = total
                        root.lastIdle = idleT
                    }
                }
            }

            Process {
                id: tempProc
                command: ["sh", "-c",
                    "sensors 2>/dev/null | grep -m1 -E 'Tctl|Tdie|Package id' | awk '{print $2}' | tr -d '+°C'" +
                    " || awk '{printf \"%d\", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null"]
                running: false
                stdout: SplitParser {
                    onRead: data => {
                        if (data && data.trim())
                            root.cpuTemp = parseFloat(data.trim()) || 0
                    }
                }
            }

            Timer {
                interval: 2000
                running: root.showWindow && root.ownsFocus
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    memProc.running = true
                    diskProc.running = true
                    cpuProc.running = true
                    tempProc.running = true
                }
            }

            Process {
                id: verifyProc
                environment: ({
                    "PASS": root.passwordDraft,
                    "USER": Quickshell.env("USER")
                })
                command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/verify-password.sh"]
                running: false
                onExited: (exitCode, exitStatus) => {
                    root.verifying = false
                    if (exitCode === 0) {
                        root.passwordDraft = ""
                        AppState.hideLockScreen()
                    } else {
                        root.authError = "Неверный пароль"
                        root.passwordDraft = ""
                        unlockFocusTimer.restart()
                    }
                }
            }
        }
    }
}
