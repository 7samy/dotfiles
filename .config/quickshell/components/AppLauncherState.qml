import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

QtObject {
    id: root

    readonly property bool launcherVisible: PickerManager.isOpen("app")
    property var allApps: []
    property bool appsLoaded: false
    property bool appsLoading: false
    // ==== 1. Cache synchron beim Start lesen ====
    // Wenn /tmp/qs-apps.list existiert, wird sie sofort geladen –
    // noch bevor der Launcher das erste Mal geöffnet wird.
    property FileView cacheFile

    cacheFile: FileView {
        path: "/tmp/qs-apps.list"
        blockLoading: true
        watchChanges: false
        onLoaded: {
            if (text && text.length > 0) {
                root.parseApplications(text);
                console.log("Apps aus Cache geladen:", root.allApps.length);
            }
        }
    }

    // ==== 2. Scan läuft parallel im Hintergrund ====
    // Aktualisiert den Cache, falls sich Apps geändert haben.
    // Blockiert nicht, aber der Launcher hat durch den Cache
    // sofort Daten.
    property Process appsProcess

    appsProcess: Process {
        running: true
        command: ["awk", "-F", "=", "FNR==1 {", "  if (NR > 1 && type==\"Application\" && !nodisplay && !hidden && name != \"\" && exec != \"\") {", "    print name \"|\" exec \"|\" icon \"|\" terminal;", "  }", "  type=nodisplay=hidden=name=exec=icon=terminal=\"\";", "  in_de=0;", "}", "/^\\[Desktop Entry\\]/ { in_de=1; next }", "/^\\[/ { in_de=0 }", "in_de && /^Type=/ { type=substr($0, 6) }", "in_de && /^NoDisplay=/ { nodisplay=(substr($0, 11)==\"true\") }", "in_de && /^Hidden=/ { hidden=(substr($0, 8)==\"true\") }", "in_de && /^Name=/ && name == \"\" { name=substr($0, 6) }", "in_de && /^Exec=/ && exec == \"\" { exec=substr($0, 6) }", "in_de && /^Icon=/ && icon == \"\" { icon=substr($0, 6) }", "in_de && /^Terminal=/ { terminal=substr($0, 10) }", "END {", "  if (type==\"Application\" && !nodisplay && !hidden && name != \"\" && exec != \"\") {", "    print name \"|\" exec \"|\" icon \"|\" terminal;", "  }", "}", "/usr/share/applications/*.desktop", "/var/lib/flatpak/exports/share/applications/*.desktop", "/home/azu/.local/share/flatpak/exports/share/applications/*.desktop"]

        stdout: StdioCollector {
            id: appsStdout

            onStreamFinished: {
                // 1. In den State übernehmen (aktualisiert die Liste live)
                root.parseApplications(text);
                // 2. Cache auf Platte schreiben fuer den naechsten Start
                cacheWriter.command = ["bash", "-c", "cat > /tmp/qs-apps.list"];
                cacheWriter.stdinEnabled = true;
                cacheWriter.running = true;
                cacheWriter.write(text);
                cacheWriter.stdinEnabled = false;
            }
        }

    }

    // Hilfs-Prozess zum Cache-Schreiben
    property Process cacheWriter

    cacheWriter: Process {
        stdinEnabled: true
    }

    function loadApps() {
        // Nur noch fuer manuellen Re-Scan – beim Start laeuft der
        // Process automatisch (running: true oben).
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
