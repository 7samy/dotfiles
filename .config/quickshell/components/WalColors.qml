import QtQuick
import Quickshell.Io

pragma Singleton

QtObject {
    id: root

    // Signale
    signal colorsUpdated()

    // Öffentliche Farb-Properties
    property string color0: "#1a1b26"
    property string color1: "#7aa2f7"
    property string color2: "#9ece6a"
    property string color3: "#e0af68"
    property string color4: "#7aa2f7"
    property string color5: "#bb9af7"
    property string color6: "#7dcfff"
    property string color7: "#c0caf5"
    property string color8: "#c0caf5"
    property string color9: "#c0caf5"
    property string color10: "#c0caf5"
    property string color11: "#c0caf5"
    property string color12: "#c0caf5"
    property string color13: "#c0caf5"
    property string color14: "#c0caf5"
    property string color15: "#c0caf5"

    property FileView fileView: FileView {
        path: "/home/azu/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: jsonAdapter
            property var colors: ({})

            onColorsChanged: {
                console.log("WalColors: Aktualisiere Farben aus JSON")
                root.color0 = colors?.color0 ?? "#1a1b26"
                root.color1 = colors?.color1 ?? "#7aa2f7"
                root.color2 = colors?.color2 ?? "#9ece6a"
                root.color3 = colors?.color3 ?? "#e0af68"
                root.color4 = colors?.color4 ?? "#7aa2f7"
                root.color5 = colors?.color5 ?? "#bb9af7"
                root.color6 = colors?.color6 ?? "#7dcfff"
                root.color7 = colors?.color7 ?? "#c0caf5"
                root.color8 = colors?.color8 ?? "#c0caf5"
                root.color9 = colors?.color9 ?? "#c0caf5"
                root.color10 = colors?.color10 ?? "#c0caf5"
                root.color11 = colors?.color11 ?? "#c0caf5"
                root.color12 = colors?.color12 ?? "#c0caf5"
                root.color13 = colors?.color13 ?? "#c0caf5"
                root.color14 = colors?.color14 ?? "#c0caf5"
                root.color15 = colors?.color15 ?? "#c0caf5"
                root.colorsUpdated()   // Signal auslösen
            }
        }
    }

    function withAlpha(hex, alpha) {
        if (!hex || hex.length < 7) return "#000000"
        var a = Math.round(alpha * 255).toString(16).padStart(2, '0')
        return "#" + a + hex.slice(1)
    }
}
