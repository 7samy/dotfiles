import "../components"
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Task-Manager im Stil des Clipboard-Pickers (volle Fläche, zentriertes Panel,
// Backdrop-Klick schließt, Intro-Animation, Keyboard-Nav).
//   • Klick auf die Zeile  → Fenster fokussieren + Picker schließen
//   • Klick auf ✕          → Fenster sauber schließen
//   • Shift + Klick auf ✕  → Prozess hart beenden (kill -9)
//   • ↑↓ Auswahl, Enter Fokus, Del/Backspace Schließen, Shift+Del Force-Quit
Item {
    id: root

    // ───────── Layout ─────────
    readonly property real pad: 16
    readonly property real panelWidth: Math.min(480, width - 48)
    readonly property real innerWidth: panelWidth - 2 * pad
    readonly property real rowH: 52
    readonly property real rowGap: 4
    readonly property real rowStride: rowH + rowGap
    readonly property real listMaxH: rowStride * 7
    readonly property string mono: "JetBrainsMono Nerd Font"

    // ───────── State ─────────
    property bool intro: true
    property real shown: 0
    property int selectedIndex: 0

    // ───────── Data ─────────
    readonly property var ignored: ["ueberzug", "xwaylandvideobridge"]
    readonly property var apps: {
        const v = Hyprland.toplevels.values;
        const out = [];
        for (let i = 0; i < v.length; i++) {
            if (isApp(v[i]))
                out.push(v[i]);
        }
        return out;
    }
    readonly property real listH: Math.min(apps.length * rowStride - (apps.length > 0 ? rowGap : 0), listMaxH)

    // ───────── Focus (aufgerufen vom PickerWindow) ─────────
    function focusSearch() {
        root.forceActiveFocus();
        clampSelection();
    }

    function clampSelection() {
        selectedIndex = Math.max(0, Math.min(selectedIndex, apps.length - 1));
    }

    function scrollTo(i) {
        if (apps.length === 0)
            return ;
        const top = i * rowStride;
        const bottom = top + rowH;
        let to = list.contentY;
        if (top - 6 < to)
            to = top - 6;
        else if (bottom + 6 > to + list.height)
            to = bottom + 6 - list.height;

        const maxY = Math.max(0, apps.length * rowStride - rowGap - list.height);
        listScroll.stop();
        listScroll.to = Math.max(0, Math.min(to, maxY));
        listScroll.start();
    }

    function moveSelection(dir) {
        if (apps.length === 0)
            return ;

        const n = selectedIndex + dir;
        if (n < 0 || n >= apps.length)
            return ;

        selectedIndex = n;
        scrollTo(n);
    }

    // ───────── Fenster-Operationen ─────────
    function appClass(t) {
        const o = t.lastIpcObject;
        const fromWayland = t.wayland ? t.wayland.appId : "";
        return fromWayland || (o ? (o["class"] ?? "") : "");
    }

    function isApp(t) {
        if (t.address === "")
            return false;

        const cls = appClass(t).toLowerCase();
        const title = (t.title ?? "").toLowerCase();
        for (let i = 0; i < ignored.length; i++) {
            if (cls.indexOf(ignored[i]) >= 0 || title.indexOf(ignored[i]) >= 0)
                return false;
        }
        const o = t.lastIpcObject;
        if (o && o["mapped"] === false)
            return false;

        const sz = o ? o["size"] : null;
        if (sz && sz.length >= 2 && sz[0] > 0 && sz[1] > 0 && sz[0] < 40 && sz[1] < 40)
            return false;

        return true;
    }

    function addr(t) {
        return t.address.startsWith("0x") ? t.address : "0x" + t.address;
    }

    function focusWindow(t) {
        if (t.wayland)
            t.wayland.activate();
        else
            Hyprland.dispatch("focuswindow address:" + addr(t));
    }

    function closeWindow(t) {
        if (t.wayland)
            t.wayland.close();
        else
            Hyprland.dispatch("closewindow address:" + addr(t));
    }

    function killWindow(t) {
        const obj = t.lastIpcObject;
        const pid = obj ? obj["pid"] : 0;
        if (pid > 0)
            Quickshell.execDetached(["kill", "-9", String(pid)]);
        else
            closeWindow(t);
    }

    function activateCurrent(alt) {
        const t = apps[selectedIndex];
        if (!t)
            return ;

        if (alt) {
            closeWindow(t);
        } else {
            focusWindow(t);
            PickerManager.close();
        }
    }

    function closeCurrent(hard) {
        const t = apps[selectedIndex];
        if (!t)
            return ;

        if (hard)
            killWindow(t);
        else
            closeWindow(t);
    }

    // ───────── Lifecycle ─────────
    function playIntro() {
        intro = true;
        introTimer.restart();
        introAnim.restart();
        selectedIndex = 0;
        list.contentY = 0;
    }

    Component.onCompleted: playIntro()
    onVisibleChanged: {
        if (visible)
            playIntro();
    }
    onAppsChanged: clampSelection()

    focus: true
    Keys.onPressed: (event) => {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        switch (event.key) {
        case Qt.Key_Escape:
            PickerManager.close();
            event.accepted = true;
            break;
        case Qt.Key_Down:
            moveSelection(1);
            event.accepted = true;
            break;
        case Qt.Key_Up:
            moveSelection(-1);
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activateCurrent(shift);
            event.accepted = true;
            break;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            closeCurrent(shift);
            event.accepted = true;
            break;
        case Qt.Key_Tab:
            PickerManager.cycle();
            event.accepted = true;
            break;
        case Qt.Key_Backtab:
            PickerManager.cycleBackward();
            event.accepted = true;
            break;
        }
    }

    // ───────── Timers / Animations ─────────
    Timer {
        id: introTimer
        interval: 700
        running: true
        onTriggered: root.intro = false
    }

    NumberAnimation {
        id: introAnim
        target: root
        property: "shown"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    NumberAnimation {
        id: listScroll
        target: list
        property: "contentY"
        duration: 300
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    // Klick außerhalb → schließen (wie Clipboard)
    MouseArea {
        anchors.fill: parent
        onClicked: PickerManager.close()
    }

    // ═════════════════ Panel ═════════════════
    Item {
        id: panel

        width: root.panelWidth
        height: column.implicitHeight + 2 * root.pad
        x: (root.width - width) / 2
        y: Math.max(40, root.height * 0.12) + (1 - root.shown) * 24
        opacity: Math.min(1, root.shown * 1.6)
        scale: 0.95 + 0.05 * root.shown
        transformOrigin: Item.Top

        // Weicher Schatten (gleicher Stack wie Clipboard)
        Repeater {
            model: 5

            Rectangle {
                readonly property real grow: (index + 1) * 6

                x: -grow
                y: -grow + 14
                width: panel.width + 2 * grow
                height: panel.height + 2 * grow
                radius: 28 + grow
                color: "#000000"
                opacity: 0.05
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 28
            color: WalColors.withAlpha(WalColors.color0, 0.97)
            border.width: 1
            border.color: WalColors.withAlpha(WalColors.color7, 0.09)
        }

        // Klicks im Panel abfangen
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            x: root.pad
            y: root.pad
            width: root.innerWidth
            spacing: 0

            // ───────── Header ─────────
            Item {
                width: parent.width
                height: 44

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Running Apps"
                    color: WalColors.color7
                    font.family: root.mono
                    font.pixelSize: 14
                    font.bold: true
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    width: Math.max(22, countText.implicitWidth + 16)
                    radius: 11
                    color: WalColors.withAlpha(WalColors.color7, 0.08)

                    Text {
                        id: countText

                        anchors.centerIn: parent
                        text: root.apps.length
                        color: WalColors.withAlpha(WalColors.color7, 0.55)
                        font.family: root.mono
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            // ───────── Liste ─────────
            Item {
                width: parent.width
                height: root.apps.length > 0 ? 8 + root.listH : 0
                visible: height > 0.5
                clip: true

                ListView {
                    id: list

                    y: 8
                    width: parent.width
                    height: root.listH
                    spacing: 0
                    model: root.apps
                    currentIndex: root.selectedIndex
                    highlightFollowsCurrentItem: false
                    cacheBuffer: 400
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    onMovementStarted: listScroll.stop()

                    // Gleitende Auswahl-Pille
                    highlight: Rectangle {
                        y: root.selectedIndex * root.rowStride
                        width: list.width
                        height: root.rowH
                        radius: 16
                        color: WalColors.withAlpha(WalColors.color4, 0.13)

                        Behavior on y {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property var obj: modelData.lastIpcObject ?? ({})
                        readonly property string cls: root.appClass(modelData)
                        readonly property var entry: cls !== "" ? DesktopEntries.heuristicLookup(cls) : null
                        readonly property string appName: entry?.name ?? (cls !== "" ? cls : modelData.title)
                        readonly property string iconSrc: {
                            if (entry && entry.icon) {
                                const p = Quickshell.iconPath(entry.icon, true);
                                if (p)
                                    return p;
                            }
                            if (cls !== "") {
                                const p2 = Quickshell.iconPath(cls.toLowerCase(), true);
                                if (p2)
                                    return p2;
                            }
                            return "";
                        }
                        readonly property int ws: modelData.workspace ? modelData.workspace.id : 0
                        readonly property bool isActive: modelData.activated
                        readonly property bool selected: root.selectedIndex === index

                        width: list.width
                        height: root.rowStride
                        opacity: root.intro ? 0 : 1

                        Component.onCompleted: {
                            if (root.intro)
                                rowEnter.start();
                        }

                        SequentialAnimation {
                            id: rowEnter

                            PauseAnimation {
                                duration: Math.min(row.index, 9) * 30 + 60
                            }
                            NumberAnimation {
                                target: row
                                property: "opacity"
                                to: 1
                                duration: 460
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                            }
                        }

                        Item {
                            width: parent.width
                            height: root.rowH

                            HoverHandler {
                                id: rowHover
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: (rowHover.hovered && !row.selected) ? WalColors.withAlpha(WalColors.color7, 0.06) : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedIndex = row.index;
                                    root.focusWindow(row.modelData);
                                    PickerManager.close();
                                }
                            }

                            // Icon
                            Item {
                                id: iconBox

                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                height: 34

                                Image {
                                    anchors.fill: parent
                                    visible: row.iconSrc !== ""
                                    source: row.iconSrc
                                    sourceSize.width: 68
                                    sourceSize.height: 68
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible: row.iconSrc === ""
                                    radius: 11
                                    color: WalColors.withAlpha(WalColors.color7, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: row.appName.length > 0 ? row.appName.charAt(0).toUpperCase() : "?"
                                        color: WalColors.withAlpha(WalColors.color7, 0.55)
                                        font.family: root.mono
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }
                            }

                            // ✕
                            Rectangle {
                                id: closeBtn

                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22
                                radius: 11
                                opacity: (row.selected || rowHover.hovered) ? 1 : 0
                                color: closeMouse.containsMouse ? WalColors.withAlpha(WalColors.color1, 0.9) : WalColors.withAlpha(WalColors.color7, 0.1)
                                scale: closeMouse.pressed ? 0.9 : 1

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 140
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 8
                                    height: 1.4
                                    radius: 0.7
                                    rotation: 45
                                    color: closeMouse.containsMouse ? WalColors.color0 : WalColors.withAlpha(WalColors.color7, 0.6)
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 8
                                    height: 1.4
                                    radius: 0.7
                                    rotation: -45
                                    color: closeMouse.containsMouse ? WalColors.color0 : WalColors.withAlpha(WalColors.color7, 0.6)
                                }

                                MouseArea {
                                    id: closeMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (mouse.modifiers & Qt.ShiftModifier)
                                            root.killWindow(row.modelData);
                                        else
                                            root.closeWindow(row.modelData);
                                    }
                                }
                            }

                            // Workspace-Nummer (dezent, verschwindet bei Hover/Select)
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: (rowHover.hovered || row.selected) ? 42 : 18
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.ws > 0
                                opacity: (rowHover.hovered || row.selected) ? 0 : 1
                                text: row.ws
                                color: WalColors.withAlpha(WalColors.color7, 0.4)
                                font.family: root.mono
                                font.pixelSize: 11

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 140
                                    }
                                }
                                Behavior on anchors.rightMargin {
                                    NumberAnimation {
                                        duration: 140
                                    }
                                }
                            }

                            // Name + Titel
                            Column {
                                anchors.left: iconBox.right
                                anchors.leftMargin: 12
                                anchors.right: closeBtn.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: row.appName
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    color: (row.selected || row.isActive) ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.72)
                                    font.family: root.mono
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: closeMouse.containsMouse ? "Close  ·  Shift+Click: force quit" : row.modelData.title
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    color: closeMouse.containsMouse ? WalColors.withAlpha(WalColors.color1, 0.9) : WalColors.withAlpha(WalColors.color7, 0.45)
                                    font.family: root.mono
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }

            // ───────── Leer ─────────
            Item {
                width: parent.width
                height: root.apps.length === 0 ? 100 : 0
                visible: height > 0.5

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "◌"
                        font.pixelSize: 32
                        color: WalColors.withAlpha(WalColors.color7, 0.2)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Nothing running"
                        font.family: root.mono
                        font.pixelSize: 12
                        color: WalColors.withAlpha(WalColors.color7, 0.38)
                    }
                }
            }

            // ───────── Footer ─────────
            Item {
                width: parent.width
                height: 14 + 18

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    y: 14
                    height: 18
                    verticalAlignment: Text.AlignVCenter
                    text: "↑↓ Select  ·  Enter Focus  ·  Del Close  ·  Shift+Del Force Quit"
                    font.family: root.mono
                    font.pixelSize: 10
                    color: WalColors.withAlpha(WalColors.color7, 0.4)
                }
            }
        }
    }
}
