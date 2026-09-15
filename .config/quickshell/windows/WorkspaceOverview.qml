import "../components"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: overview

    property bool open: false
    property int hoveredWorkspaceId: -1
    property int dropTargetWorkspaceId: -1
    property var draggedWindow: null
    property point dragGlobalPos: Qt.point(0, 0)
    readonly property int columns: 5
    readonly property var slotIds: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    readonly property var kanji: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
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

    // Ermittelt die Monitor-Geometrie zu einem Workspace, egal ob
    // ws.monitor als Objekt oder nur als Name (String) vorliegt.
    function monitorGeometryFor(ws) {
        if (!ws || !ws.monitor)
            return null;

        let mon = ws.monitor;
        if (typeof mon === "string")
            mon = Hyprland.monitors.values.find((m) => {
                return m.name === mon;
            }) || null;

        return mon;
    }

    function activate(id) {
        const ws = overview.workspaceById(id);
        const mon = overview.monitorGeometryFor(ws);
        Hyprland.dispatch("workspace " + id);
        // Cursor in die Mitte des Ziel-Monitors springen lassen,
        // damit die Maus dem Fokuswechsel folgt (Hyprland warpt den
        // Cursor bei einem reinen "workspace"-Dispatch nicht immer
        // automatisch, z.B. wenn cursor:no_warps aktiv ist).
        if (mon && typeof mon.x === "number" && typeof mon.width === "number") {
            const cx = Math.round(mon.x + mon.width / 2);
            const cy = Math.round(mon.y + mon.height / 2);
            try {
                Hyprland.dispatch("movecursor " + cx + " " + cy);
            } catch (e) {
                console.log("movecursor dispatch failed:", e);
            }
        }
        close();
    }

    function findWindowByAddress(addr) {
        return Hyprland.toplevels.values.find((t) => {
            return t.address === addr;
        }) || null;
    }

    function moveWindowTo(win, wsId) {
        if (!win)
            return ;

        Hyprland.dispatch("movetoworkspacesilent " + wsId + ",address:" + win.address);
        console.log("Move window", win.address, "->", wsId);
    }

    function close() {
        open = false;
        hoveredWorkspaceId = -1;
        dropTargetWorkspaceId = -1;
    }

    WlrLayershell.namespace: "quickshell:workspaceoverview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    screen: currentScreen
    visible: open
    color: "transparent"
    onOpenChanged: {
        if (open)
            bounce.restart();

    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
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
                anchors.centerIn: parent
                columns: overview.columns
                spacing: 24

                Repeater {
                    model: overview.slotIds

                    delegate: Item {
                        id: card

                        readonly property int wsId: modelData
                        readonly property var ws: overview.workspaceById(wsId)
                        readonly property var wins: overview.windowsOn(wsId)
                        readonly property bool hasWorkspace: ws !== null
                        readonly property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
                        readonly property bool isHovered: overview.hoveredWorkspaceId === wsId
                        readonly property bool isDropTarget: overview.dropTargetWorkspaceId === wsId
                        // Nur Hover (oder aktives Drop-Ziel während eines Drags)
                        // löst das Highlight aus - der aktive Workspace bekommt
                        // dadurch keinen Dauer-Rahmen mehr.
                        readonly property bool showBorder: isHovered || isDropTarget
                        readonly property bool brightened: isHovered || isDropTarget

                        width: 380
                        height: 220
                        scale: brightened ? 1.03 : 1

                        Rectangle {
                            id: cardBg

                            anchors.fill: parent
                            radius: 16
                            color: brightened ? WalColors.withAlpha(WalColors.color0, 0.92) : WalColors.withAlpha(WalColors.color0, 0.82)
                            border.width: showBorder ? 2 : 1
                            border.color: isDropTarget ? WalColors.color2 : (isHovered ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.15))
                            clip: true

                            // Kanji im Hintergrund
                            Text {
                                anchors.centerIn: parent
                                text: overview.kanji[card.wsId - 1] || ""
                                color: WalColors.withAlpha(WalColors.color7, card.hasWorkspace ? 0.06 : 0.03)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 120
                                font.bold: true
                                z: 0
                            }

                            // Klick auf freie Fläche wechselt Workspace.
                            // WICHTIG: z liegt UNTER previewArea (z:2), damit
                            // Presses/Drags auf den Fenster-Thumbnails zuerst
                            // bei deren eigener MouseArea ankommen und nicht
                            // hier "geschluckt" werden (das war der Grund,
                            // warum Drag&Drop nie gestartet ist).
                            MouseArea {
                                anchors.fill: parent
                                z: 1
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: overview.activate(card.wsId)
                            }

                            // Fenster-Previews
                            Item {
                                id: previewArea

                                anchors.fill: parent
                                anchors.margins: 10
                                anchors.bottomMargin: 30
                                clip: true
                                z: 2

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
                                            Drag.active: previewMouse.dragActive
                                            Drag.hotSpot: Qt.point(previewMouse.lastX, previewMouse.lastY)
                                            Drag.mimeData: ({
                                                "text/plain": String(thumbBox.win.address)
                                            })

                                            ScreencopyView {
                                                id: thumb

                                                anchors.fill: parent
                                                captureSource: thumbBox.win.wayland
                                                live: false
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

                                            MouseArea {
                                                id: previewMouse

                                                property bool dragActive: false
                                                property point pressPos: Qt.point(0, 0)
                                                property real lastX: 0
                                                property real lastY: 0

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: dragActive ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                                onPressed: (mouse) => {
                                                    pressPos = Qt.point(mouse.x, mouse.y);
                                                    lastX = mouse.x;
                                                    lastY = mouse.y;
                                                    dragActive = false;
                                                }
                                                onPositionChanged: (mouse) => {
                                                    lastX = mouse.x;
                                                    lastY = mouse.y;
                                                    if (!dragActive && (Math.abs(mouse.x - pressPos.x) > 8 || Math.abs(mouse.y - pressPos.y) > 8)) {
                                                        dragActive = true;
                                                        overview.dropTargetWorkspaceId = -1;
                                                        overview.draggedWindow = thumbBox.win;
                                                    }
                                                    if (dragActive)
                                                        overview.dragGlobalPos = previewMouse.mapToItem(dimmer, mouse.x, mouse.y);

                                                }
                                                onReleased: {
                                                    if (!dragActive)
                                                        overview.activate(card.wsId);

                                                    dragActive = false;
                                                    overview.draggedWindow = null;
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

                            // Workspace-Nummer unten rechts - Akzentfarbe
                            // markiert dezent den aktiven Workspace, zählt aber
                            // nicht als "Highlight" (siehe showBorder/brightened)
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

                            // Drop-Ziel über den Previews (bewusst ganz oben,
                            // damit man auch über bestehende Thumbnails droppen
                            // kann - eine DropArea "schluckt" aber keine
                            // normalen Klicks, blockiert also nichts).
                            DropArea {
                                anchors.fill: parent
                                z: 4
                                onEntered: {
                                    overview.dropTargetWorkspaceId = card.wsId;
                                }
                                onExited: {
                                    if (overview.dropTargetWorkspaceId === card.wsId)
                                        overview.dropTargetWorkspaceId = -1;

                                }
                                onDropped: (drop) => {
                                    const addr = drop.text;
                                    const win = overview.findWindowByAddress(addr);
                                    if (win && win.workspace && win.workspace.id !== card.wsId)
                                        overview.moveWindowTo(win, card.wsId);

                                    overview.dropTargetWorkspaceId = -1;
                                }
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

        // Ghost, der beim Ziehen der Maus folgt
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
                captureSource: overview.draggedWindow ? overview.draggedWindow.wayland : null
                live: false
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
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }

        }

    }

}
