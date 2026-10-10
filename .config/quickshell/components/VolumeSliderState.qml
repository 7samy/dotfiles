import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: root

    property bool open: false
    property bool hovered: false
    property bool expanded: false
    // ==== System-Volume (0..1) ====
    property real systemVolume: 0
    property bool systemMuted: false
    // ==== Aktive Audio-Streams ====
    // Jeder: { id, name, subtitle, icon, volume, muted }
    property var streams: []
    // Stream, der gerade per Drag veraendert wird (Poll darf ihn nicht ueberschreiben)
    property int draggingStreamId: -1
    property var _pendingStreamVol: null
    property var _pendingSystemVol: null
    // Eigene Icons als Fallback (Pfade relativ zu resources/icons)
    readonly property var localIcons: ({
        "firefox": "firefox.svg",
        "zen": "zen-browser.png",
        "chrome": "chrome.svg",
        "chromium": "chrome.svg",
        "youtube": "youtube.svg",
        "twitch": "twitch.svg",
        "tiktok": "tiktok.svg",
        "minecraft": "minecraft.png",
        "java": "minecraft.png",
        "modrinth": "modrinth.png",
        "kitty": "kitty.png"
    })
    property Timer autoCloseTimer
    property Timer pollTimer
    property Timer streamsRefreshTimer
    // ==== Prozesse ====
    property Process getProc
    property Process setProc
    property Process muteProc
    property Process getStreamsProc
    property Process setStreamVolProc
    property Process muteStreamProc

    // ==== Icon-Aufloesung ====
    // Reihenfolge: Icon-Theme -> Desktop-Entry -> eigene Icons -> "" (Popup zeigt Buchstaben)
    function resolveIcon(props) {
        const cands = [];
        const push = (s) => {
            if (s === undefined || s === null)
                return ;

            const t = String(s).trim();
            if (t === "")
                return ;

            cands.push(t);
            const stripped = t.replace(/(-bin|-wrapped|-stable)$/i, "");
            if (stripped !== t)
                cands.push(stripped);

        };
        push(props["application.icon_name"]);
        push(props["application.process.binary"]);
        push(props["application.id"]);
        push(props["application.name"]);
        push(props["node.name"]);
        try {
            for (const c of cands) {
                const variants = [c, c.toLowerCase(), c.toLowerCase().replace(/\s+/g, "-")];
                for (const v of variants) {
                    if (Quickshell.iconPath(v, true) !== "")
                        return "image://icon/" + v;

                }
            }
            for (const c of cands) {
                const e = DesktopEntries.heuristicLookup(c);
                if (e && e.icon) {
                    if (e.icon.startsWith("/"))
                        return "file://" + e.icon;

                    if (Quickshell.iconPath(e.icon, true) !== "")
                        return "image://icon/" + e.icon;

                }
            }
        } catch (err) {
            console.warn("[VolumeSliderState] icon lookup failed:", err);
        }
        for (const c of cands) {
            const l = c.toLowerCase();
            for (const key in localIcons) {
                if (l.indexOf(key) !== -1)
                    return Qt.resolvedUrl("../resources/icons/" + localIcons[key]);

            }
        }
        return "";
    }

    // ==== Popup oeffnen/schliessen ====
    function toggle() {
        if (open)
            close();
        else
            openPopup();
    }

    function openPopup() {
        open = true;
        restartAutoClose();
        getProc.running = true;
        if (expanded)
            getStreamsProc.running = true;

    }

    function close() {
        open = false;
        hovered = false;
        expanded = false;
        draggingStreamId = -1;
        autoCloseTimer.stop();
    }

    function restartAutoClose() {
        autoCloseTimer.restart();
    }

    // ==== Expand toggle ====
    function toggleExpanded() {
        expanded = !expanded;
        if (expanded) {
            restartAutoClose();
            getStreamsProc.running = true;
        }
    }

    // ==== System-Volume Aktionen ====
    function _runSystemVol(v) {
        setProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(3)];
        setProc.running = true;
    }

    function setSystemVolume(val) {
        const safeVal = Math.max(0, Math.min(val, 1));
        root.systemVolume = safeVal;
        if (setProc.running)
            _pendingSystemVol = safeVal;
        else
            _runSystemVol(safeVal);
    }

    function toggleSystemMute() {
        root.systemMuted = !root.systemMuted;
        muteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", root.systemMuted ? "1" : "0"];
        muteProc.running = true;
    }

    // ==== Stream-Aktionen ====
    function _runStreamVol(id, val) {
        setStreamVolProc.command = ["pactl", "set-sink-input-volume", String(id), Math.round(val * 100) + "%"];
        setStreamVolProc.running = true;
    }

    function _patchStream(id, patch) {
        const arr = streams.slice();
        for (let i = 0; i < arr.length; i++) {
            if (arr[i].id === id) {
                arr[i] = Object.assign({
                }, arr[i], patch);
                break;
            }
        }
        streams = arr;
    }

    function setStreamVolume(id, val) {
        const safeVal = Math.max(0, Math.min(val, 1));
        // Laeuft gerade ein Prozess, merken wir uns nur den letzten Wert,
        // statt Updates zu verlieren oder Prozesse zu stapeln.
        if (setStreamVolProc.running)
            _pendingStreamVol = {
            "id": id,
            "val": safeVal
        };
        else
            _runStreamVol(id, safeVal);
        _patchStream(id, {
            "volume": safeVal
        });
    }

    function toggleStreamMute(id) {
        let target = null;
        for (let i = 0; i < streams.length; i++) {
            if (streams[i].id === id) {
                target = streams[i];
                break;
            }
        }
        if (!target)
            return ;

        const newMuted = !target.muted;
        muteStreamProc.command = ["pactl", "set-sink-input-mute", String(id), newMuted ? "1" : "0"];
        muteStreamProc.running = true;
        _patchStream(id, {
            "muted": newMuted
        });
    }

    getProc: Process {
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: StdioCollector {
            onStreamFinished: {
                const txt = text.trim();
                const m = txt.match(/Volume:\s+([\d.]+)/);
                if (m)
                    root.systemVolume = Math.max(0, Math.min(1, parseFloat(m[1])));

                root.systemMuted = txt.indexOf("[MUTED]") !== -1;
            }
        }

    }

    setProc: Process {
        onRunningChanged: {
            if (!running && root._pendingSystemVol !== null) {
                const v = root._pendingSystemVol;
                root._pendingSystemVol = null;
                root._runSystemVol(v);
            }
        }
    }

    muteProc: Process {
    }

    getStreamsProc: Process {
        command: ["pactl", "-f", "json", "list", "sink-inputs"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const arr = [];
                    for (const item of data) {
                        const props = item.properties || {
                        };
                        const appName = props["application.name"] || props["media.name"] || "Unknown";
                        const mediaName = props["media.name"] || "";
                        let vol = 0.5;
                        if (item.volume) {
                            const ch = Object.keys(item.volume)[0];
                            if (ch && item.volume[ch] && item.volume[ch].value_percent)
                                vol = parseFloat(item.volume[ch].value_percent) / 100;

                        }
                        // Waehrend eines Drags den lokalen Wert behalten
                        if (item.index === root.draggingStreamId) {
                            for (const s of root.streams) {
                                if (s.id === item.index) {
                                    vol = s.volume;
                                    break;
                                }
                            }
                        }
                        arr.push({
                            "id": item.index,
                            "name": appName,
                            "subtitle": mediaName !== appName ? mediaName : "",
                            "icon": root.resolveIcon(props),
                            "volume": vol,
                            "muted": item.mute || false
                        });
                    }
                    arr.sort((a, b) => {
                        return a.id - b.id;
                    });
                    root.streams = arr;
                } catch (e) {
                    console.error("[VolumeSliderState] Failed to parse pactl output:", e);
                    root.streams = [];
                }
            }
        }

    }

    setStreamVolProc: Process {
        onRunningChanged: {
            if (!running && root._pendingStreamVol !== null) {
                const p = root._pendingStreamVol;
                root._pendingStreamVol = null;
                root._runStreamVol(p.id, p.val);
            }
        }
    }

    muteStreamProc: Process {
    }

    // ==== Timer ====
    autoCloseTimer: Timer {
        interval: 4000
        onTriggered: {
            if (!root.hovered && root.draggingStreamId < 0)
                root.close();
            else
                root.restartAutoClose();
        }
    }

    pollTimer: Timer {
        interval: root.open ? 200 : 1000
        running: true
        repeat: true
        onTriggered: {
            if (!getProc.running)
                getProc.running = true;

        }
    }

    streamsRefreshTimer: Timer {
        interval: 800
        running: root.expanded && root.open
        repeat: true
        onTriggered: {
            if (!getStreamsProc.running)
                getStreamsProc.running = true;

        }
    }

}
