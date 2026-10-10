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
    // Jeder: { id, name, icon, volume, muted }
    property var streams: []
    property Timer autoCloseTimer
    property Timer pollTimer
    property Timer streamsRefreshTimer
    // ==== Prozesse ====
    property Process getProc

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

    property Process setProc

    setProc: Process {
    }

    property Process muteProc

    muteProc: Process {
    }

    property Process getStreamsProc

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
                        let iconName = props["application.icon_name"] || "";
                        if (!iconName)
                            iconName = appName.toLowerCase().replace(/\s+/g, "-");

                        let vol = 0.5;
                        if (item.volume && item.volume["front-left"]) {
                            const pct = item.volume["front-left"].value_percent;
                            if (pct)
                                vol = parseFloat(pct) / 100;

                        }
                        arr.push({
                            "id": item.index,
                            "name": appName,
                            "icon": iconName,
                            "volume": vol,
                            "muted": item.mute || false
                        });
                    }
                    root.streams = arr;
                } catch (e) {
                    console.error("[VolumeSliderState] Failed to parse pactl output:", e);
                    root.streams = [];
                }
            }
        }

    }

    property Process setStreamVolProc

    setStreamVolProc: Process {
    }

    property Process muteStreamProc

    muteStreamProc: Process {
    }

    // ==== Popup öffnen/schließen ====
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
    function setSystemVolume(val) {
        const safeVal = Math.max(0, Math.min(val, 1));
        root.systemVolume = safeVal;
        setProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", safeVal.toFixed(3)];
        setProc.running = true;
    }

    function toggleSystemMute() {
        root.systemMuted = !root.systemMuted;
        muteProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", root.systemMuted ? "1" : "0"];
        muteProc.running = true;
    }

    // ==== Stream-Aktionen ====
    function setStreamVolume(id, val) {
        const safeVal = Math.max(0, Math.min(val, 1));
        setStreamVolProc.command = ["pactl", "set-sink-input-volume", String(id), Math.round(safeVal * 100) + "%"];
        setStreamVolProc.running = true;
        // Lokales Update für sofortiges Feedback
        const arr = streams.slice();
        for (let i = 0; i < arr.length; i++) {
            if (arr[i].id === id) {
                const copy = Object.assign({
                }, arr[i]);
                copy.volume = safeVal;
                arr[i] = copy;
                break;
            }
        }
        streams = arr;
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
        const arr = streams.slice();
        for (let i = 0; i < arr.length; i++) {
            if (arr[i].id === id) {
                const copy = Object.assign({
                }, arr[i]);
                copy.muted = newMuted;
                arr[i] = copy;
                break;
            }
        }
        streams = arr;
    }

    // ==== Timer ====
    autoCloseTimer: Timer {
        interval: 4000
        onTriggered: {
            if (!root.hovered)
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
