import "../components"
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string terminalCommand: "kitty" // Dein Terminal
    property var allApps: []
    property var filteredApps: allApps.filter((app) => {
        return app.name.toLowerCase().includes(AppLauncherState.searchText.toLowerCase());
    })
    // Größere Zellen für größere Icons
    readonly property real cellW: 190
    readonly property real cellH: 168
    // Fest auf 8 Spalten - dadurch immer 8 Apps pro Reihe,
    // links und rechts bleibt durch die Zentrierung gleichmäßig Platz.
    readonly property int gridColumns: 8

    function loadApplications() {
        try {
            appsProcess.running = true;
        } catch (e) {
            console.error("Error loading applications:", e);
        }
    }

    function parseApplications() {
        try {
            const lines = appsOutput.text.split('\n').filter((l) => {
                return l.trim();
            });
            const apps = [];
            const blacklist = ["qt6", "qt5", "assistant", "designer", "linguist", "qdbus", "qv4l2", "qvidcap", "avahi", "bch", "hvd", "javaws", "nvidiasettings", "displaytest", "iconbrowser", "system-config", "stoken", "emu-manager", "cmake", "texdoctk", "uxterm", "xterm", "uuctl", "wpgtk", "xgps", "Wine", "Rofi", "Xfce", "Ark", "Blackmagic", "Cppcheck", "lstopo", "OpenJDK", "rmpc", "Electron", "Advanced Network", "Htop", "Base", "Calc", "Draw", "Impress", "Math"];
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
            allApps = apps.filter((v, i, a) => {
                return a.findIndex((t) => {
                    return (t.name === v.name);
                }) === i;
            }).sort((a, b) => {
                return a.name.localeCompare(b.name);
            });
            console.log("Geladene Apps:", allApps.length);
        } catch (e) {
            console.error("Error parsing applications:", e);
        }
    }

    function launchApp(app) {
        if (!app)
            return ;

        try {
            let command = [];
            if (app.terminal)
                command = [terminalCommand, "-e", "sh", "-c", app.exec + "; exec sh"];
            else
                command = ["sh", "-c", app.exec];
            console.log("Starte:", app.name, "mit Befehl:", command);
            Quickshell.execDetached(command);
        } catch (e) {
            console.error("Fehler beim Starten von", app.name, ":", e);
        }
        AppLauncherState.close();
    }

    Component.onCompleted: {
        loadApplications();
    }
    // Grid-Auswahl bei neuer Suche immer auf den ersten Treffer zurücksetzen
    onFilteredAppsChanged: grid.currentIndex = 0
    Keys.onEscapePressed: AppLauncherState.close()
    Keys.onReturnPressed: {
        if (root.filteredApps.length > 0)
            root.launchApp(root.filteredApps[grid.currentIndex]);

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

    // Suchleiste, oben mittig
    Rectangle {
        id: searchBar

        width: Math.min(root.width * 0.4, 400)
        height: 56
        radius: height / 2
        anchors.top: parent.top
        anchors.topMargin: Math.max(root.height * 0.08, 48)
        anchors.horizontalCenter: parent.horizontalCenter
        color: WalColors.withAlpha(WalColors.color7, 0.12)
        border.width: 2
        border.color: searchInput.activeFocus ? WalColors.withAlpha(WalColors.color4, 0.6) : WalColors.withAlpha(WalColors.color2, 0.25)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: WalColors.withAlpha(WalColors.color7, 0.5)
        }

        TextInput {
            id: searchInput

            anchors.fill: parent
            anchors.leftMargin: 54
            anchors.rightMargin: 22
            verticalAlignment: Text.AlignVCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: WalColors.color7
            text: AppLauncherState.searchText
            onTextChanged: AppLauncherState.searchText = text
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: (event) => {
                switch (event.key) {
                case Qt.Key_Down:
                    grid.moveCurrentIndexDown();
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                    grid.moveCurrentIndexUp();
                    event.accepted = true;
                    break;
                case Qt.Key_Left:
                    grid.moveCurrentIndexLeft();
                    event.accepted = true;
                    break;
                case Qt.Key_Right:
                    grid.moveCurrentIndexRight();
                    event.accepted = true;
                    break;
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 54
            anchors.verticalCenter: parent.verticalCenter
            text: "Applications"
            color: WalColors.withAlpha(WalColors.color7, 0.35)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            visible: searchInput.text === ""
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }

        }

    }

    // App-Grid
    Item {
        id: gridArea

        // Feste Breite = 8 Spalten × Zellbreite.
        // Durch anchors.horizontalCenter bleibt das Grid mittig,
        // links und rechts entsteht automatisch gleichmäßiger Rand.
        width: root.gridColumns * root.cellW
        anchors.top: searchBar.bottom
        anchors.topMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter

        GridView {
            id: grid

            anchors.fill: parent
            model: root.filteredApps
            cellWidth: root.cellW
            cellHeight: root.cellH
            currentIndex: 0
            clip: true

            Text {
                anchors.centerIn: parent
                text: "Keine Anwendungen gefunden"
                color: WalColors.withAlpha(WalColors.color7, 0.4)
                font.family: "JetBrainsMono Nerd Font"
                visible: grid.count === 0
            }

            delegate: Item {
                readonly property bool isCurrent: GridView.isCurrentItem

                width: grid.cellWidth
                height: grid.cellHeight

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        id: iconBg

                        // Größerer Icon-Hintergrund
                        width: 88
                        height: 88
                        radius: 18
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: (isCurrent || mArea.containsMouse) ? WalColors.withAlpha(WalColors.color2, 0.25) : WalColors.withAlpha(WalColors.color2, 0.08)
                        border.width: isCurrent ? 2 : 0
                        border.color: WalColors.withAlpha(WalColors.color4, 0.6)
                        scale: mArea.containsMouse ? 1.08 : 1

                        Image {
                            id: appIcon

                            anchors.centerIn: parent
                            // Größeres Icon
                            width: 60
                            height: 60
                            source: modelData.icon ? "image://icon/" + modelData.icon : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            onStatusChanged: {
                                if (status === Image.Error)
                                    fallback.visible = true;

                            }
                        }

                        Text {
                            id: fallback

                            visible: appIcon.status !== Image.Ready
                            anchors.centerIn: parent
                            text: "󰈙"
                            font.pixelSize: 38
                            color: WalColors.color2
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }

                        }

                    }

                    Text {
                        width: grid.cellWidth - 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.name
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: WalColors.color7
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }

                }

                MouseArea {
                    id: mArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        grid.currentIndex = index;
                        root.launchApp(modelData);
                    }
                }

            }

        }

    }

}
