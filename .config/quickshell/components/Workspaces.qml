import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: workspaceWidget

    // ------------------------------------------------------------------
    // Steam-Daten (werden von scripts/steam_scan.sh geliefert)
    // ------------------------------------------------------------------
    property var steamTitleMap: ({})       // exakter Titel -> appid
    property var steamNormalizedMap: ({})  // normalisierter Titel -> appid
    property var steamIconMap: ({})        // appid -> file://-URL
    // Wird bei jedem fertigen Scan erhoeht -> Bindings werten neu aus
    property int mapsVersion: 0
    property var _tmpTitles: ({})
    property var _tmpNormalized: ({})
    property var _tmpIcons: ({})
    property var _rescanned: ({})
    property double lastScan: Date.now()
    readonly property string scanScript: Qt.resolvedUrl("../scripts/steam_scan.sh").toString().replace("file://", "")
    // Ordner mit den eigenen Icons (relativ zu diesem File, kein /home/azu hartkodiert)
    readonly property string iconDir: Qt.resolvedUrl("../resources/icons/").toString()
    readonly property int tabletWorkspaceId: 11
    readonly property string tabletIconPath: iconDir + "digital-art.png"
    readonly property bool tabletWorkspaceFocused: Hyprland.focusedMonitor?.activeWorkspace?.id === tabletWorkspaceId

    // ------------------------------------------------------------------
    // Hilfsfunktionen
    // ------------------------------------------------------------------
    function normalizeTitle(title) {
        return String(title || "").toLowerCase().replace(/[™®©]/g, "").replace(/[^a-z0-9]+/g, " ").trim();
    }

    // Icon-Theme-Lookup. Liefert eine verwendbare Image-Quelle oder "" wenn
    // es das Icon nicht gibt (verhindert das violett-schwarze Platzhalter-Icon).
    function themeIcon(name) {
        if (!name)
            return "";

        let p = "";
        try {
            p = Quickshell.iconPath(name, true);
        } catch (e) {
            p = "";
        }
        if (!p)
            return "";

        return p.startsWith("/") ? "file://" + p : p;
    }

    // Absoluter Pfad ODER Theme-Name -> Image-Quelle
    function iconUrl(ref) {
        if (!ref)
            return "";

        if (ref.startsWith("file://") || ref.startsWith("image://"))
            return ref;

        if (ref.startsWith("/"))
            return "file://" + ref;

        return themeIcon(ref);
    }

    function focusWorkspace(id) {
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", id.toString()]);
    }

    // Rechtsklick auf einen Workspace oeffnet die Overview
    function openOverview() {
        Quickshell.execDetached(["qs", "ipc", "call", "workspaceoverview", "toggle"]);
    }

    function requestRescan() {
        if (steamScan.running)
            return ;

        if (Date.now() - lastScan < 15000)
            return ;

        lastScan = Date.now();
        _tmpTitles = ({});
        _tmpNormalized = ({});
        _tmpIcons = ({});
        steamScan.running = true;
    }

    function findAppIdByTitleSubstring(title) {
        if (!title)
            return "";

        const lowerTitle = title.toLowerCase();
        const normTitle = normalizeTitle(title);
        let bestId = "";
        let bestLen = 0;
        for (const raw in steamTitleMap) {
            const l = raw.toLowerCase();
            if (l.length >= 4 && l.length > bestLen && lowerTitle.includes(l)) {
                bestId = steamTitleMap[raw];
                bestLen = l.length;
            }
        }
        if (!bestId && normTitle !== "") {
            for (const n in steamNormalizedMap) {
                if (n.length >= 4 && n.length > bestLen && normTitle.includes(n)) {
                    bestId = steamNormalizedMap[n];
                    bestLen = n.length;
                }
            }
        }
        return bestId;
    }

    // Steam-appid fuer ein Fenster ermitteln (Proton-Klasse oder Gamescope-Titel)
    function steamAppIdFor(cls, title) {
        if (cls.indexOf("steam_app_") === 0) {
            const id = cls.substring(10);
            if (/^[0-9]+$/.test(id) && id !== "0")
                return id;

        }
        if (!(cls === "gamescope" || cls.indexOf("steam_app_") === 0) || !title)
            return "";

        if (steamTitleMap[title])
            return steamTitleMap[title];

        const norm = normalizeTitle(title);
        if (norm !== "" && steamNormalizedMap[norm])
            return steamNormalizedMap[norm];

        return findAppIdByTitleSubstring(title);
    }

    // Reihenfolge: Theme-Icon "steam_icon_<id>" -> gecachtes Bild -> Steam-Logo
    function steamCandidates(appId) {
        const out = [];
        const t = themeIcon("steam_icon_" + appId);
        if (t)
            out.push(t);

        const cached = steamIconMap[appId];
        if (cached) {
            out.push(cached);
        } else if (!_rescanned[appId]) {
            // Neu installiertes Spiel? Einmal pro appid neu scannen.
            _rescanned[appId] = true;
            Qt.callLater(requestRescan);
        }
        const g = themeIcon("steam");
        if (g)
            out.push(g);

        return out;
    }

    // Liefert eine KETTE von Icon-Quellen. Das erste, das sich laden laesst,
    // wird angezeigt (siehe candIdx im Delegate).
    function iconCandidatesFor(win, _version) {
        const list = [];
        if (!win)
            return list;

        const cls = win.class || "";
        const title = win.title || "";
        const lc = cls.toLowerCase();
        const add = (u) => {
            if (u && list.indexOf(u) === -1)
                list.push(u);

        };
        // ---- 1) Eigene Overrides ----
        const byTitle = {
            "tmux_nvim": "neovim_1.png",
            "wallpaper-picker": "Senjogahara.png",
            "Modrinth App": "modrinth.png"
        };
        if (byTitle[title])
            add(iconDir + byTitle[title]);

        // Minecraft-Klasse aendert sich mit der Version ("Minecraft* 26.2")
        if (/^minecraft/i.test(cls) || (lc.indexOf("java") !== -1 && /minecraft/i.test(title)))
            add(iconDir + "minecraft.png");

        // ---- 2) Discord (auch Vesktop & Co. zeigen das normale Discord-Icon) ----
        if (["vesktop", "discord", "webcord", "armcord", "legcord", "equibop"].indexOf(lc) !== -1) {
            add(iconDir + "discord.svg");
            add(themeIcon("discord"));
            add(themeIcon("com.discordapp.Discord"));
        }
        // ---- 3) Steam-Spiele ----
        const appId = steamAppIdFor(cls, title);
        if (appId) {
            for (const c of steamCandidates(appId)) add(c)
        } else if (cls === "gamescope") {
            add(themeIcon("steam"));
        }
        // ---- 4) Bekannte Klassen -> Theme-Icon ----
        const classMap = {
            "code-oss": "code-oss",
            "com.obsproject.studio": "com.obsproject.Studio",
            "obs-studio": "com.obsproject.Studio",
            "zen-alpha": "zen-browser",
            "zen": "zen-browser",
            "openrgb": "openrgb",
            "yazi": "yazi",
            "fzfwindows": "yazi"
        };
        if (classMap[lc])
            add(themeIcon(classMap[lc]));

        // ---- 5) Heuristik ueber Desktop-Eintraege + Klassenname ----
        if (cls) {
            try {
                const entry = DesktopEntries.heuristicLookup(cls);
                if (entry && entry.icon)
                    add(iconUrl(entry.icon));

            } catch (e) {
            }
            add(themeIcon(cls));
            add(themeIcon(lc));
            add(themeIcon(lc.replace(/\.exe$/, "")));
        }
        // ---- 6) Eigene Fallback-Icons, falls das Theme nichts hat ----
        const localMap = {
            "zen": "zen-browser.png",
            "zen-alpha": "zen-browser.png",
            "kitty": "kitty.png",
            "firefox": "firefox.svg",
            "google-chrome": "chrome.svg",
            "chromium": "chrome.svg"
        };
        if (localMap[lc])
            add(iconDir + localMap[lc]);

        return list;
    }

    implicitWidth: bg.implicitWidth
    implicitHeight: 40

    Process {
        id: steamScan

        command: ["bash", workspaceWidget.scanScript]
        running: true
        onExited: (exitCode, exitStatus) => {
            // Erst jetzt in einem Rutsch uebernehmen (sauberes Change-Signal)
            workspaceWidget.steamTitleMap = workspaceWidget._tmpTitles;
            workspaceWidget.steamNormalizedMap = workspaceWidget._tmpNormalized;
            workspaceWidget.steamIconMap = workspaceWidget._tmpIcons;
            workspaceWidget.mapsVersion++;
        }

        stdout: SplitParser {
            onRead: (data) => {
                const parts = data.split("|");
                if (parts.length < 3)
                    return ;

                const kind = parts[0];
                const appId = parts[1].trim();
                const rest = parts.slice(2).join("|").trim();
                if (!appId || !rest)
                    return ;

                if (kind === "T") {
                    workspaceWidget._tmpTitles[rest] = appId;
                    const n = workspaceWidget.normalizeTitle(rest);
                    if (n !== "")
                        workspaceWidget._tmpNormalized[n] = appId;

                } else if (kind === "I") {
                    workspaceWidget._tmpIcons[appId] = "file://" + rest;
                }
            }
        }

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
                        // Kette moeglicher Icon-Quellen; candIdx zeigt auf die aktuell probierte.
                        // Wichtig: source bleibt IMMER gebunden (frueher wurde das Binding bei
                        // einem Ladefehler ueberschrieben, danach aktualisierte sich das Icon nie wieder).
                        readonly property var iconCandidates: workspaceWidget.iconCandidatesFor(biggestWindow, workspaceWidget.mapsVersion)
                        readonly property string iconKey: iconCandidates.join("|")
                        property int candIdx: 0
                        readonly property string iconSource: candIdx < iconCandidates.length ? iconCandidates[candIdx] : ""
                        readonly property bool iconReady: dynamicIcon.status === Image.Ready
                        readonly property bool iconExhausted: !!biggestWindow && iconSource === ""

                        visible: !isTabletWs
                        width: isTabletWs ? 0 : (35 + (isFocused ? 20 : 0))
                        height: isTabletWs ? 0 : 40
                        onIconKeyChanged: candIdx = 0

                        Rectangle {
                            id: iconBg

                            anchors.centerIn: parent
                            width: isFocused ? 36 : 35
                            height: isFocused ? 36 : 35
                            radius: 11
                            color: isFocused ? "#33ffffff" : "transparent"

                            // Workspace-Nummer: wenn leer ODER kein Icon gefunden wurde
                            Text {
                                anchors.centerIn: parent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: isFocused ? 14 : 13
                                color: isFocused ? "white" : WalColors.withAlpha(WalColors.color2, 0.6)
                                text: modelData.id.toString()
                                visible: !wsDelegate.iconReady && (!wsDelegate.biggestWindow || wsDelegate.iconExhausted)

                                Behavior on font.pixelSize {
                                    NumberAnimation {
                                        duration: 300
                                    }

                                }

                            }

                            Item {
                                anchors.fill: parent
                                visible: wsDelegate.iconReady
                                anchors.margins: isFocused ? 4 : 6

                                Image {
                                    id: dynamicIcon

                                    anchors.fill: parent
                                    source: wsDelegate.iconSource
                                    sourceSize: Qt.size(64, 64)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    // Laden fehlgeschlagen -> naechster Kandidat
                                    onStatusChanged: {
                                        if (status === Image.Error)
                                            wsDelegate.candIdx++;

                                    }
                                }

                                Desaturate {
                                    anchors.fill: dynamicIcon
                                    source: dynamicIcon
                                    desaturation: isFocused ? 0 : 1
                                    opacity: isFocused ? 1 : 0.5
                                }

                                Behavior on anchors.margins {
                                    NumberAnimation {
                                        duration: 300
                                    }

                                }

                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: 300
                                }

                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: 300
                                }

                            }

                        }

                        // Click-Handler mit hohem z-Index, damit nichts
                        // darueberliegendes den Klick abfaengt.
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

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                            }

                        }

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

                Rectangle {
                    id: tabletBg

                    anchors.centerIn: parent
                    width: workspaceWidget.tabletWorkspaceFocused ? 36 : 35
                    height: workspaceWidget.tabletWorkspaceFocused ? 36 : 35
                    radius: 11
                    color: workspaceWidget.tabletWorkspaceFocused ? "#33ffffff" : "transparent"

                    Image {
                        id: tabletIcon

                        anchors.fill: parent
                        anchors.margins: workspaceWidget.tabletWorkspaceFocused ? 4 : 6
                        source: workspaceWidget.tabletIconPath
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                        opacity: workspaceWidget.tabletWorkspaceFocused ? 1 : 0.55

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }

                        }

                        Behavior on anchors.margins {
                            NumberAnimation {
                                duration: 300
                            }

                        }

                    }

                    Text {
                        anchors.centerIn: parent
                        visible: tabletIcon.status !== Image.Ready
                        text: "󰓹"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: workspaceWidget.tabletWorkspaceFocused ? "white" : WalColors.withAlpha(WalColors.color2, 0.6)
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: 300
                        }

                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 300
                        }

                    }

                }

                // Click-Handler fuer das Tablet-Icon
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

                Behavior on width {
                    NumberAnimation {
                        duration: 300
                    }

                }

            }

        }

    }

}
