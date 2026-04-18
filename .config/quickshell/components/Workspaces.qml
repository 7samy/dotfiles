import QtQuick
import Quickshell
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

Item {
    id: workspaceWidget
    implicitWidth: bg.implicitWidth
    implicitHeight: 40

    // ------------------------------------------------------------
    // 1. Custom Icon Mapping: zuerst nach Fenstertitel, dann nach Klasse
    // ------------------------------------------------------------
    function getCustomIconForWindow(winClass, winTitle) {
        // Titel-Mapping (priorisiert) – hier kannst du beliebig viele Einträge ergänzen
        const titleMap = {
            "tmux_nvim": "file:///home/azu/.config/quickshell/resources/icons/tmux.png",
            // weitere Titel z.B. "htop": "file:///home/azu/.config/quickshell/icons/htop.png",
        };
        if (winTitle && titleMap[winTitle])
            return titleMap[winTitle];

        // Klassen-Mapping (wie ursprünglich)
        const classMap = {
            "code-oss": "code-oss",
            "com.obsproject.Studio": "com.obsproject.Studio",
            "zen-alpha": "zen-browser",
            "zen": "zen-browser",
            "openrgb": "openrgb",
            "obs-studio": "com.obsproject.Studio",
            "yazi": "yazi",
            "fzfwindows": "yazi"
        };
        if (winClass && classMap[winClass])
            return classMap[winClass];

        // Fallback: über DesktopEntries oder winClass
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

                // --------------------------------------------------------
                // 2. resolvedIconId: liefert entweder einen Icon-Namen (für image://icon/)
                //    oder eine file://-URL für ein eigenes PNG
                // --------------------------------------------------------
                readonly property string resolvedIconId: {
                    const win = biggestWindow;
                    if (!win) return "";
                    const custom = workspaceWidget.getCustomIconForWindow(win.class, win.title);
                    if (custom) return custom;   // kann file://... oder ein Icon-Name sein
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

                    // Fallback-Text (wenn kein Icon geladen werden kann)
                    Text {
                        anchors.centerIn: parent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: isFocused ? 14 : 13
                        color: isFocused ? "white" : WalColors.withAlpha(WalColors.color2, 0.6)
                        text: biggestWindow ? "" : modelData.id.toString()
                        visible: !wsDelegate.iconValid
                        Behavior on font.pixelSize { NumberAnimation { duration: 300 } }
                    }

                    // ----------------------------------------------------
                    // 3. Dynamisches Icon – unterstützt file:// und image://icon/
                    // ----------------------------------------------------
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
                                wsDelegate.iconValid = (status === Image.Ready);
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

                // Wenn sich die Icon-ID ändert, setze das Gültigkeits-Flag zurück
                onResolvedIconIdChanged: iconValid = false
            }
        }
    }
}
