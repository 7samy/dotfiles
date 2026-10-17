import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property string downloadDir: "/home/azu/Documents/Japanese-Audios"
    readonly property string statsFile: Quickshell.stateDir + "/japanese-audio-stats.json"
    property bool isOpen: false
    property bool isPlaying: false
    property string currentFile: ""
    property string statusText: ""
    property var library: []
    property var stats: ({
    })

    function toggle() {
        isOpen = !isOpen;
        if (isOpen) {
            loadLibrary();
            loadStats();
        }
    }

    function close() {
        isOpen = false;
    }

    // ── Ordner auslesen ──
    function loadLibrary() {
        listProc.running = false;
        listProc.running = true;
    }

    // ── Stats auslesen ──
    function loadStats() {
        statsReadProc.running = false;
        statsReadProc.running = true;
    }

    // ── Download via yt-dlp ──
    function searchAndDownload(queryOrUrl) {
        if (queryOrUrl.trim() === "")
            return ;

        statusText = "Searching / Downloading...";
        downloadProc.running = false;
        // ytsearch1: sucht das erste Ergebnis, falls es keine URL ist
        const target = queryOrUrl.startsWith("http") ? queryOrUrl : "ytsearch1:" + queryOrUrl;
        downloadProc.command = ["bash", "-c", "yt-dlp -x --audio-format mp3 -o '" + downloadDir + "/%(title)s.%(ext)s' '" + target + "'"];
        downloadProc.running = true;
    }

    // ── Playback via mpv ──
    function play(file) {
        if (currentFile === file && isPlaying) {
            // Pause via IPC
            ipcProc.command = ["bash", "-c", "echo '{\"command\": [\"set_property\", \"pause\", true]}' | socat - /tmp/mpv_japanese.sock"];
            ipcProc.running = true;
            isPlaying = false;
            return ;
        }
        if (currentFile === file && !isPlaying) {
            // Resume via IPC
            ipcProc.command = ["bash", "-c", "echo '{\"command\": [\"set_property\", \"pause\", false]}' | socat - /tmp/mpv_japanese.sock"];
            ipcProc.running = true;
            isPlaying = true;
            return ;
        }
        // Neuen Track starten
        currentFile = file;
        isPlaying = true;
        // Falls mpv noch läuft, killen
        killMpvProc.running = true;
        // Kurz warten, dann neu starten
        startMpvTimer.restart();
    }

    // ── Stats berechnen ──
    function getStatsForPeriod(period) {
        let now = new Date();
        let totalSeconds = 0;
        for (let dateStr in root.stats) {
            let d = new Date(dateStr);
            let include = false;
            if (period === "day") {
                include = (dateStr === Qt.formatDate(now, "yyyy-MM-dd"));
            } else if (period === "week") {
                // Berechnung der aktuellen Woche (Montag bis Sonntag)
                let dayOfWeek = (now.getDay() + 6) % 7;
                // 0 = Montag
                let monday = new Date(now);
                monday.setDate(now.getDate() - dayOfWeek);
                monday.setHours(0, 0, 0, 0);
                include = (d >= monday);
            } else if (period === "month")
                include = (d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear());
            else if (period === "year")
                include = (d.getFullYear() === now.getFullYear());
            if (include)
                totalSeconds += root.stats[dateStr];

        }
        let h = Math.floor(totalSeconds / 3600);
        let m = Math.floor((totalSeconds % 3600) / 60);
        return h + "h " + m + "m";
    }

    Process {
        id: listProc

        command: ["bash", "-c", "mkdir -p " + root.downloadDir + " && find " + root.downloadDir + " -maxdepth 1 -name '*.mp3' -printf '%f\\n' | sort"]
        onRunningChanged: {
            if (running)
                root.library = []; // Reset beim Neuladen

        }

        stdout: SplitParser {
            onRead: (data) => {
                if (!root.library.includes(data)) {
                    let arr = root.library.slice();
                    arr.push(data);
                    root.library = arr;
                }
            }
        }

    }

    Process {
        id: statsReadProc

        command: ["bash", "-c", "mkdir -p $(dirname " + root.statsFile + ") && touch " + root.statsFile + " && cat " + root.statsFile]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    try {
                        root.stats = JSON.parse(text);
                    } catch (e) {
                        root.stats = {
                        };
                    }
                }
            }
        }

    }

    Process {
        id: downloadProc

        onRunningChanged: {
            if (running) {
                root.statusText = "Downloading...";
            } else {
                root.statusText = "Download finished";
                root.loadLibrary();
                statusTimer.restart();
            }
        }
    }

    Timer {
        id: statusTimer

        interval: 3000
        onTriggered: root.statusText = ""
    }

    Process {
        id: killMpvProc

        command: ["bash", "-c", "pkill -f 'mpv.*mpv_japanese.sock' || true"]
    }

    Timer {
        id: startMpvTimer

        interval: 100
        onTriggered: {
            mpvProc.running = false;
            mpvProc.command = ["bash", "-c", "mpv --no-video --input-ipc-server=/tmp/mpv_japanese.sock --force-window=no '" + downloadDir + "/" + currentFile + "'"];
            mpvProc.running = true;
        }
    }

    Process {
        id: mpvProc

        onRunningChanged: {
            if (!running) {
                root.isPlaying = false;
                root.currentFile = "";
            }
        }
    }

    Process {
        id: ipcProc
    }

    // ── Zeit-Tracking (jede Minute) ──
    Timer {
        interval: 60000 // 1 Minute
        running: root.isPlaying
        repeat: true
        onTriggered: {
            const today = Qt.formatDate(new Date(), "yyyy-MM-dd");
            let current = root.stats[today] || 0;
            // Kopiere das Objekt, um QML-Change-Signale auszulösen
            let newStats = Object.assign({
            }, root.stats);
            newStats[today] = current + 60;
            root.stats = newStats;
            // In Datei speichern (JSON escapen für bash)
            const jsonStr = JSON.stringify(root.stats).replace(/'/g, "'\\''");
            statsWriteProc.command = ["bash", "-c", "echo '" + jsonStr + "' > " + root.statsFile];
            statsWriteProc.running = true;
        }
    }

    Process {
        id: statsWriteProc
    }

}
