import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../theme"

Rectangle {
    id: root

    required property var notification
    property bool compact: false
    property bool showActions: true
    property bool interactive: true
    property bool showTimestamp: false
    property string timestampText: ""
    property bool hoverLift: true

    signal dismissClicked()
    signal actionClicked(string identifier)

    Layout.fillWidth: true
    implicitHeight: contentCol.implicitHeight + (compact ? 24 : 32)
    radius: compact ? 14 : 16
    clip: true
    color: cardHover.hovered
        ? Qt.rgba(
            Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b,
            Theme.useGlassPanels ? 0.12 : 0.08)
        : Theme.panelBgCard
    border.color: cardHover.hovered
        ? Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.34)
        : Theme.panelBorder
    border.width: Theme.useGlassPanels || cardHover.hovered ? 1 : 0

    HoverHandler {
        id: cardHover
        enabled: root.hoverLift && root.interactive
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.sideTileHoverMs
            easing.type: Easing.OutCubic
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.sideTileHoverMs
            easing.type: Easing.OutCubic
        }
    }

    function iconSource() {
        if (!notification)
            return ""
        return normalizeIcon(notification.image)
            || normalizeIcon(notification.appIcon)
            || ""
    }

    function normalizeIcon(raw) {
        if (!raw || typeof raw !== "string")
            return ""
        const s = raw.trim()
        if (!s)
            return ""
        if (s.startsWith("file://"))
            return s
        if (s.startsWith("/"))
            return "file://" + s
        if (s.startsWith("http://") || s.startsWith("https://"))
            return s
        return s
    }

    readonly property bool hasIcon: iconSource() !== "" && !iconFailed
    property bool iconFailed: false

    onNotificationChanged: iconFailed = false

    readonly property string displayAppName: notification?.appName ?? ""
    readonly property string displaySummary: {
        if (!notification)
            return ""
        if (notification.summary)
            return notification.summary
        if (notification.body)
            return notification.body
        return displayAppName || "Notification"
    }
    readonly property string displayBody: {
        if (!notification)
            return ""
        if (notification.summary && notification.body)
            return notification.body
        return ""
    }

    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: compact ? 8 : 10
        anchors.rightMargin: compact ? 10 : 12
        z: 2
        visible: showTimestamp && timestampText !== ""
        font.family: Theme.fontFamily
        font.pixelSize: compact ? 10 : 11
        font.weight: Font.Medium
        color: Theme.textMuted
        opacity: 0.82
        text: timestampText
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.topMargin: (compact ? 10 : 14) - (cardHover.hovered ? 2 : 0)
        anchors.bottomMargin: (compact ? 10 : 14) + (cardHover.hovered ? 2 : 0)
        anchors.leftMargin: compact ? 10 : 14
        anchors.rightMargin: compact ? 10 : 14
        spacing: compact ? 4 : 6

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: Theme.sideTileHoverMs
                easing.type: Easing.OutCubic
            }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: Theme.sideTileHoverMs
                easing.type: Easing.OutCubic
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                id: iconBox
                Layout.preferredWidth: compact ? 28 : 32
                Layout.preferredHeight: compact ? 28 : 32
                clip: true

                property real iconHoverScale: cardHover.hovered ? 1.12 : 1.0

                Behavior on iconHoverScale {
                    NumberAnimation {
                        duration: Theme.sideTileHoverMs
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: iconBox.width * iconBox.iconHoverScale
                    height: iconBox.height * iconBox.iconHoverScale
                    radius: compact ? 8 : 10
                    color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.06)
                    visible: !root.hasIcon
                }

                IconImage {
                    id: notifIcon
                    anchors.centerIn: parent
                    width: (compact ? 18 : 22) * iconBox.iconHoverScale
                    height: (compact ? 18 : 22) * iconBox.iconHoverScale
                    source: root.iconSource()
                    visible: root.hasIcon
                    asynchronous: true
                    onStatusChanged: {
                        if (status === Image.Error || status === Image.Null)
                            root.iconFailed = true
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.hasIcon
                    font.family: Theme.iconFontFamily
                    font.pixelSize: (compact ? 14 : 16) * iconBox.iconHoverScale
                    color: cardHover.hovered ? Theme.textAccent : Theme.textMuted
                    text: "󰂚"

                    Behavior on color {
                        ColorAnimation { duration: Theme.sideTileHoverMs }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.rightMargin: showTimestamp && timestampText !== "" ? 36 : 0
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    visible: displayAppName !== "" && displayAppName !== displaySummary
                    font.family: Theme.fontFamily
                    font.pixelSize: compact ? 11 : 12
                    font.weight: Font.Normal
                    color: Theme.textMuted
                    text: displayAppName
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    visible: displaySummary !== ""
                    font.family: Theme.fontFamily
                    font.pixelSize: compact ? 12 : 13
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    text: displaySummary
                    wrapMode: Text.WordWrap
                    maximumLineCount: compact ? 2 : 2
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: displayBody !== ""
                    font.family: Theme.fontFamily
                    font.pixelSize: compact ? 11 : 12
                    color: Theme.textMuted
                    text: displayBody
                    wrapMode: Text.WordWrap
                    maximumLineCount: compact ? 2 : 3
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }

            Text {
                visible: interactive && !compact
                font.family: Theme.iconFontFamily
                font.pixelSize: 14
                color: Theme.textMuted
                opacity: dismissMa.containsMouse ? 0.85 : 0.45
                text: "󰅖"

                MouseArea {
                    id: dismissMa
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismissClicked()
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: showActions && !compact && (notification?.actions?.length ?? 0) > 0
            spacing: 6

            Repeater {
                model: notification?.actions ?? []

                Rectangle {
                    required property var modelData
                    height: 28
                    width: actionLbl.implicitWidth + 20
                    radius: 8
                    color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.12)
                    border.color: Qt.rgba(Theme.textAccent.r, Theme.textAccent.g, Theme.textAccent.b, 0.28)
                    border.width: 1

                    Text {
                        id: actionLbl
                        anchors.centerIn: parent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textAccent
                        text: modelData?.text ?? ""
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData)
                                modelData.invoke()
                            root.actionClicked(modelData?.identifier ?? "")
                        }
                    }
                }
            }
        }
    }
}
