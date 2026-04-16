import QtQuick
import Quickshell.Io
pragma Singleton

QtObject {
    id: root

    property string color0: "#1a1b26"
    property string color1: "#7aa2f7"
    property string color2: "#9ece6a"
    property string color3: "#e0af68"
    property string color4: "#7aa2f7"
    property string color5: "#bb9af7"
    property string color6: "#7dcfff"
    property string color7: "#c0caf5"
    readonly property string barFillColor: withAlpha(color0, 0.9)
    property FileView _fileView

    _fileView: FileView {
        path: "/home/azu/.cache/wal/colors.json"
        onLoadedChanged: {
            if (loaded) {
                try {
                    var c = JSON.parse(text()).colors;
                    console.log("WalColors: Datei geladen, neue Farben:", c);
                    root.color0 = c.color0;
                    root.color1 = c.color1;
                    root.color2 = c.color2;
                    root.color3 = c.color3;
                    root.color4 = c.color4;
                    root.color5 = c.color5;
                    root.color6 = c.color6;
                    root.color7 = c.color7;
                } catch (e) {
                    console.warn("WalColors: Fehler beim Parsen", e);
                }
            }
        }
    }

    property Timer _reloadTimer

    _reloadTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            console.log("WalColors: Timer reload");
            _fileView.reload();
        }
    }

    function withAlpha(hex, alpha) {
        var a = Math.round(alpha * 255).toString(16).padStart(2, '0');
        return "#" + a + hex.slice(1);
    }

}
