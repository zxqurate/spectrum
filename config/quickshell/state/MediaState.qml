pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    property var activePlayer: null
    property real displayPosition: 0
    property int positionTick: 0
    property bool scrubLock: false

    readonly property string artCacheFile: Quickshell.env("HOME") + "/.local/state/quickshell/media_art.jpg"
    property string trackArtSource: ""
    property string _lastFetchedArtUrl: ""

    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property string trackTitle: {
        const t = activePlayer?.trackTitle ?? ""
        return t.length > 0 ? t : "Nothing playing"
    }
    readonly property string trackArtist: {
        const a = activePlayer?.trackArtist ?? ""
        return a.length > 0 ? a : (hasPlayer ? activePlayer.identity : "Open a player")
    }
    readonly property string trackArtUrl: activePlayer?.trackArtUrl ?? ""
    readonly property real trackLength: activePlayer?.length ?? 0
    readonly property bool canToggle: activePlayer?.canTogglePlaying ?? false
    readonly property bool canPrev: activePlayer?.canGoPrevious ?? false
    readonly property bool canNext: activePlayer?.canGoNext ?? false
    readonly property bool canSeek: activePlayer?.canSeek ?? false

    function formatTime(sec) {
        if (!isFinite(sec) || sec < 0) return "0:00"
        const total = Math.floor(sec)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function syncPosition() {
        if (!activePlayer || scrubLock)
            return
        displayPosition = activePlayer.position
        positionTick++
    }

    function setPreviewPosition(pos) {
        displayPosition = pos
        positionTick++
    }

    function refreshActivePlayer() {
        const players = Mpris.players.values
        for (let i = 0; i < players.length; ++i) {
            if (players[i].isPlaying) {
                activePlayer = players[i]
                syncPosition()
                fetchArt(trackArtUrl)
                return
            }
        }
        activePlayer = players.length > 0 ? players[0] : null
        syncPosition()
        fetchArt(trackArtUrl)
    }

    function fetchArt(url) {
        const normalized = normalizeArtUrl(url)
        const key = normalized + "|" + (activePlayer?.trackTitle ?? "")
        if (key === _lastFetchedArtUrl && trackArtSource !== "")
            return
        _lastFetchedArtUrl = key
        artFetchProc.artUrl = normalized
        artFetchProc.running = true
    }

    function normalizeArtUrl(url) {
        if (!url || url.length === 0)
            return ""
        if (url.startsWith("file://") || url.startsWith("http://") || url.startsWith("https://"))
            return url
        if (url.startsWith("file:/"))
            return "file://" + url.slice(5)
        if (url.startsWith("/"))
            return "file://" + url
        return url
    }

    function togglePlaying() {
        if (!activePlayer)
            return
        if (activePlayer.canTogglePlaying)
            activePlayer.togglePlaying()
        else if (activePlayer.isPlaying)
            activePlayer.pause()
        else
            activePlayer.play()
    }

    function previousTrack() {
        if (canPrev) activePlayer.previous()
    }

    function nextTrack() {
        if (canNext) activePlayer.next()
    }

    function seekTo(fraction) {
        if (!canSeek || !activePlayer || trackLength <= 0) return
        const pos = Math.max(0, Math.min(1, fraction)) * trackLength
        activePlayer.position = pos
        displayPosition = pos
        positionTick++
    }

    Process {
        id: artFetchProc
        property string artUrl: ""
        running: false
        environment: ({
            "ART_URL": artUrl,
            "HOME": Quickshell.env("HOME"),
            "DEST": root.artCacheFile
        })
        command: ["bash", "-c",
            "mkdir -p \"$(dirname \"$DEST\")\"; " +
            "if [ -z \"$ART_URL\" ]; then rm -f \"$DEST\"; exit 0; fi; " +
            "case \"$ART_URL\" in " +
            "file://*) path=\"${ART_URL#file://}\"; " +
            "path=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.unquote(sys.argv[1]))' \"$path\"); " +
            "if [ -f \"$path\" ]; then cp -f \"$path\" \"$DEST\"; fi ;; " +
            "http://*|https://*) curl -sfL --max-time 6 \"$ART_URL\" -o \"$DEST.tmp\" && mv -f \"$DEST.tmp\" \"$DEST\" ;; " +
            "esac"
        ]
        onExited: {
            if (_lastFetchedArtUrl)
                trackArtSource = "file://" + artCacheFile + "?" + Date.now()
            else
                trackArtSource = ""
        }
    }

    Connections {
        id: playerConn
        ignoreUnknownSignals: true
        function onTrackArtUrlChanged() { root.fetchArt(root.trackArtUrl) }
        function onPositionChanged() { root.syncPosition() }
        function onIsPlayingChanged() { root.syncPosition() }
        function onPlaybackStateChanged() { root.syncPosition() }
    }

    onActivePlayerChanged: {
        playerConn.target = activePlayer
        fetchArt(trackArtUrl)
    }

    Instantiator {
        model: Mpris.players
        delegate: QtObject {
            required property var modelData

            property var conn: Connections {
                target: modelData
                function onIsPlayingChanged() {
                    if (modelData.isPlaying)
                        root.refreshActivePlayer()
                    else if (modelData === root.activePlayer)
                        root.syncPosition()
                }
                function onPlaybackStateChanged() {
                    if (modelData === root.activePlayer)
                        root.syncPosition()
                }
                function onTrackTitleChanged() { root.refreshActivePlayer() }
                function onTrackArtUrlChanged() { root.refreshActivePlayer() }
            }
        }
    }

    Timer {
        interval: 900
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshActivePlayer()
    }

    Timer {
        interval: 50
        running: root.hasPlayer && root.isPlaying && !root.scrubLock
        repeat: true
        onTriggered: root.syncPosition()
    }
}
