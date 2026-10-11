import "../components"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: overview

    property bool open: false
    // Beim Klick auf einen Workspace sofort ausblenden (kein Fade), damit die
    // Overview nicht in die Workspace-Wechsel-Animation hineinragt.
    property bool instantHide: false
    property int pendingFocusWs: -1
    property int hoveredWorkspaceId: -1
    property int dropTargetWorkspaceId: -1
    property var draggedWindow: null
    property point dragGlobalPos: Qt.point(0, 0)
    readonly property int columns: 5
    readonly property var slotIds: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    readonly property var kanji: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    readonly property string moveScript: Qt.resolvedUrl("../scripts/hypr_move_window.sh").toString().replace("file://", "")
    readonly property var currentScreen: {
        const focused = Hyprland.focusedMonitor;
        if (focused) {
            const match = Quickshell.screens.find((s) => {
                return s.name === focused.name;
            });
            if (match)
                return match;

        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }
    // Screencopy nur aktiv, wenn die Overview offen ist oder gerade
    // ausfadet. Geschlossen -> captureSource null -> DMA-Buffer werden
    // freigegeben. Vorher: ~14 MB pro Thumbnail dauerhaft im RAM.
    readonly property bool captureActive: open || dimmer.opacity > 0.01

    function workspaceById(id) {
        return Hyprland.workspaces.values.find((w) => {
            return w.id === id;
        }) || null;
    }

    function windowsOn(id) {
        return Hyprland.toplevels.values.filter((t) => {
            return t.workspace && t.workspace.id === id;
        });
    }

    // Hyprland mit Lua-Config versteht `hyprctl dispatch workspace N` nicht mehr
    // (die alte Schreibweise wird als Lua-Code gelesen -> Syntaxfehler).
    // Auch Hyprland.dispatch("workspace N") nutzt diese alte Schreibweise.
    // Neu: hl.dsp.focus({ workspace = "N" }). Antwortet Hyprland nicht mit "ok"
    // (z.B. alte Hyprlang-Config), wird die alte Schreibweise probiert.
    function focusWorkspace(id) {
        const n = String(parseInt(id));
        if (n === "NaN")
            return ;

        Quickshell.execDetached(["bash", "-c", "out=$(hyprctl dispatch \"hl.dsp.focus({ workspace = \\\"$1\\\" })\" 2>&1); " + "[ \"$out\" = ok ] || hyprctl dispatch workspace \"$1\"", "_", n]);
    }

    // Schliesst ein Fenster ueber die neue Lua-Dispatch-API.
    // Das Lua-Kommando wird in QML zusammengebaut und als fertiger String
    // an bash uebergeben (kein Quoting-Chaos, $1 wird nicht mehr "verschluckt").
    // Faellt auf die alte closewindow-Syntax zurueck, falls Lua nicht "ok" antwortet.
    function closeWindow(win) {
        if (!win || !win.address)
            return ;

        const raw = String(win.address);
        const addr = "address:" + (raw.startsWith("0x") ? raw : "0x" + raw);
        const luaCmd = 'hl.dsp.window.close({ window = "' + addr + '" })';
        Quickshell.execDetached(["bash", "-c", "out=$(hyprctl dispatch \"$1\" 2>&1); " + "[ \"$out\" = ok ] || hyprctl dispatch closewindow \"$2\"", "_", luaCmd, addr]);
        // Hyprland schickt nicht immer ein Event -> kurz danach neu einlesen
        refreshTimer.restart();
    }

    // Erst unsichtbar machen, dann (kurz danach) den Workspace wechseln:
    // Das Overview-Fenster ist dann schon unmapped, wenn die Wechsel-Animation startet.
    function activate(id) {
        instantHide = true;
        pendingFocusWs = id;
        close();
        focusTimer.restart();
    }

    function moveWindowTo(win, wsId) {
        if (!win || !win.address)
            return ;

        Quickshell.execDetached(["bash", moveScript, String(win.address), String(wsId)]);
        // Nicht jede Aenderung sendet ein Event -> kurz danach neu einlesen
        refreshTimer.restart();
    }

    function resetDrag() {
        draggedWindow = null;
        dropTargetWorkspaceId = -1;
    }

    function close() {
        open = false;
        hoveredWorkspaceId = -1;
        resetDrag();
    }

    WlrLayershell.namespace: "quickshell:workspaceoverview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    screen: currentScreen
    // Sichtbar bleiben, solange das Ausblenden laeuft
    visible: open || (!instantHide && dimmer.opacity > 0.01)
    color: "transparent"
    onOpenChanged: {
        if (open) {
            instantHide = false;
            bounce.restart();
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Timer {
        id: focusTimer

        interval: 40
        onTriggered: {
            if (overview.pendingFocusWs > 0)
                overview.focusWorkspace(overview.pendingFocusWs);

            overview.pendingFocusWs = -1;
        }
    }

    Timer {
        id: refreshTimer

        interval: 150
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
        }
    }

    IpcHandler {
        function toggle() {
            overview.open = !overview.open;
        }

        function show() {
            overview.open = true;
        }

        function hide() {
            overview.close();
        }

        target: "workspaceoverview"
    }

    Item {
        anchors.fill: parent
        focus: overview.open
        Keys.onEscapePressed: overview.close()
    }

    Rectangle {
        id: dimmer

        anchors.fill: parent
        color: WalColors.withAlpha(WalColors.color0, 0.55)
        opacity: overview.open ? 1 : 0

        MouseArea {
            anchors.fill: parent
            onClicked: overview.close()
        }

        Item {
            id: scaleWrapper

            anchors.fill: parent
            scale: 1
            transformOrigin: Item.Center

            SequentialAnimation {
                id: bounce

                NumberAnimation {
                    target: scaleWrapper
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: 260
                    easing.type: Easing.OutBack
                }

            }

            Grid {
                id: cardGrid

                anchors.centerIn: parent
                columns: overview.columns
                spacing: 24

                Repeater {
                    model: overview.slotIds

                    delegate: Item {
                        id: card

                        readonly property int wsId: modelData
                        readonly property var ws: overview.workspaceById(wsId)
                        // WICHTIG: `wins` wird nur neu gesetzt, wenn sich die Fensterliste
                        // wirklich aendert. Frueher wurde bei JEDEM Hyprland-Update ein neues
                        // Array erzeugt -> alle Thumbnails samt MouseArea wurden zerstoert und
                        // neu gebaut, mitten in einem Drag.
                        readonly property string winKey: overview.windowsOn(wsId).map((t) => {
                            return t.address;
                        }).join(",")
                        property var wins: []
                        readonly property bool hasWorkspace: ws !== null
                        readonly property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
                        readonly property bool isHovered: overview.hoveredWorkspaceId === wsId
                        readonly property bool isDropTarget: overview.dropTargetWorkspaceId === wsId
                        readonly property bool showBorder: isHovered || isDropTarget
                        readonly property bool brightened: isHovered || isDropTarget

                        width: 380
                        height: 220
                        scale: brightened ? 1.03 : 1
                        onWinKeyChanged: wins = overview.windowsOn(wsId)
                        Component.onCompleted: wins = overview.windowsOn(wsId)

                        Rectangle {
                            id: cardBg

                            anchors.fill: parent
                            radius: 16
                            color: brightened ? WalColors.withAlpha(WalColors.color0, 0.92) : WalColors.withAlpha(WalColors.color0, 0.82)
                            border.width: showBorder ? 2 : 1
                            border.color: isDropTarget ? WalColors.color2 : (isHovered ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.15))
                            clip: true

                            Text {
                                anchors.centerIn: parent
                                text: overview.kanji[card.wsId - 1] || ""
                                color: WalColors.withAlpha(WalColors.color7, card.hasWorkspace ? 0.06 : 0.03)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 120
                                font.bold: true
                                z: 0
                            }

                            Item {
                                id: previewArea

                                anchors.fill: parent
                                anchors.margins: 10
                                anchors.bottomMargin: 30
                                clip: true
                                z: 6

                                Grid {
                                    id: previewGrid

                                    readonly property int visibleCount: Math.min(card.wins.length, 4)
                                    readonly property int gridRows: Math.max(1, Math.ceil(visibleCount / columns))
                                    readonly property real cellW: (width - (columns - 1) * spacing) / columns
                                    readonly property real cellH: (height - (gridRows - 1) * spacing) / gridRows

                                    anchors.fill: parent
                                    columns: card.wins.length === 1 ? 1 : 2
                                    spacing: 6

                                    Repeater {
                                        model: card.wins.slice(0, 4)

                                        delegate: Rectangle {
                                            id: thumbBox

                                            readonly property var win: modelData
                                            readonly property bool thumbHovered: previewMouse.containsMouse && !previewMouse.dragActive

                                            width: previewGrid.cellW
                                            height: previewGrid.cellH
                                            radius: 8
                                            color: WalColors.withAlpha(WalColors.color0, 0.6)
                                            border.width: thumbHovered ? 2 : 1
                                            border.color: thumbHovered ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.12)
                                            scale: thumbHovered ? 1.03 : 1
                                            clip: true
                                            // Wird das Fenster waehrend des Drags geschlossen, Drag abbrechen
                                            Component.onDestruction: {
                                                if (overview.draggedWindow === thumbBox.win)
                                                    overview.resetDrag();

                                            }

                                            ScreencopyView {
                                                id: thumb

                                                anchors.fill: parent
                                                // Nur capturen, wenn Overview offen (oder ausfadet).
                                                // Sonst: captureSource null -> Buffer freigegeben.
                                                live: overview.captureActive
                                                captureSource: overview.captureActive ? thumbBox.win.wayland : null
                                                opacity: previewMouse.dragActive ? 0.35 : (thumbHovered ? 1 : (brightened ? 0.95 : 0.85))

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 150
                                                    }

                                                }

                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: "white"
                                                opacity: thumbHovered ? 0.1 : 0
                                                visible: opacity > 0

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 150
                                                    }

                                                }

                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                height: titleText.implicitHeight + 6
                                                color: WalColors.withAlpha(WalColors.color0, 0.75)

                                                Text {
                                                    id: titleText

                                                    anchors.fill: parent
                                                    anchors.margins: 4
                                                    text: thumbBox.win.title || "Unbenannt"
                                                    color: WalColors.color7
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    verticalAlignment: Text.AlignVCenter
                                                }

                                            }

                                            // ---- Close-Button (oben rechts, sichtbar beim Hovern) ----
                                            Rectangle {
                                                id: closeBtn

                                                readonly property bool hot: closeMouse.containsMouse

                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.topMargin: 6
                                                anchors.rightMargin: 6
                                                width: 22
                                                height: 22
                                                radius: 11
                                                color: hot ? WalColors.color1 : WalColors.withAlpha(WalColors.color0, 0.8)
                                                border.width: 1
                                                border.color: hot ? WalColors.color1 : WalColors.withAlpha(WalColors.color7, 0.25)
                                                opacity: thumbBox.thumbHovered || closeMouse.containsMouse ? 1 : 0
                                                scale: hot ? 1.12 : 1
                                                visible: opacity > 0.01
                                                z: 20

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅖"
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 12
                                                    color: closeBtn.hot ? WalColors.color0 : WalColors.withAlpha(WalColors.color7, 0.85)
                                                }

                                                MouseArea {
                                                    id: closeMouse

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: (mouse) => {
                                                        mouse.accepted = true;
                                                        overview.closeWindow(thumbBox.win);
                                                    }
                                                }

                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 140
                                                    }

                                                }

                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: 140
                                                        easing.type: Easing.OutBack
                                                        easing.overshoot: 2
                                                    }

                                                }

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }

                                                }

                                                Behavior on border.color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }

                                                }

                                            }

                                            MouseArea {
                                                id: previewMouse

                                                property bool dragActive: false
                                                property point pressPos: Qt.point(0, 0)

                                                // Position -> Workspace-Karte unter dem Mauszeiger.
                                                // Ersetzt DropArea/Drag: zuverlaessiger, kein Qt-Drag noetig.
                                                function updateDrag(mouse) {
                                                    overview.dragGlobalPos = previewMouse.mapToItem(dimmer, mouse.x, mouse.y);
                                                    const g = previewMouse.mapToItem(cardGrid, mouse.x, mouse.y);
                                                    const c = cardGrid.childAt(g.x, g.y);
                                                    const id = (c && c.wsId !== undefined) ? c.wsId : -1;
                                                    const own = thumbBox.win.workspace ? thumbBox.win.workspace.id : -1;
                                                    // Die eigene Workspace ist kein sinnvolles Ziel
                                                    overview.dropTargetWorkspaceId = (id === own) ? -1 : id;
                                                }

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                                cursorShape: dragActive ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                                onPressed: (mouse) => {
                                                    pressPos = Qt.point(mouse.x, mouse.y);
                                                    dragActive = false;
                                                }
                                                onPositionChanged: (mouse) => {
                                                    // Nur mit gedrueckter Taste ziehen. Ohne diese Pruefung
                                                    // startete schon das blosse Hovern einen "Drag".
                                                    if (!pressed)
                                                        return ;

                                                    if (!dragActive && (Math.abs(mouse.x - pressPos.x) > 8 || Math.abs(mouse.y - pressPos.y) > 8)) {
                                                        dragActive = true;
                                                        overview.draggedWindow = thumbBox.win;
                                                    }
                                                    if (dragActive)
                                                        updateDrag(mouse);

                                                }
                                                onReleased: (mouse) => {
                                                    if (!dragActive) {
                                                        // Mittelklick = Fenster schliessen
                                                        if (mouse.button === Qt.MiddleButton)
                                                            overview.closeWindow(thumbBox.win);
                                                        else
                                                            overview.activate(card.wsId);
                                                    } else {
                                                        const target = overview.dropTargetWorkspaceId;
                                                        const win = thumbBox.win;
                                                        if (target > 0 && win)
                                                            overview.moveWindowTo(win, target);

                                                    }
                                                    dragActive = false;
                                                    overview.resetDrag();
                                                }
                                                onCanceled: {
                                                    dragActive = false;
                                                    overview.resetDrag();
                                                }
                                            }

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: 120
                                                    easing.type: Easing.OutCubic
                                                }

                                            }

                                            Behavior on border.color {
                                                ColorAnimation {
                                                    duration: 120
                                                }

                                            }

                                        }

                                    }

                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 4
                                    visible: card.wins.length > 4
                                    text: "+" + (card.wins.length - 4)
                                    color: WalColors.color4
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                            }

                            Text {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                text: card.wsId
                                color: card.isActive ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.6)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                z: 3
                            }

                            // Klick auf die Karte (leere Flaeche) -> Workspace fokussieren
                            MouseArea {
                                anchors.fill: parent
                                z: 5
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: overview.activate(card.wsId)
                            }

                            HoverHandler {
                                id: hoverArea

                                onHoveredChanged: {
                                    if (hovered)
                                        overview.hoveredWorkspaceId = card.wsId;
                                    else if (overview.hoveredWorkspaceId === card.wsId)
                                        overview.hoveredWorkspaceId = -1;
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 180
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 180
                                }

                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

        }

        // Gezogenes Fenster folgt dem Mauszeiger
        Rectangle {
            id: dragGhost

            visible: overview.draggedWindow !== null
            width: 200
            height: 120
            radius: 8
            color: WalColors.withAlpha(WalColors.color0, 0.85)
            border.width: 2
            border.color: WalColors.color4
            opacity: 0.92
            scale: 1.05
            z: 100
            x: overview.dragGlobalPos.x - width / 2
            y: overview.dragGlobalPos.y - height / 2

            ScreencopyView {
                anchors.fill: parent
                anchors.margins: 4
                // Nur aktiv, wenn ein Drag laeuft.
                live: false
                captureSource: (overview.draggedWindow && overview.open) ? overview.draggedWindow.wayland : null
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                text: overview.draggedWindow ? (overview.draggedWindow.title || "Unbenannt") : ""
                color: WalColors.color7
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                elide: Text.ElideRight
            }

        }

        Behavior on opacity {
            enabled: !overview.instantHide

            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }

        }

    }

}
