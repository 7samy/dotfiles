import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property string downloadDir: "/home/azu/Documents/Japanese-Audios"
    readonly property string statsFile: Quickshell.stateDir + "/japanese-audio-stats.json"
    readonly property string ipcSocket: "/tmp/mpv_japanese.sock"
    readonly property string cookieFile: "/home/azu/.config/quickshell/youtube-cookies.txt"
    property bool isOpen: false
    property bool isPlaying: false
    property string currentFile: ""
    property string statusText: ""
    property var library: []
    property var stats: ({
    })
    property real downloadProgress: 0
    property bool isDownloading: false
    property bool isConverting: false
    property bool cancelled: false
    property bool restarting: false
    property int startPollTries: 0
    property string downloadTitle: ""
    property string downloadError: ""
    property bool isSearching: false
    property string searchError: ""
    property var searchResults: []
    property real currentPosition: 0
    property real currentDuration: 0
    property double sessionStart: 0
    property double sessionCommitted: 0

    signal downloadCompleted()

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

    function loadLibrary() {
        listProc.running = false;
        listProc.running = true;
    }

    function loadStats() {
        statsReadProc.running = false;
        statsReadProc.running = true;
    }

    // ── Suche ──
    function searchVideos(query) {
        if (query.trim() === "")
            return ;

        isSearching = true;
        searchResults = [];
        searchError = "";
        searchProc.running = false;
        // PATH erweitern, Cookies-Datei nutzen, mweb/tv-Client erzwingen
        const cmd = "export PATH=\"$PATH:$HOME/.cargo/bin:$HOME/.deno/bin:$HOME/.local/bin:/usr/local/bin\"; " + "exec yt-dlp \"ytsearch5:$1\" --flat-playlist --dump-json --cookies \"" + root.cookieFile + "\" --extractor-args \"youtube:player_client=mweb,tv\"";
        searchProc.command = ["bash", "-c", cmd, "qs-ytsearch", query];
        searchProc.running = true;
    }

    function clearSearch() {
        searchResults = [];
        searchError = "";
        isSearching = false;
    }

    // ── Download ──
    function downloadVideo(url, title) {
        if (isDownloading)
            return ;

        downloadTitle = title;
        downloadError = "";
        isDownloading = true;
        isConverting = false;
        downloadProgress = 0;
        statusText = "Downloading...";
        downloadProc.running = false;
        cancelled = false;
        // PATH erweitern, Cookies-Datei nutzen, mweb/tv-Client erzwingen
        const cmd = "export PATH=\"$PATH:$HOME/.cargo/bin:$HOME/.deno/bin:$HOME/.local/bin:/usr/local/bin\"; " + "mkdir -p \"$1\" && exec yt-dlp --newline --no-colors --no-playlist --playlist-items 1 -x --audio-format mp3 " + "--cookies \"" + root.cookieFile + "\" " + "--extractor-args \"youtube:player_client=mweb,tv\" " + "-o \"$1/%(title)s.%(ext)s\" -- \"$2\" 2>&1";
        downloadProc.command = ["bash", "-c", cmd, "qs-ytdlp", downloadDir, url];
        downloadProc.running = true;
    }

    function cancelDownload() {
        if (!isDownloading)
            return ;

        cancelled = true;
        downloadProc.running = false;
    }

    function downloadFromInput(queryOrUrl) {
        queryOrUrl = queryOrUrl.trim();
        if (queryOrUrl.startsWith("http://") || queryOrUrl.startsWith("https://") || queryOrUrl.startsWith("www.")) {
            downloadVideo(queryOrUrl, "Video");
            return true;
        }
        searchVideos(queryOrUrl);
        return false;
    }

    // ── IPC ──
    function sendIpc(jsonStr) {
        const py = "import socket,sys\n" + "try:\n" + "  s=socket.socket(socket.AF_UNIX)\n" + "  s.connect('" + ipcSocket + "')\n" + "  s.sendall(sys.argv[1].encode()+b'\\n')\n" + "  s.close()\n" + "except: sys.exit(1)";
        ipcProc.command = ["python3", "-c", py, jsonStr];
        ipcProc.running = false;
        ipcProc.running = true;
    }

    // ── Playback ──
    function play(file) {
        if (currentFile === file && mpvProc.running) {
            sendIpc('{"command": ["cycle", "pause"]}');
            isPlaying = !isPlaying;
            pollVerifier.restart();
            return ;
        }
        currentFile = file;
        isPlaying = true;
        currentPosition = 0;
        currentDuration = 0;
        restarting = true;
        killMpvProc.running = false;
        killMpvProc.running = true;
        startMpvTimer.restart();
    }

    function pollPosition() {
        const py = 'import socket, json\n' + 'try:\n' + '    s = socket.socket(socket.AF_UNIX)\n' + '    s.settimeout(0.3)\n' + '    s.connect("' + ipcSocket + '")\n' + '    def cmd(c):\n' + '        s.sendall((json.dumps({"command": c}) + "\\n").encode())\n' + '        buf = b""\n' + '        while b"\\n" not in buf:\n' + '            chunk = s.recv(4096)\n' + '            if not chunk: break\n' + '            buf += chunk\n' + '        for line in buf.split(b"\\n"):\n' + '            if line:\n' + '                try:\n' + '                    d = json.loads(line)\n' + '                    if "data" in d and "error" in d: return d["data"]\n' + '                except: pass\n' + '        return None\n' + '    pos = cmd(["get_property", "time-pos"])\n' + '    dur = cmd(["get_property", "duration"])\n' + '    pause = cmd(["get_property", "pause"])\n' + '    print(json.dumps({"pos": pos, "dur": dur, "pause": pause}))\n' + '    s.close()\n' + 'except Exception as e:\n' + '    print(json.dumps({"error": str(e)}))\n';
        posPollProc.command = ["python3", "-c", py];
        posPollProc.running = false;
        posPollProc.running = true;
    }

    function seekToFraction(fraction) {
        if (currentDuration <= 0)
            return ;

        const seconds = Math.max(0, Math.min(currentDuration, fraction * currentDuration));
        sendIpc('{"command": ["seek", ' + seconds.toFixed(2) + ', "absolute"]}');
        currentPosition = seconds;
    }

    function seekRelative(delta) {
        if (currentFile === "" || currentDuration <= 0)
            return ;

        sendIpc('{"command": ["seek", ' + delta + ', "relative"]}');
        currentPosition = Math.max(0, Math.min(currentDuration, currentPosition + delta));
    }

    function addListenTime(seconds) {
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        let newStats = Object.assign({
        }, root.stats);
        newStats[today] = (newStats[today] || 0) + seconds;
        root.stats = newStats;
        saveStats();
    }

    function saveStats() {
        const jsonStr = JSON.stringify(root.stats).replace(/'/g, "'\\''");
        statsWriteProc.command = ["bash", "-c", "echo '" + jsonStr + "' > " + root.statsFile];
        statsWriteProc.running = false;
        statsWriteProc.running = true;
    }

    function getStatsForPeriod(period) {
        let now = new Date();
        let totalSeconds = 0;
        for (let dateStr in root.stats) {
            let d = new Date(dateStr);
            let include = false;
            if (period === "day") {
                include = (dateStr === Qt.formatDate(now, "yyyy-MM-dd"));
            } else if (period === "week") {
                let dayOfWeek = (now.getDay() + 6) % 7;
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
                root.library = [];

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
        id: searchProc

        property string errBuffer: ""

        onRunningChanged: {
            if (!running) {
                root.isSearching = false;
                if (errBuffer !== "") {
                    console.warn("[JapaneseAudio] Search error:", errBuffer);
                    root.searchError = errBuffer.replace(/^ERROR:\s*/gm, "").trim();
                }
            } else {
                errBuffer = "";
            }
        }

        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const obj = JSON.parse(data);
                    if (obj && obj.title && obj.id) {
                        let arr = root.searchResults.slice();
                        arr.push({
                            "id": obj.id,
                            "title": obj.title,
                            "url": "https://www.youtube.com/watch?v=" + obj.id,
                            "duration": obj.duration_string || "",
                            "thumbnail": obj.thumbnails ? obj.thumbnails[obj.thumbnails.length - 1].url : "",
                            "uploader": obj.uploader || ""
                        });
                        root.searchResults = arr;
                    }
                } catch (e) {
                }
            }
        }

        stderr: SplitParser {
            onRead: (data) => {
                searchProc.errBuffer += data + "\n";
            }
        }

    }

    Process {
        id: downloadProc

        onExited: (exitCode, exitStatus) => {
            if (root.cancelled) {
                root.cancelled = false;
                root.isDownloading = false;
                root.isConverting = false;
                root.downloadProgress = 0;
                root.downloadTitle = "";
                root.statusText = "";
                return ;
            }
            if (root.isDownloading) {
                root.isDownloading = false;
                root.isConverting = false;
                if (exitCode === 0) {
                    root.statusText = "Download finished";
                    root.loadLibrary();
                    root.downloadCompleted();
                } else {
                    if (root.downloadError === "")
                        root.downloadError = "Exit code " + exitCode;

                    console.warn("[JapaneseAudio] download failed (" + exitCode + "): " + root.downloadError);
                    root.statusText = "Download failed";
                }
                statusTimer.restart();
            }
        }

        stdout: SplitParser {
            onRead: (data) => {
                const pm = data.match(/\[download\]\s+([\d.]+)%/);
                if (pm)
                    root.downloadProgress = parseFloat(pm[1]) / 100;

                if (data.indexOf("[ExtractAudio]") >= 0)
                    root.isConverting = true;

                const line = data.trim();
                if (line.includes("ERROR") && root.downloadError === "")
                    root.downloadError = line.replace(/^ERROR:\s*/, "").trim();

                const dm = data.match(/\[download\]\s+Destination:\s+(.+)/);
                if (dm && root.downloadTitle === "Video") {
                    const parts = dm[1].trim().split('/');
                    root.downloadTitle = parts[parts.length - 1].replace(/\.[^.]+$/, "");
                }
            }
        }

    }

    Timer {
        id: statusTimer

        interval: 3500
        onTriggered: {
            root.statusText = "";
            root.downloadProgress = 0;
            root.downloadTitle = "";
            root.downloadError = "";
        }
    }

    Process {
        id: ipcProc
    }

    Process {
        id: killMpvProc

        command: ["bash", "-c", "pkill -f 'mpv.*mpv_japanese.sock' 2>/dev/null || true"]
    }

    Timer {
        id: startMpvTimer

        interval: 150
        onTriggered: {
            const script = "M=''; " + "if [ -f /usr/lib/mpv-mpris/mpris.so ]; then M='--script=/usr/lib/mpv-mpris/mpris.so'; " + "elif [ -f /usr/share/mpv/scripts/mpris.so ]; then M='--script=/usr/share/mpv/scripts/mpris.so'; fi; " + "exec mpv --no-video --quiet $M " + "--input-ipc-server=" + ipcSocket + " " + "--force-window=no --terminal=no -- \"$1\"";
            mpvProc.command = ["bash", "-c", script, "qs-mpv", downloadDir + "/" + currentFile];
            mpvProc.running = false;
            mpvProc.running = true;
            root.startPollTries = 0;
            startPoll.restart();
            restartGuard.restart();
        }
    }

    Process {
        id: mpvProc

        onRunningChanged: {
            if (running) {
                root.restarting = false;
                return ;
            }
            if (root.restarting)
                return ;

            root.isPlaying = false;
            root.currentPosition = 0;
            root.currentDuration = 0;
        }
    }

    Timer {
        id: startPoll

        interval: 300
        repeat: true
        onTriggered: {
            root.startPollTries++;
            if (root.currentDuration > 0 || root.startPollTries > 20) {
                stop();
                return ;
            }
            root.pollPosition();
        }
    }

    Timer {
        id: restartGuard

        interval: 3000
        onTriggered: root.restarting = false
    }

    Timer {
        interval: root.isPlaying ? 1000 : 2000
        running: root.currentFile !== "" && mpvProc.running
        repeat: true
        onTriggered: root.pollPosition()
    }

    Timer {
        id: pollVerifier

        interval: 300
        onTriggered: root.pollPosition()
    }

    Process {
        id: posPollProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim());
                    if (d.error)
                        return ;

                    if (d.pos !== null && d.pos !== undefined)
                        root.currentPosition = d.pos;

                    if (d.dur !== null && d.dur !== undefined && d.dur > 0)
                        root.currentDuration = d.dur;

                    if (d.pause !== null && d.pause !== undefined)
                        root.isPlaying = !d.pause;

                } catch (e) {
                }
            }
        }

    }

    Connections {
        function onIsPlayingChanged() {
            if (root.isPlaying) {
                root.sessionStart = Date.now();
                root.sessionCommitted = 0;
            } else {
                if (root.sessionStart > 0) {
                    const elapsed = Math.round((Date.now() - root.sessionStart) / 1000);
                    const remaining = elapsed - root.sessionCommitted;
                    if (remaining > 0)
                        root.addListenTime(remaining);

                }
                root.sessionStart = 0;
                root.sessionCommitted = 0;
            }
        }

        target: root
    }

    Timer {
        interval: 30000
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.sessionStart > 0) {
                const elapsed = Math.round((Date.now() - root.sessionStart) / 1000);
                const remaining = elapsed - root.sessionCommitted;
                if (remaining > 0) {
                    root.addListenTime(remaining);
                    root.sessionCommitted = elapsed;
                }
            }
        }
    }

    Process {
        id: statsWriteProc
    }

}
