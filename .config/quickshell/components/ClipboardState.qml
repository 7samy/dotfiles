import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: root

    readonly property bool pickerVisible: PickerManager.isOpen("clipboard")
    readonly property string tempDir: "/tmp/qs-clip-images"
    property var entries: []
    property bool loaded: false
    // Session-Cache: cliphist-ID -> Dateipfad (bleibt ueber Reopens erhalten)
    property var imageCache: ({
    })
    // Decode-Queue (eine zur Zeit, nie mehrere parallel)
    property var pendingImages: []
    property bool imageLoaderBusy: false
    // ==== Prozesse ====
    property Process listProcess

    listProcess: Process {
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: root.parseList(text)
        }

    }

    property Process copyProcess

    copyProcess: Process {
    }

    property Process deleteProcess

    deleteProcess: Process {
    }

    property Process wipeProcess

    wipeProcess: Process {
        command: ["bash", "-c", "cliphist wipe; rm -rf " + tempDir]
        onRunningChanged: {
            if (!running) {
                root.imageCache = ({
                });
                root.refresh();
            }
        }
    }

    property Process imageLoader

    imageLoader: Process {
        property string entryId: ""
        property int entryIndex: -1
        property string imagePath: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const result = text.trim();
                console.log("[ClipboardState] decode", imageLoader.entryId, "->", imageLoader.imagePath, "| result:", result);
                if (result === "ok")
                    root.markImageReady(imageLoader.entryIndex, imageLoader.entryId, imageLoader.imagePath);

                root.imageLoaderBusy = false;
                root.processNextImage();
            }
        }

    }

    property Timer refreshTimer

    refreshTimer: Timer {
        interval: 80
        onTriggered: root.refresh()
    }

    function refresh() {
        listProcess.running = true;
    }

    function copyEntry(id) {
        copyProcess.command = ["bash", "-c", "cliphist decode " + id + " | wl-copy"];
        copyProcess.running = true;
        PickerManager.close();
    }

    function openImage(id) {
        const cached = imageCache[id];
        if (!cached) {
            console.warn("[ClipboardState] openImage: kein Pfad fuer id", id);
            return ;
        }
        Quickshell.execDetached(["swayimg", cached]);
        PickerManager.close();
    }

    function deleteEntry(id) {
        const c = Object.assign({
        }, imageCache);
        delete c[id];
        imageCache = c;
        deleteProcess.command = ["bash", "-c", "cliphist delete " + id + "; rm -f " + tempDir + "/" + id + ".*"];
        deleteProcess.running = true;
        refreshTimer.restart();
    }

    function wipe() {
        wipeProcess.running = true;
    }

    // ==== Erkennung & Parsing ====
    function detectMime(preview) {
        if (!preview.startsWith("[[ binary data"))
            return "";

        const lower = preview.toLowerCase();
        if (lower.indexOf(" png ") !== -1)
            return "png";

        if (lower.indexOf(" jpeg ") !== -1 || lower.indexOf(" jpg ") !== -1)
            return "jpg";

        if (lower.indexOf(" gif ") !== -1)
            return "gif";

        if (lower.indexOf(" webp ") !== -1)
            return "webp";

        if (lower.indexOf(" bmp ") !== -1)
            return "bmp";

        return "";
    }

    function parseList(text) {
        const lines = text.split('\n').filter((l) => {
            return l.trim() !== '';
        });
        const parsed = [];
        for (const line of lines) {
            // Robust: erste Zahl ist die ID, Rest ist Preview.
            // Funktioniert mit Tab ODER Space als Trenner.
            const m = line.match(/^(\d+)\s+(.*)$/);
            if (!m)
                continue;

            const id = m[1];
            const preview = m[2].replace(/\r$/, "");
            const ext = detectMime(preview);
            const isImage = ext !== "";
            const cached = (isImage && imageCache[id]) ? imageCache[id] : "";
            parsed.push({
                "id": id,
                "preview": preview,
                "isImage": isImage,
                "ext": ext,
                "imagePath": cached || (isImage ? tempDir + "/" + id + "." + ext : ""),
                "imageReady": isImage && cached !== ""
            });
        }
        entries = parsed;
        loaded = true;
        console.log("[ClipboardState] parsed:", parsed.length, "entries,", parsed.filter((e) => {
            return e.isImage;
        }).length, "images");
        queueImageLoads();
    }

    function queueImageLoads() {
        const queue = [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.isImage && !e.imageReady)
                queue.push({
                    "id": e.id,
                    "index": i,
                    "path": e.imagePath
                });

        }
        pendingImages = queue;
        processNextImage();
    }

    function processNextImage() {
        if (imageLoaderBusy || pendingImages.length === 0)
            return ;

        imageLoaderBusy = true;
        const next = pendingImages.shift();
        imageLoader.entryId = next.id;
        imageLoader.entryIndex = next.index;
        imageLoader.imagePath = next.path;
        imageLoader.command = ["bash", "-c", "mkdir -p " + tempDir + " && cliphist decode " + next.id + " > \"" + next.path + "\" 2>/dev/null && test -s \"" + next.path + "\" && echo ok || echo fail"];
        imageLoader.running = true;
    }

    function markImageReady(index, id, path) {
        const c = Object.assign({
        }, imageCache);
        c[id] = path;
        imageCache = c;
        const newEntries = entries.slice();
        const updated = Object.assign({
        }, newEntries[index]);
        updated.imageReady = true;
        newEntries[index] = updated;
        entries = newEntries;
    }

    function toggle() {
        PickerManager.toggle("clipboard");
    }

    function close() {
        if (PickerManager.isOpen("clipboard"))
            PickerManager.close();

    }

    function open() {
        PickerManager.open("clipboard");
    }

}
