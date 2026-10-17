import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: panelWindow

    required property var screen
    property bool calendarOpen: false
    property bool startupDone: false
    property real morph: calendarOpen ? 1 : 0
    // Arch-Icon-Drawer: Clipboard- und 音-Icons ausfahren
    property bool drawerOpen: false
    property real revealT: drawerOpen ? 1 : 0
    property date now: new Date()
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property date selectedDate: new Date()
    property string selectedKey: Qt.formatDate(new Date(), "yyyy-MM-dd")
    readonly property string todayKey: Qt.formatDate(now, "yyyy-MM-dd")
    readonly property real barHeight: 40
    readonly property real cornerR: 20
    readonly property real barWidth: screen.width / 1.333
    readonly property real calBodyWidth: 500
    readonly property real calWidth: calBodyWidth + 2 * cornerR
    readonly property real calHeight: calColumn.implicitHeight + 24
    readonly property real calPad: 16
    readonly property real cellW: (calBodyWidth - 2 * calPad) / 8
    readonly property real cellH: 34
    readonly property real barContentOpacity: 1 - clamp01(morph / 0.12)
    readonly property real wT: smooth((morph - 0.05) / 0.55)
    readonly property real hT: smooth((morph - 0.25) / 0.6)
    readonly property real calContentOpacity: clamp01((morph - 0.8) / 0.2)
    property real nudge: 0
    readonly property real shapeW: barWidth + (calWidth - barWidth) * wT + nudge
    readonly property real shapeH: barHeight + (calHeight - barHeight) * hT
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayLong: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var weekdayShort: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    readonly property var cells: buildCells(viewYear, viewMonth)
    readonly property var weekNumbers: buildWeekNumbers(viewYear, viewMonth)

    function clamp01(x) {
        return Math.max(0, Math.min(1, x));
    }

    function smooth(x) {
        const t = clamp01(x);
        return t * t * (3 - 2 * t);
    }

    function fmtTime(s) {
        if (!s || s < 0 || isNaN(s))
            return "0:00";

        const t = Math.floor(s);
        const h = Math.floor(t / 3600);
        const m = Math.floor((t % 3600) / 60);
        const sec = t % 60;
        const ss = sec < 10 ? "0" + sec : "" + sec;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" + m : m) + ":" + ss;

        return m + ":" + ss;
    }

    function redrawShape() {
        barShape.fillColor = "transparent";
        forceRedrawTimer.restart();
    }

    function toggleCalendar() {
        if (!BarState.barVisible)
            return ;

        calendarOpen = !calendarOpen;
    }

    function closeCalendar() {
        calendarOpen = false;
    }

    function goToday() {
        now = new Date();
        viewYear = now.getFullYear();
        viewMonth = now.getMonth();
        selectedDate = now;
        selectedKey = Qt.formatDate(now, "yyyy-MM-dd");
    }

    function shiftMonth(delta) {
        const d = new Date(viewYear, viewMonth + delta, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }

    function selectCell(c) {
        selectedKey = c.key;
        selectedDate = new Date(c.year, c.month, c.day);
        if (!c.inMonth) {
            viewYear = c.year;
            viewMonth = c.month;
        }
    }

    function buildCells(year, month) {
        const offset = (new Date(year, month, 1).getDay() + 6) % 7;
        const list = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(year, month, 1 - offset + i);
            list.push({
                "day": d.getDate(),
                "month": d.getMonth(),
                "year": d.getFullYear(),
                "inMonth": d.getMonth() === month,
                "key": Qt.formatDate(d, "yyyy-MM-dd")
            });
        }
        return list;
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const dayNum = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - dayNum);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 8.64e+07 + 1) / 7);
    }

    function buildWeekNumbers(year, month) {
        const offset = (new Date(year, month, 1).getDay() + 6) % 7;
        const list = [];
        for (let r = 0; r < 6; r++) {
            list.push(isoWeek(new Date(year, month, 1 - offset + r * 7 + 3)));
        }
        return list;
    }

    function describe(d) {
        return weekdayLong[d.getDay()] + ", " + monthNames[d.getMonth()] + " " + d.getDate() + "  ·  Week " + isoWeek(d);
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Math.max(barHeight, calHeight)
    color: "transparent"
    exclusiveZone: BarState.barVisible ? 40 : 0
    WlrLayershell.keyboardFocus: calendarOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onCalendarOpenChanged: {
        if (calendarOpen) {
            if (PickerManager.isOpen("apps"))
                PickerManager.close();

            goToday();
        }
    }
    onDrawerOpenChanged: {
        if (!drawerOpen && PickerManager.isOpen("apps"))
            PickerManager.close();

    }

    margins {
        top: BarState.barVisible ? 0 : -40

        Behavior on top {
            NumberAnimation {
                duration: 400
                easing.type: BarState.barVisible ? Easing.OutBack : Easing.InQuad
            }

        }

    }

    HyprlandFocusGrab {
        windows: [panelWindow]
        active: panelWindow.calendarOpen
        onCleared: panelWindow.closeCalendar()
    }

    Connections {
        function onBarVisibleChanged() {
            if (!BarState.barVisible) {
                panelWindow.closeCalendar();
                if (PickerManager.isOpen("apps"))
                    PickerManager.close();

            }
        }

        target: BarState
    }

    Timer {
        interval: 1000
        running: panelWindow.morph > 0
        repeat: true
        onTriggered: panelWindow.now = new Date()
    }

    Item {
        id: rootContainer

        anchors.fill: parent
        opacity: BarState.barVisible ? (panelWindow.startupDone ? 1 : 0.004) : 0

        Shape {
            id: shapeItem

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: panelWindow.shapeW
            height: panelWindow.shapeH
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: barShape

                fillColor: WalColors.withAlpha(WalColors.color0, 1)
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0
                startY: 0

                PathArc {
                    x: panelWindow.cornerR
                    y: panelWindow.cornerR
                    radiusX: panelWindow.cornerR
                    radiusY: panelWindow.cornerR
                }

                PathLine {
                    x: panelWindow.cornerR
                    y: shapeItem.height - panelWindow.cornerR
                }

                PathArc {
                    x: 2 * panelWindow.cornerR
                    y: shapeItem.height
                    radiusX: panelWindow.cornerR
                    radiusY: panelWindow.cornerR
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: shapeItem.width - 2 * panelWindow.cornerR
                    y: shapeItem.height
                }

                PathArc {
                    x: shapeItem.width - panelWindow.cornerR
                    y: shapeItem.height - panelWindow.cornerR
                    radiusX: panelWindow.cornerR
                    radiusY: panelWindow.cornerR
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: shapeItem.width - panelWindow.cornerR
                    y: panelWindow.cornerR
                }

                PathArc {
                    x: shapeItem.width
                    y: 0
                    radiusX: panelWindow.cornerR
                    radiusY: panelWindow.cornerR
                }

                PathLine {
                    x: 0
                    y: 0
                }

            }

        }

        Connections {
            function onColorsUpdated() {
                panelWindow.redrawShape();
            }

            target: WalColors
        }

        Timer {
            id: forceRedrawTimer

            interval: 10
            onTriggered: barShape.fillColor = Qt.binding(() => {
                return WalColors.withAlpha(WalColors.color0, 1);
            })
        }

        Timer {
            id: startupFix

            property int ticks: 0

            interval: 150
            running: true
            repeat: true
            onTriggered: {
                ticks++;
                panelWindow.nudge = (ticks % 2 === 1) ? 0.1 : 0;
                if (ticks >= 4) {
                    stop();
                    panelWindow.startupDone = true;
                }
            }
        }

        Item {
            id: barClip

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: panelWindow.shapeW
            height: panelWindow.barHeight
            clip: true
            opacity: panelWindow.barContentOpacity
            visible: opacity > 0.01
            enabled: !panelWindow.calendarOpen

            Item {
                anchors.centerIn: parent
                width: panelWindow.barWidth
                height: panelWindow.barHeight

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 35
                    anchors.rightMargin: 35

                    // ═════════════════════════ LINKE SEITE ═════════════════════════
                    Row {
                        id: leftRow

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Item {
                            id: archBtn

                            width: 24 + 16
                            height: 32

                            Text {
                                id: archGlyph

                                x: 0
                                width: 24
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "󰣇"
                                font.pixelSize: 24
                                color: (archHover.hovered || panelWindow.drawerOpen) ? WalColors.color4 : WalColors.color2
                                rotation: panelWindow.drawerOpen ? 90 : 0
                                scale: archHover.hovered ? 1.1 : 1
                                transformOrigin: Item.Center

                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: 460
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.5
                                    }

                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 180
                                    }

                                }

                            }

                            Rectangle {
                                x: 19
                                y: 5
                                width: 6
                                height: 6
                                radius: 3
                                color: WalColors.color4
                                visible: scale > 0.01
                                scale: (JapaneseAudioState.isPlaying && !panelWindow.drawerOpen) ? 1 : 0

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 260
                                        easing.type: Easing.OutBack
                                    }

                                }

                            }

                            HoverHandler {
                                id: archHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 10
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panelWindow.drawerOpen = !panelWindow.drawerOpen
                            }

                        }

                        Item {
                            id: drawer

                            width: panelWindow.revealT * drawerContent.implicitWidth
                            height: 32
                            clip: true

                            // Pill-Ebene: gleiche Logik wie die rechte Icon-Gruppe.
                            Item {
                                id: pillLayer

                                x: drawerContent.x
                                width: drawerContent.implicitWidth
                                height: drawerContent.height
                                opacity: panelWindow.revealT

                                Rectangle {
                                    id: drawerPill

                                    x: drawerContent.pillX
                                    y: (parent.height - height) / 2
                                    width: drawerContent.pillW
                                    height: 32
                                    radius: height / 2
                                    color: WalColors.withAlpha(WalColors.color4, drawerContent.focused ? 0.3 : 0.12)

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 320
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 1.08
                                        }

                                    }

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 320
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 1.08
                                        }

                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 260
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                            }

                            Row {
                                id: drawerContent

                                // ── Pill-Logik (analog zur rechten Icon-Gruppe) ──
                                readonly property int hoveredIndex: {
                                    if (cbSlot.hovered)
                                        return 0;

                                    if (appsSlot.hovered)
                                        return 1;

                                    if (jaBtn.hovered)
                                        return 2;

                                    return -1;
                                }
                                readonly property int lockedIndex: {
                                    if (ClipboardState.pickerVisible)
                                        return 0;

                                    if (PickerManager.isOpen("apps"))
                                        return 1;

                                    if (JapaneseAudioState.isPlaying)
                                        return 2;

                                    return -1;
                                }
                                readonly property int effectiveIndex: hoveredIndex >= 0 ? hoveredIndex : lockedIndex
                                readonly property bool focused: effectiveIndex >= 0
                                readonly property real pillWidth: 34
                                // WICHTIG: Im Ruhezustand um die Differenz der Paddings verkleinern, damit die Icons exakt mittig sitzen.
                                readonly property real pillW: focused ? pillWidth : implicitWidth - (rightPadding - leftPadding)
                                readonly property real pillX: {
                                    if (!focused)
                                        return 0;

                                    if (effectiveIndex === 0)
                                        return cbSlot.x + cbSlot.width / 2 - pillWidth / 2;

                                    if (effectiveIndex === 1)
                                        return appsSlot.x + appsSlot.width / 2 - pillWidth / 2;

                                    if (effectiveIndex === 2)
                                        return jaGroup.x + jaBtn.x + jaBtn.width / 2 - pillWidth / 2;

                                    return 0;
                                }

                                x: drawer.width - implicitWidth
                                height: parent.height
                                leftPadding: 6
                                rightPadding: 16
                                spacing: 6
                                opacity: panelWindow.revealT

                                // Clipboard
                                DrawerSlot {
                                    id: cbSlot

                                    icon: "clipboard"
                                    active: ClipboardState.pickerVisible
                                    reveal: panelWindow.clamp01(panelWindow.revealT * 1.6)
                                    onClicked: ClipboardState.toggle()
                                }

                                // Laufende Apps ansehen / schließen
                                DrawerSlot {
                                    id: appsSlot

                                    icon: "apps"
                                    active: PickerManager.isOpen("apps")
                                    reveal: panelWindow.clamp01(panelWindow.revealT * 1.6 - 0.3)
                                    onClicked: PickerManager.toggle("apps")
                                }

                                Item {
                                    id: jaGroup

                                    readonly property bool miniActive: JapaneseAudioState.currentFile !== ""
                                    property bool collapsed: false
                                    readonly property bool miniShown: miniActive && !collapsed
                                    readonly property bool hoverKeep: miniHover.hovered || jaBtn.hovered || capsule.dragging
                                    readonly property real frac: JapaneseAudioState.currentDuration > 0 ? panelWindow.clamp01(JapaneseAudioState.currentPosition / JapaneseAudioState.currentDuration) : 0
                                    property real shownFrac: frac
                                    readonly property real reveal: panelWindow.clamp01(panelWindow.revealT * 1.6 - 0.6)
                                    readonly property real timeW: JapaneseAudioState.currentDuration >= 3600 ? 44 : 29
                                    readonly property real miniW: 116 + 2 * timeW

                                    height: 32
                                    width: capsule.x + capsule.width + 2
                                    opacity: reveal
                                    scale: 0.6 + 0.4 * reveal
                                    transformOrigin: Item.Left

                                    Rectangle {
                                        id: capsule

                                        readonly property bool dragging: trackMouse.pressed
                                        property real dragFrac: 0
                                        readonly property real dispFrac: dragging ? dragFrac : jaGroup.shownFrac
                                        readonly property real dispSecs: dragging ? dragFrac * JapaneseAudioState.currentDuration : JapaneseAudioState.currentPosition

                                        x: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 28
                                        radius: 14
                                        width: 28 + (jaGroup.miniShown ? jaGroup.miniW : 0)
                                        color: WalColors.withAlpha(WalColors.color4, jaGroup.miniShown ? (miniHover.hovered ? 0.2 : 0.12) : 0)

                                        HoverHandler {
                                            id: miniHover
                                        }

                                        WheelHandler {
                                            enabled: jaGroup.miniShown
                                            onWheel: (event) => {
                                                JapaneseAudioState.seekRelative(event.angleDelta.y > 0 ? 5 : -5);
                                            }
                                        }

                                        Item {
                                            id: miniWrap

                                            x: 28
                                            width: Math.max(0, capsule.width - 28)
                                            height: parent.height
                                            clip: true
                                            opacity: jaGroup.miniShown ? 1 : 0

                                            Rectangle {
                                                x: 0
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 24
                                                height: 24
                                                radius: 12
                                                color: WalColors.withAlpha(WalColors.color4, 0.3)
                                                visible: JapaneseAudioState.isPlaying
                                                opacity: 0

                                                SequentialAnimation on opacity {
                                                    running: JapaneseAudioState.isPlaying
                                                    loops: Animation.Infinite

                                                    NumberAnimation {
                                                        to: 0.9
                                                        duration: 1000
                                                        easing.type: Easing.InOutSine
                                                    }

                                                    NumberAnimation {
                                                        to: 0
                                                        duration: 1000
                                                        easing.type: Easing.InOutSine
                                                    }

                                                }

                                            }

                                            Rectangle {
                                                id: miniBtn

                                                x: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 20
                                                height: 20
                                                radius: 10
                                                color: WalColors.color4
                                                scale: miniPlayArea.pressed ? 0.9 : (miniPlayArea.containsMouse ? 1.1 : 1)

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 2
                                                    opacity: JapaneseAudioState.isPlaying ? 1 : 0
                                                    scale: JapaneseAudioState.isPlaying ? 1 : 0.4

                                                    Rectangle {
                                                        width: 2.5
                                                        height: 8
                                                        radius: 1
                                                        color: WalColors.color0
                                                    }

                                                    Rectangle {
                                                        width: 2.5
                                                        height: 8
                                                        radius: 1
                                                        color: WalColors.color0
                                                    }

                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: 140
                                                        }

                                                    }

                                                    Behavior on scale {
                                                        NumberAnimation {
                                                            duration: 180
                                                            easing.type: Easing.OutBack
                                                        }

                                                    }

                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    anchors.horizontalCenterOffset: 1
                                                    text: "▶"
                                                    font.pixelSize: 8
                                                    color: WalColors.color0
                                                    opacity: JapaneseAudioState.isPlaying ? 0 : 1
                                                    scale: JapaneseAudioState.isPlaying ? 0.4 : 1

                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: 140
                                                        }

                                                    }

                                                    Behavior on scale {
                                                        NumberAnimation {
                                                            duration: 180
                                                            easing.type: Easing.OutBack
                                                        }

                                                    }

                                                }

                                                MouseArea {
                                                    id: miniPlayArea

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: JapaneseAudioState.play(JapaneseAudioState.currentFile)
                                                }

                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: 140
                                                        easing.type: Easing.OutBack
                                                    }

                                                }

                                            }

                                            Text {
                                                x: 30
                                                width: jaGroup.timeW
                                                anchors.verticalCenter: parent.verticalCenter
                                                horizontalAlignment: Text.AlignRight
                                                text: panelWindow.fmtTime(capsule.dispSecs)
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 10
                                                font.bold: capsule.dragging
                                                color: capsule.dragging ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, JapaneseAudioState.isPlaying ? 0.9 : 0.5)

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 200
                                                    }

                                                }

                                            }

                                            Item {
                                                id: trackBox

                                                x: 30 + jaGroup.timeW + 6
                                                width: 64
                                                height: parent.height

                                                Rectangle {
                                                    id: trackBg

                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width
                                                    height: (trackMouse.containsMouse || capsule.dragging) ? 5 : 3
                                                    radius: height / 2
                                                    color: WalColors.withAlpha(WalColors.color7, 0.16)

                                                    Behavior on height {
                                                        NumberAnimation {
                                                            duration: 120
                                                        }

                                                    }

                                                }

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width * capsule.dispFrac
                                                    height: trackBg.height
                                                    radius: height / 2
                                                    color: WalColors.withAlpha(WalColors.color4, JapaneseAudioState.isPlaying ? 1 : 0.55)

                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: 200
                                                        }

                                                    }

                                                }

                                                Rectangle {
                                                    x: parent.width * capsule.dispFrac - width / 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: capsule.dragging ? 10 : (trackMouse.containsMouse ? 8 : 0)
                                                    height: width
                                                    radius: width / 2
                                                    color: WalColors.color4
                                                    border.width: 1.5
                                                    border.color: WalColors.withAlpha(WalColors.color0, 0.9)

                                                    Behavior on width {
                                                        NumberAnimation {
                                                            duration: 140
                                                            easing.type: Easing.OutBack
                                                        }

                                                    }

                                                }

                                                MouseArea {
                                                    id: trackMouse

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    preventStealing: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onPressed: (mouse) => {
                                                        capsule.dragFrac = panelWindow.clamp01(mouse.x / width);
                                                    }
                                                    onPositionChanged: (mouse) => {
                                                        if (pressed)
                                                            capsule.dragFrac = panelWindow.clamp01(mouse.x / width);

                                                    }
                                                    onReleased: {
                                                        if (JapaneseAudioState.currentDuration > 0)
                                                            JapaneseAudioState.seekToFraction(capsule.dragFrac);

                                                    }
                                                }

                                            }

                                            Text {
                                                x: trackBox.x + 64 + 6
                                                width: jaGroup.timeW
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: JapaneseAudioState.currentDuration > 0 ? panelWindow.fmtTime(JapaneseAudioState.currentDuration) : "--:--"
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 10
                                                color: WalColors.withAlpha(WalColors.color7, 0.4)
                                            }

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 240
                                                }

                                            }

                                        }

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }

                                        }

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 320
                                                easing.type: Easing.OutCubic
                                            }

                                        }

                                    }

                                    DrawerSlot {
                                        id: jaBtn

                                        x: 0
                                        icon: "wave"
                                        active: JapaneseAudioState.isPlaying
                                        playing: JapaneseAudioState.isPlaying
                                        onClicked: JapaneseAudioState.toggle()
                                    }

                                    Timer {
                                        interval: 3000
                                        running: jaGroup.miniActive && !jaGroup.collapsed && !JapaneseAudioState.isPlaying && !jaGroup.hoverKeep
                                        onTriggered: jaGroup.collapsed = true
                                    }

                                    Connections {
                                        function onIsPlayingChanged() {
                                            if (JapaneseAudioState.isPlaying)
                                                jaGroup.collapsed = false;

                                        }

                                        target: JapaneseAudioState
                                    }

                                    Behavior on shownFrac {
                                        enabled: !trackMouse.pressed

                                        NumberAnimation {
                                            duration: 950
                                            easing.type: Easing.Linear
                                        }

                                    }

                                }

                            }

                        }

                        Item {
                            width: (1 - panelWindow.revealT) * 14
                            height: 1
                        }

                        ActiveWindow {
                        }

                    }

                    Workspaces {
                        anchors.centerIn: parent
                    }

                    // ═════════════════════════ RECHTE SEITE (Dropdowns) ═════════════════════════
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        spacing: 40

                        Item {
                            id: iconGroup

                            property int hoveredIndex: -1
                            readonly property real pillWidth: 34
                            readonly property int lockedIndex: {
                                if (typeof VpnState !== "undefined" && VpnState.dropdownOpen)
                                    return 3;

                                if (typeof StatsState !== "undefined" && StatsState.dropdownOpen)
                                    return 2;

                                if (typeof AudioState !== "undefined" && AudioState.dropdownOpen)
                                    return 1;

                                return -1;
                            }
                            readonly property int effectiveIndex: hoveredIndex >= 0 ? hoveredIndex : lockedIndex
                            readonly property bool focused: effectiveIndex >= 0
                            readonly property real pillX: {
                                if (!focused)
                                    return 0;

                                const kids = [pmBtn, atBtn, stBtn, vpnBtn];
                                const c = kids[effectiveIndex];
                                if (!c)
                                    return 0;

                                return innerRow.x + c.x + c.width / 2 - pillWidth / 2;
                            }
                            readonly property real pillW: focused ? pillWidth : width

                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            width: innerRow.implicitWidth + 28

                            Rectangle {
                                id: morphPill

                                anchors.verticalCenter: parent.verticalCenter
                                height: 32
                                radius: height / 2
                                color: WalColors.withAlpha(WalColors.color4, iconGroup.focused ? 0.3 : 0.12)
                                x: iconGroup.pillX
                                width: iconGroup.pillW

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 320
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.08
                                    }

                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 320
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.08
                                    }

                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 260
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            Row {
                                id: innerRow

                                anchors.centerIn: parent
                                spacing: 10
                                height: parent.height

                                VpnToggle {
                                    id: vpnBtn

                                    hoverBoxEnabled: false
                                }

                                AudioToggle {
                                    id: atBtn

                                    hoverBoxEnabled: false
                                }

                                Stats {
                                    id: stBtn

                                    hoverBoxEnabled: false
                                }

                                PowerMenuButton {
                                    id: pmBtn

                                    hoverBoxEnabled: false
                                }

                            }

                            HoverHandler {
                                id: groupHover

                                onPointChanged: {
                                    const px = point.position.x;
                                    let found = -1;
                                    const kids = [pmBtn, atBtn, stBtn, vpnBtn];
                                    for (let i = 0; i < kids.length; i++) {
                                        const c = kids[i];
                                        if (!c)
                                            continue;

                                        const cx = innerRow.x + c.x;
                                        if (px >= cx && px <= cx + c.width) {
                                            found = i;
                                            break;
                                        }
                                    }
                                    if (iconGroup.hoveredIndex !== found)
                                        iconGroup.hoveredIndex = found;

                                }
                                onHoveredChanged: {
                                    if (!hovered)
                                        iconGroup.hoveredIndex = -1;

                                }
                            }

                        }

                        Clock {
                            onClicked: panelWindow.toggleCalendar()
                        }

                    }

                }

            }

        }

        // Kalender-Inhalt
        Item {
            id: calClip

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: panelWindow.calBodyWidth
            height: shapeItem.height
            clip: true
            opacity: panelWindow.calContentOpacity
            visible: opacity > 0.01
            enabled: panelWindow.calendarOpen
            focus: panelWindow.calendarOpen
            Keys.onPressed: (event) => {
                event.accepted = true;
                switch (event.key) {
                case Qt.Key_Escape:
                    panelWindow.closeCalendar();
                    break;
                case Qt.Key_Left:
                case Qt.Key_PageUp:
                    panelWindow.shiftMonth(-1);
                    break;
                case Qt.Key_Right:
                case Qt.Key_PageDown:
                    panelWindow.shiftMonth(1);
                    break;
                case Qt.Key_Home:
                    panelWindow.goToday();
                    break;
                default:
                    event.accepted = false;
                }
            }

            Column {
                id: calColumn

                width: panelWindow.calBodyWidth - 2 * panelWindow.calPad
                topPadding: 16
                spacing: 6

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }

                Item {
                    width: parent.width
                    height: 54

                    Item {
                        id: timeRow

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: timeText.width + secText.width + 2
                        height: timeText.height

                        Text {
                            id: timeText

                            text: Qt.formatTime(panelWindow.now, "hh:mm")
                            color: WalColors.color2
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Text {
                            id: secText

                            anchors.left: timeText.right
                            anchors.leftMargin: 2
                            anchors.baseline: timeText.baseline
                            text: Qt.formatTime(panelWindow.now, ":ss")
                            color: WalColors.withAlpha(WalColors.color2, 0.55)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                        }

                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: timeRow.bottom
                        anchors.topMargin: 2
                        text: panelWindow.describe(panelWindow.selectedDate)
                        color: WalColors.withAlpha(WalColors.color7, 0.7)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: WalColors.withAlpha(WalColors.color7, 0.1)
                }

                Item {
                    width: parent.width
                    height: 30

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: prevMouse.containsMouse ? WalColors.withAlpha(WalColors.color4, 0.2) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅁"
                            color: prevMouse.containsMouse ? WalColors.color4 : WalColors.color2
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: prevMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panelWindow.shiftMonth(-1)
                        }

                    }

                    Text {
                        anchors.centerIn: parent
                        text: panelWindow.monthNames[panelWindow.viewMonth] + " " + panelWindow.viewYear
                        color: titleMouse.containsMouse ? WalColors.color4 : WalColors.color7
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.bold: true

                        MouseArea {
                            id: titleMouse

                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panelWindow.goToday()
                        }

                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: nextMouse.containsMouse ? WalColors.withAlpha(WalColors.color4, 0.2) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅂"
                            color: nextMouse.containsMouse ? WalColors.color4 : WalColors.color2
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: nextMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panelWindow.shiftMonth(1)
                        }

                    }

                }

                Row {
                    height: 16

                    Text {
                        width: panelWindow.cellW
                        horizontalAlignment: Text.AlignHCenter
                        text: "Wk"
                        color: WalColors.withAlpha(WalColors.color4, 0.55)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.bold: true
                    }

                    Repeater {
                        model: panelWindow.weekdayShort

                        delegate: Text {
                            width: panelWindow.cellW
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: WalColors.withAlpha(WalColors.color7, 0.45)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.bold: true
                        }

                    }

                }

                Column {
                    id: dayGrid

                    WheelHandler {
                        onWheel: (event) => {
                            panelWindow.shiftMonth(event.angleDelta.y > 0 ? -1 : 1);
                        }
                    }

                    Repeater {
                        model: 6

                        delegate: Row {
                            id: weekRow

                            required property int index

                            Item {
                                width: panelWindow.cellW
                                height: panelWindow.cellH

                                Text {
                                    anchors.centerIn: parent
                                    text: panelWindow.weekNumbers[weekRow.index]
                                    color: WalColors.withAlpha(WalColors.color4, 0.5)
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                }

                            }

                            Repeater {
                                model: 7

                                delegate: Item {
                                    id: dayCell

                                    required property int index
                                    readonly property var cell: panelWindow.cells[weekRow.index * 7 + index]
                                    readonly property bool isToday: cell.key === panelWindow.todayKey
                                    readonly property bool isSelected: cell.key === panelWindow.selectedKey

                                    width: panelWindow.cellW
                                    height: panelWindow.cellH

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 30
                                        height: 30
                                        radius: 15
                                        color: dayCell.isToday ? WalColors.color4 : (dayMouse.containsMouse ? WalColors.withAlpha(WalColors.color2, 0.18) : "transparent")
                                        border.width: dayCell.isSelected && !dayCell.isToday ? 1.5 : 0
                                        border.color: WalColors.color4

                                        Text {
                                            anchors.centerIn: parent
                                            text: dayCell.cell.day
                                            color: dayCell.isToday ? WalColors.color0 : (dayCell.cell.inMonth ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.25))
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            font.bold: dayCell.isToday
                                        }

                                    }

                                    MouseArea {
                                        id: dayMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panelWindow.selectCell(dayCell.cell)
                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.slow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }

        }

    }

    // Einheitlicher Slot für alle Drawer-Icons (Hover-/Aktiv-Hintergrund übernimmt die Drawer-Pill)
    component DrawerSlot: Item {
        id: slot

        property string icon: "clipboard"
        property bool active: false
        property bool playing: false
        property real reveal: 1
        readonly property bool hovered: slotHover.hovered
        readonly property color ink: (hovered || active) ? WalColors.color4 : WalColors.withAlpha(WalColors.color2, 0.85)
        readonly property bool hoverWave: icon === "wave" && (hovered || playing)
        property real hoverEnergy: hoverWave ? 1 : 0
        property real hoverPhase: 0

        signal clicked()

        width: 32
        height: 32
        opacity: reveal
        scale: 0.6 + 0.4 * reveal

        Item {
            anchors.centerIn: parent
            width: 18
            height: 18
            visible: slot.icon === "clipboard"
            scale: slot.hovered ? 1.12 : 1

            Rectangle {
                x: 2
                y: 3
                width: 14
                height: 14
                radius: 3
                color: "transparent"
                border.width: 1.6
                border.color: slot.ink
            }

            Rectangle {
                x: 5
                y: 8
                width: slot.hovered ? 8 : 6
                height: 1.6
                radius: 0.8
                color: slot.ink

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Rectangle {
                x: 5
                y: 12
                width: slot.hovered ? 5 : 8
                height: 1.6
                radius: 0.8
                color: WalColors.withAlpha(slot.ink, 0.65)

                Behavior on width {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Rectangle {
                x: 6
                y: slot.hovered ? 0.5 : 1
                width: 6
                height: 4.5
                radius: 2
                color: slot.ink

                Behavior on y {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }

            }

        }

        Item {
            id: appsIcon

            property real spread: slot.hovered ? 1 : 0

            anchors.centerIn: parent
            width: 18
            height: 18
            visible: slot.icon === "apps"
            scale: slot.hovered ? 1.12 : 1

            Repeater {
                model: 4

                delegate: Rectangle {
                    required property int index
                    readonly property int cx: index % 2
                    readonly property int cy: Math.floor(index / 2)

                    x: 2.2 + cx * 7.6 + (cx === 0 ? -1 : 1) * appsIcon.spread
                    y: 2.2 + cy * 7.6 + (cy === 0 ? -1 : 1) * appsIcon.spread
                    width: 6.2
                    height: 6.2
                    radius: 2
                    antialiasing: true
                    color: slot.ink
                    rotation: (slot.active && index === 1) ? 45 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutBack
                        }

                    }

                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on spread {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }

            }

        }

        Row {
            anchors.centerIn: parent
            spacing: 1.9
            visible: slot.icon === "wave"
            scale: slot.hovered ? 1.12 : 1

            Repeater {
                model: 5

                delegate: Item {
                    id: bar

                    required property int index
                    readonly property var baseH: [7, 10, 12, 10, 7]
                    readonly property var hAmp: [2, 3.5, 4.5, 3.5, 2]

                    width: 2
                    height: 18

                    Rectangle {
                        x: 0
                        y: (parent.height - height) / 2
                        width: parent.width
                        height: bar.baseH[bar.index] + slot.hoverEnergy * bar.hAmp[bar.index] * Math.sin(slot.hoverPhase - bar.index * 0.9)
                        radius: width / 2
                        antialiasing: true
                        color: slot.ink
                    }

                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }

            }

        }

        HoverHandler {
            id: slotHover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: slot.clicked()
        }

        Behavior on hoverEnergy {
            NumberAnimation {
                duration: 450
                easing.type: Easing.InOutSine
            }

        }

        NumberAnimation on hoverPhase {
            from: 0
            to: 2 * Math.PI
            duration: 1600
            loops: Animation.Infinite
            running: slot.icon === "wave" && (slot.hoverWave || slot.hoverEnergy > 0.001)
        }

    }

    mask: Region {
        item: shapeItem
    }

    Behavior on morph {
        NumberAnimation {
            duration: 620
            easing.type: Easing.Linear
        }

    }

    Behavior on revealT {
        NumberAnimation {
            duration: 480
            easing.type: Easing.OutCubic
        }

    }

}
