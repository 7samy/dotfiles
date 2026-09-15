import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Qt5Compat.GraphicalEffects

Item {
    id: workspaceWidget
    implicitWidth: bg.implicitWidth
    implicitHeight: 40

    property var steamTitleMap: ({})
    property var steamNormalizedMap: ({})
    property var steamIconMap: ({})
    property bool acfDone: false
    property bool iconsDone: false
    property bool mapsReady: acfDone && iconsDone

    readonly property int tabletWorkspaceId: 11
    readonly property string tabletIconPath: "file:///home/azu/.config/quickshell/resources/icons/digital-art.png"
    readonly property bool tabletWorkspaceFocused: Hyprland.focusedMonitor?.activeWorkspace?.id === tabletWorkspaceId

    function safeSteamThemeIcon(name) {
        var path = Quickshell.iconPath(name);
        return path ? "file://" + path : "";
    }

    function normalizeTitle(title) {
        return title.replace(/[™®©]/g, "").replace(/\s+/g, " ").trim().toLowerCase();
    }

    // Zentrale Funktion für den Workspace-Wechsel
    function focusWorkspace(id) {
        console.log("Wechsle zu Workspace:", id);
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", id.toString()]);
    }

    // Rechtsklick auf einen Workspace öffnet die Overview
    function openOverview() {
        console.log("Öffne Workspace Overview");
        Quickshell.execDetached(["qs", "ipc", "call", "workspaceoverview", "toggle"]);
    }

    Process {
        id: acfParser
        command: ["bash", "-c", "awk -F'\"' '/^\\t\"appid\"/{appid=$4} /^\\t\"name\"/{print appid \"|\" $4}' ~/.local/share/Steam/steamapps/appmanifest_*.acf"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var idx = data.indexOf("|");
                if (idx === -1) return;
                var appId = data.substring(0, idx).trim();
                var name = data.substring(idx + 1).trim();
                if (!appId || !name) return;
                workspaceWidget.steamTitleMap[name] = appId;
                workspaceWidget.steamNormalizedMap[workspaceWidget.normalizeTitle(name)] = appId;
            }
        }
        onExited: (exitCode, exitStatus) => { workspaceWidget.acfDone = true; }
    }

    Process {
        id: iconScanner
        command: ["bash", "-c", [
            "for d in ~/.local/share/Steam/appcache/librarycache/*/; do",
            "  appid=$(basename \"$d\");",
            "  icon=$(ls \"$d\" | grep -vE '^(header|library_|logo|icon)' | grep '\\.jpg$' | head -1);",
            "  if [ -n \"$icon\" ]; then echo \"$appid|$d$icon\"; fi;",
            "done"
        ].join(" ")]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var idx = data.indexOf("|");
                if (idx === -1) return;
                var appId = data.substring(0, idx).trim();
                var path = data.substring(idx + 1).trim();
                if (!appId || !path) return;
                workspaceWidget.steamIconMap[appId] = "file://" + path;
            }
        }
        onExited: (exitCode, exitStatus) => { workspaceWidget.iconsDone = true; }
    }

    function getSteamIcon(appId) {
        if (workspaceWidget.steamIconMap[appId])
            return workspaceWidget.steamIconMap[appId];
        var generic = workspaceWidget.safeSteamThemeIcon("steam");
        return generic ? generic : "";
    }

    function getCustomIconForWindow(winClass, winTitle) {
        var titleMap = {
            "tmux_nvim": "file:///home/azu/.config/quickshell/resources/icons/tmux.png",
            "wallpaper-picker": "file:///home/azu/.config/quickshell/resources/icons/Senjogahara.png",
            "Modrinth App": "file:///home/azu/.config/quickshell/resources/icons/icons8-minecraft-96.png"
        };
        if (winTitle && titleMap[winTitle])
            return titleMap[winTitle];

        if (winClass === "gamescope" && winTitle) {
            var appId = workspaceWidget.steamTitleMap[winTitle];
            if (!appId)
                appId = workspaceWidget.steamNormalizedMap[workspaceWidget.normalizeTitle(winTitle)];
            if (!appId)
                appId = workspaceWidget.findAppIdByTitleSubstring(winTitle);
            if (appId) return workspaceWidget.getSteamIcon(appId);
            return "steam";
        }

        if (winClass && winClass.startsWith("steam_app_")) {
            var appId = winClass.replace("steam_app_", "");
            return workspaceWidget.getSteamIcon(appId);
        }

        var classMap = {
            "code-oss":              "code-oss",
            "com.obsproject.Studio": "com.obsproject.Studio",
            "zen-alpha":             "zen-browser",
            "zen":                   "zen-browser",
            "openrgb":               "openrgb",
            "obs-studio":            "com.obsproject.Studio",
            "yazi":                  "yazi",
            "fzfwindows":            "yazi"
        };
        if (winClass && classMap[winClass])
            return classMap[winClass];

        if (winClass) {
            var entry = DesktopEntries.heuristicLookup(winClass);
            if (entry && entry.icon) return entry.icon;
            return winClass.toLowerCase();
        }
        return "";
    }

    function findAppIdByTitleSubstring(title) {
        if (!title) return "";
        var lowerTitle = title.toLowerCase();
        var bestMatchId = "";
        var bestMatchLen = 0;
        for (var rawName in workspaceWidget.steamTitleMap) {
            var lowerRaw = rawName.toLowerCase();
            if (lowerTitle.includes(lowerRaw) && lowerRaw.length > bestMatchLen) {
                bestMatchId = workspaceWidget.steamTitleMap[rawName];
                bestMatchLen = lowerRaw.length;
            }
        }
        if (!bestMatchId) {
            for (var normName in workspaceWidget.steamNormalizedMap) {
                if (lowerTitle.includes(normName) && normName.length > bestMatchLen) {
                    bestMatchId = workspaceWidget.steamNormalizedMap[normName];
                    bestMatchLen = normName.length;
                }
            }
        }
        return bestMatchId;
    }

    Rectangle {
        id: bg
        anchors.centerIn: parent
        implicitWidth: mainRow.implicitWidth + 16
        height: 40
        radius: 13
        color: WalColors.withAlpha(WalColors.color2, 0.2)
        border.color: WalColors.withAlpha(WalColors.color2, 0.4)
        border.width: 2

        Row {
            id: mainRow
            anchors.centerIn: parent
            spacing: 0

            Row {
                id: row
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    model: Hyprland.workspaces
                    delegate: Item {
                        id: wsDelegate
                        required property HyprlandWorkspace modelData

                        readonly property bool isTabletWs: modelData.id === workspaceWidget.tabletWorkspaceId
                        readonly property bool isFocused: modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id
                        readonly property var biggestWindow: HyprlandData.biggestWindowForWorkspace(modelData.id)

                        readonly property string resolvedIconId: {
                            var _ = workspaceWidget.mapsReady;
                            var win = biggestWindow;
                            if (!win) return "";
                            var custom = workspaceWidget.getCustomIconForWindow(win.class, win.title);
                            if (custom) return custom;
                            return "";
                        }

                        property bool iconValid: false

                        visible: !isTabletWs
                        width: isTabletWs ? 0 : (35 + (isFocused ? 20 : 0))
                        height: isTabletWs ? 0 : 40
                        Behavior on width { NumberAnimation { duration: 300 } }

                        Rectangle {
                            id: iconBg
                            anchors.centerIn: parent
                            width: isFocused ? 36 : 35
                            height: isFocused ? 36 : 35
                            radius: 11
                            color: isFocused ? "#33ffffff" : "transparent"
                            Behavior on width { NumberAnimation { duration: 300 } }
                            Behavior on height { NumberAnimation { duration: 300 } }

                            Text {
                                anchors.centerIn: parent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: isFocused ? 14 : 13
                                color: isFocused ? "white" : WalColors.withAlpha(WalColors.color2, 0.6)
                                text: biggestWindow ? "" : modelData.id.toString()
                                visible: !wsDelegate.iconValid
                                Behavior on font.pixelSize { NumberAnimation { duration: 300 } }
                            }

                            Item {
                                anchors.fill: parent
                                visible: wsDelegate.iconValid
                                anchors.margins: isFocused ? 4 : 6
                                Behavior on anchors.margins { NumberAnimation { duration: 300 } }

                                Image {
                                    id: dynamicIcon
                                    anchors.fill: parent
                                    source: {
                                        if (wsDelegate.resolvedIconId.startsWith("file://"))
                                            return wsDelegate.resolvedIconId;
                                        else if (wsDelegate.resolvedIconId !== "")
                                            return "image://icon/" + wsDelegate.resolvedIconId;
                                        else
                                            return "";
                                    }
                                    sourceSize: Qt.size(48, 48)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    onStatusChanged: {
                                        if (status === Image.Ready) {
                                            wsDelegate.iconValid = true;
                                        } else if (status === Image.Error) {
                                            var src = source.toString();
                                            if (src.includes("librarycache") && !src.includes("/logo.png") && !src.includes("/header.jpg") && !src.includes("image://")) {
                                                var steamPath = workspaceWidget.safeSteamThemeIcon("steam");
                                                if (steamPath) {
                                                    source = steamPath;
                                                } else {
                                                    wsDelegate.iconValid = false;
                                                }
                                            } else {
                                                wsDelegate.iconValid = false;
                                            }
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

                        // Click-Handler mit hohem z-Index, damit nichts
                        // darüberliegendes den Klick abfängt.
                        MouseArea {
                            anchors.fill: parent
                            z: 100
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    workspaceWidget.focusWorkspace(modelData.id);
                                    mouse.accepted = true;
                                } else if (mouse.button === Qt.RightButton) {
                                    workspaceWidget.openOverview();
                                    mouse.accepted = true;
                                }
                            }
                        }

                        onResolvedIconIdChanged: iconValid = false
                    }
                }
            }

            Item {
                id: tabletSeparator
                width: 13
                height: 40

                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: 20
                    color: WalColors.withAlpha(WalColors.color2, 0.35)
                }
            }

            Item {
                id: tabletItem
                width: 35 + (workspaceWidget.tabletWorkspaceFocused ? 20 : 0)
                height: 40
                Behavior on width { NumberAnimation { duration: 300 } }

                Rectangle {
                    id: tabletBg
                    anchors.centerIn: parent
                    width: workspaceWidget.tabletWorkspaceFocused ? 36 : 35
                    height: workspaceWidget.tabletWorkspaceFocused ? 36 : 35
                    radius: 11
                    color: workspaceWidget.tabletWorkspaceFocused ? "#33ffffff" : "transparent"
                    Behavior on width { NumberAnimation { duration: 300 } }
                    Behavior on height { NumberAnimation { duration: 300 } }

                    Image {
                        id: tabletIcon
                        anchors.fill: parent
                        anchors.margins: workspaceWidget.tabletWorkspaceFocused ? 4 : 6
                        source: workspaceWidget.tabletIconPath
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                        opacity: workspaceWidget.tabletWorkspaceFocused ? 1.0 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Behavior on anchors.margins { NumberAnimation { duration: 300 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: tabletIcon.status !== Image.Ready
                        text: "󰓹"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: workspaceWidget.tabletWorkspaceFocused ? "white" : WalColors.withAlpha(WalColors.color2, 0.6)
                    }
                }

                // Click-Handler für das Tablet-Icon
                MouseArea {
                    anchors.fill: parent
                    z: 100
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            workspaceWidget.focusWorkspace(workspaceWidget.tabletWorkspaceId);
                            mouse.accepted = true;
                        } else if (mouse.button === Qt.RightButton) {
                            workspaceWidget.openOverview();
                            mouse.accepted = true;
                        }
                    }
                }
            }
        }
    }
}
