pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property string confPath:
        Quickshell.env("HOME") + "/.config/quickshell/notifications.conf"

    property bool hydrated: false
    property bool soundEnabled: true
    property string soundEvent: "message-new-instant"
    property string criticalSoundEvent: "dialog-warning"
    property bool doNotDisturb: false
    property bool dndCollectHistory: true
    property int toastDurationMs: 5000
    property bool showOnLockScreen: true
    property int maxHistory: 50
    property bool clearingAll: false

    readonly property var builtInSoundEvents: [
        "message-new-instant",
        "message-new-email",
        "complete",
        "bell-window-system",
        "dialog-warning",
        "dialog-error"
    ]

    readonly property string customSoundsDir:
        Quickshell.env("HOME") + "/.config/quickshell/sounds/notifications"

    property var customSoundIds: []
    property var soundEventChoices: builtInSoundEvents

    readonly property int toastDurationMinMs: 1000
    readonly property int toastDurationMaxMs: 30000

    property var activeToasts: []
    property var _receivedAt: ({})
    property var _seenNotifIds: ({})
    property int _listRev: 0

    readonly property var server: notifServer
    readonly property var trackedList: notifServer.trackedNotifications
    readonly property int count: trackedList?.values?.length ?? 0
    readonly property bool hasNotifications: count > 0
    readonly property var sidePanelModel: {
        const list = trackedList
        const rev = _listRev
        void list
        void rev
        return trackedNewestFirst()
    }
    readonly property var lockScreenModel: sidePanelModel

    readonly property int dismissAnimMs: 185

    signal toastAdded(var notification)
    signal clearAllStarted()
    signal soundChoicesChanged()

    property var _pendingClear: []

    function isCustomSound(id) {
        return typeof id === "string" && id.indexOf("custom:") === 0
    }

    function customSoundFileName(id) {
        return isCustomSound(id) ? id.substring(7) : ""
    }

    function customSoundPath(id) {
        const name = customSoundFileName(id)
        return name ? customSoundsDir + "/" + name : ""
    }

    function soundLabel(id) {
        if (!id)
            return ""
        if (isCustomSound(id)) {
            const name = customSoundFileName(id)
            const dot = name.lastIndexOf(".")
            return dot > 0 ? name.substring(0, dot) : name
        }
        return id.replace(/-/g, " ")
    }

    function isValidSoundChoice(id) {
        if (!id)
            return false
        if (builtInSoundEvents.indexOf(id) >= 0)
            return true
        return isCustomSound(id) && customSoundIds.indexOf(id) >= 0
    }

    function rebuildSoundChoices() {
        soundEventChoices = builtInSoundEvents.concat(customSoundIds)
        soundChoicesChanged()
    }

    function normalizeLoadedSoundEvents() {
        soundEvent = normalizeSoundEvent(soundEvent, builtInSoundEvents[0])
        criticalSoundEvent = normalizeSoundEvent(criticalSoundEvent, "dialog-warning")
    }

    function refreshCustomSounds() {
        scanSoundsProc.running = false
        scanSoundsProc.running = true
    }

    function clampToastDurationMs(ms) {
        const n = parseInt(ms)
        if (isNaN(n))
            return toastDurationMs
        return Math.max(toastDurationMinMs, Math.min(toastDurationMaxMs, n))
    }

    function normalizeSoundEvent(raw, fallback) {
        if (isValidSoundChoice(raw))
            return raw
        if (fallback && isValidSoundChoice(fallback))
            return fallback
        return builtInSoundEvents[0]
    }

    function setSoundEnabled(val) {
        soundEnabled = val
        persist()
    }

    function setSoundEvent(val) {
        soundEvent = normalizeSoundEvent(val, soundEvent)
        persist()
    }

    function setCriticalSoundEvent(val) {
        criticalSoundEvent = normalizeSoundEvent(val, "dialog-warning")
        persist()
    }

    function setDoNotDisturb(val) {
        doNotDisturb = val
        if (val)
            activeToasts = []
        persist()
    }

    function setDndCollectHistory(val) {
        dndCollectHistory = val
        persist()
    }

    function setShowOnLockScreen(val) {
        showOnLockScreen = val
        persist()
    }

    function setToastDurationMs(ms) {
        toastDurationMs = clampToastDurationMs(ms)
        persist()
    }

    function setMaxHistory(val) {
        const n = parseInt(val)
        if (isNaN(n))
            return
        maxHistory = Math.max(5, Math.min(200, n))
        trimHistory()
        persist()
    }

    function trackedValues() {
        return trackedList?.values ?? []
    }

    function trackedNewestFirst() {
        const vals = trackedValues()
        if (!vals.length)
            return []
        return vals.slice().reverse()
    }

    function recentForLockScreen(limit) {
        if (limit === undefined || limit <= 0)
            return trackedNewestFirst()
        return trackedNewestFirst().slice(0, limit)
    }

    function recordReceivedAt(notification) {
        if (!notification)
            return
        const id = notification.id
        const copy = Object.assign({}, _receivedAt)
        copy[id] = Date.now()
        _receivedAt = copy
    }

    function receivedAtFor(notification) {
        if (!notification)
            return 0
        return _receivedAt[notification.id] ?? 0
    }

    function formatReceivedTime(ts) {
        if (!ts)
            return ""
        const d = new Date(ts)
        const now = new Date()
        const diffMs = now.getTime() - ts
        if (diffMs < 45000)
            return Qt.formatTime(d, "HH:mm")
        if (diffMs < 3600000) {
            const mins = Math.max(1, Math.floor(diffMs / 60000))
            return mins + "m"
        }
        if (d.toDateString() === now.toDateString())
            return Qt.formatTime(d, "HH:mm")
        return Qt.formatDateTime(d, "dd.MM HH:mm")
    }

    function forgetReceivedAt(notification) {
        if (!notification || _receivedAt[notification.id] === undefined)
            return
        const copy = Object.assign({}, _receivedAt)
        delete copy[notification.id]
        _receivedAt = copy
    }

    function markSeen(notification) {
        if (!notification)
            return
        const id = notification.id
        if (_seenNotifIds[id])
            return
        const copy = Object.assign({}, _seenNotifIds)
        copy[id] = true
        _seenNotifIds = copy
    }

    function wasSeen(notification) {
        if (!notification)
            return false
        return !!_seenNotifIds[notification.id]
    }

    function forgetSeen(notification) {
        if (!notification || !_seenNotifIds[notification.id])
            return
        const copy = Object.assign({}, _seenNotifIds)
        delete copy[notification.id]
        _seenNotifIds = copy
    }

    function shouldShowToast(notification) {
        if (!notification || notification.lastGeneration)
            return false
        if (AppState.lockScreenVisible && !showOnLockScreen)
            return false
        if (doNotDisturb)
            return false
        return true
    }

    function toastTimeoutMs(notification) {
        const exp = notification?.expireTimeout ?? -1
        if (exp === 0)
            return 0
        if (exp > 0)
            return Math.min(exp, toastDurationMs > 0 ? toastDurationMs : exp)
        return toastDurationMs
    }

    function handleIncoming(notification) {
        if (!notification)
            return

        if (doNotDisturb && !dndCollectHistory) {
            notification.dismiss()
            return
        }

        notification.tracked = true
        recordReceivedAt(notification)
        trimHistory()

        if (soundEnabled && !doNotDisturb)
            playSound(notification.urgency)

        if (shouldShowToast(notification))
            pushToast(notification)
    }

    function pushToast(notification) {
        const ids = activeToasts.map(t => t.id)
        if (ids.includes(notification.id))
            return
        activeToasts = activeToasts.concat([notification])
        toastAdded(notification)
    }

    function removeToast(notification) {
        if (!notification)
            return
        activeToasts = activeToasts.filter(n => n.id !== notification.id)
    }

    function finalizeDismiss(notification) {
        if (!notification)
            return
        removeToast(notification)
        forgetReceivedAt(notification)
        forgetSeen(notification)
        notification.dismiss()
    }

    function dismissNotification(notification) {
        finalizeDismiss(notification)
    }

    function clearAllAnimated() {
        const list = trackedNewestFirst()
        if (!list.length || clearingAll)
            return
        clearingAll = true
        _pendingClear = list.slice()
        clearAllStarted()
        clearFinishTimer.interval = dismissAnimMs + 24
        clearFinishTimer.restart()
    }

    function finishClearAll() {
        const batch = _pendingClear.slice()
        _pendingClear = []
        activeToasts = []
        for (let i = 0; i < batch.length; ++i) {
            const n = batch[i]
            if (!n)
                continue
            forgetReceivedAt(n)
            forgetSeen(n)
            n.dismiss()
        }
        clearingAll = false
    }

    function clearAll() {
        clearAllAnimated()
    }

    function trimHistory() {
        const vals = trackedValues()
        while (vals.length > maxHistory)
            vals[0].dismiss()
    }

    function playSound(urgency) {
        const event = urgency === NotificationUrgency.Critical
            ? criticalSoundEvent
            : soundEvent
        if (isCustomSound(event)) {
            customSoundProc.filePath = customSoundPath(event)
            customSoundProc.running = false
            customSoundProc.running = true
            return
        }
        soundProc.eventName = event
        soundProc.running = false
        soundProc.running = true
    }

    function parseConfText(text) {
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i].trim()
            if (!line || line.startsWith("#"))
                continue
            const eq = line.indexOf("=")
            if (eq < 0)
                continue
            const k = line.substring(0, eq).trim()
            const v = line.substring(eq + 1).trim()
            switch (k) {
                case "sound_enabled":
                    soundEnabled = v === "true" || v === "1"
                    break
                case "sound_event":
                    soundEvent = normalizeSoundEvent(v, soundEvent)
                    break
                case "critical_sound_event":
                    criticalSoundEvent = normalizeSoundEvent(v, "dialog-warning")
                    break
                case "do_not_disturb":
                    doNotDisturb = v === "true" || v === "1"
                    break
                case "dnd_collect_history":
                    dndCollectHistory = v !== "false" && v !== "0"
                    break
                case "toast_duration_ms": {
                    toastDurationMs = clampToastDurationMs(v)
                    break
                }
                case "show_on_lock_screen":
                    showOnLockScreen = v !== "false" && v !== "0"
                    break
                case "max_history": {
                    const n = parseInt(v)
                    if (!isNaN(n))
                        maxHistory = Math.max(5, Math.min(200, n))
                    break
                }
            }
        }
    }

    function persist() {
        if (!hydrated)
            return
        writeProc.running = false
        writeProc.running = true
    }

    function reloadFromDisk() {
        readProc.running = true
    }

    Timer {
        id: clearFinishTimer
        onTriggered: root.finishClearAll()
    }

    NotificationServer {
        id: notifServer
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        bodySupported: true
        bodyHyperlinksSupported: true
        inlineReplySupported: false
        persistenceSupported: true

        onNotification: notification => root.handleIncoming(notification)

        onTrackedNotificationsChanged: root._listRev++
    }

    Process {
        id: readProc
        command: ["bash", "-c",
            "[ -f '" + root.confPath + "' ] && cat '" + root.confPath + "' || true"]
        running: false
        stdout: SplitParser {
            property string _buf: ""
            onRead: data => { _buf += data }
        }
        onExited: {
            if (stdout._buf.trim())
                root.parseConfText(stdout._buf)
            stdout._buf = ""
            root.refreshCustomSounds()
        }
    }

    Process {
        id: scanSoundsProc
        command: ["bash", "-c",
            "DIR='" + root.customSoundsDir + "'\n" +
            "mkdir -p \"$DIR\"\n" +
            "find \"$DIR\" -maxdepth 1 -type f \\( -iname '*.wav' -o -iname '*.ogg' -o -iname '*.mp3' -o -iname '*.flac' \\) -printf '%f\\n' | sort"]
        running: false
        stdout: SplitParser {
            property string _buf: ""
            onRead: data => { _buf += data }
        }
        onExited: {
            const lines = stdout._buf.trim().split("\n").filter(line => line.length > 0)
            root.customSoundIds = lines.map(name => "custom:" + name)
            root.rebuildSoundChoices()
            root.normalizeLoadedSoundEvents()
            stdout._buf = ""
            root.hydrated = true
        }
    }

    Process {
        id: writeProc
        command: ["bash", "-c",
            "mkdir -p \"$(dirname '" + root.confPath + "')\" && " +
            "printf '%s\\n' " +
            "'# quickshell-notifications' " +
            "'sound_enabled=" + (root.soundEnabled ? "true" : "false") + "' " +
            "'sound_event=" + root.soundEvent + "' " +
            "'critical_sound_event=" + root.criticalSoundEvent + "' " +
            "'do_not_disturb=" + (root.doNotDisturb ? "true" : "false") + "' " +
            "'dnd_collect_history=" + (root.dndCollectHistory ? "true" : "false") + "' " +
            "'toast_duration_ms=" + root.toastDurationMs + "' " +
            "'show_on_lock_screen=" + (root.showOnLockScreen ? "true" : "false") + "' " +
            "'max_history=" + root.maxHistory + "' " +
            "> '" + root.confPath + "'"]
        running: false
    }

    Process {
        id: customSoundProc
        property string filePath: ""
        command: ["bash", "-c",
            "f='" + filePath + "'; " +
            "[ -f \"$f\" ] || exit 0; " +
            "canberra-gtk-play -f \"$f\" 2>/dev/null || paplay \"$f\" 2>/dev/null || aplay \"$f\" 2>/dev/null || true"]
        running: false
    }

    Process {
        id: soundProc
        property string eventName: "message-new-instant"
        command: ["canberra-gtk-play", "-i", eventName]
        running: false
    }

    Component.onCompleted: reloadFromDisk()
}
