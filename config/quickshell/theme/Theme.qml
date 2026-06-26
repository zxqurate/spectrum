pragma Singleton

import QtQuick
import Quickshell
import "../state"

Singleton {
    // Palette still dark while matugen regenerates after switching to light.
    readonly property bool interimLight: ThemeState.lightTheme && !Colors.isLight
    readonly property bool useGlassPanels: AppearanceState.glassActive

    function surfaceMain() {
        return interimLight ? Colors.md3.inverse_surface : Colors.md3.surface_container
    }

    function surfaceHigh() {
        return interimLight ? Colors.md3.primary_fixed : Colors.md3.surface_container_high
    }

    function surfaceOutline() {
        return interimLight ? Colors.md3.outline : Colors.md3.outline_variant
    }

    function onSurface() {
        return interimLight ? Colors.md3.inverse_on_surface : Colors.md3.on_surface
    }

    function onSurfaceMuted() {
        return interimLight ? Colors.md3.outline : Colors.md3.on_surface_variant
    }

    readonly property int barHeight: 36
    readonly property int barRadius: 12
    readonly property int barMargin: 10
    readonly property int barHideAnimMs: 260
    readonly property int barPadding: 12
    readonly property int pillHeight: 44
    readonly property int pillGap: 10
    readonly property int pillPaddingH: 18
    readonly property int pillPaddingHCompact: 16
    readonly property int fontSize: 14
    readonly property int iconSize: 19
    readonly property int moduleSpacing: 10
    readonly property int workspaceSlot: 26
    readonly property int workspaceGap: 8
    readonly property int workspacePillWidth: workspaceSlot * 10 + workspaceGap * 9 + pillPaddingH * 2
    readonly property string fontFamily: "Rubik"
    readonly property string iconFontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontWeight: Font.Medium
    readonly property int pillBorderWidth: 2
    readonly property int pillBorderWidthEffective: useGlassPanels ? 0 : pillBorderWidth
    // QTBUG-137166: never pair color "transparent" with border.* on the same Rectangle.
    readonly property color clearFill: Qt.rgba(0, 0, 0, 0.001)
    readonly property real workspaceDotBorder: 1.5
    readonly property int compactPillWidth: pillPaddingHCompact * 2 + iconSize + 4
    readonly property int clockPillWidth: pillPaddingH * 2 + 52
    readonly property int networkPopupRightMargin: barMargin + clockPillWidth + pillGap
    readonly property int volumePopupRightMargin: barMargin + clockPillWidth + pillGap + compactPillWidth + pillGap
    readonly property int statsPillWidth: pillPaddingH * 2 + 230
    readonly property int centerClusterWidth:
        compactPillWidth + pillGap + statsPillWidth + pillGap + compactPillWidth
    readonly property int rightClusterWidth:
        compactPillWidth + pillGap + compactPillWidth + pillGap + clockPillWidth
    readonly property int mediaPillClusterOffset:
        compactPillWidth + pillGap + statsPillWidth + pillGap

    function mediaPopupLeftMargin(screenWidth) {
        const inner = Math.max(0, screenWidth - barMargin * 2)
        const clusterLeft = barMargin + Math.round((inner - centerClusterWidth) / 2)
        return clusterLeft + mediaPillClusterOffset
    }

    readonly property int wifiPopupWidth: 280
    readonly property int wifiPopupHeight: 360
    readonly property int mediaPopupWidth: 340
    readonly property int mediaPopupHeight: 124
    readonly property int volumeOsdWidth: 300
    readonly property int volumeOsdHeight: 72
    readonly property int notificationToastWidth: 360

    readonly property color barColor:
        useGlassPanels
            ? AppearanceState.panelColor(Colors.md3.surface_container, AppearanceState.panelOpacity, false)
            : AppearanceState.solidColor(surfaceMain())
    readonly property color pillColor: panelBgCard
    readonly property color barBorderColor: Qt.color(surfaceOutline())
    readonly property color textPrimary: Qt.color(onSurface())
    readonly property color textMuted: Qt.color(onSurfaceMuted())
    readonly property color textAccent: Colors.md3.primary
    readonly property color workspaceActive: Colors.md3.primary
    readonly property color workspaceOccupied: Colors.md3.secondary
    readonly property color workspaceEmpty: surfaceOutline()

    readonly property int ccWidth: 480
    readonly property int ccHeight: 600
    readonly property int ccRadius: 28
    readonly property int ccPadding: 32
    readonly property int ccAvatarSize: 96
    readonly property color ccBg: barColor
    readonly property color ccBgCard: pillColor
    readonly property color ccBorder: surfaceOutline()

    readonly property color popupBg: panelBgCard
    readonly property color popupBorder:
        useGlassPanels ? panelBorder : surfaceOutline()

    readonly property color panelBgNested:
        useGlassPanels
            ? AppearanceState.panelColor(Colors.md3.surface_container_high,
                                       AppearanceState.panelCardOpacity, true)
            : AppearanceState.solidColor(surfaceHigh())
    readonly property color panelBg:
        useGlassPanels
            ? AppearanceState.panelColor(Colors.md3.surface_container,
                                       AppearanceState.panelOpacity, false)
            : AppearanceState.solidColor(surfaceMain())
    readonly property color panelBgCard:
        useGlassPanels
            ? AppearanceState.panelColor(Colors.md3.surface_container_high,
                                       AppearanceState.panelCardOpacity, true)
            : AppearanceState.solidColor(surfaceHigh())
    readonly property color panelBorder:
        useGlassPanels
            ? AppearanceState.panelColor(Colors.md3.outline_variant,
                                       Math.min(1, AppearanceState.panelOpacity + 0.12), false)
            : surfaceOutline()
    readonly property int lockMediaWidth: 400
    readonly property int lockMediaHeight: 228
    readonly property int lockAvatarSize: 112
    readonly property int lockAvatarOuter: 260
    readonly property int lockGaugeSize: 92
    readonly property int lockCardRadius: 22
    readonly property int lockSideGap: 48
    readonly property int lockSideColumnWidth: 400

    readonly property int sidePanelWidth: 360
    readonly property int sidePanelRadius: 24
    readonly property int sidePanelAnimMs: 280
    readonly property int sidePanelTopInset: barMargin + pillHeight + pillGap
    readonly property int notificationAnimMs: 185
    readonly property int notificationCollapseMs: 200
    readonly property int sideTileHoverMs: 180

    readonly property color pillSurface: pillColor
}
