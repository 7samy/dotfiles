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
    // ==== Aktive Audio-Streams (nach App gruppiert) ====
    // Jeder: { key, name, subtitle, icon, volume, muted, ids: [int] }
    property var streams: []
    // Key der Gruppe, die gerade gezogen wird (Poll darf sie nicht ueberschreiben)
    property string draggingGroupKey: ""
    property var _pendingStreamVol: null
    property var _pendingSystemVol: null
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
    property Process getProc
    property Process setProc
    property Process muteProc
    property Process getStreamsProc
    property Process setStreamVolProc
    property Process muteStreamProc

    // ==== Icon-Aufloesung ====
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

    // ==== Gruppen-Key fuer einen sink-input ====
    // Alle Streams derselben App landen in einer Gruppe.
    function groupKeyFor(props) {
        const name = (props["application.name"] || "").toLowerCase().trim();
        if (name !== "")
            return "app:" + name;

        const bin = (props["application.process.binary"] || "").toLowerCase().trim();
        if (bin !== "")
            return "bin:" + bin;

        const node = (props["node.name"] || "").toLowerCase().trim();
        if (node !== "")
            return "node:" + node;

        return "unknown";
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
        draggingGroupKey = "";
        autoCloseTimer.stop();
    }

    function restartAutoClose() {
        autoCloseTimer.restart();
    }

    function toggleExpanded() {
        expanded = !expanded;
        if (expanded) {
            restartAutoClose();
            getStreamsProc.running = true;
        }
    }

    // ==== System-Volume ====
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

    // ==== Stream-Aktionen (arbeiten auf Gruppen) ====
    function _findGroup(key) {
        for (let i = 0; i < streams.length; i++) {
            if (streams[i].key === key)
                return streams[i];

        }
        return null;
    }

    function _patchStream(key, patch) {
        const arr = streams.slice();
        for (let i = 0; i < arr.length; i++) {
            if (arr[i].key === key) {
                arr[i] = Object.assign({
                }, arr[i], patch);
                break;
            }
        }
        streams = arr;
    }

    // Setzt die Lautstaerke fuer alle Streams einer Gruppe auf einmal.
    function _runStreamVol(ids, val) {
        const pct = Math.round(val * 100) + "%";
        // pactl kennt nur einen Sink-Input pro Aufruf -> bash-Loop.
        const cmds = ids.map((id) => {
            return "pactl set-sink-input-volume " + id + " " + pct;
        }).join("; ");
        setStreamVolProc.command = ["bash", "-c", cmds];
        setStreamVolProc.running = true;
    }

    function setStreamVolume(key, val) {
        const safeVal = Math.max(0, Math.min(val, 1));
        const group = _findGroup(key);
        if (!group)
            return ;

        if (setStreamVolProc.running)
            _pendingStreamVol = {
            "key": key,
            "val": safeVal
        };
        else
            _runStreamVol(group.ids, safeVal);
        _patchStream(key, {
            "volume": safeVal
        });
    }

    // Toggelt Mute fuer alle Streams einer Gruppe.
    function _runStreamMute(ids, muteOn) {
        const arg = muteOn ? "1" : "0";
        const cmds = ids.map((id) => {
            return "pactl set-sink-input-mute " + id + " " + arg;
        }).join("; ");
        muteStreamProc.command = ["bash", "-c", cmds];
        muteStreamProc.running = true;
    }

    function toggleStreamMute(key) {
        const group = _findGroup(key);
        if (!group)
            return ;

        const newMuted = !group.muted;
        _runStreamMute(group.ids, newMuted);
        _patchStream(key, {
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
                    const groups = {
                    };
                    for (const item of data) {
                        const props = item.properties || {
                        };
                        const appName = props["application.name"] || props["media.name"] || "Unknown";
                        const mediaName = props["media.name"] || "";
                        const key = root.groupKeyFor(props);
                        let vol = 0.5;
                        if (item.volume) {
                            const ch = Object.keys(item.volume)[0];
                            if (ch && item.volume[ch] && item.volume[ch].value_percent)
                                vol = parseFloat(item.volume[ch].value_percent) / 100;

                        }
                        if (!groups[key])
                            groups[key] = {
                                "key": key,
                                "name": appName,
                                "subtitle": mediaName !== appName ? mediaName : "",
                                "icon": root.resolveIcon(props),
                                "ids": [],
                                "vols": [],
                                "mutedCount": 0,
                                "total": 0
                            };

                        const g = groups[key];
                        g.ids.push(item.index);
                        g.vols.push(vol);
                        g.total += 1;
                        if (item.mute)
                            g.mutedCount += 1;

                    }
                    const arr = [];
                    for (const k in groups) {
                        const g = groups[k];
                        // Durchschnitts-Volume, aber wenn die Gruppe gerade
                        // gezogen wird, den lokalen Wert behalten.
                        let avg = 0;
                        if (g.vols.length > 0) {
                            for (const v of g.vols) avg += v
                            avg = avg / g.vols.length;
                        }
                        if (k === root.draggingGroupKey) {
                            const existing = root._findGroup(k);
                            if (existing)
                                avg = existing.volume;

                        }
                        // Als "muted" zaehlt nur, wenn ALLE Streams gemutet sind.
                        const allMuted = g.mutedCount === g.total;
                        // Subtitle: bei mehreren Streams "N streams" anzeigen.
                        let subtitle = g.subtitle;
                        if (g.total > 1)
                            subtitle = g.total + " streams";

                        arr.push({
                            "key": g.key,
                            "name": g.name,
                            "subtitle": subtitle,
                            "icon": g.icon,
                            "volume": avg,
                            "muted": allMuted,
                            "ids": g.ids
                        });
                    }
                    arr.sort((a, b) => {
                        if (a.ids.length === 0 || b.ids.length === 0)
                            return 0;

                        return a.ids[0] - b.ids[0];
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
                const group = root._findGroup(p.key);
                if (group)
                    root._runStreamVol(group.ids, p.val);

            }
        }
    }

    muteStreamProc: Process {
    }

    // ==== Timer ====
    autoCloseTimer: Timer {
        interval: 4000
        onTriggered: {
            if (!root.hovered && root.draggingGroupKey === "")
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
        // Pausiert waehrend eines Drags, damit der Slider nicht springt.
        interval: 800
        running: root.expanded && root.open && root.draggingGroupKey === ""
        repeat: true
        onTriggered: {
            if (!getStreamsProc.running)
                getStreamsProc.running = true;

        }
    }

}
