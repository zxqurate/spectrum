import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme"
import "."

RowLayout {
    id: root
    spacing: 10

    property bool polling: true

    // ── Compact pill data ─────────────────────────────────────────────────────
    property string ramUsed:  "--"
    property string swapUsed: "--"
    property int    cpuUsage: 0
    property string cpuTemp:  "--"

    // ── Detailed data for hover popup ─────────────────────────────────────────
    property real ramUsedGb:   0
    property real ramTotalGb:  0
    property real swapUsedGb:  0
    property real swapTotalGb: 0

    property real lastCpuIdle:  0
    property real lastCpuTotal: 0

    // ── RAM segment ───────────────────────────────────────────────────────────
    RowLayout {
        spacing: 4

        BarLabel {
            text: "󰍛"
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize - 1
            color: Theme.textMuted
        }
        BarLabel {
            text: root.ramUsed
            font.pixelSize: Theme.fontSize - 1
            color: Theme.textPrimary
        }
    }

    // ── Separator dot ─────────────────────────────────────────────────────────
    Rectangle {
        width: 3; height: 3; radius: 1.5
        color: Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.4)
    }

    // ── Swap segment ──────────────────────────────────────────────────────────
    RowLayout {
        spacing: 4

        BarLabel {
            text: "󰾷"
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize - 1
            color: Theme.textMuted
        }
        BarLabel {
            text: root.swapUsed
            font.pixelSize: Theme.fontSize - 1
            color: Theme.textMuted
        }
    }

    // ── Separator dot ─────────────────────────────────────────────────────────
    Rectangle {
        width: 3; height: 3; radius: 1.5
        color: Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.4)
    }

    // ── CPU segment ───────────────────────────────────────────────────────────
    RowLayout {
        spacing: 4

        BarLabel {
            text: "\uf4bc"
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize - 1
            color: Theme.textMuted
        }
        BarLabel {
            text: root.cpuTemp !== "--" ? root.cpuTemp + "°" : "--"
            font.pixelSize: Theme.fontSize - 1
            color: Theme.textAccent
        }
        BarLabel {
            text: root.cpuUsage + "%"
            font.pixelSize: Theme.fontSize - 1
            color: Theme.textPrimary
        }
    }

    // ── Data processes ────────────────────────────────────────────────────────
    Process {
        id: cpuStatProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                const p = data.trim().split(/\s+/)
                const user    = parseInt(p[1]) || 0
                const nice    = parseInt(p[2]) || 0
                const system  = parseInt(p[3]) || 0
                const idle    = parseInt(p[4]) || 0
                const iowait  = parseInt(p[5]) || 0
                const irq     = parseInt(p[6]) || 0
                const softirq = parseInt(p[7]) || 0
                const total    = user + nice + system + idle + iowait + irq + softirq
                const idleTime = idle + iowait
                if (root.lastCpuTotal > 0) {
                    const dTotal = total - root.lastCpuTotal
                    const dIdle  = idleTime - root.lastCpuIdle
                    if (dTotal > 0)
                        root.cpuUsage = Math.round(100 * (dTotal - dIdle) / dTotal)
                }
                root.lastCpuTotal = total
                root.lastCpuIdle  = idleTime
            }
        }
    }

    Process {
        id: memProc
        command: ["sh", "-c", "free -b | awk '/Mem:/{printf \"%.1f,%.2f,%.2f\", $3/1e9, $3/1e9, $2/1e9} /Swap:/{printf \",%.2f,%.2f\", $3/1e9, $2/1e9}'"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || !data.trim()) return
                const parts = data.trim().split(",")
                if (parts.length < 5) return
                root.ramUsed     = parts[0] + "G"
                root.ramUsedGb   = parseFloat(parts[1]) || 0
                root.ramTotalGb  = parseFloat(parts[2]) || 0
                root.swapUsedGb  = parseFloat(parts[3]) || 0
                root.swapTotalGb = parseFloat(parts[4]) || 0
                root.swapUsed    = parseFloat(parts[3]).toFixed(1) + "G"
            }
        }
    }

    Process {
        id: tempProc
        command: ["sh", "-c",
            "sensors 2>/dev/null | grep -m1 -E 'Tctl|Tdie|Package id' | awk '{print $2}' | tr -d '+°C'" +
            " || awk '{printf \"%d\", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) root.cpuTemp = data.trim()
            }
        }
    }

    Timer {
        id: memTimer
        interval: 500
        running: root.polling
        repeat: true
        triggeredOnStart: true
        onTriggered: memProc.running = true
    }

    Timer {
        interval: 2000
        running: root.polling
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuStatProc.running = true
            tempProc.running = true
        }
    }
}
