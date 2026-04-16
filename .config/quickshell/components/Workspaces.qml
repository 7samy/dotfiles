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
    property var steamPath: ""
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
        let idx = 0
        function tryNext() {
            if (idx >= paths.length) {
                console.log("Steam nicht gefunden")
                return
            }
            let p = paths[idx]
            let proc = Process.create()
            proc.command = ["sh", "-c", "test -d " + p + " && echo 'exists'"]
            proc.running = true
            proc.onFinished.connect(() => {
                let stdout = ""
                let parser = StdioCollector.create()
                parser.onRead.connect((data) => { stdout += data })
                proc.stdout = parser
                proc.running = true
                proc.waitForFinished()
                if (stdout.trim() === "exists") {
                    steamPath = p
                    console.log("Steam Pfad:", steamPath)
                    loadSteamGames()
                } else {
                    idx++
                    tryNext()
                }
            })
        }
        tryNext()
    }

    function loadSteamGames() {
        if (!steamPath) return
        let manifestDir = steamPath + "/steamapps/"
        let proc = Process.create()
        proc.command = ["sh", "-c", "ls " + manifestDir + "appmanifest_*.acf 2>/dev/null"]
        proc.running = true
        proc.onFinished.connect(() => {
            let stdout = ""
            let parser = StdioCollector.create()
            parser.onRead.connect((data) => { stdout += data })
            proc.stdout = parser
            proc.running = true
            proc.waitForFinished()
            let files = stdout.trim().split("\n")
            for (let f of files) {
                if (f === "") continue
                let match = f.match(/appmanifest_(\d+)\.acf/)
                if (!match) continue
                let appId = match[1]
                let nameProc = Process.create()
                nameProc.command = ["grep", "-m1", '"name"', f]
                nameProc.running = true
                nameProc.onFinished.connect(() => {
                    let nameOut = ""
                    let nameParser = StdioCollector.create()
                    nameParser.onRead.connect((data) => { nameOut += data })
                    nameProc.stdout = nameParser
                    nameProc.running = true
                    nameProc.waitForFinished()
                    let gameName = nameOut.split('"')[3]
                    if (gameName) {
                        steamGameMap[gameName.toLowerCase()] = appId
                        console.log("Geladen:", gameName, "->", appId)
                    }
                })
            }
        })
    }

    function findAppIdForTitle(title, callback) {
        if (!title || !steamPath) {
            callback("")
            return
        }
        let lowerTitle = title.toLowerCase()
        if (iconCache[lowerTitle]) {
            callback(iconCache[lowerTitle])
            return
        }
        for (let gameName in steamGameMap) {
            if (lowerTitle.indexOf(gameName) !== -1 || gameName.indexOf(lowerTitle) !== -1) {
                let appId = steamGameMap[gameName]
                iconCache[lowerTitle] = appId
                callback(appId)
                return
            }
        }
        let manifestDir = steamPath + "/steamapps/"
        let lsProc = Process.create()
        lsProc.command = ["sh", "-c", "ls " + manifestDir + "appmanifest_*.acf"]
        lsProc.running = true
        lsProc.onFinished.connect(() => {
            let out = ""
            let p = StdioCollector.create()
            p.onRead.connect((data) => { out += data })
            lsProc.stdout = p
            lsProc.running = true
            lsProc.waitForFinished()
            let files = out.trim().split("\n")
            let found = ""
            let remaining = files.length
            if (remaining === 0) {
                callback("")
                return
            }
            for (let f of files) {
                if (f === "") {
                    remaining--
                    if (remaining === 0) callback("")
                    continue
                }
                let match = f.match(/appmanifest_(\d+)\.acf/)
                if (!match) {
                    remaining--
                    if (remaining === 0) callback(found)
                    continue
                }
                let appId = match[1]
                let grepProc = Process.create()
                grepProc.command = ["grep", "-m1", '"name"', f]
                grepProc.running = true
                grepProc.onFinished.connect(() => {
                    let nameOut = ""
                    let np = StdioCollector.create()
                    np.onRead.connect((data) => { nameOut += data })
                    grepProc.stdout = np
                    grepProc.running = true
                    grepProc.waitForFinished()
                    let gameName = nameOut.split('"')[3]
                    if (gameName && lowerTitle.indexOf(gameName.toLowerCase()) !== -1) {
                        found = appId
                        steamGameMap[gameName.toLowerCase()] = appId
                    }
                    remaining--
                    if (remaining === 0) {
                        if (found) iconCache[lowerTitle] = found
                        callback(found)
                    }
                })
            }
        })
    }

    function getIconPathForAppId(appId) {
        if (!appId) return ""
        let user = Qt.environmentVariables().USER
        let sizes = ["64x64", "48x48", "128x128", "256x256", "32x32"]
        for (let sz of sizes) {
            let path = "/home/" + user + "/.local/share/icons/hicolor/" + sz + "/apps/steam_icon_" + appId + ".png"
            let testProc = Process.create()
            testProc.command = ["test", "-f", path]
            testProc.running = true
            testProc.waitForFinished()
            if (testProc.exitCode === 0) {
                return "file://" + path
            }
        }
        return ""
    }

    function resolveIcon(winClass, winTitle, callback) {
        if (winClass === "steam") {
            callback("steam")
            return
        }
        if (winClass === "gamescope" && winTitle) {
            findAppIdForTitle(winTitle, (appId) => {
                if (appId) {
                    let icon = getIconPathForAppId(appId)
                    if (icon) {
                        callback(icon)
                        return
                    }
                }
                callback("steam")
            })
            return
        }
        if (winClass) {
            let entry = DesktopEntries.heuristicLookup(winClass)
            if (entry && entry.icon) {
                callback(entry.icon)
                return
            }
            callback(winClass.toLowerCase())
            return
        }
        callback("")
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
                required property HyprlandWorkspace modelData
                readonly property bool isFocused: modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id
                readonly property var biggestWindow: HyprlandData.biggestWindowForWorkspace(modelData.id)

                property string currentIcon: ""
                property bool iconValid: false

                onBiggestWindowChanged: {
                    if (biggestWindow) {
                        iconValid = false
                        currentIcon = ""
                        resolveIcon(biggestWindow.class, biggestWindow.title, (icon) => {
                            currentIcon = icon
                            iconValid = true
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
                                if (currentIcon.startsWith("file://"))
                                    return currentIcon
                                else if (currentIcon !== "")
                                    return "image://icon/" + currentIcon
                                else
                                    return ""
                            }
                            sourceSize: Qt.size(48, 48)
                            fillMode: Image.PreserveAspectFit
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    currentIcon = "steam"
                                }
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
            }
        }
    }
}
