import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: root

    readonly property bool pickerVisible: PickerManager.isOpen("music")
    readonly property string musicDir: "/home/azu/Music/"
    // ==== Song-Liste (bleibt als kleines String-Array im RAM) ====
    property var allSongs: []
    property bool songsLoaded: false
    property bool songsLoading: false
    // ==== Cover-Cache (Songpfad -> /tmp/qs_cover_*.jpg) ====
    // Bleibt im State, damit beim Wiederoeffnen die Cover nicht neu
    // aus den MP3s extrahiert werden muessen.
    property var coverCache: ({
    })
    property var coverQueue: []
    property bool coverBusy: false
    // ==== Process-Instanzen im Singleton ====
    property Process songsProcess

    songsProcess: Process {
        command: ["mpc", "listall"]

        stdout: StdioCollector {
            onStreamFinished: root.parseSongs(text)
        }

    }

    property Process coverProcess

    coverProcess: Process {
        property string songPath: ""
        property string outFile: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const result = text.trim();
                const finishedPath = root.coverProcess.songPath;
                root.coverBusy = false;
                if (result) {
                    // Neue Map erzeugen, damit QML-Bindings das Update merken
                    const updated = Object.assign({
                    }, root.coverCache);
                    updated[finishedPath] = result;
                    root.coverCache = updated;
                }
                root.processCoverQueue();
            }
        }

    }

    function loadSongs() {
        if (root.songsLoaded || root.songsLoading)
            return ;

        root.songsLoading = true;
        root.songsProcess.running = true;
    }

    function parseSongs(rawText) {
        try {
            const lines = rawText.split('\n').filter((l) => {
                return l.trim();
            });
            root.allSongs = lines.sort((a, b) => {
                return a.localeCompare(b);
            });
            root.songsLoaded = true;
            console.log("Gefundene Songs:", root.allSongs.length);
        } catch (e) {
            console.error("Error parsing songs:", e);
        }
        root.songsLoading = false;
    }

    function requestCover(songPath) {
        if (!songPath || root.coverCache[songPath] || root.coverQueue.includes(songPath))
            return ;

        root.coverQueue.push(songPath);
        root.processCoverQueue();
    }

    function processCoverQueue() {
        if (root.coverBusy || root.coverQueue.length === 0)
            return ;

        root.coverBusy = true;
        const path = root.coverQueue.shift();
        const outFile = "/tmp/qs_cover_" + Qt.md5(path) + ".jpg";
        root.coverProcess.songPath = path;
        root.coverProcess.outFile = outFile;
        root.coverProcess.command = ["bash", "-c", 'ffmpeg -i "$1" -an -vcodec copy "$2" -y 2>/dev/null && echo "$2"', "_", root.musicDir + path, outFile];
        root.coverProcess.running = true;
    }

    function displayName(songPath) {
        if (!songPath)
            return "";

        const base = songPath.split("/").pop();
        return base.replace(/\.[^.]+$/, "");
    }

    function toggle() {
        PickerManager.toggle("music");
    }

    function close() {
        if (PickerManager.isOpen("music"))
            PickerManager.close();

    }

    function open() {
        PickerManager.open("music");
    }

    Component.onCompleted: loadSongs()
}
