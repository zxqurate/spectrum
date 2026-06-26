import QtQuick
import QtQuick.Layouts
import "../state"
import "../theme"

Item {
    id: root

    required property var notification
    property bool compact: true
    property bool showActions: true
    property bool interactive: true
    property bool swipeEnabled: true
    property bool showTimestamp: true
    property bool enterFromRight: false

    signal dismissed(var notification)
    signal actionClicked(string identifier)

    Layout.fillWidth: true
    implicitHeight: collapsing ? 0 : card.implicitHeight
    clip: true

    readonly property int animMs: Theme.notificationAnimMs
    readonly property int collapseMs: Theme.notificationCollapseMs
    readonly property string timeLabel:
        NotificationState.formatReceivedTime(NotificationState.receivedAtFor(notification))

    property real dragX: 0
    property real dragOpacity: 1
    property real enterOpacity: 1
    property real enterOffset: 0
    property real exitTargetX: 0
    property bool exitStarted: false
    property bool collapsing: false
    property int _boundId: -1

    opacity: Math.min(enterOpacity, dragOpacity)

    transform: Translate {
        x: root.dragX + root.enterOffset
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: root.collapseMs
            easing.type: Easing.OutCubic
        }
    }

    Behavior on dragX {
        enabled: !swipeDrag.active
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: card
        radius: card.radius
        color: Theme.textAccent
        opacity: swipeEnabled ? Math.min(0.22, Math.abs(root.dragX) / Math.max(root.width, 1) * 0.35) : 0
        visible: Math.abs(root.dragX) > 6
    }

    NotificationCard {
        id: card
        width: parent.width
        notification: root.notification
        compact: root.compact
        showActions: root.showActions
        interactive: root.interactive
        showTimestamp: root.showTimestamp
        timestampText: root.timeLabel
        onDismissClicked: root.playExit(function(n) { root.dismissed(n) })
        onActionClicked: identifier => root.actionClicked(identifier)
    }

    DragHandler {
        id: swipeDrag
        enabled: swipeEnabled && interactive && !root.exitStarted && !NotificationState.clearingAll
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        grabPermissions: PointerHandler.TakeOverForbidden

        property real anchorX: 0

        onActiveChanged: {
            if (active)
                anchorX = root.dragX
            else
                root.releaseSwipe()
        }
        onTranslationChanged: {
            root.dragX = anchorX + translation.x
            root.dragOpacity = 1 - Math.min(0.5, Math.abs(root.dragX) / Math.max(root.width, 1))
        }
    }

    function skipEnterAnim() {
        enterOpacity = 1
        enterOffset = 0
    }

    function runEnterAnim() {
        enterOpacity = 0
        enterOffset = enterFromRight ? 22 : 0
        if (notification)
            NotificationState.markSeen(notification)
        enterAnim.start()
    }

    function releaseSwipe() {
        const threshold = root.width * 0.28
        if (Math.abs(root.dragX) > threshold) {
            const notif = root.notification
            root.playExit(function() { root.dismissed(notif) })
        } else {
            root.dragX = 0
        }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: root
            property: "enterOpacity"
            to: 1
            duration: root.animMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "enterOffset"
            to: 0
            duration: root.animMs
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation {
            target: root
            property: "dragX"
            to: root.exitTargetX
            duration: root.animMs
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root
            property: "dragOpacity"
            to: 0
            duration: root.animMs
            easing.type: Easing.InCubic
        }
    }

    Timer {
        id: exitPhaseTimer
        interval: root.animMs
        property var doneCallback: null
        property bool skipCollapse: false
        onTriggered: {
            if (!doneCallback)
                return
            if (skipCollapse) {
                const cb = doneCallback
                doneCallback = null
                cb()
                return
            }
            collapsing = true
            collapseTimer.doneCallback = doneCallback
            doneCallback = null
            collapseTimer.restart()
        }
    }

    Timer {
        id: collapseTimer
        interval: root.collapseMs + 16
        property var doneCallback: null
        onTriggered: {
            if (doneCallback)
                doneCallback()
            doneCallback = null
        }
    }

    function playExit(callback, slideRight, skipCollapse) {
        if (exitStarted)
            return
        exitStarted = true
        swipeDrag.enabled = false
        const right = slideRight === true || (slideRight !== false && dragX >= 0)
        exitTargetX = right ? Math.max(width, 1) * 1.06 : -Math.max(width, 1) * 1.06
        exitAnim.start()
        if (!callback)
            return
        exitPhaseTimer.skipCollapse = skipCollapse === true
        exitPhaseTimer.doneCallback = callback
        exitPhaseTimer.restart()
    }

    function bindNotification(n) {
        if (!n)
            return
        if (exitStarted)
            return
        if (n.id === _boundId)
            return
        _boundId = n.id
        dragX = 0
        dragOpacity = 1
        exitStarted = false
        collapsing = false
        if (NotificationState.wasSeen(n))
            skipEnterAnim()
        else
            runEnterAnim()
    }

    onNotificationChanged: bindNotification(notification)

    Component.onCompleted: bindNotification(notification)

    Connections {
        target: NotificationState
        function onClearAllStarted() {
            if (!root.notification)
                return
            root.playExit(null, true, true)
        }
    }

}
