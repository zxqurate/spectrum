import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../state"
import "../theme"

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell"
    WlrLayershell.layer: WlrLayer.Top

    property bool showWindow: false
    visible: showWindow

    readonly property bool blocksPointer: AppState.wallpaperPickerVisible

    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: -1
    color: "transparent"
    focusable: true

    readonly property string avatarPath:       "file://" + Quickshell.env("HOME") + "/.face"
    readonly property string appearanceConfPath: Quickshell.env("HOME") + "/.config/hypr/appearance.conf"
    readonly property string keybindsConfPath:   Quickshell.env("HOME") + "/.config/hypr/keybinds.conf"
    readonly property string spectrumLogoPath: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/spectrum_logo.png"
    readonly property string spectrumRepoUrl:  "https://github.com/zxqurate/spectrum"

    property bool   showSettings:       false
    property bool   showPowerMenu:      false
    property bool   settingsHydrated:   false
    property bool   appearanceDirty:    false
    property string selectedSection:    "appearance"
    property bool   showAddLayoutInput: false
    property string newLayoutDraft:     ""
    property bool   capturingBind:      false   // root-level key capture active
    property bool   avatarPickerActive: false
    property string _pickedAvatarPath:  ""

    readonly property int settingsTransitionMs: 260
    readonly property int sectionSwitchMs: 165
    readonly property var sectionOrder: ["appearance", "windows", "animations", "input", "notifications", "systeminfo"]
    property string _prevSection: "appearance"
    property int sectionSwitchDir: 1

    onSelectedSectionChanged: {
        const p = sectionOrder.indexOf(_prevSection)
        const n = sectionOrder.indexOf(selectedSection)
        if (p >= 0 && n >= 0 && p !== n)
            sectionSwitchDir = n > p ? 1 : -1
        _prevSection = selectedSection
        settingsFlickable.contentY = 0
    }

    // ── Settings model ────────────────────────────────────────────────────────
    QtObject {
        id: settings
        property bool   blurEnabled:     true
        property int    blurSize:        6
        property int    blurPasses:      2
        property bool   blurXray:        false
        property bool   blurNewOptimizations: true
        property bool   blurIgnoreOpacity:    true
        property real   blurBrightness:  1.0
        property real   blurContrast:    1.0
        property real   blurVibrancy:    0.0
        property real   blurVibrancyDarkness: 0.0
        property bool   systemBlurEnabled:    true
        property bool   shadowEnabled:   true
        property int    shadowRange:     12
        property int    rounding:        10
        property real   activeOpacity:   1.0
        property real   inactiveOpacity: 1.0
        property bool   animEnabled:     true
        property int    animSpeed:       3        // 1 = slowest … 5 = fastest
        property string kbLayout:        "us"
        property real   sensitivity:     0.0
        property bool   naturalScroll:   true
        property string kbSwitchBind:    ""
        property bool   borderEnabled:   true
        property int    borderSize:      2
    }

    readonly property int ccSettingValueWidth: 84
    readonly property int ccSettingRowHeight:   40
    readonly property int ccSettingSubRowHeight: 36
    readonly property int ccSettingRowGap:      8
    readonly property int ccSettingSectionGap: 14
    readonly property int ccNavFontSize:        13
    readonly property int ccSettingFontSize:    15
    readonly property int ccSettingSubFontSize: 14
    readonly property int ccSectionHeaderSize:  16
    readonly property int ccSettingTitleSize:   18

    property real   _readPanelOpacity:    NaN
    property real   _readPanelCardOpacity: NaN

    function applyAppearancePrefsFromSettings(useParsedPanel) {
        const po = useParsedPanel && !isNaN(_readPanelOpacity) ? _readPanelOpacity : undefined
        const pc = useParsedPanel && !isNaN(_readPanelCardOpacity) ? _readPanelCardOpacity : undefined
        AppearanceState.applyFromSettings(settings.systemBlurEnabled, po, pc)
    }

    function confBool(v) {
        return v === "1" || v === "true"
    }

    function pctFromFloat(v) { return Math.round(v * 100) }
    function floatFromPct(p) { return p / 100 }
    function openUrl(url) {
        if (!url || !String(url).trim())
            return
        openUrlProc.targetUrl = String(url).trim()
        openUrlProc.running = true
    }

    function runPowerAction(actionId) {
        root.showPowerMenu = false
        AppState.controlCenterVisible = false
        powerActionProc.actionId = actionId
        powerActionProc.running = false
        powerActionProc.running = true
    }

    readonly property var powerActions: [
        { id: "shutdown",  icon: "󰐥", label: "Выключить",    color: "#e57373" },
        { id: "reboot",    icon: "󰑐", label: "Перезагрузить", color: "#ffb74d" },
        { id: "hibernate", icon: "󰒄", label: "Гибернация",   color: "#64b5f6" },
        { id: "uefi",      icon: "󰒧", label: "Выйти в UEFI", color: "#ba68c8" },
        { id: "logout",    icon: "󰍃", label: "Выйти",        color: "accent" }
    ]

    component PowerActionBtn: Rectangle {
        id: pBtn
        property string icon: ""
        property string label: ""
        property string actionId: ""
        property string actionColor: "accent"
        property int enterDelay: 0
        property bool menuOpen: false
        signal triggered(string id)

        readonly property color tint: actionColor === "accent" ? Theme.textAccent : Qt.color(actionColor)

        height: 46
        radius: 12
        opacity: 0
        property real _slide: 14
        transform: Translate { y: pBtn._slide }

        color: pMa.containsMouse
            ? Qt.rgba(tint.r, tint.g, tint.b, 0.14)
            : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.04)
        border.color: pMa.containsMouse
            ? Qt.rgba(tint.r, tint.g, tint.b, 0.35)
            : Qt.rgba(Theme.panelBorder.r, Theme.panelBorder.g, Theme.panelBorder.b, 0.45)
        border.width: 1

        scale: pMa.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 10
                color: Qt.rgba(tint.r, tint.g, tint.b, pMa.containsMouse ? 0.22 : 0.12)
                Behavior on color { ColorAnimation { duration: 140 } }
                Text {
                    anchors.centerIn: parent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 16
                    color: tint
                    text: pBtn.icon
                }
            }

            Text {
                Layout.fillWidth: true
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                color: Theme.textPrimary
                text: pBtn.label
            }

            Text {
                font.family: Theme.iconFontFamily
                font.pixelSize: 12
                color: Theme.textMuted
                opacity: pMa.containsMouse ? 0.75 : 0.35
                text: "󰅂"
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }

        MouseArea {
            id: pMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pBtn.triggered(pBtn.actionId)
        }

        Timer {
            id: enterTimer
            interval: pBtn.enterDelay
            onTriggered: enterAnim.start()
        }

        ParallelAnimation {
            id: enterAnim
            NumberAnimation {
                target: pBtn
                property: "opacity"
                to: 1
                duration: 260
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pBtn
                property: "_slide"
                to: 0
                duration: 320
                easing.type: Easing.OutBack
            }
        }

        onMenuOpenChanged: {
            if (menuOpen) {
                opacity = 0
                _slide = 14
                enterTimer.restart()
            } else {
                opacity = 0
                _slide = 14
            }
        }

        Component.onCompleted: {
            if (menuOpen)
                enterTimer.restart()
        }
    }

    // ── Reusable: sidebar nav item ────────────────────────────────────────────
    component NavItem: Rectangle {
        id: navRoot
        property string sectionId:  ""
        property string navIcon:    ""
        property string navLabel:   ""
        readonly property bool active: root.selectedSection === sectionId
        Layout.fillWidth: true; height: 40; radius: 8
        color: active
            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.18)
            : (navHov.containsMouse
                ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.07)
                : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
        // Left accent stripe
        Rectangle {
            visible: navRoot.active
            width: 3; height: 16; radius: 1.5
            anchors { left: parent.left; leftMargin: 3; verticalCenter: parent.verticalCenter }
            color: Theme.textAccent
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 8 }
            spacing: 8
            Text { font.family: Theme.iconFontFamily; font.pixelSize: ccSectionHeaderSize
                color: navRoot.active ? Theme.textAccent : Theme.textMuted; text: navRoot.navIcon
                Behavior on color { ColorAnimation { duration: 120 } } }
            Text { Layout.fillWidth: true; font.family: Theme.fontFamily; font.pixelSize: ccNavFontSize
                font.weight: navRoot.active ? Font.Medium : Font.Normal
                color: navRoot.active ? Theme.textPrimary : Theme.textMuted
                text: navRoot.navLabel; elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 120 } } }
        }
        MouseArea { id: navHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.selectedSection = navRoot.sectionId }
    }

    // ── Settings section pane (animated switch) ───────────────────────────────
    component SettingSectionPane: Item {
        id: pane
        property string sectionId: ""
        readonly property bool active: root.selectedSection === sectionId
        default property alias content: contentCol.data

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: contentCol.implicitHeight

        property real _op: 0
        opacity: _op
        property real slideX: 0
        transform: Translate { x: slideX }

        visible: active || _op > 0.002
        enabled: active
        z: active ? 2 : 1

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 0
        }

        Connections {
            target: root
            function onSelectedSectionChanged() {
                if (pane.active) {
                    pane.slideX = root.sectionSwitchDir * 14
                    pane._op = 0
                    enterAnim.start()
                } else if (pane._op > 0.01) {
                    exitAnim.start()
                }
            }
        }

        ParallelAnimation {
            id: enterAnim
            NumberAnimation {
                target: pane; property: "slideX"; to: 0
                duration: root.sectionSwitchMs; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pane; property: "_op"; to: 1
                duration: root.sectionSwitchMs; easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: exitAnim
            NumberAnimation {
                target: pane; property: "slideX"
                to: -root.sectionSwitchDir * 14
                duration: root.sectionSwitchMs; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pane; property: "_op"; to: 0
                duration: root.sectionSwitchMs; easing.type: Easing.OutCubic
            }
        }

        Component.onCompleted: {
            if (active) {
                _op = 1
                slideX = 0
            }
        }
    }

    // ── Reusable: number input field ──────────────────────────────────────────
    component NumInput: Rectangle {
        id: nir
        property string nText: "0"     // text shown / synced when not focused
        property string nUnit: ""      // optional suffix, e.g. "%"
        property bool enabled: true
        signal committed(string raw)   // fired when user confirms (Enter / blur)
        width: 82; height: 30; radius: 7
        opacity: enabled ? 1 : 0.35
        color: nf.activeFocus && enabled
            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.12)
            : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.07)
        border.width: 1.5
        border.color: nf.activeFocus && enabled
            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.55)
            : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.15)
        Behavior on color       { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
            spacing: 2
            TextInput {
                id: nf
                Layout.fillWidth: true
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize
                color: Theme.textPrimary; clip: true; selectByMouse: true
                readOnly: !nir.enabled
                Binding on text { when: !nf.activeFocus; value: nir.nText; restoreMode: Binding.RestoreNone }
                onActiveFocusChanged: {
                    if (activeFocus && !nir.enabled)
                        focus = false
                    else if (activeFocus)
                        selectAll()
                }
                Keys.onReturnPressed: {
                    if (!nir.enabled)
                        return
                    nir.committed(text.trim())
                    focus = false
                }
                onEditingFinished: {
                    if (nir.enabled)
                        nir.committed(text.trim())
                }
            }
            Text {
                visible: nir.nUnit !== ""
                font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize - 1
                color: Theme.textMuted; text: nir.nUnit
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: nir.enabled ? Qt.IBeamCursor : Qt.ArrowCursor
            enabled: nir.enabled
            onClicked: nf.forceActiveFocus()
        }
    }

    // ── Reusable: styled toggle ───────────────────────────────────────────────
    component SettingToggle: Rectangle {
        id: tog
        property bool checked: false
        property bool enabled: true
        signal toggled(bool val)
        width: 38; height: 22; radius: 11
        color: {
            if (!tog.enabled)
                return Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.10)
            if (tog.checked)
                return Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.88)
            return Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.15)
        }
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 16; height: 16; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: tog.checked ? parent.width - width - 3 : 3
            color: {
                if (!tog.enabled)
                    return Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.42)
                if (tog.checked)
                    return "white"
                return Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.7)
            }
            Behavior on x     { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation  { duration: 160 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: tog.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: tog.enabled
            onClicked: { if (tog.enabled) tog.toggled(!tog.checked) }
        }
    }

    component SettingToggleRow: RowLayout {
        property string rowIcon: ""
        property string rowLabel: ""
        property bool rowChecked: false
        property bool rowEnabled: true
        signal toggled(bool val)
        Layout.fillWidth: true
        Layout.preferredHeight: ccSettingRowHeight
        Layout.leftMargin: 14; Layout.rightMargin: 20
        Layout.bottomMargin: ccSettingRowGap
        spacing: 10
        opacity: 1
        Behavior on opacity { ColorAnimation { duration: 150 } }
        Text {
            font.family: Theme.iconFontFamily; font.pixelSize: ccSectionHeaderSize
            color: rowEnabled ? Theme.textAccent : Theme.textMuted
            text: rowIcon
            Layout.maximumWidth: 18
        }
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            font.family: Theme.fontFamily; font.pixelSize: ccSettingFontSize; font.weight: Font.Medium
            color: rowEnabled ? Theme.textPrimary : Theme.textMuted
            text: rowLabel; elide: Text.ElideRight
        }
        SettingToggle {
            Layout.preferredWidth: 38
            Layout.maximumWidth: 38
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: rowChecked
            enabled: rowEnabled
            onToggled: val => { if (rowEnabled) parent.toggled(val) }
        }
    }

    component SettingNumRow: RowLayout {
        property string rowIcon: ""
        property string rowLabel: ""
        property bool subRow: false
        property bool rowEnabled: true
        property alias nText: numField.nText
        property alias nUnit: numField.nUnit
        signal committed(string raw)
        Layout.fillWidth: true
        Layout.preferredHeight: subRow ? ccSettingSubRowHeight : ccSettingRowHeight
        Layout.leftMargin: 14; Layout.rightMargin: 20
        Layout.bottomMargin: subRow ? ccSettingRowGap : ccSettingSectionGap
        spacing: 10
        opacity: (subRow && !rowEnabled) ? 0.35 : 1
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Item { width: subRow ? 22 : 0; height: 1 }
        Text {
            visible: rowIcon !== ""
            font.family: Theme.iconFontFamily; font.pixelSize: ccSectionHeaderSize; color: Theme.textAccent
            text: rowIcon
        }
        Text {
            Layout.fillWidth: true
            font.family: Theme.fontFamily
            font.pixelSize: subRow ? ccSettingSubFontSize : ccSettingFontSize
            font.weight: Font.Medium
            color: rowEnabled ? Theme.textPrimary : Theme.textMuted
            opacity: subRow ? 0.82 : 1
            text: rowLabel; elide: Text.ElideRight
        }
        NumInput {
            id: numField
            enabled: rowEnabled
            Layout.preferredWidth: ccSettingValueWidth
            onCommitted: raw => { if (rowEnabled) parent.committed(raw) }
        }
    }

    component SettingSubToggleRow: RowLayout {
        property string rowLabel: ""
        property bool rowChecked: false
        property bool rowEnabled: true
        signal toggled(bool val)
        Layout.fillWidth: true
        Layout.preferredHeight: ccSettingSubRowHeight
        Layout.leftMargin: 14; Layout.rightMargin: 20
        Layout.bottomMargin: ccSettingRowGap
        spacing: 10
        opacity: 1
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Item { width: 22; height: 1 }
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize; font.weight: Font.Medium
            color: Theme.textPrimary; opacity: 0.82
            text: rowLabel; elide: Text.ElideRight
        }
        SettingToggle {
            Layout.preferredWidth: 38
            Layout.maximumWidth: 38
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            checked: rowChecked
            enabled: rowEnabled
            onToggled: val => { if (rowEnabled) parent.toggled(val) }
        }
    }

    component InfoLinkButton: Rectangle {
        property string linkIcon: ""
        property string linkLabel: ""
        property string linkUrl: ""
        readonly property bool linkActive: linkUrl !== "" && linkUrl.trim() !== ""

        implicitWidth: linkRow.implicitWidth + 24
        height: 36
        radius: height / 2
        opacity: linkActive ? 1 : 0.38
        color: linkMa.containsMouse && linkActive
            ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.12)
            : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.07)
        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
            id: linkRow
            anchors.centerIn: parent
            spacing: 7
            Text {
                font.family: Theme.iconFontFamily; font.pixelSize: ccSettingSubFontSize
                color: Theme.textAccent; text: linkIcon
            }
            Text {
                font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize
                color: Theme.textPrimary; text: linkLabel
            }
        }
        MouseArea {
            id: linkMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: linkActive ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: linkActive
            onClicked: root.openUrl(linkUrl)
        }
    }

    component SystemInfoBlock: ColumnLayout {
        id: blockRoot
        property string blockIcon: ""
        property string blockTitle: ""
        property string productName: ""
        property string productUrl: ""
        property string logoPath: ""
        property bool logoFailed: false

        readonly property bool useTux: logoPath === "tux" || logoPath === "" || logoFailed
        readonly property string logoSource: {
            if (useTux)
                return ""
            if (logoPath.indexOf("file://") === 0)
                return logoPath
            return "file://" + logoPath
        }

        Layout.fillWidth: true
        Layout.leftMargin: 14
        Layout.rightMargin: 14
        Layout.bottomMargin: 22
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                font.family: Theme.iconFontFamily; font.pixelSize: ccSectionHeaderSize
                color: Theme.textAccent; text: blockRoot.blockIcon
            }
            Text {
                font.family: Theme.fontFamily; font.pixelSize: ccSectionHeaderSize
                font.weight: Font.Medium; color: Theme.textPrimary; text: blockRoot.blockTitle
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Item {
                Layout.preferredWidth: 76
                Layout.preferredHeight: 76

                Image {
                    anchors.fill: parent
                    visible: !blockRoot.useTux
                    source: blockRoot.logoSource
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    onStatusChanged: if (status === Image.Error) blockRoot.logoFailed = true
                }
                Text {
                    anchors.centerIn: parent
                    visible: blockRoot.useTux
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 46
                    color: Theme.textAccent
                    text: "󰌽"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    font.family: Theme.fontFamily
                    font.pixelSize: ccSettingTitleSize
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                    text: blockRoot.productName
                }
                Text {
                    id: urlLbl
                    font.family: Theme.fontFamily
                    font.pixelSize: ccSettingSubFontSize
                    color: Theme.textAccent
                    text: blockRoot.productUrl
                    visible: blockRoot.productUrl !== ""
                }
                MouseArea {
                    anchors.fill: urlLbl
                    visible: urlLbl.visible
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openUrl(blockRoot.productUrl)
                }
            }
        }
    }

    // ── Reusable: accent-coloured slider ─────────────────────────────────────
    component StyledSlider: Slider {
        id: ssl
        background: Rectangle {
            x: ssl.leftPadding; y: ssl.topPadding + ssl.availableHeight / 2 - height / 2
            width: ssl.availableWidth; height: 4; radius: 2
            color: Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.18)
            Rectangle {
                width: ssl.visualPosition * parent.width; height: 4; radius: 2
                color: Theme.textAccent
                Behavior on width { NumberAnimation { duration: 30 } }
            }
        }
        handle: Rectangle {
            x: ssl.leftPadding + ssl.visualPosition * (ssl.availableWidth - width)
            y: ssl.topPadding  + ssl.availableHeight / 2 - height / 2
            width: 14; height: 14; radius: 7
            color: Theme.textAccent
            scale: ssl.pressed ? 1.25 : 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }

    component SettingComboBox: ComboBox {
        id: cb
        property bool boxEnabled: true

        implicitHeight: 30
        implicitWidth: 180
        enabled: boxEnabled

        delegate: ItemDelegate {
            width: Math.max(cb.width, 180)
            height: 32
            contentItem: Text {
                text: NotificationState.soundLabel(typeof modelData === "string" ? modelData : "")
                font.family: Theme.fontFamily
                font.pixelSize: ccSettingSubFontSize
                color: highlighted ? Theme.textPrimary : Theme.textMuted
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 6
                color: highlighted
                    ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.14)
                    : "transparent"
            }
        }

        contentItem: Text {
            leftPadding: 8
            rightPadding: cb.indicator.width + cb.spacing + 4
            text: cb.currentIndex >= 0 && cb.model.length > 0
                ? NotificationState.soundLabel(cb.model[cb.currentIndex])
                : ""
            font.family: Theme.fontFamily
            font.pixelSize: ccSettingSubFontSize
            color: Theme.textPrimary
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            x: cb.width - width - 8
            y: (cb.height - height) / 2
            font.family: Theme.iconFontFamily
            font.pixelSize: 11
            color: Theme.textMuted
            text: "󰅀"
        }

        background: Rectangle {
            implicitWidth: 180
            implicitHeight: 30
            radius: 7
            color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.07)
            border.width: 1.5
            border.color: cb.activeFocus
                ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.55)
                : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.15)
        }

        popup: Popup {
            y: cb.height + 2
            width: Math.max(cb.width, 180)
            implicitHeight: Math.min(list.contentHeight + 8, 228)
            padding: 4
            contentItem: ListView {
                id: list
                clip: true
                implicitHeight: Math.min(contentHeight, 220)
                model: cb.delegateModel
                currentIndex: cb.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator { }
            }
            background: Rectangle {
                radius: 10
                color: Theme.panelBgCard
                border.color: Theme.panelBorder
                border.width: 1
            }
        }

        function syncToValue(value) {
            const idx = model.indexOf(value)
            currentIndex = idx >= 0 ? idx : 0
        }
    }

    component SettingSoundPickerRow: RowLayout {
        property string rowLabel: ""
        property string rowHint: ""
        property bool subRow: true
        property bool rowEnabled: true
        property alias pickerModel: soundPicker.model
        property string pickerValue: ""
        signal picked(string value)

        Layout.fillWidth: true
        Layout.preferredHeight: rowHint !== "" ? ccSettingRowHeight + 10 : (subRow ? ccSettingSubRowHeight : ccSettingRowHeight)
        Layout.leftMargin: 14
        Layout.rightMargin: 20
        Layout.bottomMargin: ccSettingRowGap
        spacing: 10
        opacity: rowEnabled ? 1 : 0.35
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Item { width: subRow ? 22 : 0; height: 1 }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                font.family: Theme.fontFamily
                font.pixelSize: subRow ? ccSettingSubFontSize : ccSettingFontSize
                font.weight: Font.Medium
                color: rowEnabled ? Theme.textPrimary : Theme.textMuted
                opacity: subRow ? 0.82 : 1
                text: rowLabel
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: rowHint !== ""
                font.family: Theme.fontFamily
                font.pixelSize: ccNavFontSize
                color: Theme.textMuted
                opacity: 0.72
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                text: rowHint
            }
        }

        SettingComboBox {
            id: soundPicker
            boxEnabled: rowEnabled
            onActivated: idx => parent.picked(model[idx])
            Component.onCompleted: syncToValue(parent.pickerValue)
            Connections {
                target: parent
                function onPickerValueChanged() {
                    soundPicker.syncToValue(parent.pickerValue)
                }
            }
            Connections {
                target: NotificationState
                function onSoundChoicesChanged() {
                    soundPicker.syncToValue(parent.pickerValue)
                }
            }
        }
    }

    // ── Keybind helpers ───────────────────────────────────────────────────────
    function isModifierKey(key) {
        return key === Qt.Key_Shift   || key === Qt.Key_Control ||
               key === Qt.Key_Alt     || key === Qt.Key_Meta    ||
               key === Qt.Key_Super_L || key === Qt.Key_Super_R ||
               key === Qt.Key_Hyper_L || key === Qt.Key_Hyper_R ||
               key === Qt.Key_AltGr
    }
    function keyToHyprland(key) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
        const map = {
            [Qt.Key_Space]:       "SPACE",
            [Qt.Key_Return]:      "RETURN",
            [Qt.Key_Tab]:         "TAB",
            [Qt.Key_Backspace]:   "BACKSPACE",
            [Qt.Key_Delete]:      "DELETE",
            [Qt.Key_Insert]:      "INSERT",
            [Qt.Key_Home]:        "HOME",
            [Qt.Key_End]:         "END",
            [Qt.Key_PageUp]:      "PAGE_UP",
            [Qt.Key_PageDown]:    "PAGE_DOWN",
            [Qt.Key_Up]:          "UP",
            [Qt.Key_Down]:        "DOWN",
            [Qt.Key_Left]:        "LEFT",
            [Qt.Key_Right]:       "RIGHT",
            [Qt.Key_F1]:  "F1",  [Qt.Key_F2]:  "F2",  [Qt.Key_F3]:  "F3",  [Qt.Key_F4]:  "F4",
            [Qt.Key_F5]:  "F5",  [Qt.Key_F6]:  "F6",  [Qt.Key_F7]:  "F7",  [Qt.Key_F8]:  "F8",
            [Qt.Key_F9]:  "F9",  [Qt.Key_F10]: "F10", [Qt.Key_F11]: "F11", [Qt.Key_F12]: "F12",
            [Qt.Key_Semicolon]:   "semicolon",
            [Qt.Key_Comma]:       "comma",
            [Qt.Key_Period]:      "period",
            [Qt.Key_Slash]:       "slash",
            [Qt.Key_Backslash]:   "backslash",
            [Qt.Key_Minus]:       "minus",
            [Qt.Key_Plus]:        "plus",
            [Qt.Key_Equal]:       "equal",
            [Qt.Key_BracketLeft]: "bracketleft",
            [Qt.Key_BracketRight]:"bracketright",
            [Qt.Key_QuoteLeft]:   "grave",
        }
        return map[key] !== undefined ? map[key] : ""
    }
    function modsToHyprland(modifiers) {
        const parts = []
        if (modifiers & Qt.MetaModifier)    parts.push("SUPER")
        if (modifiers & Qt.ShiftModifier)   parts.push("SHIFT")
        if (modifiers & Qt.ControlModifier) parts.push("CTRL")
        if (modifiers & Qt.AltModifier)     parts.push("ALT")
        return parts.join(" ")
    }
    function modifierKeyToHyprland(key) {
        const map = {
            [Qt.Key_Shift]:   "Shift_L",
            [Qt.Key_Control]: "Control_L",
            [Qt.Key_Alt]:     "Alt_L",
            [Qt.Key_Meta]:    "Super_L",
            [Qt.Key_Super_L]: "Super_L",
            [Qt.Key_Super_R]: "Super_R",
            [Qt.Key_AltGr]:   "ISO_Level3_Shift",
        }
        return map[key] !== undefined ? map[key] : ""
    }
    function keyToModifierBit(key) {
        if (key === Qt.Key_Shift)                                                   return Qt.ShiftModifier
        if (key === Qt.Key_Control)                                                  return Qt.ControlModifier
        if (key === Qt.Key_Alt || key === Qt.Key_AltGr)                              return Qt.AltModifier
        if (key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R) return Qt.MetaModifier
        return 0
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function kbLayouts()     { return settings.kbLayout.split(",").map(s => s.trim()).filter(s => s.length > 0) }
    function kbRemoveLayout(idx) {
        var arr = kbLayouts().filter((_, i) => i !== idx)
        if (arr.length === 0) arr = ["us"]
        settings.kbLayout = arr.join(",")
        root.applyKeyword("input:kb_layout", settings.kbLayout)
    }
    function kbAddLayout(code) {
        var arr = kbLayouts()
        if (code.trim() && !arr.includes(code.trim())) {
            arr.push(code.trim())
            settings.kbLayout = arr.join(",")
            root.applyKeyword("input:kb_layout", settings.kbLayout)
        }
        root.showAddLayoutInput = false
        root.newLayoutDraft = ""
    }

    function applyThemeMode(isLight) {
        ThemeState.setTheme(isLight)
    }

    function applyBorderSize() {
        const size = settings.borderEnabled ? settings.borderSize : 0
        root.applyKeyword("general:border_size", size.toString())
    }

    function applyKeyword(key, val) {
        kwProc.running = false
        kwProc.kwKey   = key
        kwProc.kwVal   = val
        kwProc.running = true
        if (key === "decoration:blur:enabled")
            AppearanceState.setHyprBlurEnabled(val === "true" || val === "1")
        persistAppearanceConf(false)
    }

    function flushAppearanceSave() {
        if (!settingsHydrated)
            return
        saveAppearanceProc._content = buildAppearanceConf()
        saveAppearanceProc.running = false
        saveAppearanceProc.running = true
    }

    function persistAppearanceConf(reloadAfter) {
        if (!settingsHydrated) {
            appearanceDirty = true
            return
        }
        appearanceSaveTimer.restart()
    }

    function restoreLayerShellFocus() {
        if (AppState.wallpaperPickerVisible || avatarPickerActive) return
        WlrLayershell.layer = WlrLayer.Top
        WlrLayershell.keyboardFocus = root.showSettings
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None
    }

    function syncWallpaperPickerLayer() {
        if (AppState.wallpaperPickerVisible) {
            WlrLayershell.layer = WlrLayer.Background
            WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
        } else if (!avatarPickerActive) {
            restoreLayerShellFocus()
        }
    }

    function openAvatarPicker() {
        if (avatarPickerProc.running || avatarPickerActive) return
        avatarPickerActive = true
        _pickedAvatarPath = ""
        WlrLayershell.layer = WlrLayer.Background
        WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
        avatarPickerProc.running = true
    }

    function finishAvatarPicker(pickedPath) {
        if (!avatarPickerActive) return
        avatarPickerActive = false
        _pickedAvatarPath = ""
        restoreLayerShellFocus()
        if (pickedPath) {
            avatarCopyProc.srcPath = pickedPath
            avatarCopyProc.running = true
        }
    }

    function animDurationToSpeed(windowsDur) {
        const targets = [13, 8, 5, 3, 2]   // windows ms for speeds 1…5
        const n = parseInt(windowsDur) || 5
        let best = 3, bestDiff = 999
        for (let i = 0; i < targets.length; i++) {
            const d = Math.abs(n - targets[i])
            if (d < bestDiff) { bestDiff = d; best = i + 1 }
        }
        return best
    }

    function applyAnimSpeed(speed) {
        settings.animSpeed = speed
        const m  = [2.5, 1.6, 1.0, 0.6, 0.35]
        const f  = m[Math.max(0, Math.min(4, speed - 1))]
        const w  = Math.max(1, Math.round(5 * f))
        const wo = Math.max(1, Math.round(4 * f))
        const b  = Math.max(1, Math.round(8 * f))
        const fa = Math.max(1, Math.round(6 * f))
        const ws = Math.max(1, Math.round(5 * f))
        animSpeedProc.running = false
        animSpeedProc.batchCmd =
            "keyword animation windows,1,"    + w  + ",easeOut,slide ; " +
            "keyword animation windowsOut,1," + wo + ",easeInOut,slide ; " +
            "keyword animation border,1,"     + b  + ",easeOut ; " +
            "keyword animation fade,1,"       + fa + ",easeOut ; " +
            "keyword animation workspaces,1," + ws + ",easeOut,slide"
        animSpeedProc.running = true
        persistAppearanceConf(false)
    }

    function buildAppearanceConf() {
        const s  = settings
        const m  = [2.5, 1.6, 1.0, 0.6, 0.35]
        const f  = m[Math.max(0, Math.min(4, s.animSpeed - 1))]
        const w  = Math.max(1, Math.round(5 * f))
        const wo = Math.max(1, Math.round(4 * f))
        const b  = Math.max(1, Math.round(8 * f))
        const fa = Math.max(1, Math.round(6 * f))
        const ws = Math.max(1, Math.round(5 * f))
        return "# Auto-managed by Quickshell Settings Panel — do not edit by hand\n\n" +
            "general {\n" +
            "    border_size = " + (s.borderEnabled ? s.borderSize : 0) + "\n" +
            "}\n\n" +
            "decoration {\n" +
            "    rounding = " + s.rounding + "\n\n" +
            "    blur {\n" +
            "        enabled           = " + (s.blurEnabled ? "true" : "false") + "\n" +
            "        size              = " + s.blurSize    + "\n" +
            "        passes            = " + s.blurPasses  + "\n" +
            "        xray              = " + (s.blurXray ? "true" : "false") + "\n" +
            "        new_optimizations = " + (s.blurNewOptimizations ? "true" : "false") + "\n" +
            "        ignore_opacity    = " + (s.blurIgnoreOpacity ? "true" : "false") + "\n" +
            "        brightness        = " + s.blurBrightness.toFixed(2) + "\n" +
            "        contrast          = " + s.blurContrast.toFixed(2) + "\n" +
            "        vibrancy          = " + s.blurVibrancy.toFixed(2) + "\n" +
            "        vibrancy_darkness = " + s.blurVibrancyDarkness.toFixed(2) + "\n" +
            "    }\n\n" +
            "    shadow {\n" +
            "        enabled      = " + (s.shadowEnabled ? "true" : "false") + "\n" +
            "        range        = " + s.shadowRange + "\n" +
            "        render_power = 3\n" +
            "        color        = rgba(00000066)\n" +
            "    }\n\n" +
            "    active_opacity   = " + s.activeOpacity.toFixed(2)   + "\n" +
            "    inactive_opacity = " + s.inactiveOpacity.toFixed(2) + "\n" +
            "}\n\n" +
            "animations {\n" +
            "    enabled = " + (s.animEnabled ? "true" : "false") + "\n\n" +
            "    animation = windows,    1, " + w  + ", easeOut,   slide\n" +
            "    animation = windowsOut, 1, " + wo + ", easeInOut, slide\n" +
            "    animation = border,     1, " + b  + ", easeOut\n" +
            "    animation = fade,       1, " + fa + ", easeOut\n" +
            "    animation = workspaces, 1, " + ws + ", easeOut,   slide\n" +
            "}\n\n" +
            "input {\n" +
            "    kb_layout   = " + s.kbLayout + "\n" +
            "    sensitivity = " + s.sensitivity.toFixed(2) + "\n\n" +
            "    touchpad {\n" +
            "        natural_scroll = " + (s.naturalScroll ? "true" : "false") + "\n" +
            "    }\n" +
            "}\n\n" +
            "# quickshell-system-blur=" + (s.systemBlurEnabled ? "true" : "false") + "\n" +
            "# quickshell-border-size=" + s.borderSize + "\n" +
            "# quickshell-panel-opacity=" + AppearanceState.panelOpacity.toFixed(2) + "\n" +
            "# quickshell-panel-card-opacity=" + AppearanceState.panelCardOpacity.toFixed(2) + "\n"
    }

    function persistKbSwitchBindConf() {
        const b = settings.kbSwitchBind.trim()
        saveKbSwitchBindProc.bindLine = b
            ? ("bind = " + b + ", exec, hyprctl switchxkblayout all next")
            : ""
        saveKbSwitchBindProc.running = true
    }

    function applyKbSwitchBindLive(prevBind, newBind) {
        const prev = prevBind.trim()
        const next = newBind.trim()
        let batch = ""
        if (prev) batch += "keyword unbind " + prev + " ; "
        if (next) batch += "keyword bind " + next + ", exec, hyprctl switchxkblayout all next"
        kbSwitchBindProc.running = false
        kbSwitchBindProc.batchCmd = batch.trim()
        if (kbSwitchBindProc.batchCmd !== "")
            kbSwitchBindProc.running = true
        persistKbSwitchBindConf()
    }

    function setKbSwitchBind(newBind) {
        const prev = settings.kbSwitchBind
        settings.kbSwitchBind = newBind
        applyKbSwitchBindLive(prev, newBind)
    }

    // ── Visibility gating ─────────────────────────────────────────────────────
    Connections {
        target: AppState
        function onWallpaperPickerVisibleChanged() {
            root.syncWallpaperPickerLayer()
        }
    }

    Connections {
        target: AppState
        function onControlCenterVisibleChanged() {
            if (AppState.controlCenterVisible) {
                AppearanceState.reload()
                hideTimer.stop()
                avatarImg.source = ""
                avatarImg.source = root.avatarPath
                root.showWindow  = true
            } else {
                root.showPowerMenu = false
                if (root.avatarPickerActive)
                    root.finishAvatarPicker("")
                if (root.showSettings) root.showSettings = false
                hideTimer.restart()
            }
        }
    }

    Timer {
        id: hideTimer; interval: 560; repeat: false
        onTriggered: { if (!AppState.controlCenterVisible) root.showWindow = false }
    }

    onShowSettingsChanged: {
        if (showSettings) {
            settingsHydrated = false
            appearanceDirty = false
            _readPanelOpacity = NaN
            _readPanelCardOpacity = NaN
            WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand
            root.selectedSection = "appearance"
            readSettingsProc.running      = true
            readWallpaperPathProc.running = true
            distroInfoProc.running        = true
            ThemeState.reloadFromDisk()
        } else {
            root.capturingBind  = false
            root.showAddLayoutInput = false
            if (!avatarPickerActive)
                WlrLayershell.keyboardFocus = WlrKeyboardFocus.None
            appearanceSaveTimer.stop()
            if (settingsHydrated) {
                root.flushAppearanceSave()
                persistKbSwitchBindConf()
            }
            settingsHydrated = false
            appearanceDirty = false
        }
    }

    Timer {
        id: appearanceSaveTimer
        interval: 300
        repeat: false
        onTriggered: root.flushAppearanceSave()
    }

    Item {
        id: bindKeyCatcher
        anchors.fill: parent
        focus: root.capturingBind
        visible: root.capturingBind
        onVisibleChanged: if (visible) forceActiveFocus()

        Keys.onPressed: (event) => {
            event.accepted = true

            if (event.key === Qt.Key_Escape) {
                root.capturingBind = false; return
            }

            if (root.isModifierKey(event.key)) {
                // Support modifier-only combos like SHIFT+ALT:
                // record when a modifier key is pressed while another modifier is already held.
                const ownBit    = root.keyToModifierBit(event.key)
                const allMods   = Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier
                const otherMods = (event.modifiers & ~ownBit) & allMods
                if (otherMods !== 0) {
                    const mods   = root.modsToHyprland(otherMods)
                    const keyStr = root.modifierKeyToHyprland(event.key)
                    if (keyStr && mods) {
                        root.setKbSwitchBind(mods + ", " + keyStr)
                        root.capturingBind = false
                    }
                }
                return
            }

            const mods   = root.modsToHyprland(event.modifiers)
            const keyStr = root.keyToHyprland(event.key)
            if (!keyStr) return

            root.setKbSwitchBind(mods !== "" ? (mods + ", " + keyStr) : keyStr)
            root.capturingBind = false
        }
    }

    // ── Click-outside dismiss (no dim scrim — glass is on the card only) ───────
    MouseArea {
        anchors.fill: parent
        enabled: !root.blocksPointer
        onClicked: AppState.controlCenterVisible = false
    }

    readonly property real slideOriginY: -(Screen.height / 2 - Theme.barMargin - Theme.pillHeight / 2)

    // ── Main card ─────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        z: 1
        anchors.centerIn: parent
        width: root.showSettings ? 760 : Theme.ccWidth
        height: Theme.ccHeight
        Behavior on width {
            NumberAnimation {
                duration: root.settingsTransitionMs
                easing.type: Easing.InOutCubic
            }
        }
        radius: Theme.ccRadius
        color: Theme.panelBg; border.color: Theme.panelBorder; border.width: 1.5
        clip: true

        property real yOffset: root.slideOriginY
        transform: Translate { y: card.yOffset }

        state: AppState.controlCenterVisible ? "open" : "closed"
        states: [
            State { name: "closed"
                PropertyChanges { target: card; yOffset: root.slideOriginY; opacity: 0.0 } },
            State { name: "open"
                PropertyChanges { target: card; yOffset: 0.0; opacity: 1.0 } }
        ]
        transitions: [
            Transition { from: "closed"; to: "open"
                NumberAnimation { target: card; property: "yOffset"; duration: 420; easing.type: Easing.OutExpo }
                NumberAnimation { target: card; property: "opacity"; duration: 220; easing.type: Easing.OutQuad }
            },
            Transition { from: "open"; to: "closed"
                NumberAnimation { target: card; property: "yOffset"; duration: 500; easing.type: Easing.InQuart }
                NumberAnimation { target: card; property: "opacity"; duration: 420; easing.type: Easing.InQuad }
            }
        ]

        MouseArea {
            anchors.fill: parent
            enabled: !root.blocksPointer && !root.showPowerMenu
        }

        // ════════════════════════════════════════════════════════════════════
        // MAIN VIEW
        // ════════════════════════════════════════════════════════════════════
        Item {
            id: mainViewItem
            width: Theme.ccWidth
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            opacity: root.showSettings ? 0.0 : 1.0
            enabled: !root.showSettings
            Behavior on opacity {
                NumberAnimation {
                    duration: root.settingsTransitionMs
                    easing.type: Easing.InOutCubic
                }
            }
            property real vY: 0
            transform: Translate { y: mainViewItem.vY }
            states: [
                State { name: "shown"; when: !root.showSettings
                    PropertyChanges { target: mainViewItem; vY: 0 } },
                State { name: "gone";  when:  root.showSettings
                    PropertyChanges { target: mainViewItem; vY: -12 } }
            ]
            transitions: Transition {
                NumberAnimation {
                    target: mainViewItem
                    property: "vY"
                    duration: root.settingsTransitionMs
                    easing.type: Easing.InOutCubic
                }
            }

            // Power button (top-left)
            Rectangle {
                z: 30
                anchors { top: parent.top; left: parent.left; topMargin: 14; leftMargin: 14 }
                width: 30; height: 30; radius: 8
                color: powerMa.containsMouse
                    ? Qt.rgba(0.90, 0.45, 0.45, 0.16)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    font.family: Theme.iconFontFamily; font.pixelSize: 15
                    color: powerMa.containsMouse ? "#e57373" : Theme.textMuted
                    text: "\uf011"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: powerMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: 1
                    onClicked: root.showPowerMenu = !root.showPowerMenu
                }
            }

            // Settings cog button (top-right)
            Rectangle {
                z: 30
                anchors { top: parent.top; right: parent.right; topMargin: 14; rightMargin: 14 }
                width: 30; height: 30; radius: 8
                color: cogMa.containsMouse
                    ? Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.15)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    font.family: Theme.iconFontFamily; font.pixelSize: 15
                    color: cogMa.containsMouse ? Theme.textPrimary : Theme.textMuted; text: "\uf013"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: cogMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.showPowerMenu = false
                        root.showSettings = true
                    }
                }
            }

            ColumnLayout {
                z: 1
                anchors { fill: parent; topMargin: Theme.ccPadding; bottomMargin: Theme.ccPadding
                          leftMargin: Theme.ccPadding; rightMargin: Theme.ccPadding }
                spacing: 0

                // Time
                Text {
                    id: timeText
                    Layout.alignment: Qt.AlignHCenter
                    font.family: Theme.fontFamily; font.pixelSize: 54; font.weight: Font.Light
                    color: Theme.textPrimary
                    text: Qt.formatDateTime(new Date(), "HH:mm")
                    Timer { interval: 1000; running: root.visible; repeat: true
                        onTriggered: timeText.text = Qt.formatDateTime(new Date(), "HH:mm") }
                }

                // Date
                Text {
                    id: dateText
                    Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 4
                    font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted
                    text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
                    Timer { interval: 60000; running: root.visible; repeat: true
                        onTriggered: dateText.text = Qt.formatDateTime(new Date(), "dddd, d MMMM") }
                }

                Item { Layout.preferredHeight: 28 }

                // Avatar
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    readonly property int avatarSize: Theme.ccAvatarSize
                    width: avatarSize + 14; height: avatarSize + 14

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.avatarSize + 14; height: parent.avatarSize + 14
                        radius: width / 2; color: "transparent"; border.width: 1
                        border.color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.28)
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.avatarSize + 6; height: parent.avatarSize + 6
                        radius: width / 2; color: "transparent"; border.width: 1.5
                        border.color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.80)
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }
                    Item {
                        anchors.centerIn: parent
                        width: parent.avatarSize; height: parent.avatarSize
                        Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.panelBgCard }
                        Image {
                            id: avatarImg; anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop; cache: false
                            source: root.avatarPath; smooth: true
                            visible: false; layer.enabled: true; layer.smooth: true
                        }
                        Rectangle {
                            id: avatarMaskShape; anchors.fill: parent
                            radius: width / 2; visible: false; layer.enabled: true
                        }
                        OpacityMask {
                            anchors.fill: parent; source: avatarImg
                            maskSource: avatarMaskShape; visible: avatarImg.status === Image.Ready
                        }
                        Text {
                            visible: avatarImg.status !== Image.Ready; anchors.centerIn: parent
                            font.family: Theme.iconFontFamily; font.pixelSize: 46
                            color: Theme.textMuted; text: "\uf007"
                        }
                        Rectangle {
                            anchors.fill: parent; radius: width / 2
                            color: Qt.rgba(0, 0, 0, 0.45)
                            opacity: avatarMouse.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; font.family: Theme.iconFontFamily
                                font.pixelSize: 24; color: "white"; text: "\uf030" }
                        }
                    }
                    MouseArea {
                        id: avatarMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openAvatarPicker()
                    }
                }

                // Username
                Text {
                    Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 12
                    font.family: Theme.fontFamily; font.pixelSize: 18; font.weight: Font.Medium
                    color: Theme.textPrimary; text: Quickshell.env("USER")
                }

                // Avatar hint
                Text {
                    id: avatarHint
                    Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 5
                    opacity: 0; font.family: Theme.fontFamily; font.pixelSize: 11
                    color: Theme.textMuted; text: "Нажмите на аватар чтобы изменить"
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Timer { id: hintTimer; interval: 3000; onTriggered: avatarHint.opacity = 0 }
                }

                Item { Layout.preferredHeight: 20 }

                // System info card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: infoLayout.implicitHeight + 24
                    radius: 16; color: Theme.panelBgCard; border.color: Theme.panelBorder; border.width: 1

                    ColumnLayout {
                        id: infoLayout
                        anchors { left: parent.left; right: parent.right; top: parent.top
                                  leftMargin: 20; rightMargin: 20; topMargin: 12 }
                        spacing: 8

                        RowLayout { spacing: 10
                            Text { font.family: Theme.iconFontFamily; font.pixelSize: 14; color: Theme.textAccent; text: "\uf303" }
                            Text { Layout.fillWidth: true; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted; text: sysInfo.osName;  elide: Text.ElideRight } }
                        RowLayout { spacing: 10
                            Text { font.family: Theme.iconFontFamily; font.pixelSize: 14; color: Theme.textAccent; text: "\uf4bc" }
                            Text { Layout.fillWidth: true; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted; text: sysInfo.cpuName; elide: Text.ElideRight } }
                        RowLayout { spacing: 10
                            Text { font.family: Theme.iconFontFamily; font.pixelSize: 14; color: Theme.textAccent; text: "󰢮" }
                            Text { Layout.fillWidth: true; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted; text: sysInfo.gpuName; elide: Text.ElideRight } }
                        RowLayout { spacing: 10
                            Text { font.family: Theme.iconFontFamily; font.pixelSize: 14; color: Theme.textAccent; text: "󰍛" }
                            Text { Layout.fillWidth: true; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted; text: sysInfo.ramInfo; elide: Text.ElideRight } }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ── Power menu overlay ────────────────────────────────────────────
            Item {
                id: powerOverlay
                anchors.fill: parent
                visible: root.showPowerMenu
                enabled: visible
                z: 40
                focus: visible

                opacity: visible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                onVisibleChanged: {
                    if (visible)
                        Qt.callLater(() => powerOverlay.forceActiveFocus())
                }

                Keys.onEscapePressed: root.showPowerMenu = false

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.ccRadius
                    color: Qt.rgba(0, 0, 0, 0.52)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.showPowerMenu = false
                }

                Rectangle {
                    id: powerPanel
                    anchors.centerIn: parent
                    width: Math.min(300, parent.width - 36)
                    radius: 18
                    color: Theme.panelBgCard
                    border.color: Theme.panelBorder
                    border.width: 1

                    property real panelScale: root.showPowerMenu ? 1 : 0.92
                    scale: panelScale

                    Behavior on panelScale {
                        NumberAnimation { duration: 320; easing.type: Easing.OutBack }
                    }

                    ColumnLayout {
                        id: powerPanelCol
                        width: parent.width - 32
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 16
                        anchors.bottomMargin: 16
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 18
                                color: "#e57373"
                                text: "\uf011"
                            }

                            Text {
                                Layout.fillWidth: true
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                color: Theme.textPrimary
                                text: "Питание"
                            }

                            Rectangle {
                                width: 28; height: 28; radius: 8
                                color: powerCloseMa.containsMouse
                                    ? Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.14)
                                    : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: 14
                                    color: powerCloseMa.containsMouse ? Theme.textPrimary : Theme.textMuted
                                    text: "󰅖"
                                }
                                MouseArea {
                                    id: powerCloseMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showPowerMenu = false
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.panelBorder
                            opacity: 0.5
                        }

                        ColumnLayout {
                            id: powerList
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: root.powerActions
                                delegate: PowerActionBtn {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    icon: modelData.icon
                                    label: modelData.label
                                    actionId: modelData.id
                                    actionColor: modelData.color
                                    enterDelay: index * 48
                                    menuOpen: root.showPowerMenu
                                    onTriggered: id => root.runPowerAction(id)
                                }
                            }
                        }
                    }

                    height: powerPanelCol.implicitHeight + 32

                    MouseArea {
                        anchors.fill: parent
                        onClicked: mouse => mouse.accepted = true
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // SETTINGS VIEW
        // ════════════════════════════════════════════════════════════════════
        Item {
            id: settingsViewItem
            anchors.fill: parent
            enabled: root.showSettings
            opacity: root.showSettings ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.settingsTransitionMs
                    easing.type: Easing.InOutCubic
                }
            }
            property real vY: 12
            transform: Translate { y: settingsViewItem.vY }
            states: [
                State { name: "shown"; when:  root.showSettings
                    PropertyChanges { target: settingsViewItem; vY: 0 } },
                State { name: "gone";  when: !root.showSettings
                    PropertyChanges { target: settingsViewItem; vY: 12 } }
            ]
            transitions: Transition {
                NumberAnimation {
                    target: settingsViewItem
                    property: "vY"
                    duration: root.settingsTransitionMs
                    easing.type: Easing.InOutCubic
                }
            }

            // ── Header bar ──────────────────────────────────────────────────
            Rectangle {
                id: settingsHeader
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 52; color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 10
                    // Back button
                    Rectangle {
                        width: 28; height: 28; radius: 7
                        color: backMa.containsMouse
                            ? Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.14)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; font.family: Theme.iconFontFamily; font.pixelSize: 13
                            color: backMa.containsMouse ? Theme.textPrimary : Theme.textMuted; text: "\uf060"
                            Behavior on color { ColorAnimation { duration: 100 } } }
                        MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.showSettings = false }
                    }
                    Text { font.family: Theme.iconFontFamily; font.pixelSize: ccSectionHeaderSize; color: Theme.textAccent; text: "\uf013" }
                    Text { font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Medium
                        color: Theme.textPrimary; text: "Settings" }
                    Item { Layout.fillWidth: true }
                }
                // Hairline divider
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1; color: Theme.ccBorder; opacity: 0.6
                }
            }

            // ── Body: sidebar + content ──────────────────────────────────────
            RowLayout {
                anchors { top: settingsHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                spacing: 0

                // ── Sidebar ──────────────────────────────────────────────────
                Rectangle {
                    Layout.preferredWidth: 152; Layout.fillHeight: true
                    color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.05)
                    radius: 0
                    ColumnLayout {
                        anchors { fill: parent; topMargin: 10; bottomMargin: 10; leftMargin: 8; rightMargin: 8 }
                        spacing: 3
                        NavItem { sectionId: "appearance"; navIcon: "󰸉"; navLabel: "Appearance" }
                        NavItem { sectionId: "windows";    navIcon: "󰖯"; navLabel: "Windows"    }
                        NavItem { sectionId: "animations"; navIcon: "󰄜"; navLabel: "Animations" }
                        NavItem { sectionId: "input";      navIcon: "󰌌"; navLabel: "Input"       }
                        NavItem { sectionId: "notifications"; navIcon: "󰂚"; navLabel: "Notifications" }
                        NavItem { sectionId: "systeminfo"; navIcon: "󰋼"; navLabel: "System Info" }
                        Item { Layout.fillHeight: true }
                    }
                }

                // Hairline separator
                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.ccBorder; opacity: 0.6 }

                // ── Content pane ──────────────────────────────────────────────
                // Flickable instead of ScrollView: only intercepts vertical drags
                // so horizontal slider movement is not blocked.
                Flickable {
                    id: settingsFlickable
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.rightMargin: 2
                    clip: true
                    contentWidth: width
                    contentHeight: sectionStack.height + 24
                    flickableDirection: Flickable.VerticalFlick
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; implicitWidth: 8 }

                    Item {
                        id: sectionStack
                        width: settingsFlickable.width - 10
                        x: 5
                        height: root.selectedSection === "windows"    ? windowsPane.implicitHeight
                              : root.selectedSection === "animations" ? animPane.implicitHeight
                              : root.selectedSection === "input"      ? inputPane.implicitHeight
                              : root.selectedSection === "notifications" ? notificationsPane.implicitHeight
                              : root.selectedSection === "systeminfo" ? systemInfoPane.implicitHeight
                              : appearancePane.implicitHeight

                        Behavior on height {
                            NumberAnimation {
                                duration: root.sectionSwitchMs
                                easing.type: Easing.OutCubic
                            }
                        }

                        // ════════════════════════════════
                        // APPEARANCE section
                        // ════════════════════════════════
                        SettingSectionPane {
                            id: appearancePane
                            sectionId: "appearance"

                            // Wallpaper preview
                            Item {
                                Layout.fillWidth: true
                                Layout.topMargin: 14; Layout.bottomMargin: 10
                                Layout.leftMargin: 14; Layout.rightMargin: 14
                                height: 170
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 16
                                    color: Theme.panelBgCard
                                    border.color: Theme.panelBorder
                                    border.width: 1
                                    clip: true

                                    Image {
                                        id: wpPreview
                                        anchors.fill: parent
                                        smooth: true
                                        asynchronous: true
                                        cache: false
                                        fillMode: Image.PreserveAspectCrop
                                        visible: false
                                        source: AppState.currentWallpaperPath !== ""
                                            ? "file://" + AppState.currentWallpaperPath : ""
                                    }
                                    Rectangle {
                                        id: wpMaskShape
                                        anchors.fill: parent
                                        radius: 16
                                        visible: false
                                    }
                                    OpacityMask {
                                        anchors.fill: parent
                                        source: wpPreview
                                        maskSource: wpMaskShape
                                        visible: wpPreview.status === Image.Ready
                                            && AppState.currentWallpaperPath !== ""
                                    }
                                    Connections {
                                        target: AppState
                                        function onCurrentWallpaperPathChanged() {
                                            wpPreview.source = ""
                                            wpPreview.source = AppState.currentWallpaperPath !== ""
                                                ? "file://" + AppState.currentWallpaperPath : ""
                                        }
                                    }
                                    // Empty state icon
                                    Text {
                                        visible: AppState.currentWallpaperPath === ""
                                        anchors.centerIn: parent
                                        font.family: Theme.iconFontFamily; font.pixelSize: 28
                                        color: Theme.textMuted; opacity: 0.25; text: "󰸉"
                                    }
                                    // Hover overlay
                                    Rectangle {
                                        id: wpOverlay
                                        anchors.fill: parent; radius: 16
                                        color: AppearanceState.dimOverlay(0.5)
                                        opacity: wpMa.containsMouse ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                        RowLayout {
                                            anchors.centerIn: parent; spacing: 8
                                            Text { font.family: Theme.iconFontFamily; font.pixelSize: 16; color: "white"; text: "󰸉" }
                                            Text { font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize; font.weight: Font.Medium
                                                color: "white"; text: "Change wallpaper" }
                                        }
                                    }
                                    MouseArea { id: wpMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: AppState.wallpaperPickerVisible = true }
                                }
                            }

                            // Dark / Light theme toggle
                            RowLayout {
                                Layout.fillWidth: true; Layout.bottomMargin: 14
                                Layout.leftMargin: 14; Layout.rightMargin: 14; spacing: 8

                                // Dark
                                Rectangle {
                                    Layout.fillWidth: true; height: 38; radius: 9
                                    color: !ThemeState.lightTheme
                                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.20)
                                        : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.07)
                                    border.width: 1.5
                                    border.color: !ThemeState.lightTheme
                                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.55)
                                        : "transparent"
                                    Behavior on color       { ColorAnimation { duration: 160 } }
                                    Behavior on border.color { ColorAnimation { duration: 160 } }
                                    RowLayout { anchors.centerIn: parent; spacing: 6
                                        Text { font.family: Theme.iconFontFamily; font.pixelSize: ccSettingSubFontSize
                                            color: !ThemeState.lightTheme ? Theme.textAccent : Theme.textMuted; text: "󰖔"
                                            Behavior on color { ColorAnimation { duration: 160 } } }
                                        Text { font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize
                                            color: !ThemeState.lightTheme ? Theme.textPrimary : Theme.textMuted; text: "Dark"
                                            Behavior on color { ColorAnimation { duration: 160 } } }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.applyThemeMode(false) }
                                }

                                // Light
                                Rectangle {
                                    Layout.fillWidth: true; height: 38; radius: 9
                                    color: ThemeState.lightTheme
                                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.20)
                                        : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.07)
                                    border.width: 1.5
                                    border.color: ThemeState.lightTheme
                                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.55)
                                        : "transparent"
                                    Behavior on color       { ColorAnimation { duration: 160 } }
                                    Behavior on border.color { ColorAnimation { duration: 160 } }
                                    RowLayout { anchors.centerIn: parent; spacing: 6
                                        Text { font.family: Theme.iconFontFamily; font.pixelSize: ccSettingSubFontSize
                                            color: ThemeState.lightTheme ? Theme.textAccent : Theme.textMuted; text: "󰖙"
                                            Behavior on color { ColorAnimation { duration: 160 } } }
                                        Text { font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize
                                            color: ThemeState.lightTheme ? Theme.textPrimary : Theme.textMuted; text: "Light"
                                            Behavior on color { ColorAnimation { duration: 160 } } }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.applyThemeMode(true) }
                                }
                            }

                            // Thin divider before remaining options
                            Rectangle {
                                Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14
                                Layout.bottomMargin: 12; height: 1
                                color: Theme.panelBorder; opacity: 0.5
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                SettingToggleRow {
                                    rowIcon: "󰴰"; rowLabel: "System blur"
                                    rowEnabled: !ThemeState.lightTheme && settingsHydrated
                                    rowChecked: ThemeState.lightTheme ? false : settings.systemBlurEnabled
                                    onToggled: val => {
                                        if (ThemeState.lightTheme || !settingsHydrated)
                                            return
                                        settings.systemBlurEnabled = val
                                        appearanceDirty = true
                                        AppearanceState.applyFromSettings(val, undefined, undefined)
                                        root.persistAppearanceConf(false)
                                    }
                                }

                                Text {
                                    visible: ThemeState.lightTheme
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 42
                                    Layout.rightMargin: 14
                                    Layout.topMargin: -2
                                    Layout.bottomMargin: 8
                                    font.family: Theme.fontFamily
                                    font.pixelSize: ccNavFontSize
                                    color: Theme.textMuted
                                    opacity: 0.75
                                    wrapMode: Text.WordWrap
                                    text: "Системный blur недоступен в светлой теме"
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14
                                Layout.topMargin: 4; Layout.bottomMargin: 12; height: 1
                                color: Theme.panelBorder; opacity: 0.5
                            }

                            // Blur
                            SettingToggleRow {
                                rowIcon: "󰻂"; rowLabel: "Blur"; rowChecked: settings.blurEnabled
                                onToggled: val => {
                                    settings.blurEnabled = val
                                    AppearanceState.setHyprBlurEnabled(val)
                                    root.applyKeyword("decoration:blur:enabled", val ? "true" : "false")
                                }
                            }
                            SettingNumRow {
                                subRow: true; rowLabel: "Size"; rowEnabled: settings.blurEnabled
                                nText: settings.blurSize.toString()
                                onCommitted: raw => {
                                    const v = Math.max(1, Math.min(20, parseInt(raw) || settings.blurSize))
                                    settings.blurSize = v
                                    root.applyKeyword("decoration:blur:size", v.toString())
                                }
                            }
                            SettingNumRow {
                                subRow: true; rowLabel: "Passes"; rowEnabled: settings.blurEnabled
                                nText: settings.blurPasses.toString()
                                onCommitted: raw => {
                                    const v = Math.max(1, Math.min(10, parseInt(raw) || settings.blurPasses))
                                    settings.blurPasses = v
                                    root.applyKeyword("decoration:blur:passes", v.toString())
                                }
                            }
                            SettingSubToggleRow {
                                rowLabel: "Xray"; rowChecked: settings.blurXray
                                rowEnabled: settings.blurEnabled
                                onToggled: val => {
                                    settings.blurXray = val
                                    root.applyKeyword("decoration:blur:xray", val ? "true" : "false")
                                }
                            }
                            SettingSubToggleRow {
                                rowLabel: "New optimizations"; rowChecked: settings.blurNewOptimizations
                                rowEnabled: settings.blurEnabled
                                onToggled: val => {
                                    settings.blurNewOptimizations = val
                                    root.applyKeyword("decoration:blur:new_optimizations", val ? "true" : "false")
                                }
                            }
                            SettingSubToggleRow {
                                rowLabel: "Ignore opacity"; rowChecked: settings.blurIgnoreOpacity
                                rowEnabled: settings.blurEnabled
                                onToggled: val => {
                                    settings.blurIgnoreOpacity = val
                                    root.applyKeyword("decoration:blur:ignore_opacity", val ? "true" : "false")
                                }
                            }
                            SettingNumRow {
                                subRow: true; rowLabel: "Brightness"; rowEnabled: settings.blurEnabled
                                nText: root.pctFromFloat(settings.blurBrightness).toString()
                                nUnit: "%"
                                onCommitted: raw => {
                                    const p = Math.max(0, Math.min(200, parseInt(raw) || root.pctFromFloat(settings.blurBrightness)))
                                    settings.blurBrightness = root.floatFromPct(p)
                                    root.applyKeyword("decoration:blur:brightness", settings.blurBrightness.toFixed(2))
                                }
                            }
                            SettingNumRow {
                                subRow: true; rowLabel: "Contrast"; rowEnabled: settings.blurEnabled
                                nText: root.pctFromFloat(settings.blurContrast).toString()
                                nUnit: "%"
                                onCommitted: raw => {
                                    const p = Math.max(0, Math.min(200, parseInt(raw) || root.pctFromFloat(settings.blurContrast)))
                                    settings.blurContrast = root.floatFromPct(p)
                                    root.applyKeyword("decoration:blur:contrast", settings.blurContrast.toFixed(2))
                                }
                            }
                            SettingNumRow {
                                subRow: true; rowLabel: "Vibrancy"; rowEnabled: settings.blurEnabled
                                nText: root.pctFromFloat(settings.blurVibrancy).toString()
                                nUnit: "%"
                                onCommitted: raw => {
                                    const p = Math.max(0, Math.min(100, parseInt(raw) || root.pctFromFloat(settings.blurVibrancy)))
                                    settings.blurVibrancy = root.floatFromPct(p)
                                    root.applyKeyword("decoration:blur:vibrancy", settings.blurVibrancy.toFixed(2))
                                }
                            }
                            SettingNumRow {
                                subRow: true; rowLabel: "Vibrancy darkness"; rowEnabled: settings.blurEnabled
                                Layout.bottomMargin: ccSettingSectionGap
                                nText: root.pctFromFloat(settings.blurVibrancyDarkness).toString()
                                nUnit: "%"
                                onCommitted: raw => {
                                    const p = Math.max(0, Math.min(100, parseInt(raw) || root.pctFromFloat(settings.blurVibrancyDarkness)))
                                    settings.blurVibrancyDarkness = root.floatFromPct(p)
                                    root.applyKeyword("decoration:blur:vibrancy_darkness", settings.blurVibrancyDarkness.toFixed(2))
                                }
                            }

                            SettingNumRow {
                                rowIcon: "󰩭"; rowLabel: "Rounding"
                                nText: settings.rounding.toString()
                                onCommitted: raw => {
                                    const v = Math.max(0, Math.min(24, parseInt(raw) || settings.rounding))
                                    settings.rounding = v
                                    root.applyKeyword("decoration:rounding", v.toString())
                                }
                            }

                            SettingToggleRow {
                                rowIcon: "󰇄"; rowLabel: "Shadows"; rowChecked: settings.shadowEnabled
                                onToggled: val => {
                                    settings.shadowEnabled = val
                                    root.applyKeyword("decoration:shadow:enabled", val ? "true" : "false")
                                }
                            }
                            SettingNumRow {
                                subRow: true; rowLabel: "Range"; rowEnabled: settings.shadowEnabled
                                nText: settings.shadowRange.toString()
                                onCommitted: raw => {
                                    const v = Math.max(1, Math.min(30, parseInt(raw) || settings.shadowRange))
                                    settings.shadowRange = v
                                    root.applyKeyword("decoration:shadow:range", v.toString())
                                }
                            }

                            SettingNumRow {
                                rowIcon: "󰘓"; rowLabel: "Active opacity"
                                nText: root.pctFromFloat(settings.activeOpacity).toString()
                                nUnit: "%"
                                onCommitted: raw => {
                                    const p = Math.max(0, Math.min(100, parseInt(raw) || root.pctFromFloat(settings.activeOpacity)))
                                    settings.activeOpacity = root.floatFromPct(p)
                                    root.applyKeyword("decoration:active_opacity", settings.activeOpacity.toFixed(2))
                                }
                            }
                            SettingNumRow {
                                rowIcon: "󰘓"; rowLabel: "Inactive opacity"
                                Layout.bottomMargin: ccSettingSectionGap
                                nText: root.pctFromFloat(settings.inactiveOpacity).toString()
                                nUnit: "%"
                                onCommitted: raw => {
                                    const p = Math.max(0, Math.min(100, parseInt(raw) || root.pctFromFloat(settings.inactiveOpacity)))
                                    settings.inactiveOpacity = root.floatFromPct(p)
                                    root.applyKeyword("decoration:inactive_opacity", settings.inactiveOpacity.toFixed(2))
                                }
                            }
                        }

                        // ════════════════════════════════
                        // WINDOWS section
                        // ════════════════════════════════
                        SettingSectionPane {
                            id: windowsPane
                            sectionId: "windows"

                            Item { Layout.preferredHeight: 14 }

                            SettingToggleRow {
                                rowIcon: "󰋊"; rowLabel: "Window borders"
                                rowChecked: settings.borderEnabled
                                onToggled: val => {
                                    settings.borderEnabled = val
                                    root.applyBorderSize()
                                }
                            }
                            SettingNumRow {
                                subRow: true
                                rowLabel: "Border size"
                                rowEnabled: settings.borderEnabled
                                nText: settings.borderSize.toString()
                                Layout.bottomMargin: ccSettingSectionGap
                                onCommitted: raw => {
                                    if (!settings.borderEnabled)
                                        return
                                    const v = Math.max(1, Math.min(20, parseInt(raw) || settings.borderSize))
                                    settings.borderSize = v
                                    root.applyBorderSize()
                                }
                            }
                        }

                        // ════════════════════════════════
                        // ANIMATIONS section
                        // ════════════════════════════════
                        SettingSectionPane {
                            id: animPane
                            sectionId: "animations"

                            Item { Layout.preferredHeight: 14 }

                            // Toggle
                            RowLayout {
                                Layout.fillWidth: true; spacing: 10; Layout.bottomMargin: 4
                                Layout.leftMargin: 14; Layout.rightMargin: 20
                                Text { font.family: Theme.iconFontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textAccent; text: "󰄜" }
                                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textPrimary; text: "Animations" }
                                SettingToggle {
                                    Layout.preferredWidth: 38
                                    Layout.maximumWidth: 38
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    checked: settings.animEnabled
                                    onToggled: val => {
                                        settings.animEnabled = val
                                        root.applyKeyword("animations:enabled", val ? "true" : "false")
                                    }
                                }
                            }

                            // Speed ── custom MouseArea slider (avoids Flickable conflict)
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8; Layout.bottomMargin: 16
                                Layout.leftMargin: 14; Layout.rightMargin: 20
                                opacity: settings.animEnabled ? 1 : 0.35
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Text { font.family: Theme.iconFontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textAccent; text: "󰦖" }
                                Text {
                                    Layout.preferredWidth: 52
                                    font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textPrimary
                                    text: "Speed"
                                }

                                // Track + handle — smooth continuous drag, snap-animation on release
                                Item {
                                    id: speedTrack
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: 220
                                    height: 24
                                    property int  speed: settings.animSpeed          // 1-5 integer, live label
                                    property real fillW: 0                           // track fill width, set imperatively

                                    function syncFromSettings() {
                                        if (width <= speedHandle.width) return
                                        const sp = settings.animSpeed
                                        speed = sp
                                        const frac = (sp - 1) / 4
                                        speedHandle.x = frac * (width - speedHandle.width)
                                        fillW = frac * width
                                    }

                                    Component.onCompleted: syncFromSettings()
                                    onWidthChanged: syncFromSettings()
                                    Connections {
                                        target: settings
                                        function onAnimSpeedChanged() {
                                            if (!speedDrag.pressed) speedTrack.syncFromSettings()
                                        }
                                    }
                                    Connections {
                                        target: root
                                        function onSelectedSectionChanged() {
                                            if (root.selectedSection === "animations")
                                                Qt.callLater(speedTrack.syncFromSettings)
                                        }
                                    }

                                    // Track background
                                    Rectangle {
                                        y: (parent.height - height) / 2
                                        width: parent.width; height: 4; radius: 2
                                        color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.12)
                                    }
                                    // Track fill (width updated imperatively → no binding conflict)
                                    Rectangle {
                                        id: speedFill
                                        y: (parent.height - height) / 2
                                        width: speedTrack.fillW; height: 4; radius: 2
                                        color: Theme.textAccent
                                        Behavior on width { enabled: !speedDrag.pressed; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    }
                                    // Tick marks
                                    Repeater {
                                        model: 5
                                        delegate: Rectangle {
                                            required property int index
                                            y: (speedTrack.height - height) / 2
                                            x: index / 4 * (speedTrack.width - width)
                                            width: 4; height: 4; radius: 2
                                            color: index < speedTrack.speed
                                                ? Qt.rgba(1,1,1,0.4)
                                                : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.22)
                                        }
                                    }
                                    // Handle — Behavior disabled during drag, enabled for snap on release
                                    Rectangle {
                                        id: speedHandle
                                        y: (parent.height - height) / 2
                                        width: 18; height: 18; radius: 9
                                        color: Theme.textAccent
                                        scale: speedDrag.pressed ? 1.18 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        Behavior on x { enabled: !speedDrag.pressed; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    }
                                    MouseArea {
                                        id: speedDrag
                                        anchors.fill: parent

                                        function moveAt(mx) {
                                            const frac = Math.max(0, Math.min(1, mx / speedTrack.width))
                                            // Update handle & fill immediately (no animation during drag)
                                            speedHandle.x    = frac * (speedTrack.width - speedHandle.width)
                                            speedTrack.fillW = frac * speedTrack.width
                                            // Update integer speed for label
                                            speedTrack.speed = Math.max(1, Math.min(5, Math.round(frac * 4) + 1))
                                            settings.animSpeed = speedTrack.speed
                                        }

                                        onPressed:         (e) => moveAt(e.x)
                                        onPositionChanged: (e) => { if (pressed) moveAt(e.x) }
                                        onReleased: {
                                            // Snap handle + fill to nearest integer position (Behavior fires now)
                                            const snapFrac = (speedTrack.speed - 1) / 4
                                            speedHandle.x    = snapFrac * (speedTrack.width - speedHandle.width)
                                            speedTrack.fillW = snapFrac * speedTrack.width
                                            root.applyAnimSpeed(speedTrack.speed)
                                        }
                                    }
                                }

                                Text {
                                    Layout.leftMargin: 4
                                    font.family: Theme.fontFamily; font.pixelSize: 11; color: Theme.textMuted
                                    text: (["", "Slow", "Slow", "Normal", "Fast", "Fast"])[speedTrack.speed]
                                    Layout.preferredWidth: 44; horizontalAlignment: Text.AlignLeft
                                }
                                Item { Layout.fillWidth: true; height: 1 }
                            }
                        }

                        // ════════════════════════════════
                        // INPUT section
                        // ════════════════════════════════
                        SettingSectionPane {
                            id: inputPane
                            sectionId: "input"

                            Item { Layout.preferredHeight: 14 }

                            // ── Keyboard layouts ──────────────────────────────
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.bottomMargin: 12
                                Layout.leftMargin: 14; Layout.rightMargin: 14
                                spacing: 8

                                // Header
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { font.family: Theme.iconFontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textAccent; text: "󰌌" }
                                    Text { font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textPrimary; text: "Keyboard layouts" }
                                    Item { Layout.fillWidth: true }
                                }

                                // Chips row (RowLayout, not Flow — no sizing surprises)
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 6
                                    Repeater {
                                        model: root.kbLayouts()
                                        delegate: Rectangle {
                                            required property string modelData
                                            required property int    index
                                            height: 28; radius: 7
                                            width: chipLbl.implicitWidth + 28
                                            color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.13)
                                            border.width: 1
                                            border.color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.38)
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: 5
                                                Text { id: chipLbl
                                                    font.family: Theme.fontFamily; font.pixelSize: 12
                                                    font.weight: Font.Medium; color: Theme.textPrimary
                                                    text: modelData }
                                                Text { font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize
                                                    color: Theme.textMuted; text: "×"
                                                    visible: root.kbLayouts().length > 1 }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                enabled: root.kbLayouts().length > 1
                                                onClicked: root.kbRemoveLayout(index)
                                            }
                                        }
                                    }
                                    // "+ New" button
                                    Rectangle {
                                        height: 28; width: 60; radius: 7
                                        color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.10)
                                        border.width: 1
                                        border.color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.28)
                                        RowLayout {
                                            anchors.centerIn: parent; spacing: 4
                                            Text { font.family: Theme.iconFontFamily; font.pixelSize: 10; color: Theme.textAccent; text: "" }
                                            Text { font.family: Theme.fontFamily; font.pixelSize: 11; color: Theme.textAccent; text: "New" }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.newLayoutDraft = ""
                                                root.showAddLayoutInput = true
                                                // focus is set via onVisibleChanged on the input row
                                            }
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                // Add layout input row
                                Rectangle {
                                    Layout.fillWidth: true; height: 36; radius: 8
                                    visible: root.showAddLayoutInput
                                    onVisibleChanged: if (visible) addLayoutInput.forceActiveFocus()
                                    color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.06)
                                    border.width: 1.5
                                    border.color: addLayoutInput.activeFocus
                                        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.55)
                                        : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.18)
                                    Behavior on border.color { ColorAnimation { duration: 120 } }
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                                        spacing: 8
                                        Item {
                                            Layout.fillWidth: true; implicitHeight: 36
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: addLayoutInput.text.length === 0
                                                font.family: Theme.fontFamily; font.pixelSize: 13
                                                color: Theme.textMuted; text: "Layout code, e.g. ru"
                                            }
                                            TextInput {
                                                id: addLayoutInput
                                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                                font.family: Theme.fontFamily; font.pixelSize: 13
                                                color: Theme.textPrimary; clip: true
                                                text: root.newLayoutDraft
                                                onTextChanged: root.newLayoutDraft = text
                                                Keys.onReturnPressed: root.kbAddLayout(text)
                                                Keys.onEscapePressed: { root.showAddLayoutInput = false; root.newLayoutDraft = "" }
                                            }
                                        }
                                        // Confirm
                                        Rectangle {
                                            width: 28; height: 28; radius: 6
                                            color: confirmMa.containsMouse
                                                ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.20)
                                                : Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.10)
                                            Text { anchors.centerIn: parent; font.family: Theme.iconFontFamily
                                                font.pixelSize: 13; color: Theme.textAccent; text: "" }
                                            MouseArea { id: confirmMa; anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.kbAddLayout(addLayoutInput.text) }
                                        }
                                        // Cancel
                                        Rectangle {
                                            width: 28; height: 28; radius: 6
                                            color: cancelMa.containsMouse
                                                ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.10)
                                                : "transparent"
                                            Text { anchors.centerIn: parent; font.family: Theme.iconFontFamily
                                                font.pixelSize: ccNavFontSize; color: Theme.textMuted; text: "" }
                                            MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { root.showAddLayoutInput = false; root.newLayoutDraft = "" } }
                                        }
                                    }
                                }

                                // Switch keybind ── key-capture recorder
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { font.family: Theme.iconFontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textMuted; text: "󰌗" }
                                    Text { font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textMuted; text: "Switch bind" }
                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        id: bindBox
                                        width: 160; height: 30; radius: 7
                                        color: root.capturingBind
                                            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.14)
                                            : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.06)
                                        border.width: 1.5
                                        border.color: root.capturingBind
                                            ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.65)
                                            : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.15)
                                        Behavior on color        { ColorAnimation { duration: 120 } }
                                        Behavior on border.color { ColorAnimation { duration: 120 } }

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                                            spacing: 6
                                            Text {
                                                Layout.fillWidth: true
                                                font.family: Theme.fontFamily; font.pixelSize: 11
                                                elide: Text.ElideRight
                                                color: {
                                                    if (root.capturingBind) return Theme.textAccent
                                                    if (settings.kbSwitchBind !== "") return Theme.textPrimary
                                                    return Theme.textMuted
                                                }
                                                text: {
                                                    if (root.capturingBind) return "Press key combo…"
                                                    if (settings.kbSwitchBind !== "") return settings.kbSwitchBind
                                                    return "Click to record"
                                                }
                                            }
                                            Text {
                                                visible: settings.kbSwitchBind !== "" && !root.capturingBind
                                                font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; text: "×"
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.setKbSwitchBind("") }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.capturingBind = true
                                                bindKeyCatcher.forceActiveFocus()
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Sensitivity ───────────────────────────────────
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8; Layout.bottomMargin: 10
                                Layout.leftMargin: 14; Layout.rightMargin: 14
                                Text { font.family: Theme.iconFontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textAccent; text: "󰍽" }
                                Text { font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textPrimary; text: "Sensitivity" }
                                Item { Layout.fillWidth: true }
                                NumInput {
                                    nText: settings.sensitivity.toFixed(2)
                                    onCommitted: raw => {
                                        const v = Math.max(-1, Math.min(1, parseFloat(raw)))
                                        if (!isNaN(v)) {
                                            settings.sensitivity = Math.round(v * 20) / 20
                                            root.applyKeyword("input:sensitivity", settings.sensitivity.toFixed(2))
                                        }
                                    }
                                }
                            }

                            // ── Natural scroll ────────────────────────────────
                            RowLayout {
                                Layout.fillWidth: true; spacing: 10; Layout.bottomMargin: 14
                                Layout.leftMargin: 14; Layout.rightMargin: 20
                                Text { font.family: Theme.iconFontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textAccent; text: "󱕸" }
                                Text { Layout.fillWidth: true; Layout.minimumWidth: 0; font.family: Theme.fontFamily; font.pixelSize: ccSettingSubFontSize; color: Theme.textPrimary; text: "Natural scroll" }
                                SettingToggle {
                                    Layout.preferredWidth: 38
                                    Layout.maximumWidth: 38
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    checked: settings.naturalScroll
                                    onToggled: val => {
                                        settings.naturalScroll = val
                                        root.applyKeyword("input:touchpad:natural_scroll", val ? "true" : "false")
                                    }
                                }
                            }
                        }

                        // ════════════════════════════════
                        // NOTIFICATIONS section
                        // ════════════════════════════════
                        SettingSectionPane {
                            id: notificationsPane
                            sectionId: "notifications"

                            Connections {
                                target: root
                                function onSelectedSectionChanged() {
                                    if (root.selectedSection === "notifications")
                                        NotificationState.refreshCustomSounds()
                                }
                            }

                            Item { Layout.preferredHeight: 14 }

                            SettingToggleRow {
                                rowIcon: "󰕾"; rowLabel: "Notification sounds"
                                rowChecked: NotificationState.soundEnabled
                                onToggled: NotificationState.setSoundEnabled(val)
                            }

                            SettingSoundPickerRow {
                                rowLabel: "Default sound"
                                rowEnabled: NotificationState.soundEnabled
                                pickerModel: NotificationState.soundEventChoices
                                pickerValue: NotificationState.soundEvent
                                onPicked: NotificationState.setSoundEvent(value)
                            }

                            SettingSoundPickerRow {
                                rowLabel: "Urgent alerts"
                                rowHint: "For critical-priority notifications"
                                rowEnabled: NotificationState.soundEnabled
                                pickerModel: NotificationState.soundEventChoices
                                pickerValue: NotificationState.criticalSoundEvent
                                onPicked: NotificationState.setCriticalSoundEvent(value)
                            }

                            SettingToggleRow {
                                rowIcon: "󰂛"; rowLabel: "Do not disturb"
                                rowChecked: NotificationState.doNotDisturb
                                onToggled: NotificationState.setDoNotDisturb(val)
                            }

                            SettingToggleRow {
                                rowIcon: "󰂚"; rowLabel: "Collect while DND"
                                rowEnabled: NotificationState.doNotDisturb
                                rowChecked: NotificationState.dndCollectHistory
                                onToggled: NotificationState.setDndCollectHistory(val)
                            }

                            SettingToggleRow {
                                rowIcon: "󰌾"; rowLabel: "Show on lock screen"
                                rowChecked: NotificationState.showOnLockScreen
                                onToggled: NotificationState.setShowOnLockScreen(val)
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 14
                                Layout.rightMargin: 20
                                Layout.bottomMargin: ccSettingRowGap
                                spacing: 10

                                Text {
                                    font.family: Theme.iconFontFamily
                                    font.pixelSize: ccSectionHeaderSize
                                    color: Theme.textAccent
                                    text: "󰔟"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    font.family: Theme.fontFamily
                                    font.pixelSize: ccSettingFontSize
                                    font.weight: Font.Medium
                                    color: Theme.textPrimary
                                    text: "Toast duration"
                                }

                                Text {
                                    font.family: Theme.fontFamily
                                    font.pixelSize: ccSettingSubFontSize
                                    color: Theme.textMuted
                                    text: Math.round(NotificationState.toastDurationMs / 1000) + "s"
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.leftMargin: 36
                                Layout.rightMargin: 20
                                Layout.bottomMargin: ccSettingRowGap
                                height: 24

                                readonly property int minSec: NotificationState.toastDurationMinMs / 1000
                                readonly property int maxSec: NotificationState.toastDurationMaxMs / 1000
                                readonly property real frac:
                                    (NotificationState.toastDurationMs / 1000 - minSec)
                                    / Math.max(1, maxSec - minSec)

                                Rectangle {
                                    y: (parent.height - height) / 2
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.12)
                                }

                                Rectangle {
                                    y: (parent.height - height) / 2
                                    width: parent.width * parent.frac
                                    height: 4
                                    radius: 2
                                    color: Theme.textAccent
                                    Behavior on width { NumberAnimation { duration: 80 } }
                                }

                                Rectangle {
                                    id: toastHandle
                                    y: (parent.height - height) / 2
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: Theme.textAccent
                                    x: parent.frac * (parent.width - width)
                                    scale: toastDrag.pressed ? 1.25 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    id: toastDrag
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    function valueFromX(xPos) {
                                        const span = Math.max(1, parent.width - toastHandle.width)
                                        const frac = Math.max(0, Math.min(1, xPos / span))
                                        return Math.round(parent.minSec + frac * (parent.maxSec - parent.minSec))
                                    }
                                    onPressed: pos => {
                                        NotificationState.toastDurationMs =
                                            NotificationState.clampToastDurationMs(valueFromX(pos.x) * 1000)
                                    }
                                    onPositionChanged: pos => {
                                        if (!pressed)
                                            return
                                        NotificationState.toastDurationMs =
                                            NotificationState.clampToastDurationMs(valueFromX(pos.x) * 1000)
                                    }
                                    onReleased: NotificationState.persist()
                                }
                            }

                            SettingNumRow {
                                rowIcon: "󰄪"
                                rowLabel: "History limit"
                                nText: NotificationState.maxHistory.toString()
                                onCommitted: raw => NotificationState.setMaxHistory(raw)
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: 36
                                Layout.rightMargin: 20
                                Layout.bottomMargin: ccSettingSectionGap
                                font.family: Theme.fontFamily
                                font.pixelSize: ccNavFontSize
                                color: Theme.textMuted
                                opacity: 0.72
                                wrapMode: Text.Wrap
                                text: "Custom sounds: drop .wav / .ogg / .mp3 into\n" + NotificationState.customSoundsDir
                            }
                        }

                        // ════════════════════════════════
                        // SYSTEM INFO section
                        // ════════════════════════════════
                        SettingSectionPane {
                            id: systemInfoPane
                            sectionId: "systeminfo"

                            Item { Layout.preferredHeight: 14 }

                            SystemInfoBlock {
                                blockIcon: "󰇄"
                                blockTitle: "Distribution"
                                productName: sysInfo.distroName
                                productUrl: sysInfo.distroHome
                                logoPath: sysInfo.distroLogo
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.leftMargin: 14
                                Layout.rightMargin: 14
                                Layout.bottomMargin: 22
                                implicitHeight: distroLinks.implicitHeight
                                Flow {
                                    id: distroLinks
                                    width: parent.width
                                    spacing: 8
                                    InfoLinkButton {
                                        linkIcon: "󰂽"
                                        linkLabel: "Documentation"
                                        linkUrl: sysInfo.distroDoc
                                    }
                                    InfoLinkButton {
                                        linkIcon: "󰖟"
                                        linkLabel: "Help"
                                        linkUrl: sysInfo.distroSupport
                                    }
                                    InfoLinkButton {
                                        linkIcon: "󰨰"
                                        linkLabel: "Report a bug"
                                        linkUrl: sysInfo.distroBug
                                    }
                                    InfoLinkButton {
                                        linkIcon: "󰒃"
                                        linkLabel: "Privacy policy"
                                        linkUrl: sysInfo.distroPrivacy
                                    }
                                }
                            }

                            SystemInfoBlock {
                                blockIcon: "󰉋"
                                blockTitle: "Dotfiles"
                                productName: "spectrum"
                                productUrl: root.spectrumRepoUrl
                                logoPath: root.spectrumLogoPath
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.leftMargin: 14
                                Layout.rightMargin: 14
                                Layout.bottomMargin: 22
                                implicitHeight: dotfileLinks.implicitHeight
                                Flow {
                                    id: dotfileLinks
                                    width: parent.width
                                    spacing: 8
                                    InfoLinkButton {
                                        linkIcon: "󰂽"
                                        linkLabel: "Documentation"
                                        linkUrl: root.spectrumRepoUrl
                                    }
                                    InfoLinkButton {
                                        linkIcon: "󰨰"
                                        linkLabel: "Issues"
                                        linkUrl: root.spectrumRepoUrl + "/issues"
                                    }
                                    InfoLinkButton {
                                        linkIcon: "󰍡"
                                        linkLabel: "Discussions"
                                        linkUrl: root.spectrumRepoUrl + "/discussions"
                                    }
                                    InfoLinkButton {
                                        linkIcon: "󰂺"
                                        linkLabel: "Support"
                                        linkUrl: root.spectrumRepoUrl
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                Layout.topMargin: 4
                                Layout.rightMargin: 18
                                Layout.bottomMargin: 12
                                Text {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    font.family: Theme.fontFamily
                                    font.pixelSize: ccNavFontSize
                                    color: Theme.textMuted
                                    opacity: 0.5
                                    text: "made by zxqurate"
                                }
                            }
                        }

                        Item { height: 4; width: 1 }
                    }
                }
            }
        }
    }  // end card

    // ── System info data ──────────────────────────────────────────────────────
    QtObject {
        id: sysInfo
        property string osName:  "..."
        property string cpuName: "..."
        property string gpuName: "..."
        property string ramInfo: "..."
        property string distroId:      "linux"
        property string distroName:    "Linux"
        property string distroHome:    ""
        property string distroDoc:     ""
        property string distroSupport: ""
        property string distroBug:     ""
        property string distroPrivacy: ""
        property string distroLogo:    "tux"
    }

    Process {
        id: openUrlProc
        property string targetUrl: ""
        command: ["xdg-open", targetUrl]
        running: false
    }

    Process {
        id: powerActionProc
        property string actionId: ""
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/power-action.sh", actionId]
        running: false
    }

    Process {
        id: distroInfoProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/read-distro-info.sh"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (!line || line.indexOf("=") < 0)
                    return
                const eq = line.indexOf("=")
                const key = line.slice(0, eq)
                const val = line.slice(eq + 1)
                if (key === "distro_id")      sysInfo.distroId = val
                else if (key === "distro_name")    sysInfo.distroName = val
                else if (key === "distro_home")    sysInfo.distroHome = val
                else if (key === "distro_doc")     sysInfo.distroDoc = val
                else if (key === "distro_support") sysInfo.distroSupport = val
                else if (key === "distro_bug")     sysInfo.distroBug = val
                else if (key === "distro_privacy") sysInfo.distroPrivacy = val
                else if (key === "distro_logo")    sysInfo.distroLogo = val
                if (sysInfo.osName === "..." || sysInfo.osName === "")
                    sysInfo.osName = sysInfo.distroName
            }
        }
    }

    Process {
        id: cpuProc
        command: ["bash", "-c", "grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs"]
        running: false
        stdout: SplitParser { onRead: data => { if (data.trim()) sysInfo.cpuName = data.trim() } }
    }
    Process {
        id: gpuProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/read-gpu-info.sh"]
        running: false
        stdout: SplitParser { onRead: data => { if (data.trim()) sysInfo.gpuName = data.trim() } }
    }
    Process {
        id: ramProc
        command: ["bash", "-c", "free -b | awk '/Mem:/ {printf \"%.1f / %.0f GB\", $3/1e9, $2/1e9}'"]
        running: false
        stdout: SplitParser { onRead: data => { if (data.trim()) sysInfo.ramInfo = data.trim() } }
    }

    // ── Avatar file picker ────────────────────────────────────────────────────
    Process {
        id: avatarPickerProc
        command: ["zenity", "--file-selection", "--title=Выберите аватар",
            "--file-filter=Изображения (jpg png webp gif) | *.jpg *.jpeg *.JPG *.png *.PNG *.webp *.gif"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._pickedAvatarPath = text.trim()
        }
        onRunningChanged: {
            if (!running)
                Qt.callLater(() => root.finishAvatarPicker(root._pickedAvatarPath))
        }
    }
    Process {
        id: avatarCopyProc
        property string srcPath: ""
        command: ["bash", "-c", "cp -- \"$SRC\" \"$HOME/.face\" && chmod 644 \"$HOME/.face\""]
        environment: ({ "SRC": srcPath })
        running: false
        onExited: (code) => {
            if (code === 0) {
                avatarImg.source = ""; avatarImg.source = root.avatarPath
                avatarHint.text = "Аватар обновлён!"
            } else {
                avatarHint.text = "Ошибка — не удалось скопировать файл"
            }
            avatarHint.opacity = 1.0; hintTimer.restart()
        }
    }

    // ── Settings: live apply ──────────────────────────────────────────────────
    Process {
        id: kwProc
        property string kwKey: ""
        property string kwVal: ""
        command: ["hyprctl", "keyword", kwKey, kwVal]
        running: false
    }

    Process {
        id: animSpeedProc
        property string batchCmd: ""
        command: ["hyprctl", "--batch", batchCmd]
        running: false
    }

    // ── Settings: read current Hyprland values on panel open ──────────────────
    Process {
        id: readSettingsProc
        command: ["bash", "-c", [
            "CONF=\"$HOME/.config/hypr/appearance.conf\"",
            "be=$(awk '/blur \\{/,/\\}/ { if ($1==\"enabled\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "bs=$(awk '/blur \\{/,/\\}/ { if ($1==\"size\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "bp=$(awk '/blur \\{/,/\\}/ { if ($1==\"passes\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "bx=$(awk '/blur \\{/,/\\}/ { if ($1==\"xray\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "bno=$(awk '/blur \\{/,/\\}/ { if ($1==\"new_optimizations\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "bio=$(awk '/blur \\{/,/\\}/ { if ($1==\"ignore_opacity\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "bb=$(awk '/blur \\{/,/\\}/ { if ($1==\"brightness\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "bc=$(awk '/blur \\{/,/\\}/ { if ($1==\"contrast\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "bv=$(awk '/blur \\{/,/\\}/ { if ($1==\"vibrancy\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "bvd=$(awk '/blur \\{/,/\\}/ { if ($1==\"vibrancy_darkness\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "se=$(awk '/shadow \\{/,/\\}/ { if ($1==\"enabled\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "sr=$(awk '/shadow \\{/,/\\}/ { if ($1==\"range\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "ro=$(awk '/^[[:space:]]*rounding[[:space:]]*=/{print $3; exit}' \"$CONF\" 2>/dev/null | tr -d ',')",
            "ao=$(awk '/^[[:space:]]*active_opacity[[:space:]]*=/{print $3; exit}' \"$CONF\" 2>/dev/null | tr -d ',')",
            "io=$(awk '/^[[:space:]]*inactive_opacity[[:space:]]*=/{print $3; exit}' \"$CONF\" 2>/dev/null | tr -d ',')",
            "ae=$(awk '/^animations \\{/,/\\}/ { if ($1==\"enabled\") { print $3; exit } }' \"$CONF\" 2>/dev/null | tr -d ',')",
            "aw=$(awk -F',' '/animation = windows/{gsub(/ /,\"\",$3); print $3; exit}' \"$CONF\" 2>/dev/null)",
            "[ -z \"$be\" ] && be=$(hyprctl getoption decoration:blur:enabled 2>/dev/null | awk '/int:/{print $2}')",
            "[ -z \"$bs\" ] && bs=$(hyprctl getoption decoration:blur:size    2>/dev/null | awk '/int:/{print $2}')",
            "[ -z \"$bp\" ] && bp=$(hyprctl getoption decoration:blur:passes  2>/dev/null | awk '/int:/{print $2}')",
            "[ -z \"$bx\" ] && bx=$(hyprctl getoption decoration:blur:xray  2>/dev/null | awk '/int:/{print $2}')",
            "[ -z \"$bno\" ] && bno=$(hyprctl getoption decoration:blur:new_optimizations 2>/dev/null | awk '/int:/{print $2}')",
            "[ -z \"$bio\" ] && bio=$(hyprctl getoption decoration:blur:ignore_opacity 2>/dev/null | awk '/int:/{print $2}')",
            "[ -z \"$bb\" ] && bb=$(hyprctl getoption decoration:blur:brightness 2>/dev/null | awk '/float:/{printf \"%.2f\",$2}')",
            "[ -z \"$bc\" ] && bc=$(hyprctl getoption decoration:blur:contrast 2>/dev/null | awk '/float:/{printf \"%.2f\",$2}')",
            "[ -z \"$bv\" ] && bv=$(hyprctl getoption decoration:blur:vibrancy 2>/dev/null | awk '/float:/{printf \"%.2f\",$2}')",
            "[ -z \"$bvd\" ] && bvd=$(hyprctl getoption decoration:blur:vibrancy_darkness 2>/dev/null | awk '/float:/{printf \"%.2f\",$2}')",
            "[ -z \"$se\" ] && se=$(hyprctl getoption decoration:shadow:enabled 2>/dev/null | awk '/int:/{print $2}')",
            "[ -z \"$sr\" ] && sr=$(hyprctl getoption decoration:shadow:range   2>/dev/null | awk '/int:/{print $2}')",
            "[ -z \"$ro\" ] && ro=$(hyprctl getoption decoration:rounding        2>/dev/null | awk '/int:/{print $2}')",
            "[ -z \"$ao\" ] && ao=$(hyprctl getoption decoration:active_opacity  2>/dev/null | awk '/float:/{printf \"%.2f\",$2}')",
            "[ -z \"$io\" ] && io=$(hyprctl getoption decoration:inactive_opacity 2>/dev/null | awk '/float:/{printf \"%.2f\",$2}')",
            "[ -z \"$ae\" ] && ae=$(hyprctl getoption animations:enabled     2>/dev/null | awk '/int:/{print $2}')",
            "[ -z \"$aw\" ] && aw=$(hyprctl getoption animation:windows      2>/dev/null | sed -n 's/.*custom: [0-9]*, \\([0-9]*\\).*/\\1/p')",
            "bsz=$(hyprctl getoption general:border_size       2>/dev/null | awk '/int:/{print $2}')",
            "kl=$(hyprctl getoption input:kb_layout        2>/dev/null | awk '/str:/{print $2}')",
            "sv=$(hyprctl getoption input:sensitivity      2>/dev/null | awk '/float:/{printf \"%.2f\",$2}')",
            "ns=$(hyprctl getoption input:touchpad:natural_scroll 2>/dev/null | awk '/int:/{print $2}')",
            "kb=$(grep -m1 'switchxkblayout all next' \"$HOME/.config/hypr/keybinds.conf\" 2>/dev/null | sed 's/^bind = //; s/, exec,.*//')",
            "[ -z \"$kb\" ] && kb=$(grep -m1 'switchxkblayout all next' \"$HOME/.config/hypr/settings-panel.conf\" 2>/dev/null | sed 's/^bind = //; s/, exec,.*//')",
            "[ -z \"$kb\" ] && kb=$(grep -m1 'switchxkblayout all next' \"$HOME/.config/hypr/appearance.conf\" 2>/dev/null | sed 's/^bind = //; s/, exec,.*//')",
            "printf 'blur_enabled=%s\\nblur_size=%s\\nblur_passes=%s\\n' \"$be\" \"$bs\" \"$bp\"",
            "printf 'blur_xray=%s\\nblur_new_opt=%s\\nblur_ignore_opacity=%s\\n' \"$bx\" \"$bno\" \"$bio\"",
            "printf 'blur_brightness=%s\\nblur_contrast=%s\\nblur_vibrancy=%s\\nblur_vibrancy_darkness=%s\\n' \"$bb\" \"$bc\" \"$bv\" \"$bvd\"",
            "printf 'shadow_enabled=%s\\nshadow_range=%s\\nrounding=%s\\n' \"$se\" \"$sr\" \"$ro\"",
            "printf 'border_size=%s\\n' \"$bsz\"",
            "printf 'active_opacity=%s\\ninactive_opacity=%s\\nanim_enabled=%s\\n' \"$ao\" \"$io\" \"$ae\"",
            "printf 'anim_windows=%s\\n' \"$aw\"",
            "printf 'kb_layout=%s\\nsensitivity=%s\\nnatural_scroll=%s\\n' \"$kl\" \"$sv\" \"$ns\"",
            "printf 'kb_switch_bind=%s\\n' \"$kb\"",
            "qsb=$(grep -m1 '^# quickshell-system-blur=' \"$HOME/.config/hypr/appearance.conf\" 2>/dev/null | sed 's/^# quickshell-system-blur=//')",
            "qbs=$(grep -m1 '^# quickshell-border-size=' \"$HOME/.config/hypr/appearance.conf\" 2>/dev/null | sed 's/^# quickshell-border-size=//')",
            "qpo=$(grep -m1 '^# quickshell-panel-opacity=' \"$HOME/.config/hypr/appearance.conf\" 2>/dev/null | sed 's/^# quickshell-panel-opacity=//')",
            "qpc=$(grep -m1 '^# quickshell-panel-card-opacity=' \"$HOME/.config/hypr/appearance.conf\" 2>/dev/null | sed 's/^# quickshell-panel-card-opacity=//')",
            "printf 'system_blur=%s\\nborder_saved=%s\\npanel_opacity=%s\\npanel_card_opacity=%s\\n' \"$qsb\" \"$qbs\" \"$qpo\" \"$qpc\""
        ].join("; ")]
        running: false
        onExited: {
            if (root.appearanceDirty)
                AppearanceState.applyFromSettings(root.settings.systemBlurEnabled, undefined, undefined)
            else
                root.applyAppearancePrefsFromSettings(true)
            root.settingsHydrated = true
            if (root.appearanceDirty) {
                root.appearanceDirty = false
                root.persistAppearanceConf(false)
            }
        }
        stdout: SplitParser {
            onRead: data => {
                if (root.appearanceDirty)
                    return
                const line = data.trim()
                if (!line || !line.includes("=")) return
                const eq = line.indexOf("=")
                const k  = line.substring(0, eq)
                const v  = line.substring(eq + 1).trim()
                if (k === "kb_switch_bind") {
                    settings.kbSwitchBind = v
                    return
                }
                if (v === "" || v === "null") return
                switch (k) {
                    case "blur_enabled":     settings.blurEnabled     = root.confBool(v); break
                    case "blur_size":        { const n = parseInt(v);   if (!isNaN(n)) settings.blurSize        = n   } break
                    case "blur_passes":      { const n = parseInt(v);   if (!isNaN(n)) settings.blurPasses      = n   } break
                    case "blur_xray":        settings.blurXray             = root.confBool(v); break
                    case "blur_new_opt":     settings.blurNewOptimizations = root.confBool(v); break
                    case "blur_ignore_opacity": settings.blurIgnoreOpacity = root.confBool(v); break
                    case "blur_brightness":  { const f = parseFloat(v); if (!isNaN(f)) settings.blurBrightness  = f } break
                    case "blur_contrast":    { const f = parseFloat(v); if (!isNaN(f)) settings.blurContrast    = f } break
                    case "blur_vibrancy":    { const f = parseFloat(v); if (!isNaN(f)) settings.blurVibrancy    = f } break
                    case "blur_vibrancy_darkness": { const f = parseFloat(v); if (!isNaN(f)) settings.blurVibrancyDarkness = f } break
                    case "shadow_enabled":   settings.shadowEnabled   = root.confBool(v); break
                    case "shadow_range":     { const n = parseInt(v);   if (!isNaN(n)) settings.shadowRange     = n   } break
                    case "rounding":         { const n = parseInt(v);   if (!isNaN(n)) settings.rounding        = n   } break
                    case "border_size": {
                        const n = parseInt(v)
                        if (!isNaN(n)) {
                            settings.borderEnabled = n > 0
                            if (n > 0)
                                settings.borderSize = n
                        }
                    } break
                    case "border_saved": {
                        const n = parseInt(v)
                        if (!isNaN(n) && n > 0 && !settings.borderEnabled)
                            settings.borderSize = n
                    } break
                    case "active_opacity":   { const f = parseFloat(v); if (!isNaN(f)) settings.activeOpacity   = f   } break
                    case "inactive_opacity": { const f = parseFloat(v); if (!isNaN(f)) settings.inactiveOpacity = f   } break
                    case "anim_enabled":     settings.animEnabled     = root.confBool(v); break
                    case "anim_windows":     settings.animSpeed = root.animDurationToSpeed(v); break
                    case "kb_layout":        if (v) settings.kbLayout  = v; break
                    case "sensitivity":      { const f = parseFloat(v); if (!isNaN(f)) settings.sensitivity     = f   } break
                    case "natural_scroll":   settings.naturalScroll   = root.confBool(v); break
                    case "system_blur":
                        settings.systemBlurEnabled = root.confBool(v)
                        break
                    case "panel_opacity": {
                        const f = parseFloat(v)
                        if (!isNaN(f))
                            root._readPanelOpacity = f
                    } break
                    case "panel_card_opacity": {
                        const f = parseFloat(v)
                        if (!isNaN(f))
                            root._readPanelCardOpacity = f
                    } break
                }
            }
        }
    }

    Process {
        id: kbSwitchBindProc
        property string batchCmd: ""
        command: ["hyprctl", "--batch", batchCmd]
        running: false
    }

    Process {
        id: saveKbSwitchBindProc
        property string bindLine: ""
        command: ["bash", "-c",
            "FILE=\"" + Quickshell.env("HOME") + "/.config/hypr/keybinds.conf\"; " +
            "BEGIN='# BEGIN QUICKSHELL SETTINGS PANEL'; " +
            "END='# END QUICKSHELL SETTINGS PANEL'; " +
            "TMP=$(mktemp); " +
            "awk -v b=\"$BEGIN\" -v e=\"$END\" '$0==b{skip=1;next}$0==e{skip=0;next}!skip{print}' \"$FILE\" > \"$TMP\"; " +
            "if [ -n \"$BIND\" ]; then printf '\\n%s\\n%s\\n%s\\n' \"$BEGIN\" \"$BIND\" \"$END\" >> \"$TMP\"; fi; " +
            "mv \"$TMP\" \"$FILE\""]
        environment: ({ "BIND": bindLine })
        running: false
    }

    // ── Settings: persist to appearance.conf ──────────────────────────────────
    Process {
        id: saveAppearanceProc
        property string _content: ""
        command: ["bash", "-c", "printf '%s' \"$CONF\" > \"$DEST\""]
        environment: ({ "CONF": _content, "DEST": root.appearanceConfPath })
        running: false
    }

    // ── Wallpaper path ───────────────────────────────────────────────────────
    Process {
        id: readWallpaperPathProc
        command: ["bash", "-c", "cat \"$HOME/.local/state/quickshell/current_wallpaper\" 2>/dev/null || true"]
        running: false
        stdout: SplitParser { onRead: data => { const p = data.trim(); if (p) AppState.currentWallpaperPath = p } }
    }

    // ── RAM poll ──────────────────────────────────────────────────────────────
    Timer {
        interval: 500
        running: AppState.controlCenterVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!ramProc.running) ramProc.running = true }
    }

    Component.onCompleted: {
        cpuProc.running             = true
        gpuProc.running             = true
        ramProc.running             = true
        distroInfoProc.running      = true
    }
}
