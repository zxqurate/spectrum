import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../components"
import "../state"
import "../theme"
import "../widgets"

GlassPanelWindow {
    id: root

    required property var screen

    WlrLayershell.namespace: "quickshell"
    WlrLayershell.layer: WlrLayer.Top

    screen: root.screen
    anchors { top: true; left: true; right: true; bottom: true }
    margins.top: Theme.sidePanelTopInset
    exclusiveZone: -1
    color: "transparent"
    visible: showWindow && ownsPanel && !AppState.lockScreenVisible

    readonly property bool ownsPanel: AppState.isSameScreen(AppState.sidePanelScreen, root.screen)

    property bool showWindow: false
    property bool panelOpen: false

    property string uptimeText: "..."
    property bool calendarExpanded: false
    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()
    property var calCells: []

    readonly property int calCollapsedH: 50
    readonly property int calExpandedH: 268

    function syncPopupState() {
        if (!AppState.sidePanelVisible || !ownsPanel) {
            if (!AppState.sidePanelVisible) {
                panelOpen = false
                calendarExpanded = false
                hideTimer.restart()
            } else {
                showWindow = false
                panelOpen = false
            }
            return
        }
        hideTimer.stop()
        showWindow = true
        panelOpen = false
        openTimer.restart()
        rebuildCalendar()
        VolumeState.refresh()
        uptimeProc.running = true
    }

    Component.onCompleted: syncPopupState()

    function rebuildCalendar() {
        const y = calYear
        const m = calMonth
        const firstDow = (new Date(y, m, 1).getDay() + 6) % 7
        const daysInMonth = new Date(y, m + 1, 0).getDate()
        const today = new Date()
        const cells = []
        for (let i = 0; i < firstDow; ++i)
            cells.push({ day: 0, today: false, current: false })
        for (let d = 1; d <= daysInMonth; ++d) {
            cells.push({
                day: d,
                today: today.getFullYear() === y && today.getMonth() === m && today.getDate() === d,
                current: true
            })
        }
        while (cells.length % 7 !== 0)
            cells.push({ day: 0, today: false, current: false })
        calCells = cells
    }

    function monthLabel() {
        return Qt.formatDateTime(new Date(calYear, calMonth, 1), "MMMM yyyy")
    }

    Connections {
        target: AppState
        function onSidePanelVisibleChanged() { root.syncPopupState() }
        function onSidePanelScreenChanged() { root.syncPopupState() }
        function onLockScreenVisibleChanged() {
            if (AppState.lockScreenVisible)
                AppState.hideSidePanel()
        }
        function onControlCenterVisibleChanged() {
            if (AppState.controlCenterVisible) AppState.hideSidePanel()
        }
        function onWifiPopupVisibleChanged() {
            if (AppState.wifiPopupVisible) AppState.hideSidePanel()
        }
        function onVolumePopupVisibleChanged() {
            if (AppState.volumePopupVisible) AppState.hideSidePanel()
        }
        function onMediaPopupVisibleChanged() {
            if (AppState.mediaPopupVisible) AppState.hideSidePanel()
        }
    }

    Timer {
        id: openTimer
        interval: 16
        onTriggered: root.panelOpen = true
    }

    Timer {
        id: hideTimer
        interval: Theme.sidePanelAnimMs
        onTriggered: {
            if (!AppState.sidePanelVisible) {
                root.showWindow = false
                AppState.finalizeSidePanelHide()
            }
        }
    }

    // ── Click outside to close (no dim scrim) ─────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: root.showWindow
        onClicked: AppState.hideSidePanel()
    }

    // ── Right column stack — slides in from the right ─────────────────────────
    Item {
        id: stack
        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
            rightMargin: Theme.barMargin
            bottomMargin: Theme.barMargin
        }
        width: Theme.sidePanelWidth
        z: 1

        // Block click-through on panel chrome only.
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: mouse => mouse.accepted = true
        }

        property real slideX: Theme.sidePanelWidth + Theme.barMargin + 12
        transform: Translate { x: stack.slideX }

        states: [
            State {
                name: "open"
                when: root.panelOpen
                PropertyChanges { target: stack; slideX: 0 }
            },
            State {
                name: "closed"
                when: !root.panelOpen
                PropertyChanges {
                    target: stack
                    slideX: Theme.sidePanelWidth + Theme.barMargin + 12
                }
            }
        ]

        transitions: [
            Transition {
                from: "closed"
                to: "open"
                NumberAnimation {
                    property: "slideX"
                    duration: Theme.sidePanelAnimMs
                    easing.type: Easing.OutQuint
                }
            },
            Transition {
                from: "open"
                to: "closed"
                NumberAnimation {
                    property: "slideX"
                    duration: Theme.sidePanelAnimMs
                    easing.type: Easing.InQuint
                }
            }
        ]

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.pillGap

            // ── Main card ───────────────────────────────────────────────────
            Rectangle {
                id: mainCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.sidePanelRadius
                color: Theme.panelBg
                border.color: Theme.panelBorder
                border.width: Theme.useGlassPanels ? 1 : 0
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textMuted
                            text: "Uptime " + root.uptimeText
                        }

                        SideAlwaysOnChip {
                            active: AlwaysOnState.enabled
                            onClicked: AlwaysOnState.toggle()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            id: bigClock
                            Layout.alignment: Qt.AlignHCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: 48
                            font.weight: Font.Light
                            color: Theme.textPrimary
                            text: Qt.formatDateTime(new Date(), "HH:mm")
                        }

                        Text {
                            id: bigDate
                            Layout.alignment: Qt.AlignHCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            color: Theme.textMuted
                            text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
                        }

                        Timer {
                            interval: 1000
                            running: root.showWindow
                            repeat: true
                            onTriggered: {
                                bigClock.text = Qt.formatDateTime(new Date(), "HH:mm")
                                bigDate.text = Qt.formatDateTime(new Date(), "dddd, d MMMM")
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        SideQuickTile {
                            Layout.fillWidth: true
                            icon: ConnectionState.barGlyph
                            title: "Network"
                            subtitle: ConnectionState.label
                            active: ConnectionState.connected
                            onClicked: {
                                AppState.hideSidePanel()
                                AppState.showWifiPopup(root.screen)
                            }
                        }

                        SideQuickTile {
                            Layout.fillWidth: true
                            icon: VolumeState.volumeIcon()
                            title: "Sound"
                            subtitle: VolumeState.muted ? "Muted" : VolumeState.percentLevel + "%"
                            active: !VolumeState.muted && VolumeState.percentLevel > 0
                            wheelEnabled: true
                            iconHoverBoost: true
                            onClicked: VolumeState.toggleMute()
                            onWheeled: wheel => {
                                const delta = wheel.angleDelta.y > 0 ? 5 : -5
                                VolumeState.adjustVolume(delta)
                            }
                        }

                        SideQuickTile {
                            Layout.fillWidth: true
                            icon: MicState.micIcon()
                            title: "Mic"
                            subtitle: MicState.muted ? "Muted" : "On"
                            active: !MicState.muted
                            onClicked: MicState.toggleMute()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.panelBorder
                        opacity: 0.45
                    }

                    Text {
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        text: "Notifications"
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 80

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: NotificationState.count === 0
                            spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 36
                            color: Theme.textMuted
                            opacity: emptyBellHover.hovered ? 0.55 : 0.4
                            text: "󰂚"

                            HoverHandler { id: emptyBellHover }

                            Behavior on opacity {
                                NumberAnimation { duration: Theme.sideTileHoverMs }
                            }
                        }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textMuted
                                text: "Nothing here yet"
                            }
                        }

                        ListView {
                            id: notifList
                            anchors.fill: parent
                            visible: NotificationState.count > 0
                            spacing: 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.VerticalFlick
                            interactive: true
                            cacheBuffer: 240

                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                                implicitWidth: 6
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

                            remove: Transition {
                                NumberAnimation {
                                    properties: "opacity"
                                    from: 1
                                    to: 0
                                    duration: Theme.notificationAnimMs
                                    easing.type: Easing.OutCubic
                                }
                            }

                            model: NotificationState.sidePanelModel

                            delegate: AnimatedNotificationItem {
                                required property var modelData
                                required property int index
                                width: notifList.width
                                notification: modelData
                                compact: true
                                showActions: true
                                swipeEnabled: true
                                showTimestamp: true
                                enterFromRight: true
                                onDismissed: notification => {
                                    if (!NotificationState.clearingAll && notification)
                                        NotificationState.finalizeDismiss(notification)
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.panelBorder
                        opacity: 0.45
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 14
                            color: Theme.textMuted
                            text: "󰂚"
                        }
                        Text {
                            Layout.fillWidth: true
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.textMuted
                            text: NotificationState.count + (NotificationState.count === 1 ? " notification" : " notifications")
                        }
                        Text {
                            id: clearIcon
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 14
                            color: Theme.textMuted
                            opacity: clearMa.containsMouse && NotificationState.count > 0 ? 0.85 : 0.45
                            text: "󰆴"
                            scale: clearMa.pressed ? 0.88 : (NotificationState.clearingAll ? 1.12 : 1)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }

                            MouseArea {
                                id: clearMa
                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                enabled: NotificationState.count > 0 && !NotificationState.clearingAll
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    clearSpin.start()
                                    NotificationState.clearAllAnimated()
                                }
                            }

                            RotationAnimation {
                                id: clearSpin
                                target: clearIcon
                                from: 0
                                to: 360
                                duration: 520
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            // ── Calendar pill (separate, below main card) ─────────────────────
            Rectangle {
                id: calPill
                Layout.fillWidth: true
                Layout.preferredHeight: root.calendarExpanded ? root.calExpandedH : root.calCollapsedH
                radius: Theme.sidePanelRadius
                color: Theme.panelBg
                border.color: Theme.panelBorder
                border.width: Theme.useGlassPanels ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: Theme.sidePanelAnimMs
                        easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    MouseArea {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calendarExpanded = !root.calendarExpanded

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 13
                                color: Theme.textMuted
                                text: root.calendarExpanded ? "󰅀" : "󰅂"
                                rotation: root.calendarExpanded ? 0 : -90
                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: Theme.sidePanelAnimMs
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textPrimary
                                text: Qt.formatDateTime(new Date(), "dddd, MMMM d") + " • 0 tasks"
                                elide: Text.ElideRight
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6
                        visible: root.calendarExpanded
                        opacity: root.calendarExpanded ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.sidePanelAnimMs
                                easing.type: Easing.OutCubic
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: Theme.textPrimary
                                text: root.monthLabel()
                            }

                            SideIconBtn {
                                icon: "󰅁"
                                onClicked: {
                                    root.calMonth--
                                    if (root.calMonth < 0) { root.calMonth = 11; root.calYear-- }
                                    root.rebuildCalendar()
                                }
                            }
                            SideIconBtn {
                                icon: "󰅂"
                                onClicked: {
                                    root.calMonth++
                                    if (root.calMonth > 11) { root.calMonth = 0; root.calYear++ }
                                    root.rebuildCalendar()
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 7
                            rowSpacing: 3
                            columnSpacing: 2

                            Repeater {
                                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                delegate: Text {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.textMuted
                                    text: modelData
                                }
                            }

                            Repeater {
                                model: root.calCells
                                delegate: Item {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28

                                    readonly property real cellSize: Math.min(width, height, 26)

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: cellSize
                                        height: cellSize
                                        radius: 7
                                        visible: modelData.current && modelData.day > 0
                                        color: modelData.today
                                            ? Theme.textAccent
                                            : (dayMa.containsMouse
                                                ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g,
                                                          Theme.textPrimary.b, 0.07)
                                                : "transparent")
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: modelData.current && modelData.day > 0
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: modelData.today ? Colors.md3.on_primary : Theme.textPrimary
                                        text: modelData.day
                                    }

                                    MouseArea {
                                        id: dayMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: modelData.current && modelData.day > 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["bash", "-c",
            "awk '{s=int($1); h=int(s/3600); m=int((s%3600)/60); printf \"%dh %dm\", h, m}' /proc/uptime"]
        running: false
        stdout: SplitParser {
            onRead: data => { if (data.trim()) root.uptimeText = data.trim() }
        }
    }

    Timer {
        interval: 60000
        running: root.showWindow
        repeat: true
        onTriggered: uptimeProc.running = true
    }

    component SideAlwaysOnChip: Rectangle {
        id: chip
        property bool active: false
        signal clicked()

        implicitHeight: 28
        implicitWidth: Math.max(108, chipRow.implicitWidth + 18)
        radius: height / 2

        readonly property color glowColor: active
            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 1)
            : Theme.textMuted

        color: active
            ? Qt.rgba(glowColor.r, glowColor.g, glowColor.b, chipMa.containsMouse ? 0.20 : 0.12)
            : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b,
                      chipMa.containsMouse ? 0.09 : 0.045)
        border.color: active
            ? Qt.rgba(glowColor.r, glowColor.g, glowColor.b, chipMa.containsMouse ? 0.55 : 0.38)
            : Qt.rgba(Theme.panelBorder.r, Theme.panelBorder.g, Theme.panelBorder.b, 0.65)
        border.width: 1

        scale: chipMa.pressed ? 0.96 : (chipMa.containsMouse ? 1.02 : 1)
        Behavior on scale {
            NumberAnimation { duration: Theme.sideTileHoverMs; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: chipGlow
            anchors.fill: parent
            radius: parent.radius
            visible: chip.active
            color: "transparent"
            border.color: Qt.rgba(chip.glowColor.r, chip.glowColor.g, chip.glowColor.b, 0.22)
            border.width: 4
            opacity: 0.15
        }

        SequentialAnimation {
            id: glowPulse
            running: chip.active
            loops: Animation.Infinite
            NumberAnimation {
                target: chipGlow
                property: "opacity"
                from: 0.15
                to: 0.45
                duration: 1400
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: chipGlow
                property: "opacity"
                from: 0.45
                to: 0.15
                duration: 1400
                easing.type: Easing.InOutSine
            }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                font.family: Theme.iconFontFamily
                font.pixelSize: 12
                color: chip.active ? Theme.textAccent : Theme.textMuted
                text: chip.active ? "󰖙" : "󰖔"
                scale: chipMa.containsMouse ? 1.08 : 1
                Behavior on scale {
                    NumberAnimation { duration: Theme.sideTileHoverMs; easing.type: Easing.OutCubic }
                }
            }

            Text {
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: chip.active ? Font.Medium : Font.Normal
                color: chip.active ? Theme.textPrimary : Theme.textMuted
                text: "Always On"
            }
        }

        MouseArea {
            id: chipMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component SideIconBtn: MouseArea {
        property string icon: ""
        implicitWidth: 28
        implicitHeight: 28
        cursorShape: Qt.PointingHandCursor
        Text {
            anchors.centerIn: parent
            font.family: Theme.iconFontFamily
            font.pixelSize: 14
            color: parent.containsMouse ? Theme.textAccent : Theme.textMuted
            text: icon
        }
    }

    component SideQuickTile: Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property bool wheelEnabled: false
        property bool iconHoverBoost: false
        signal clicked()
        signal wheeled(WheelEvent wheel)

        radius: 14
        height: 80
        color: tileMa.containsMouse || active
            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, active ? 0.12 : 0.06)
            : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.035)
        border.color: active
            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.28)
            : Qt.rgba(Theme.panelBorder.r, Theme.panelBorder.g, Theme.panelBorder.b, 0.55)
        border.width: 1

        property real hoverLift: tileMa.containsMouse ? -4 : 0
        property real hoverScale: tileMa.containsMouse ? 1.045 : 1.0

        scale: hoverScale
        transform: Translate { y: hoverLift }

        Behavior on hoverLift {
            NumberAnimation {
                duration: Theme.sideTileHoverMs
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.sideTileHoverMs
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 3

            Text {
                id: tileIcon
                font.family: Theme.iconFontFamily
                font.pixelSize: 20
                color: active ? Theme.textAccent : Theme.textMuted
                text: tile.icon
                scale: tileMa.containsMouse
                    ? (tile.iconHoverBoost ? 1.16 : 1.1)
                    : 1.0
                transformOrigin: Item.TopLeft

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.sideTileHoverMs
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Theme.textPrimary
                text: tile.title
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textMuted
                text: tile.subtitle
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: tileMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
            onWheel: wheel => {
                if (!tile.wheelEnabled)
                    return
                wheel.accepted = true
                tile.wheeled(wheel)
            }
        }
    }
}
