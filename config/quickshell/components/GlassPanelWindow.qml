import Quickshell

// Layer windows must request an alpha-capable surface before first paint (QsWindow FAQ).
PanelWindow {
    color: "transparent"
    surfaceFormat.opaque: false
}
