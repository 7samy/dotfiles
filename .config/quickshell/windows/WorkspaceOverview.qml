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

    function activate(id) {
        Hyprland.dispatch("workspace " + id);
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

                            // Fenster-Previews
                            // z bewusst höher als die "Klick auf freie Fläche"-MouseArea
                            // weiter unten (z: 5): sonst schluckt die überall aufliegende
                            // Karten-MouseArea jeden Press, bevor previewMouse (tief in
                            // thumbBox verschachtelt) ihn je zu Gesicht bekommt - Qt Quick
                            // reicht Mausereignisse bei Überlappung nicht automatisch an
                            // tiefer liegende Items durch. Außerhalb der Thumbnails trifft
                            // previewArea (nicht-interaktiv) ohnehin nicht, das Ereignis
                            // fällt dort ganz normal zur Karten-MouseArea durch.
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
                                        // Wichtig: thumbBox selbst bewegt sich nie (bleibt fest im Grid).
                                        // Qt Quicks Drag/DropArea-System erkennt ein DropArea-"entered"
                                        // aber nur, wenn sich die Position des Items mit Drag.active
                                        // tatsächlich ändert. Deshalb hängen die Drag-Properties jetzt am
                                        // wirklich beweglichen dragGhost weiter unten, nicht mehr hier.

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

                                            ScreencopyView {
                                                id: thumb

                                                anchors.fill: parent
                                                captureSource: thumbBox.win.wayland
                                                live: true
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

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: dragActive ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                                onPressed: (mouse) => {
                                                    pressPos = Qt.point(mouse.x, mouse.y);
                                                    dragActive = false;
                                                }
                                                onPositionChanged: (mouse) => {
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
                                                    else
                                                        // Ohne diesen Aufruf würde Qt Quick den Drag beim
                                                        // Loslassen nur abbrechen (cancel) - er muss explizit
                                                        // "gedroppt" werden, damit die DropArea, über der
                                                        // dragGhost gerade hängt, ihr onDropped feuert.
                                                        dragGhost.Drag.drop();
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

                            // Drop-Ziel über den Previews
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

                            // Klick auf freie Fläche wechselt Workspace
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
            // dragGhost trägt jetzt den eigentlichen Drag: es ist das einzige Item,
            // dessen Position sich während des Ziehens wirklich ändert (x/y sind an
            // dragGlobalPos gebunden). Genau das braucht Qt Quick, um beim Überfahren
            // einer Workspace-Karte deren DropArea "entered" auszulösen.
            Drag.active: overview.draggedWindow !== null
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Drag.mimeData: ({
                "text/plain": overview.draggedWindow ? String(overview.draggedWindow.address) : ""
            })

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
