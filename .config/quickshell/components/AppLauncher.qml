import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root
    
    property string terminalCommand: "kitty"   // Dein Terminal
    
    property var allApps: []
    property var filteredApps: allApps.filter(app => 
        app.name.toLowerCase().includes(AppLauncherState.searchText.toLowerCase())
    )
    
    Component.onCompleted: {
        loadApplications()
    }
    
    Process {
        id: appsProcess
        command: ["bash", "-c", "for f in /usr/share/applications/*.desktop; do \
            grep -q '^Type=Application' \"$f\" || continue; \
            grep -q '^NoDisplay=true' \"$f\" && continue; \
            grep -q '^Hidden=true' \"$f\" && continue; \
            name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2); \
            exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2); \
            icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2); \
            terminal=$(grep -m1 '^Terminal=' \"$f\" | cut -d= -f2); \
            echo \"$name|$exec|$icon|$terminal\"; \
        done"]
        
        stdout: StdioCollector {
            id: appsOutput
            onStreamFinished: parseApplications()
        }
    }
    
    function loadApplications() {
        try {
            appsProcess.running = true
        } catch(e) {
            console.error("Error loading applications:", e)
        }
    }
    
    function parseApplications() {
        try {
            const lines = appsOutput.text.split('\n').filter(l => l.trim())
            const apps = []
            
            const blacklist = [
                "qt6", "qt5", "assistant", "designer", "linguist", "qdbus", 
                "qv4l2", "qvidcap", "avahi", "bch", "hvd", "javaws", 
                "nvidiasettings", "displaytest", "iconbrowser", "system-config",
                "stoken", "emu-manager", "cmake", "texdoctk", "uxterm", "xterm",
                "uuctl", "wpgtk", "xgps", "Wine", "Rofi", "Xfce", "Ark", "Blackmagic",
                "Cppcheck", "lstopo", "OpenJDK","rmpc", "Electron", "Advanced Network",
                "Htop", "Base", "Calc", "Draw", "Impress", "Math"
            ];

            for (let line of lines) {
                const parts = line.split('|')
                if (parts.length >= 3) {
                    let name = parts[0].trim()
                    let exec = parts[1].trim()
                    let icon = parts[2] ? parts[2].trim() : ""
                    let needsTerminal = (parts[3] && parts[3].trim() === "true")
                    
                    exec = exec.replace(/%[fFuUikcnvezt]/g, "").trim()
                    
                    const fullNameInfo = (name + " " + exec).toLowerCase();
                    const isBlacklisted = blacklist.some(item => 
                        fullNameInfo.includes(item.toLowerCase())
                    )

                    if (name && exec && !isBlacklisted) {
                        apps.push({
                            name: name,
                            exec: exec,
                            icon: icon,
                            terminal: needsTerminal
                        })
                    }
                }
            }
            
            allApps = apps.filter((v,i,a)=>a.findIndex(t=>(t.name===v.name))===i)
                         .sort((a, b) => a.name.localeCompare(b.name))
            console.log("Geladene Apps:", allApps.length)
        } catch(e) {
            console.error("Error parsing applications:", e)
        }
    }
    
    // ----- Prozess zum Starten (ohne detach) -----
    Process {
        id: launcher
        // KEIN detach: true – nicht unterstützt
    }
    
    function launchApp(app) {
        if (!app) return;
        
        try {
            let command = []
            
            if (app.terminal) {
                // Terminal-App: Terminal öffnen, darin die App starten
                // Das Terminal läuft dann eigenständig – kein Blockieren
                command = [terminalCommand, "-e", "sh", "-c", app.exec + "; exec sh"]
            } else {
                // Grafische App: Im Hintergrund starten mit '&'
                // Die Shell beendet sich sofort, der Process wird frei
                command = ["sh", "-c", "setsid " + app.exec + " &"]
            }
            
            console.log("Starte:", app.name, "mit Befehl:", command)
            launcher.command = command
            launcher.running = true
            // Der Process läuft nur kurz (weil das Kommando sofort zurückkehrt)
        } catch(e) {
            console.error("Fehler beim Starten von", app.name, ":", e)
        }
        
        AppLauncherState.close()
    }
    
    // ----- UI (unverändert) -----
    Column {
        anchors.fill: parent
        spacing: 16
        
        Rectangle {
            width: parent.width
            height: 50
            color: WalColors.withAlpha(WalColors.color3, 0.55)
            radius: 8
            border.width: 2
            border.color: WalColors.withAlpha(WalColors.color2, 0.4)
            
            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: Text.AlignVCenter
                font.family: "ArcadeClassic"
                font.pixelSize: 16
                color: WalColors.withAlpha(WalColors.color7, 0.5)
                text: AppLauncherState.searchText
                onTextChanged: AppLauncherState.searchText = text
                
                Component.onCompleted: forceActiveFocus()
                
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down) appList.incrementCurrentIndex()
                    else if (event.key === Qt.Key_Up) appList.decrementCurrentIndex()
                }
            }
            
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "Search..."
                color: WalColors.withAlpha(WalColors.color7, 0.3)
                font.family: "ArcadeClassic"
                font.pixelSize: 16
                visible: searchInput.text === ""
            }
        }
        
        Rectangle {
            width: parent.width
            height: parent.height - 66
            color: "transparent"
            clip: true
            
            ListView {
                id: appList
                anchors.fill: parent
                model: root.filteredApps
                spacing: 4
                currentIndex: 0
                
                delegate: Rectangle {
                    width: appList.width
                    height: 48
                    color: (appList.currentIndex === index || mArea.containsMouse) 
                           ? WalColors.withAlpha(WalColors.color2, 0.2) 
                           : "transparent"
                    radius: 6
                    
                    Behavior on color { ColorAnimation { duration: 100 } }
                    
                    MouseArea {
                        id: mArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.launchApp(modelData)
                    }
                    
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        spacing: 12
                        
                        Rectangle {
                            width: 32; height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 4
                            color: WalColors.withAlpha(WalColors.color2, 0.1)
                            
                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 24; height: 24
                                source: modelData.icon ? "image://icon/" + modelData.icon : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                onStatusChanged: if (status === Image.Error) fallback.visible = true
                            }

                            Text {
                                id: fallback
                                visible: appIcon.status !== Image.Ready
                                anchors.centerIn: parent
                                text: "󰈙"
                                font.pixelSize: 18
                                color: WalColors.color2
                            }
                        }
                        
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: WalColors.color7
                        }
                    }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "No applications found"
                    color: "#999999"
                    visible: appList.count === 0
                }
            }
        }
    }
    
    Keys.onEscapePressed: AppLauncherState.close()
    Keys.onReturnPressed: {
        if (root.filteredApps.length > 0) {
            root.launchApp(root.filteredApps[appList.currentIndex])
        }
    }
}
