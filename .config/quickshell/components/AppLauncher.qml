import "../components"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string terminalCommand: "kitty"
    property string keyboardLayout: "de" // 👈 Change this to match your system (e.g. "de nodeadkeys")
    property var allApps: []
    property var filteredApps: allApps.filter((app) => {
        return app.name.toLowerCase().includes(AppLauncherState.searchText.toLowerCase());
    })

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
            const blacklist = ["Fcitx", "Keyboard", "qt6", "qt5", "assistant", "designer", "linguist", "qdbus", "qv4l2", "qvidcap", "avahi", "bch", "hvd", "javaws", "nvidiasettings", "displaytest", "iconbrowser", "system-config", "stoken", "emu-manager", "cmake", "texdoctk", "uxterm", "xterm", "uuctl", "wpgtk", "xgps", "Wine", "Rofi", "Xfce", "Ark", "Blackmagic", "Cppcheck", "lstopo", "OpenJDK", "rmpc", "Electron", "Advanced Network", "Htop", "Base", "Calc", "Draw", "Impress", "Math"];
            for (let line of lines) {
                const parts = line.split('|');
                if (parts.length >= 6) {
                    let name = parts[0].trim();
                    let exec = parts[1].trim();
                    let icon = parts[2] ? parts[2].trim() : "";
                    let needsTerminal = (parts[3] && parts[3].trim() === "true");
                    let dbusActivatable = (parts[4] && parts[4].trim() === "true");
                    let desktopId = parts[5].trim();
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
                            "terminal": needsTerminal,
                            "dbusActivatable": dbusActivatable,
                            "desktopId": desktopId
                        });

                }
            }
            allApps = apps.filter((v, i, a) => {
                return a.findIndex((t) => {
                    return t.name === v.name;
                }) === i;
            }).sort((a, b) => {
                return a.name.localeCompare(b.name);
            });
            console.log("Loaded apps:", allApps.length);
        } catch (e) {
            console.error("Error parsing applications:", e);
        }
    }

    function launchApp(app) {
        if (!app)
            return ;

        try {
            let command = [];
            if (app.dbusActivatable) {
                // D‑Bus activated app: pass keyboard layout explicitly
                command = ["env", "XKB_DEFAULT_LAYOUT=" + keyboardLayout, "gtk-launch", app.desktopId];
            } else if (app.terminal) {
                // Terminal app: set layout inside the shell
                command = ["env", "XKB_DEFAULT_LAYOUT=" + keyboardLayout, terminalCommand, "-e", "sh", "-c", app.exec + "; exec sh"];
            } else {
                // Normal GUI app: setsid with layout
                let args = app.exec.split(/\s+/).filter((a) => {
                    return a;
                });
                command = ["env", "XKB_DEFAULT_LAYOUT=" + keyboardLayout, "setsid"].concat(args);
            }
            console.log("Launching:", app.name, "with command:", command);
            launcher.command = command;
            launcher.running = true;
        } catch (e) {
            console.error("Error launching", app.name, ":", e);
        }
        AppLauncherState.close();
    }

    Component.onCompleted: {
        loadApplications();
    }
    Keys.onEscapePressed: AppLauncherState.close()
    Keys.onReturnPressed: {
        if (root.filteredApps.length > 0)
            root.launchApp(root.filteredApps[appList.currentIndex]);

    }

    Process {
        id: appsProcess

        command: ["bash", "-c", "for f in /usr/share/applications/*.desktop; do \
                grep -q '^Type=Application' \"$f\" || continue; \
                grep -q '^NoDisplay=true' \"$f\" && continue; \
                grep -q '^Hidden=true' \"$f\" && continue; \
                name=$(grep -m1 '^Name=' \"$f\" | sed 's/^Name=//'); \
                exec=$(grep -m1 '^Exec=' \"$f\" | sed 's/^Exec=//'); \
                icon=$(grep -m1 '^Icon=' \"$f\" | sed 's/^Icon=//'); \
                terminal=$(grep -m1 '^Terminal=' \"$f\" | sed 's/^Terminal=//'); \
                dbus=$(grep -m1 '^DBusActivatable=' \"$f\" | sed 's/^DBusActivatable=//'); \
                id=$(basename \"$f\" .desktop); \
                echo \"$name|$exec|$icon|$terminal|$dbus|$id\"; \
            done"]

        stdout: StdioCollector {
            id: appsOutput

            onStreamFinished: parseApplications()
        }

    }

    Process {
        // No environment property set → inherits all vars from the parent Quickshell process.
        // We pass XKB_DEFAULT_LAYOUT explicitly in the command above.

        id: launcher
    }

    Column {
        anchors.fill: parent
        spacing: 16

        Rectangle {
            width: parent.width
            height: 50
            color: WalColors.withAlpha(WalColors.color7, 0.2)
            radius: 8
            border.width: 2
            border.color: WalColors.withAlpha(WalColors.color2, 0.3)

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
                    if (event.key === Qt.Key_Down)
                        appList.incrementCurrentIndex();
                    else if (event.key === Qt.Key_Up)
                        appList.decrementCurrentIndex();
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

                Text {
                    anchors.centerIn: parent
                    text: "No applications found"
                    color: "#999999"
                    visible: appList.count === 0
                }

                delegate: Rectangle {
                    width: appList.width
                    height: 48
                    color: (appList.currentIndex === index || mArea.containsMouse) ? WalColors.withAlpha(WalColors.color2, 0.2) : "transparent"
                    radius: 6

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
                            width: 32
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 6
                            color: WalColors.withAlpha(WalColors.color2, 0.1)

                            Image {
                                id: appIcon

                                anchors.centerIn: parent
                                width: 24
                                height: 24
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
                                font.pixelSize: 18
                                color: WalColors.color2
                            }

                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: WalColors.color7
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }

                    }

                }

            }

        }

    }

}
