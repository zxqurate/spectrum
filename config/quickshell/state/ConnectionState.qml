pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    property bool connected: false
    property bool isWifi: false
    property string label: "Offline"
    property string barGlyph: "󰤮"
    property int wifiStrength: 0

    function isWifiDevice(dev) {
        const name = (dev.name || "").toLowerCase()
        return name.includes("wlan") || name.includes("wifi") || name.includes("wlp")
            || dev.type === DeviceType.Wifi
    }

    function wifiGlyph(strength) {
        if (strength >= 75) return "󰤨"
        if (strength >= 50) return "󰤥"
        if (strength >= 25) return "󰤢"
        return "󰤟"
    }

    function normalizeSignal(raw) {
        if (raw <= 0) return 0
        return raw <= 1 ? Math.round(raw * 100) : Math.round(raw)
    }

    function refresh() {
        const devices = Networking.devices?.values ?? []

        for (let i = 0; i < devices.length; ++i) {
            const dev = devices[i]
            if (!dev.connected || root.isWifiDevice(dev))
                continue
            root.connected = true
            root.isWifi = false
            root.label = "Ethernet"
            root.barGlyph = "󰈀"
            root.wifiStrength = 0
            return
        }

        for (let i = 0; i < devices.length; ++i) {
            const dev = devices[i]
            if (!dev.connected || !root.isWifiDevice(dev))
                continue
            root.connected = true
            root.isWifi = true
            let strength = 0
            let ssid = dev.name || "Wi‑Fi"
            const nets = dev.networks?.values ?? []
            for (let j = 0; j < nets.length; ++j) {
                if (nets[j].connected) {
                    strength = nets[j].signalStrength ?? 0
                    ssid = nets[j].name || ssid
                    break
                }
            }
            root.wifiStrength = root.normalizeSignal(strength)
            root.label = ssid
            root.barGlyph = root.wifiGlyph(root.wifiStrength)
            return
        }

        root.connected = false
        root.isWifi = false
        root.label = "Offline"
        root.barGlyph = "󰤮"
        root.wifiStrength = 0
    }

    Component.onCompleted: refresh()

    Connections {
        target: Networking
        function onWifiEnabledChanged() { root.refresh() }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
