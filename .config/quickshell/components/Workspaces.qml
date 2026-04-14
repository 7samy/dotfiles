import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Qt5Compat.GraphicalEffects

Item {
    id: workspaceWidget
    implicitWidth: bg.implicitWidth
    implicitHeight: 40

    // Cache: Titel/AppID -> Icon-Pfad
    property var iconCache: ({})
    property var steamPath: ""

    // Initialisierung: Steam-Pfad einmalig ermitteln
    Component.onCompleted: {
        steamPath = findSteamPath()
        console.log("Steam path:", steamPath)
    }

    // Hilfsfunktion: synchronen Shell-Befehl ausführen und stdout zurückgeben
    function runCmd(cmd) {
        let proc = Process.create()
        proc.command = ["sh", "-c", cmd]
        let output = ""
        let parser = StdioCollector.create()
        parser.delimiter = "\n"
        parser.onRead.connect(function(data) { output += data })
        proc.stdout = parser
        proc.running = true
        proc.waitForFinished(-1)
        return output.trim()
    }

    // Steam-Installationspfad finden
    function findSteamPath() {
        let user = Qt.environmentVariables().USER
        let paths = [
            "/home/" + user + "/.local/share/Steam",
            "/home/" + user + "/.steam/steam"
        ]
        for (let p of paths) {
            if (runCmd("test -d " + p + " && echo 'yes'") === "yes") {
                return p
            }
        }
        return ""
    }

    // Aus einem Fenstertitel die Steam-App-ID ermitteln
    function getAppIdFromTitle(title) {
        if (!steamPath || title === "") return ""
        let manifestDir = steamPath + "/steamapps/"
        // Einmalig alle Manifest-Dateien einlesen (wird pro Titel aufgerufen, aber durch Cache abgefangen)
        let files = runCmd("ls " + manifestDir + "appmanifest_*.acf 2>/dev/null")
        if (files === "") return ""
        let manifests = files.split("\n")
        for (let m of manifests) {
            // Extrahiere App-ID aus Dateinamen
            let match = m.match(/appmanifest_(\d+)\.acf/)
            if (!match) continue
            let appId = match[1]
            // Lese den Spielnamen aus der Datei (nur einmal pro AppId cachen)
            let name = runCmd("grep -m1 '\"name\"' " + m + " | cut -d'\"' -f4")
            if (name !== "" && title.toLowerCase().indexOf(name.toLowerCase()) !== -1) {
                return appId
            }
        }
        return ""
    }

    // Icon-Pfad für eine Steam-App-ID finden
    function getSteamIconPath(appId) {
        if (!appId) return ""
        // Suche in verschiedenen Größen (priorisiere 64x64 oder 48x48)
        let sizes = ["64x64", "48x64", "128x128", "256x256", "32x32"]
        for (let sz of sizes) {
            let iconPath = "/home/" + Qt.environmentVariables().USER + "/.local/share/icons/hicolor/" + sz + "/apps/steam_icon_" + appId + ".png"
            if (runCmd("test -f " + iconPath + " && echo 'yes'") === "yes") {
                return "file://" + iconPath
            }
        }
        // Fallback: im Steam-Verzeichnis nach .ico suchen (selten)
        let icoPath = steamPath + "/games/steam_icon_" + appId + ".ico"
        if (runCmd("test -f " + icoPath + " && echo 'yes'") === "yes") {
            return "file://" + icoPath
        }
        return ""
    }

    // Hauptfunktion: Icon für ein Fenster ermitteln
    function getCustomIconForWindow(winClass, winTitle) {
        // Manuelle Ausnahmen (für nicht-Steam-Apps)
        const titleMap = {
            "tmux_nvim": "file:///home/azu/.config/quickshell/resources/icons/tmux.png"
        }
        if (winTitle && titleMap[winTitle]) return titleMap[winTitle]

        const classMap = {
            "code-oss": "code-oss",
            "code": "visual-studio-code",
            "zen-alpha": "zen-browser",
            "zen": "zen-browser",
            "yazi": "yazi"
        }
        if (winClass && classMap[winClass]) return classMap[winClass]

        // Steam selbst
        if (winClass === "steam") {
            return "steam"   // wird über image://icon/... aufgelöst
        }

        // Gamescope (Steam-Spiele)
        if (winClass === "gamescope" && winTitle) {
            let cacheKey = "gamescope_" + winTitle
            if (iconCache[cacheKey]) return iconCache[cacheKey]

            let appId = getAppIdFromTitle(winTitle)
            if (appId) {
                let iconPath = getSteamIconPath(appId)
                if (iconPath) {
                    iconCache[cacheKey] = iconPath
                    return iconPath
                }
            }
            // Fallback: generisches Spiel-Icon (du kannst auch "steam" nehmen)
            iconCache[cacheKey] = "steam"
            return "steam"
        }

        // Normale Desktop-Apps
        if (winClass) {
            let entry = DesktopEntries.heuristicLookup(winClass)
            if (entry && entry.icon) return entry.icon
            return winClass.toLowerCase()
        }
        return ""
    }

    // UI-Teil (unverändert, bis auf die Verwendung der obigen Funktion)
    Rectangle {
        id: bg
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + 16
        height: 40
        radius: 13
        color: WalColors.withAlpha(WalColors.color2, 0.2)
        border.color: WalColors.withAlpha(WalColors.color2, 0.4)
        border.width: 2
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: Hyprland.workspaces
            delegate: Item {
                id: wsDelegate
                required property HyprlandWorkspace modelData
                readonly property bool isFocused: modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id
                readonly property var biggestWindow: HyprlandData.biggestWindowForWorkspace(modelData.id)

                readonly property string resolvedIconId: {
                    const win = biggestWindow
                    if (!win) return ""
                    return workspaceWidget.getCustomIconForWindow(win.class, win.title)
                }

                property bool iconValid: false

                width: 35 + (isFocused ? 20 : 0)
                height: 40
                Behavior on width { NumberAnimation { duration: 300 } }

                Rectangle {
                    id: iconBg
                    anchors.centerIn: parent
                    width: isFocused ? 36 : 35
                    height: isFocused ? 36 : 35
                    radius: 11
                    color: isFocused ? "#33ffffff" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: isFocused ? 14 : 13
                        color: isFocused ? "white" : WalColors.withAlpha(WalColors.color2, 0.6)
                        text: biggestWindow ? "" : modelData.id.toString()
                        visible: !wsDelegate.iconValid
                    }

                    Item {
                        anchors.fill: parent
                        visible: wsDelegate.iconValid
                        anchors.margins: isFocused ? 4 : 6

                        Image {
                            id: dynamicIcon
                            anchors.fill: parent
                            source: {
                                if (wsDelegate.resolvedIconId.startsWith("file://"))
                                    return wsDelegate.resolvedIconId
                                else if (wsDelegate.resolvedIconId !== "")
                                    return "image://icon/" + wsDelegate.resolvedIconId
                                else
                                    return ""
                            }
                            sourceSize: Qt.size(48, 48)
                            fillMode: Image.PreserveAspectFit
                            onStatusChanged: {
                                wsDelegate.iconValid = (status === Image.Ready)
                            }
                        }

                        Desaturate {
                            anchors.fill: dynamicIcon
                            source: dynamicIcon
                            desaturation: isFocused ? 0.0 : 1.0
                            opacity: isFocused ? 1.0 : 0.5
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + modelData.id)
                }

                onResolvedIconIdChanged: iconValid = false
            }
        }
    }
}
