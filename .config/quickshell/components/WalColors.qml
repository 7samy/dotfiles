import QtQuick
import Quickshell.Io

pragma Singleton

QtObject {
    id: root

    // 1. FileView beobachtet die Datei
    property FileView fileView: FileView {
        path: "/home/azu/.cache/wal/colors.json"   // korrekter Pfad
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        // 2. JsonAdapter als Kind – wird automatisch der 'adapter' des FileView
        JsonAdapter {
            id: jsonAdapter

            // Die Struktur deiner JSON-Datei: { "colors": { "color0": "...", ... } }
            property var colors: ({})

            // Bequeme Properties für jede Farbe mit Fallback
            readonly property string color0: colors?.color0 ?? "#ffffff"
            readonly property string color1: colors?.color1 ?? "#7aa2f7"
            readonly property string color2: colors?.color2 ?? "#9ece6a"
            readonly property string color3: colors?.color3 ?? "#e0af68"
            readonly property string color4: colors?.color4 ?? "#7aa2f7"
            readonly property string color5: colors?.color5 ?? "#bb9af7"
            readonly property string color6: colors?.color6 ?? "#7dcfff"
            readonly property string color7: colors?.color7 ?? "#c0caf5"
            readonly property string color8: colors?.color8 ?? "#c0caf5"
            readonly property string color9: colors?.color9 ?? "#c0caf5"
            readonly property string color10: colors?.color10 ?? "#c0caf5"
            readonly property string color11: colors?.color11 ?? "#c0caf5"
            readonly property string color12: colors?.color12 ?? "#c0caf5"
            readonly property string color13: colors?.color13 ?? "#c0caf5"
            readonly property string color14: colors?.color14 ?? "#c0caf5"
            readonly property string color15: colors?.color15 ?? "#c0caf5"
            // Falls deine JSON mehr Farben hat (bis color15), füge sie hier hinzu
        }
    }

    // 3. Öffentliche Properties des Singletons – leiten an jsonAdapter weiter
    readonly property string color0: fileView.adapter.color0
    readonly property string color1: fileView.adapter.color1
    readonly property string color2: fileView.adapter.color2
    readonly property string color3: fileView.adapter.color3
    readonly property string color4: fileView.adapter.color4
    readonly property string color5: fileView.adapter.color5
    readonly property string color6: fileView.adapter.color6
    readonly property string color7: fileView.adapter.color7
    readonly property string color8: fileView.adapter.color8
    readonly property string color9: fileView.adapter.color9
    readonly property string color10: fileView.adapter.color10
    readonly property string color11: fileView.adapter.color11
    readonly property string color12: fileView.adapter.color12
    readonly property string color13: fileView.adapter.color13
    readonly property string color14: fileView.adapter.color14
    readonly property string color15: fileView.adapter.color15

    // 4. Hilfsfunktion für Alpha-Kanal
    function withAlpha(hex, alpha) {
        var a = Math.round(alpha * 255).toString(16).padStart(2, '0')
        return "#" + a + hex.slice(1)
    }
}
