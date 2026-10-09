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
            const blacklist = ["qt5", "assistant", "designer", "linguist", "qdbus", "qv4l2", "qvidcap", "avahi", "bch", "hvd", "javaws", "nvidiasettings", "displaytest", "iconbrowser", "system-config", "stoken", "emu-manager", "cmake", "texdoctk", "uuctl", "wpgtk", "xgps", "Wine", "Rofi", "Xfce", "Ark", "Blackmagic", "Cppcheck", "lstopo", "OpenJDK", "rmpc", "Electron", "Advanced Network", "Htop", "Base", "Calc", "Draw", "Impress", "Math"];
            for (let line of lines) {
                const parts = line.split('|');
                if (parts.length >= 3) {
                    let name = parts[0].trim();
                    let exec = parts[1].trim();
                    let icon = parts[2] ? parts[2].trim() : "";
                    let needsTerminal = (parts[3] && parts[3].trim() === "true");
                    exec = exec.replace(/%[fFuUikcnvezt]/g, "").trim();
                    const fullNameInfo = (name + " " + exec).toLowerCase();
                    const isBlacklisted = blacklist.some((item) => {
                        return fullNameInfo.includes(item.toLowerCase());
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

}
