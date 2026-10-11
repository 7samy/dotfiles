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
    // ==== Link-Download (Spotify / SoundCloud -> mp3) ====
    // Phasen: "idle" | "busy" | "done" | "error"
    property string dlPhase: "idle"
    readonly property bool dlBusy: dlPhase === "busy"
    property string dlStatus: ""
    property real dlProgress: -1 // 0..1, -1 = unbekannt
    property string dlName: ""
    property string dlError: ""
    property int dlDoneCounter: 0
    property bool _dlOk: false
    readonly property string dlScript: Qt.resolvedUrl("../scripts/music_download.sh").toString().replace("file://", "")
    // ==== Process-Instanzen im Singleton ====
    property Process songsProcess
    property Process coverProcess
    property Process dlProcess

    // Dienst anhand des Links erkennen: "spotify" | "soundcloud" | ""
    function serviceOf(url) {
        const u = String(url || "").trim().toLowerCase();
        if (/^https:\/\/(open\.spotify\.com|spotify\.link)\//.test(u) || u.indexOf("spotify:track:") === 0)
            return "spotify";

        if (/^https:\/\/((www|m|on)\.)?soundcloud\.com\//.test(u) || /^https:\/\/snd\.sc\//.test(u))
            return "soundcloud";

        return "";
    }

    function downloadUrl(url) {
        if (root.dlBusy)
            return ;

        const u = String(url || "").trim();
        if (serviceOf(u) === "") {
            root.dlError = "Kein Spotify- oder SoundCloud-Link";
            root.dlPhase = "error";
            return ;
        }
        root.dlError = "";
        root.dlName = "";
        root._dlOk = false;
        root.dlProgress = -1;
        root.dlStatus = "Starte …";
        root.dlPhase = "busy";
        root.dlProcess.command = ["bash", root.dlScript, u, root.musicDir];
        root.dlProcess.running = true;
    }

    // Fertig-/Fehlermeldung quittieren (z.B. wenn der Nutzer weitertippt)
    function dlAck() {
        if (root.dlPhase !== "busy") {
            root.dlPhase = "idle";
            root.dlError = "";
        }
    }

    function loadSongs() {
        if (root.songsLoaded || root.songsLoading)
            return ;

        root.songsLoading = true;
        root.songsProcess.running = true;
    }

    // Song-Liste neu von mpd holen (nach einem Download)
    function reloadSongs() {
        root.songsLoaded = false;
        root.loadSongs();
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

    songsProcess: Process {
        command: ["mpc", "listall"]

        stdout: StdioCollector {
            onStreamFinished: root.parseSongs(text)
        }

    }

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

    dlProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (root._dlOk) {
                root.dlPhase = "done";
                root.dlDoneCounter++;
                root.reloadSongs();
            } else {
                if (root.dlError === "")
                    root.dlError = "Download fehlgeschlagen";

                root.dlPhase = "error";
            }
        }

        stdout: SplitParser {
            onRead: (data) => {
                const idx = data.indexOf("|");
                if (idx === -1)
                    return ;

                const kind = data.substring(0, idx);
                const rest = data.substring(idx + 1).trim();
                if (kind === "STATUS") {
                    root.dlStatus = rest;
                } else if (kind === "PROG") {
                    const p = parseFloat(rest);
                    if (!isNaN(p))
                        root.dlProgress = Math.max(0, Math.min(1, p / 100));

                } else if (kind === "DONE") {
                    root.dlName = rest;
                    root._dlOk = true;
                } else if (kind === "ERR") {
                    root.dlError = rest;
                }
            }
        }

    }

}
