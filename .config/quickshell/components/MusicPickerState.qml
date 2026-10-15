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
    // ==== Warteschlange ("Up next") ====
    // Songpfade, die direkt hinter dem laufenden Song gespielt werden.
    // Spiegelt den Block hinter dem laufenden Song in der mpd-Playlist.
    property var queue: []
    // Datei des gerade laufenden Songs ("" = es laeuft nichts)
    property string nowPlaying: ""
    property var queueJobs: []
    property bool queueBusy: false
    readonly property string queueScript: Qt.resolvedUrl("../scripts/music_queue.sh").toString().replace("file://", "")
    // ==== Link-Download (Spotify / SoundCloud / YouTube -> mp3) ====
    // Phasen: "idle" | "busy" | "done" | "error"
    property string dlPhase: "idle"
    readonly property bool dlBusy: dlPhase === "busy"
    property string dlStatus: ""
    property real dlProgress: -1 // 0..1, -1 = unbekannt
    property string dlName: ""
    property string dlError: ""
    property int dlDoneCounter: 0
    // Stufe: 0 Suchen, 1 Download, 2 Konvertieren, 3 Bibliothek, 4 fertig
    property int dlStage: 0
    property bool _dlOk: false
    readonly property string dlScript: Qt.resolvedUrl("../scripts/music_download.sh").toString().replace("file://", "")
    // ==== Process-Instanzen im Singleton ====
    property Process songsProcess
    property Process coverProcess
    property Process dlProcess
    property Process queueProcess
    property Process nowProcess

    // Dienst anhand des Links erkennen: "spotify" | "soundcloud" | "youtube" | ""
    function serviceOf(url) {
        const u = String(url || "").trim().toLowerCase();
        if (/^https:\/\/(open\.spotify\.com|spotify\.link)\//.test(u) || u.indexOf("spotify:track:") === 0)
            return "spotify";

        if (/^https:\/\/((www|m|on)\.)?soundcloud\.com\//.test(u) || /^https:\/\/snd\.sc\//.test(u))
            return "soundcloud";

        if (/^https:\/\/((www|m|music)\.)?youtube\.com\//.test(u) || /^https:\/\/youtu\.be\//.test(u))
            return "youtube";

        return "";
    }

    // Statusmeldung des Skripts -> Stufe
    function stageOf(t) {
        const s = String(t || "").toLowerCase();
        if (s.indexOf("bibliothek") !== -1)
            return 3;

        if (s.indexOf("konvert") !== -1 || s.indexOf("tags") !== -1)
            return 2;

        if (s.indexOf("lade") !== -1 && s.indexOf("songdaten") === -1)
            return 1;

        return 0;
    }

    function downloadUrl(url) {
        if (root.dlBusy)
            return ;

        const u = String(url || "").trim();
        if (serviceOf(u) === "") {
            root.dlError = "Kein Spotify-, SoundCloud- oder YouTube-Link";
            root.dlPhase = "error";
            return ;
        }
        root.dlError = "";
        root.dlName = "";
        root._dlOk = false;
        root.dlProgress = -1;
        root.dlStage = 0;
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

    // ==== Warteschlange ====
    // Alle mpd-Aenderungen laufen nacheinander (ein Job nach dem anderen),
    // damit sich schnelle Klicks nicht gegenseitig die Positionen verschieben.
    function runQueueJob(args) {
        root.queueJobs.push(args);
        root.nextQueueJob();
    }

    function nextQueueJob() {
        if (root.queueBusy || root.queueJobs.length === 0)
            return ;

        root.queueBusy = true;
        const args = root.queueJobs.shift();
        root.queueProcess.command = ["bash", root.queueScript].concat(args);
        root.queueProcess.running = true;
    }

    // Song hinten an die Queue anhaengen
    function addToQueue(songPath) {
        if (!songPath || root.queue.indexOf(songPath) !== -1)
            return ;

        const k = root.queue.length;
        root.queue = root.queue.concat([songPath]);
        root.requestCover(songPath);
        root.runQueueJob(["add", songPath, String(k)]);
    }

    function removeFromQueue(index) {
        if (index < 0 || index >= root.queue.length)
            return ;

        root.queue = root.queue.filter((p, i) => {
            return i !== index;
        });
        root.runQueueJob(["del", String(index)]);
    }

    // Song an den Anfang der Queue ziehen ("Play next")
    function queueNext(index) {
        if (index <= 0 || index >= root.queue.length)
            return ;

        const q = root.queue.slice();
        const song = q.splice(index, 1)[0];
        q.unshift(song);
        root.queue = q;
        root.runQueueJob(["next", String(index)]);
    }

    function clearQueue() {
        if (root.queue.length === 0)
            return ;

        const n = root.queue.length;
        root.queue = [];
        root.runQueueJob(["clear", String(n)]);
    }

    // Queue-Song sofort abspielen (die Queue rueckt ueber nowPlaying nach)
    function playQueued(index) {
        if (index < 0 || index >= root.queue.length)
            return ;

        root.runQueueJob(["play", String(index)]);
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
    // Spielt mpd einen Queue-Song ab, ist er nicht mehr "als naechstes dran":
    // alles bis einschliesslich dieses Songs faellt aus der Queue.
    onNowPlayingChanged: {
        if (nowPlaying === "")
            return ;

        requestCover(nowPlaying);
        const i = queue.indexOf(nowPlaying);
        if (i !== -1)
            queue = queue.slice(i + 1);

    }

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

    queueProcess: Process {
        onExited: (exitCode, exitStatus) => {
            root.queueBusy = false;
            root.nextQueueJob();
        }
    }

    // Beobachtet mpd per `mpc idle player` (ereignisgesteuert, kein Polling).
    // Gibt bei jedem Player-Ereignis "NOW|<datei>" aus; laeuft mpd nicht,
    // wird alle 3 s neu versucht.
    nowProcess: Process {
        command: ["bash", "-c", 'while true; do echo "NOW|$(mpc -f "%file%" current 2>/dev/null)"; mpc idle player >/dev/null 2>&1 || sleep 3; done']
        running: true

        stdout: SplitParser {
            onRead: (data) => {
                if (data.indexOf("NOW|") === 0)
                    root.nowPlaying = data.substring(4).trim();

            }
        }

    }

    dlProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (root._dlOk) {
                root.dlStage = 4;
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
                    root.dlStage = Math.max(root.dlStage, root.stageOf(rest));
                } else if (kind === "PROG") {
                    const p = parseFloat(rest);
                    if (!isNaN(p)) {
                        root.dlProgress = Math.max(0, Math.min(1, p / 100));
                        root.dlStage = Math.max(root.dlStage, 1);
                    }
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
