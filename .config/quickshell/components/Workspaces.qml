import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Qt5Compat.GraphicalEffects

Item {
    id: workspaceWidget
    implicitWidth: bg.implicitWidth
    implicitHeight: 40

    property var steamTitleMap: ({})     // game name → appId
    property var steamNormalizedMap: ({}) // normalized name → appId
    property var steamIconMap: ({})       // appId → local icon file path
    property bool acfDone: false
    property bool iconsDone: false
    property bool mapsReady: acfDone && iconsDone   // ← re-added

    function normalizeTitle(title) {
        return title.replace(/[™®©]/g, "").replace(/\s+/g, " ").trim().toLowerCase();
    }

    // Parse all ACF manifests to build title → appId map
    Process {
        id: acfParser
        command: ["bash", "-c", "awk -F'\"' '/^\\t\"appid\"/{appid=$4} /^\\t\"name\"/{print appid \"|\" $4}' ~/.local/share/Steam/steamapps/appmanifest_*.acf"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const idx = data.indexOf("|");
                if (idx === -1) return;
                const appId = data.substring(0, idx).trim();
                const name = data.substring(idx + 1).trim();
                if (!appId || !name) return;
                workspaceWidget.steamTitleMap[name] = appId;
                workspaceWidget.steamNormalizedMap[workspaceWidget.normalizeTitle(name)] = appId;
            }
        }
        onExited: (exitCode, exitStatus) => {
            workspaceWidget.acfDone = true;
        }
    }

    // Scan librarycache dirs for the hash-named icon file (e.g. b6e290dd...jpg)
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
                const idx = data.indexOf("|");
                if (idx === -1) return;
                const appId = data.substring(0, idx).trim();
                const path = data.substring(idx + 1).trim();
                if (!appId || !path) return;
                workspaceWidget.steamIconMap[appId] = "file://" + path;
            }
        }
        onExited: (exitCode, exitStatus) => {
            workspaceWidget.iconsDone = true;
        }
    }

    function getSteamIcon(appId) {
        if (workspaceWidget.steamIconMap[appId])
            return workspaceWidget.steamIconMap[appId];
        return "file:///home/azu/.local/share/Steam/appcache/librarycache/" + appId + "/logo.png";
    }

    function getCustomIconForWindow(winClass, winTitle) {
        const titleMap = {
            "tmux_nvim": "file:///home/azu/.config/quickshell/resources/icons/tmux.png",
        };
        if (winTitle && titleMap[winTitle])
            return titleMap[winTitle];

        // Gamescope wraps games — class is "gamescope", title is the game name
        if (winClass === "gamescope" && winTitle) {
            let appId = workspaceWidget.steamTitleMap[winTitle];
            if (!appId)
                appId = workspaceWidget.steamNormalizedMap[workspaceWidget.normalizeTitle(winTitle)];
            if (appId) return getSteamIcon(appId);
        }

        // Non-gamescope Proton/native Steam games
        if (winClass && winClass.startsWith("steam_app_")) {
            const appId = winClass.replace("steam_app_", "");
            return getSteamIcon(appId);
        }

        const classMap = {
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
            const entry = DesktopEntries.heuristicLookup(winClass);
            if (entry && entry.icon) return entry.icon;
            return winClass.toLowerCase();
        }
        return "";
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

                readonly property string resolvedIconId: {
                    const _ = workspaceWidget.mapsReady;   // ← re-evaluates when maps load
                    const win = biggestWindow;
                    if (!win) return "";
                    const custom = workspaceWidget.getCustomIconForWindow(win.class, win.title);
                    if (custom) return custom;
                    return "";
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
                                    const src = source.toString();
                                    if (!src.includes("/logo.png") && !src.includes("/header.jpg") && !src.includes("image://")) {
                                        // hash icon failed, try logo.png
                                        const appId = src.replace("file:///home/azu/.local/share/Steam/appcache/librarycache/", "").split("/")[0];
                                        source = "file:///home/azu/.local/share/Steam/appcache/librarycache/" + appId + "/logo.png";
                                    } else if (src.includes("/logo.png")) {
                                        source = src.replace("/logo.png", "/header.jpg");
                                    } else if (src.includes("/header.jpg")) {
                                        source = "image://icon/steam";
                                    } else {
                                        // All fallbacks exhausted (including the generic Steam icon) – give up
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

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + modelData.id)
                }

                onResolvedIconIdChanged: iconValid = false
            }
        }
    }
}
