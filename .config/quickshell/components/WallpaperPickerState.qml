import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: root

    readonly property bool pickerVisible: PickerManager.isOpen("wallpaper")
    readonly property string wallpaperDir: "/home/azu/Pictures/Wallpaper/"
    // Wallpaper-Liste wird einmal beim Start geladen und bleibt als
    // leichtes Array (nur Name + URL) im RAM.
    property var allWallpapers: []
    property bool wallpapersLoaded: false
    property bool wallpapersLoading: false
    property Process listProcess

    listProcess: Process {
        command: ["bash", "-c", "find /home/azu/Pictures/Wallpaper -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\) -printf '%f\\n' | sort"]

        stdout: StdioCollector {
            onStreamFinished: root.parseWallpapers(text)
        }

    }

    function loadWallpapers() {
        if (root.wallpapersLoaded || root.wallpapersLoading)
            return ;

        root.wallpapersLoading = true;
        root.listProcess.running = true;
    }

    function parseWallpapers(rawText) {
        const lines = rawText.split('\n').filter((l) => {
            return l.trim();
        });
        root.allWallpapers = lines.map((name) => {
            return {
                "name": name,
                "url": "file://" + root.wallpaperDir + name
            };
        });
        root.wallpapersLoaded = true;
        root.wallpapersLoading = false;
        console.log("Gefundene Wallpaper:", root.allWallpapers.length);
    }

    function toggle() {
        PickerManager.toggle("wallpaper");
    }

    function close() {
        if (PickerManager.isOpen("wallpaper"))
            PickerManager.close();

    }

    function open() {
        PickerManager.open("wallpaper");
    }

    Component.onCompleted: loadWallpapers()
}
