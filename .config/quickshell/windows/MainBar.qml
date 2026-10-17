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
        if (calendarOpen)
            goToday();

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
            if (!BarState.barVisible)
                panelWindow.closeCalendar();

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
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 16 // Von 20 auf 16 reduziert für etwas mehr Nähe

                        Text {
                            text: "󰣇"
                            color: WalColors.color2
                            font.pixelSize: 24
                            verticalAlignment: Text.AlignVCenter
                        }

                        ClipboardToggle {
                        }

                        // Japanese Audio Toggle (Kanji 音)
                        Item {
                            id: jaBtn

                            width: 24
                            height: 24

                            // Hover-Hintergrund
                            Rectangle {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                radius: 8
                                color: WalColors.withAlpha(WalColors.color4, 0.15)
                                visible: jaHover.hovered
                                scale: jaHover.hovered ? 1 : 0.6

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            Text {
                                anchors.centerIn: parent
                                text: "音"
                                font.pixelSize: 18
                                font.bold: true
                                font.family: "JetBrainsMono Nerd Font"
                                color: (jaHover.hovered || JapaneseAudioState.isPlaying) ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.5)
                                // Skalierung beim Hovern
                                scale: jaHover.hovered ? 1.15 : 1
                                transformOrigin: Item.Center

                                // Von 6 auf 5 Pixel reduziert
                                transform: Translate {
                                    y: 5
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }

                                }

                            }

                            HoverHandler {
                                id: jaHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: JapaneseAudioState.toggle()
                            }

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
                            // 0=PowerMenu, 1=Audio, 2=Stats, 3=VPN
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

    mask: Region {
        item: shapeItem
    }

    Behavior on morph {
        NumberAnimation {
            duration: 620
            easing.type: Easing.Linear
        }

    }

}
