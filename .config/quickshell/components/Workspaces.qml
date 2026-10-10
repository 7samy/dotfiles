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
    // appid-Cache fuer Gamescope-Fenster (Schluessel: pid|address)
    property var pidAppIds: ({})
    property var _pidPending: ({})
    property var _pidQueue: []
    property int pidVersion: 0
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
        return String(title || "").toLowerCase().replace(/[™®©]/g, "").replace(/[^a-z0-9]+/g, "");
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

    // Unscharfer Titelvergleich auf kompakten Strings ("stellarblade").
    // Steam-Name im Fenstertitel ODER Fenstertitel im Steam-Namen.
    function findAppIdByTitleSubstring(title) {
        const t = normalizeTitle(title);
        if (t === "" || t === "gamescope")
            return "";

        let bestId = "";
        let bestScore = 0;
        for (const n in steamNormalizedMap) {
            let score = 0;
            if (n === t)
                score = 1000;
            else if (n.length >= 4 && t.includes(n))
                score = n.length;
            else if (t.length >= 5 && n.includes(t))
                score = t.length - 1;
            if (score > bestScore) {
                bestScore = score;
                bestId = steamNormalizedMap[n];
            }
        }
        return bestId;
    }

    // Liest SteamGameId/SteamAppId aus der Umgebung des Fenster-Prozesses
    // (Gamescope erbt sie von Steam). Asynchron: erster Aufruf liefert "",
    // danach erhoeht pidVersion und die Bindings werten neu aus.
    function appIdForWindow(win) {
        if (!win || !win.pid)
            return "";

        const key = String(win.pid) + "|" + (win.address || "");
        if (pidAppIds[key] !== undefined)
            return pidAppIds[key];

        if (!_pidPending[key]) {
            _pidPending[key] = true;
            _pidQueue.push({
                "key": key,
                "pid": String(win.pid)
            });
            Qt.callLater(processPidQueue);
        }
        return "";
    }

    function processPidQueue() {
        if (pidProc.running || _pidQueue.length === 0)
            return ;

        const next = _pidQueue.shift();
        pidProc.key = next.key;
        pidProc.pid = next.pid;
        pidProc.running = true;
    }

    // Steam-appid fuer ein Fenster:
    // 1) Proton-Klasse steam_app_<id>
    // 2) Gamescope: SteamGameId aus dem Prozess (zuverlaessig)
    // 3) Fenstertitel (unscharf) als Fallback
    function steamAppIdFor(win) {
        const cls = win.class || "";
        if (cls.indexOf("steam_app_") === 0) {
            const id = cls.substring(10);
            if (/^[0-9]+$/.test(id) && id !== "0")
                return id;

        }
        if (!(cls === "gamescope" || cls.indexOf("steam_app_") === 0))
            return "";

        const pidId = appIdForWindow(win);
        if (pidId)
            return pidId;

        const norm = normalizeTitle(win.title);
        if (norm === "" || norm === "gamescope")
            return "";

        if (steamNormalizedMap[norm])
            return steamNormalizedMap[norm];

        return findAppIdByTitleSubstring(win.title);
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
    function iconCandidatesFor(win, _mapsVersion, _pidVersion) {
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
        const appId = steamAppIdFor(win);
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
        id: pidProc

        property string key: ""
        property string pid: ""

        command: ["bash", "-c", "tr '\\0' '\\n' < /proc/" + pid + "/environ 2>/dev/null | grep -m1 -E '^(SteamGameId|SteamAppId)=[0-9]+' || true"]
        onRunningChanged: {
            if (!running)
                Qt.callLater(workspaceWidget.processPidQueue);

        }

        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/=([0-9]+)/);
                workspaceWidget.pidAppIds[pidProc.key] = (m && m[1] !== "0") ? m[1] : "";
                workspaceWidget.pidVersion++;
            }
        }

    }

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
                        readonly property var iconCandidates: workspaceWidget.iconCandidatesFor(biggestWindow, workspaceWidget.mapsVersion, workspaceWidget.pidVersion)
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
