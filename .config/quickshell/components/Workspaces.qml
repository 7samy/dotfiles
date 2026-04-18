import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Qt5Compat.GraphicalEffects

Item {
    id: workspaceWidget
    implicitWidth: bg.implicitWidth
    implicitHeight: 40

    property var iconCache: ({})
    property string steamPath: ""
    property var steamGameMap: ({})

    Component.onCompleted: {
        findSteamPathAndGames()
    }

    function findSteamPathAndGames() {
        let user = Qt.environmentVariables().USER
        let paths = [
            "/home/" + user + "/.local/share/Steam",
            "/home/" + user + "/.steam/steam"
        ]
        
        // Einfacherer Check via Shell
        let checkProc = Process.create()
        checkProc.command = ["sh", "-c", `for p in ${paths.join(" ")}; do if [ -d "$p" ]; then echo "$p"; break; fi; done`]
        
        let output = ""
        let collector = StdioCollector.create()
        collector.onRead.connect(data => { output += data })
        checkProc.stdout = collector
        
        checkProc.onFinished.connect(() => {
            let found = output.trim()
            if (found) {
                steamPath = found
                console.log("Steam Pfad gefunden:", steamPath)
                loadSteamGames()
            }
        })
        checkProc.running = true
    }

    function loadSteamGames() {
        if (!steamPath) return
        let manifestDir = steamPath + "/steamapps/"
        
        let proc = Process.create()
        // Extrahiert AppID und Name direkt paarweise aus allen .acf Dateien
        proc.command = ["sh", "-c", `grep -hE '("appid"|"name")' ${manifestDir}appmanifest_*.acf | awk -F'寿' '{print $4}' | sed 'N;s/\\n/|/'`]
        
        let output = ""
        let collector = StdioCollector.create()
        collector.onRead.connect(data => { output += data })
        proc.stdout = collector
        
        proc.onFinished.connect(() => {
            let lines = output.trim().split("\n")
            for (let line of lines) {
                let parts = line.split("|")
                if (parts.length === 2) {
                    let id = parts[0]
                    let name = parts[1].toLowerCase()
                    steamGameMap[name] = id
                }
            }
            console.log("Steam Spiele geladen:", Object.keys(steamGameMap).length)
        })
        proc.running = true
    }

    function resolveIcon(winClass, winTitle, callback) {
        if (!winClass) { callback(""); return; }
        let lClass = winClass.toLowerCase()

        if (lClass === "steam") {
            callback("steam")
            return
        }

        if (lClass === "gamescope" && winTitle) {
            let lowerTitle = winTitle.toLowerCase()
            for (let gameName in steamGameMap) {
                if (lowerTitle.includes(gameName)) {
                    let appId = steamGameMap[gameName]
                    let iconPath = `file:///home/${Qt.environmentVariables().USER}/.local/share/icons/hicolor/64x64/apps/steam_icon_${appId}.png`
                    callback(iconPath)
                    return
                }
            }
            callback("steam")
            return
        }

        let entry = DesktopEntries.heuristicLookup(winClass)
        if (entry && entry.icon) {
            callback(entry.icon)
        } else {
            callback(lClass)
        }
    }

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
                required property var modelData
                readonly property bool isFocused: modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id
                readonly property var biggestWindow: HyprlandData.biggestWindowForWorkspace(modelData.id)

                property string currentIcon: ""
                property bool iconValid: false

                onBiggestWindowChanged: {
                    if (biggestWindow) {
                        resolveIcon(biggestWindow.class, biggestWindow.title, (icon) => {
                            currentIcon = icon
                            iconValid = (icon !== "")
                        })
                    } else {
                        currentIcon = ""
                        iconValid = false
                    }
                }

                width: 35 + (isFocused ? 20 : 0)
                height: 40
                Behavior on width { NumberAnimation { duration: 300 } }

                Rectangle {
                    anchors.centerIn: parent
                    width: isFocused ? 36 : 32
                    height: width
                    opacity: isFocused ? 1 : 0.4
                    radius: 10
                    color: isFocused ? "#33ffffff" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: isFocused ? "white" : WalColors.color2
                        text: modelData.id.toString()
                        visible: !wsDelegate.iconValid
                    }

                    Item {
                        anchors.fill: parent
                        visible: wsDelegate.iconValid
                        anchors.margins: 4

                        Image {
                            id: dynamicIcon
                            anchors.fill: parent
                            source: {
                                if (!currentIcon) return ""
                                if (currentIcon.startsWith("file://")) return currentIcon
                                return "image://icon/" + currentIcon
                            }
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            onStatusChanged: if (status === Image.Error) currentIcon = "steam"
                        }

                        Desaturate {
                            anchors.fill: dynamicIcon
                            source: dynamicIcon
                            desaturation: isFocused ? 0.0 : 1.0
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + modelData.id)
                }
            }
        }
    }
}
