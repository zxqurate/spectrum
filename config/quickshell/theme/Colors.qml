pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    property alias md3: jsonAdapter.md3
    property alias base16: jsonAdapter.base16
    property alias palette: jsonAdapter.palette

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/generated/colors.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: jsonAdapter

            readonly property Md3 md3: Md3 {}
            readonly property Base16 base16: Base16 {}
            readonly property Palette palette: Palette {}
        }
    }

    readonly property bool isLight: {
        const c = Qt.color(md3.surface)
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.55
    }

    component Md3: JsonObject {
        property string background: "#101418"
        property string error: "#ffb4ab"
        property string error_container: "#93000a"
        property string inverse_on_surface: "#2e3135"
        property string inverse_primary: "#4f6d8c"
        property string inverse_surface: "#e1e2e5"
        property string on_background: "#e1e2e5"
        property string on_error: "#690005"
        property string on_error_container: "#ffdad6"
        property string on_primary: "#001d33"
        property string on_primary_container: "#cce5ff"
        property string on_primary_fixed: "#001d33"
        property string on_primary_fixed_variant: "#334a66"
        property string on_secondary: "#233240"
        property string on_secondary_container: "#d4e4f5"
        property string on_secondary_fixed: "#233240"
        property string on_secondary_fixed_variant: "#3a4857"
        property string on_surface: "#e1e2e5"
        property string on_surface_variant: "#c3c6cf"
        property string on_tertiary: "#342b44"
        property string on_tertiary_container: "#e9ddff"
        property string on_tertiary_fixed: "#342b44"
        property string on_tertiary_fixed_variant: "#4b415c"
        property string outline: "#8b9198"
        property string outline_variant: "#41474d"
        property string primary: "#7c9ebf"
        property string primary_container: "#334a66"
        property string primary_fixed: "#cce5ff"
        property string primary_fixed_dim: "#4f6d8c"
        property string scrim: "#000000"
        property string secondary: "#b8c8d9"
        property string secondary_container: "#3a4857"
        property string secondary_fixed: "#d4e4f5"
        property string secondary_fixed_dim: "#3a4857"
        property string shadow: "#000000"
        property string surface: "#101418"
        property string surface_bright: "#36393e"
        property string surface_container: "#1c2024"
        property string surface_container_high: "#272a2e"
        property string surface_container_highest: "#313539"
        property string surface_container_low: "#181c20"
        property string surface_container_lowest: "#0b0e12"
        property string surface_dim: "#101418"
        property string surface_tint: "#7c9ebf"
        property string surface_variant: "#41474d"
        property string tertiary: "#cdbde0"
        property string tertiary_container: "#4b415c"
        property string tertiary_fixed: "#e9ddff"
        property string tertiary_fixed_dim: "#4b415c"
    }

    component Base16: JsonObject {
        property string base00: "#101418"
        property string base01: "#181c20"
        property string base02: "#1c2024"
        property string base03: "#41474d"
        property string base04: "#8b9198"
        property string base05: "#c3c6cf"
        property string base06: "#e1e2e5"
        property string base07: "#ffffff"
        property string base08: "#ffb4ab"
        property string base09: "#7c9ebf"
        property string base0a: "#b8c8d9"
        property string base0b: "#cdbde0"
        property string base0c: "#4f6d8c"
        property string base0d: "#7c9ebf"
        property string base0e: "#cdbde0"
        property string base0f: "#334a66"
    }

    component Palette: JsonObject {
        property string primary0: "#000000"
        property string primary100: "#ffffff"
    }
}
