import QtQuick
import "../state"
import "../theme"

Item {
    id: root

    implicitHeight: 18

    readonly property real frac: scrubbing
        ? scrubFrac
        : (MediaState.trackLength > 0
            ? Math.max(0, Math.min(1, MediaState.displayPosition / MediaState.trackLength))
            : 0)

    property bool scrubbing: false
    property real scrubFrac: 0

    function setScrub(x) {
        if (width <= 0 || MediaState.trackLength <= 0)
            return
        scrubFrac = Math.max(0, Math.min(1, x / width))
        MediaState.setPreviewPosition(scrubFrac * MediaState.trackLength)
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.1)
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * root.frac
        height: 4
        radius: 2
        color: Theme.textAccent
    }

    Rectangle {
        x: parent.width * root.frac - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 10
        radius: 5
        color: Theme.textAccent
        visible: MediaState.canSeek && MediaState.trackLength > 0
    }

    MouseArea {
        anchors.fill: parent
        enabled: MediaState.canSeek && MediaState.trackLength > 0
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        onPressed: e => {
            root.scrubbing = true
            MediaState.scrubLock = true
            root.setScrub(e.x)
        }
        onPositionChanged: e => {
            if (pressed)
                root.setScrub(e.x)
        }
        onReleased: e => {
            root.setScrub(e.x)
            MediaState.seekTo(root.scrubFrac)
            root.scrubbing = false
            MediaState.scrubLock = false
        }
        onCanceled: {
            root.scrubbing = false
            MediaState.scrubLock = false
            MediaState.syncPosition()
        }
    }
}
