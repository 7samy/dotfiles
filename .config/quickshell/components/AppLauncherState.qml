import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: root

    readonly property bool launcherVisible: PickerManager.isOpen("app")
    // Alle geladenen Apps. Wird einmal beim Start befuellt und bleibt
    // als leichtes Array (~50 KB) im RAM – kostet fast nichts, spart
    // aber den Neu-Scan beim Wiederoeffnen des Launchers.
    property var allApps: []
    property bool appsLoaded: false
    property bool appsLoading: false
    // Process-Instanz im Singleton – laeuft einmal beim Start.
    // Bash expandiert die Globs (Quickshell selbst kann das nicht).
    property Process appsProcess

    function loadApps() {
        if (root.appsLoaded || root.appsLoading)
            return ;

        root.appsLoading = true;
        root.appsProcess.running = true;
    }

    function parseApplications(rawText) {
        try {
            const lines = rawText.split('\n').filter((l) => {
                return l.trim();
            });
            const apps = [];
            // Blacklist: exakte Namen (case-insensitive) ODER eindeutige
            // Exec-Fragmente. Kurze generische Woerter wie "draw", "calc",
            // "base", "math" wurden entfernt, weil sie andere Apps wie
            // drawio faelschlich ausblenden.
            const blacklistExact = ["qt5", "assistant", "designer", "linguist", "qdbus", "qv4l2", "qvidcap", "avahi", "bch", "hvd", "javaws", "nvidiasettings", "displaytest", "iconbrowser", "system-config", "stoken", "emu-manager", "cmake", "texdoctk", "uuctl", "wpgtk", "xgps", "wine", "rofi", "xfce", "ark", "blackmagic", "cppcheck", "lstopo", "openjdk", "rmpc", "electron", "advanced network", "htop", "libreoffice base", "libreoffice calc", "libreoffice draw", "libreoffice impress", "libreoffice math"];
            // Exec-basierte Filter: pruefen den Exec-Befehl, nicht den Namen.
            const blacklistExec = ["libreoffice --base", "libreoffice --calc", "libreoffice --draw", "libreoffice --impress", "libreoffice --math"];
            for (let line of lines) {
                const parts = line.split('|');
                if (parts.length >= 3) {
                    let name = parts[0].trim();
                    let exec = parts[1].trim();
                    let icon = parts[2] ? parts[2].trim() : "";
                    let needsTerminal = (parts[3] && parts[3].trim() === "true");
                    exec = exec.replace(/%[fFuUikcnvezt]/g, "").trim();
                    const nameLower = name.toLowerCase();
                    const execLower = exec.toLowerCase();
                    const isBlacklisted = blacklistExact.some((item) => {
                        return nameLower === item;
                    }) || blacklistExec.some((item) => {
                        return execLower.includes(item);
                    });
                    if (name && exec && !isBlacklisted)
                        apps.push({
                        "name": name,
                        "exec": exec,
                        "icon": icon,
                        "terminal": needsTerminal
                    });

                }
            }
            root.allApps = apps.filter((v, i, a) => {
                return a.findIndex((t) => {
                    return (t.name === v.name);
                }) === i;
            }).sort((a, b) => {
                return a.name.localeCompare(b.name);
            });
            root.appsLoaded = true;
            console.log("Geladene Apps:", root.allApps.length);
        } catch (e) {
            console.error("Error parsing applications:", e);
        }
        root.appsLoading = false;
    }

    function toggle() {
        PickerManager.toggle("app");
    }

    function close() {
        if (PickerManager.isOpen("app"))
            PickerManager.close();

    }

    function open() {
        PickerManager.open("app");
    }

    appsProcess: Process {
        running: true
        command: ["bash", "-c", "for f in /usr/share/applications/*.desktop /var/lib/flatpak/exports/share/applications/*.desktop /home/azu/.local/share/flatpak/exports/share/applications/*.desktop; do \
            [ -f \"$f\" ] || continue; \
            grep -q '^Type=Application' \"$f\" || continue; \
            grep -q '^NoDisplay=true' \"$f\" && continue; \
            grep -q '^Hidden=true' \"$f\" && continue; \
            name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); \
            exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-); \
            icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); \
            terminal=$(grep -m1 '^Terminal=' \"$f\" | cut -d= -f2-); \
            echo \"$name|$exec|$icon|$terminal\"; \
        done"]

        stdout: StdioCollector {
            onStreamFinished: root.parseApplications(text)
        }

    }

}
