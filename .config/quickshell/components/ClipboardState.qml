import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property string tempDir: "/tmp/qs-clip-images"
    readonly property int imageLimit: 40
    readonly property int textLimit: 300
    readonly property bool pickerVisible: PickerManager.isOpen("clipboard")
    property var entries: []
    property bool loaded: false
    property string signature: ""
    property var readyIds: ({
    })
    property var attempted: ({
    })
    property bool decodeQueued: false
    readonly property string decodeScript: 'dir="$1"; shift; mkdir -p "$dir"; for spec in "$@"; do id="${spec%%:*}"; ext="${spec##*:}"; f="$dir/$id.$ext"; if [ -s "$f" ] || { cliphist decode "$id" > "$f" 2>/dev/null && [ -s "$f" ]; }; then echo "$id"; else rm -f "$f"; fi; done'

    function refresh() {
        if (!listProc.running)
            listProc.running = true;

    }

    function copyEntry(e) {
        Quickshell.execDetached(["bash", "-c", 'if [ -n "$2" ]; then cliphist decode "$1" | wl-copy -t "$2"; else cliphist decode "$1" | wl-copy; fi', "qs-clip", String(e.id), e.mime || ""]);
    }

    function openImage(e) {
        Quickshell.execDetached(["swayimg", e.path]);
    }

    function deleteEntry(id) {
        entries = entries.filter((e) => {
            return e.id !== id;
        });
        signature = entries.map((e) => {
            return e.id;
        }).join(",");
        const r = Object.assign({
        }, readyIds);
        delete r[id];
        readyIds = r;
        Quickshell.execDetached(["bash", "-c", 'printf "%s\\tx\\n" "$1" | cliphist delete; rm -f "$2"/"$1".*', "qs-clip", String(id), tempDir]);
    }

    function wipe() {
        entries = [];
        signature = "";
        readyIds = ({
        });
        attempted = ({
        });
        Quickshell.execDetached(["bash", "-c", 'cliphist wipe; rm -rf "$1"', "qs-clip", tempDir]);
    }

    function detectExt(preview) {
        if (!preview.startsWith("[[ binary data"))
            return "";

        const m = preview.toLowerCase().match(/\b(png|jpe?g|gif|webp|bmp)\b/);
        if (!m)
            return "";

        return m[1] === "jpeg" ? "jpg" : m[1];
    }

    function mimeFor(ext) {
        switch (ext) {
        case "png":
            return "image/png";
        case "jpg":
            return "image/jpeg";
        case "gif":
            return "image/gif";
        case "webp":
            return "image/webp";
        case "bmp":
            return "image/bmp";
        }
        return "";
    }

    function imageMeta(preview) {
        const m = preview.match(/binary data\s+([\d.]+\s*\S+)\s+\S+\s+(\d+)x(\d+)/i);
        return m ? (m[2] + "×" + m[3] + "  ·  " + m[1]) : "";
    }

    function textKind(t) {
        if (/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(t))
            return "color";

        if (/^(https?|ftp):\/\/\S+$/i.test(t) || /^www\.\S+$/i.test(t))
            return "url";

        return "text";
    }

    function parseList(text) {
        const parsed = [];
        for (const line of text.split("\n")) {
            const m = line.match(/^(\d+)\s+(.*)$/);
            if (!m)
                continue;

            const id = m[1];
            const preview = m[2].replace(/\r$/, "");
            const ext = detectExt(preview);
            if (ext !== "") {
                parsed.push({
                    "id": id,
                    "preview": preview,
                    "hay": preview.toLowerCase(),
                    "label": preview,
                    "isImage": true,
                    "ext": ext,
                    "mime": mimeFor(ext),
                    "path": tempDir + "/" + id + "." + ext,
                    "kind": "image",
                    "meta": imageMeta(preview)
                });
            } else {
                const label = preview.replace(/\s+/g, " ").trim();
                if (label === "")
                    continue;

                parsed.push({
                    "id": id,
                    "preview": preview,
                    "hay": label.toLowerCase(),
                    "label": label,
                    "isImage": false,
                    "ext": "",
                    "mime": "",
                    "path": "",
                    "kind": textKind(label),
                    "meta": ""
                });
            }
        }
        const sig = parsed.map((e) => {
            return e.id;
        }).join(",");
        if (sig !== signature) {
            entries = parsed;
            signature = sig;
        }
        loaded = true;
        startDecode();
    }

    function startDecode() {
        const specs = [];
        let seen = 0;
        for (const e of entries) {
            if (!e.isImage)
                continue;

            if (++seen > imageLimit)
                break;

            if (readyIds[e.id] || attempted[e.id])
                continue;

            specs.push(e.id + ":" + e.ext);
        }
        if (specs.length === 0)
            return ;

        if (decodeProc.running) {
            decodeQueued = true;
            return ;
        }
        for (const s of specs) attempted[s.split(":")[0]] = true
        decodeProc.command = ["bash", "-c", decodeScript, "qs-clip", tempDir].concat(specs);
        decodeProc.running = true;
    }

    function markReady(id) {
        if (id === "" || readyIds[id])
            return ;

        const c = Object.assign({
        }, readyIds);
        c[id] = true;
        readyIds = c;
    }

    function toggle() {
        PickerManager.toggle("clipboard");
    }

    function open() {
        PickerManager.open("clipboard");
    }

    function close() {
        if (PickerManager.isOpen("clipboard"))
            PickerManager.close();

    }

    Process {
        id: listProc

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[ClipboardState] listProc finished, bytes:", text.length);
                root.parseList(text);
            }
        }

    }

    Process {
        id: decodeProc

        onRunningChanged: {
            if (!running && root.decodeQueued) {
                root.decodeQueued = false;
                root.startDecode();
            }
        }

        stdout: SplitParser {
            onRead: (line) => {
                return root.markReady(line.trim());
            }
        }

    }

    // Refresh einmal beim Öffnen
    Connections {
        function onActivePickerChanged() {
            if (PickerManager.activePicker === "clipboard")
                root.refresh();

        }

        target: PickerManager
    }

    // NEU: Refresh laufend alle 500ms, solange Picker offen ist.
    // cliphist hat keinen Watch-Mechanismus, deshalb pollen wir.
    Timer {
        id: liveRefreshTimer

        interval: 500
        running: root.pickerVisible
        repeat: true
        onTriggered: root.refresh()
    }

}
