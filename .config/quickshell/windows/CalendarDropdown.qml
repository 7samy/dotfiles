import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: calendar

    property bool expanded: false
    property bool heightAnimOn: false
    property real closeFactor: 1
    required property var screen
    readonly property real cornerRadius: 20
    readonly property real menuWidth: 284
    readonly property real edgePadding: 8
    readonly property real sidePadding: 18
    readonly property real topPadding: 14
    // Höhe der Bar: links setzt das Menü hier an (mit Kurve), rechts geht es bis y = 0
    readonly property real barHeight: 40
    // Breite des rechten Bereichs, der bis zum Bildschirmrand hochgezogen wird.
    // Bei Bedarf anpassen (von der rechten Menükante nach links gemessen).
    readonly property real rightFillWidth: 110
    // 0..1: wie weit das Menü gerade offen ist (folgt Öffnen UND Schließen).
    // Der Streifen oben rechts wächst/schrumpft damit, so wirkt es, als würde
    // sich die Bar selbst um den Kalender erweitern bzw. wieder zusammenziehen.
    readonly property real fillFactor: Math.max(0, Math.min(1, container.height / (fullHeight + barHeight), closeFactor))
    readonly property real currentFillWidth: rightFillWidth * fillFactor
    // Füllfarbe: auf die Farbe deiner RoundedDropShape.qml setzen, falls sie abweicht
    readonly property color shapeColor: WalColors.color0
    readonly property real contentWidth: menuWidth - 2 * sidePadding
    readonly property real cellWidth: contentWidth / 7
    readonly property real cellSize: 32
    readonly property real fullHeight: contentColumn.implicitHeight + cornerRadius
    readonly property var monthNames: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    readonly property var weekdayLabels: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    property date displayDate: new Date()
    readonly property int viewYear: displayDate.getFullYear()
    readonly property int viewMonth: displayDate.getMonth()
    property var cells: buildCells(viewYear, viewMonth)

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function buildCells(year, month) {
        const firstWeekday = (new Date(year, month, 1).getDay() + 6) % 7;
        const totalDays = daysInMonth(year, month);
        const prevYear = month === 0 ? year - 1 : year;
        const prevMonth = month === 0 ? 11 : month - 1;
        const prevMonthDays = daysInMonth(prevYear, prevMonth);
        const today = new Date();
        const list = [];
        for (let i = 0; i < firstWeekday; i++) {
            list.push({
                "day": prevMonthDays - firstWeekday + 1 + i,
                "inMonth": false,
                "isToday": false
            });
        }
        for (let d = 1; d <= totalDays; d++) {
            list.push({
                "day": d,
                "inMonth": true,
                "isToday": today.getFullYear() === year && today.getMonth() === month && today.getDate() === d
            });
        }
        let nextDay = 1;
        while (list.length < 42) {
            list.push({
                "day": nextDay,
                "inMonth": false,
                "isToday": false
            });
            nextDay++;
        }
        return list;
    }

    function goToPrevMonth() {
        displayDate = new Date(viewYear, viewMonth - 1, 1);
        cells = buildCells(displayDate.getFullYear(), displayDate.getMonth());
    }

    function goToNextMonth() {
        displayDate = new Date(viewYear, viewMonth + 1, 1);
        cells = buildCells(displayDate.getFullYear(), displayDate.getMonth());
    }

    WlrLayershell.namespace: "quickshell:calendar"
    WlrLayershell.layer: WlrLayer.Top
    exclusiveZone: -1
    implicitWidth: menuWidth + 2 * cornerRadius
    implicitHeight: container.height
    color: "transparent"

    anchors {
        top: true
        left: true
    }

    // Zentriert unter der Uhr. Position kommt aus CalendarState.iconCenterX,
    // das von Clock.qml per Binding live aktualisiert wird.
    // Fallback auf ~86% der Bildschirmbreite, falls der Wert noch 0 ist
    // (passiert nur im allerersten Frame, bevor die Binding feuert).
    // top: 0, weil rechts bis zum Bildschirmrand gezeichnet wird; der linke
    // Versatz um die Bar-Höhe steckt in der Shape selbst.
    margins {
        top: 0
        left: {
            const centerX = (CalendarState.iconCenterX > 0) ? CalendarState.iconCenterX : screen.width * 0.86;
            const desired = centerX - implicitWidth / 2;
            return Math.max(edgePadding, Math.min(desired, screen.width - implicitWidth - edgePadding));
        }
    }

    Connections {
        function onDropdownOpenChanged() {
            if (CalendarState.dropdownOpen) {
                const fresh = !calendar.expanded;
                closeAnim.stop();
                calendar.heightAnimOn = true;
                calendar.expanded = true;
                if (fresh) {
                    calendar.displayDate = new Date();
                    calendar.cells = calendar.buildCells(calendar.displayDate.getFullYear(), calendar.displayDate.getMonth());
                    calendarClock.updateTime();
                }
                if (calendar.closeFactor !== 1 || gridArea.opacity !== 1)
                    reopenAnim.restart();

            } else if (calendar.expanded) {
                reopenAnim.stop();
                closeAnim.restart();
            }
        }

        target: CalendarState
    }

    ParallelAnimation {
        id: reopenAnim

        NumberAnimation {
            target: calendar
            property: "closeFactor"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: gridArea
            property: "opacity"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }

    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation {
                target: calendar
                property: "closeFactor"
                to: 0
                duration: 280
                easing.type: Easing.InOutCubic
            }

            NumberAnimation {
                target: gridArea
                property: "opacity"
                to: 0
                duration: 280
                easing.type: Easing.InOutQuad
            }

        }

        ScriptAction {
            script: {
                calendar.heightAnimOn = false;
                calendar.expanded = false;
                calendar.closeFactor = 1;
                gridArea.opacity = 1;
            }
        }

    }

    Item {
        id: container

        width: parent.width
        height: calendar.expanded ? calendar.fullHeight + calendar.barHeight : 0
        clip: true

        Item {
            id: body

            width: parent.width
            height: calendar.fullHeight * calendar.closeFactor + calendar.barHeight
            clip: true

            // Eigene Form:
            //  - links: konkave Kurve unter der Bar (wie vorher)
            //  - rechts: gerade Kante bis y = 0 (Bildschirmrand), kein Anschluss an die Bar
            Shape {
                id: dropShape

                readonly property real cr: calendar.cornerRadius
                readonly property real w: calendar.implicitWidth
                readonly property real t: calendar.barHeight
                readonly property real h: calendar.barHeight + Math.max(2 * cr, calendar.fullHeight * calendar.closeFactor)
                readonly property real fw: calendar.currentFillWidth

                anchors.top: parent.top
                anchors.left: parent.left
                width: w
                height: h
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    fillColor: calendar.shapeColor
                    startX: 0
                    startY: dropShape.t

                    // konkave Kurve links oben
                    PathArc {
                        x: dropShape.cr
                        y: dropShape.t + dropShape.cr
                        radiusX: dropShape.cr
                        radiusY: dropShape.cr
                        direction: PathArc.Clockwise
                    }

                    // linke Kante nach unten
                    PathLine {
                        x: dropShape.cr
                        y: dropShape.h - dropShape.cr
                    }

                    // Ecke unten links
                    PathArc {
                        x: 2 * dropShape.cr
                        y: dropShape.h
                        radiusX: dropShape.cr
                        radiusY: dropShape.cr
                        direction: PathArc.Counterclockwise
                    }

                    // untere Kante
                    PathLine {
                        x: dropShape.w - 2 * dropShape.cr
                        y: dropShape.h
                    }

                    // Ecke unten rechts
                    PathArc {
                        x: dropShape.w - dropShape.cr
                        y: dropShape.h - dropShape.cr
                        radiusX: dropShape.cr
                        radiusY: dropShape.cr
                        direction: PathArc.Counterclockwise
                    }

                    // rechte Kante gerade bis zum Bildschirmrand
                    PathLine {
                        x: dropShape.w - dropShape.cr
                        y: 0
                    }

                    // oben entlang zurück (nur der rechte Füllbereich)
                    PathLine {
                        x: dropShape.w - dropShape.cr - dropShape.fw
                        y: 0
                    }

                    PathLine {
                        x: dropShape.w - dropShape.cr - dropShape.fw
                        y: dropShape.t
                    }

                    // zurück zum Start (Unterkante der Bar)
                    PathLine {
                        x: 0
                        y: dropShape.t
                    }

                }

            }

            Column {
                id: contentColumn

                width: calendar.contentWidth
                topPadding: calendar.topPadding
                spacing: 10

                anchors {
                    top: parent.top
                    topMargin: calendar.barHeight
                    horizontalCenter: parent.horizontalCenter
                }

                Item {
                    width: parent.width
                    height: 30

                    Text {
                        id: calendarClock

                        function updateTime() {
                            calendarClock.text = Qt.formatDateTime(new Date(), "hh:mm:ss");
                        }

                        anchors.centerIn: parent
                        color: WalColors.color2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.bold: true
                        Component.onCompleted: updateTime()

                        Timer {
                            interval: 1000
                            running: calendar.expanded
                            repeat: true
                            onTriggered: calendarClock.updateTime()
                        }

                    }

                }

                Item {
                    width: parent.width
                    height: 24

                    Text {
                        id: prevBtn

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅁"
                        color: prevMouse.containsMouse ? WalColors.color4 : WalColors.color2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16

                        MouseArea {
                            id: prevMouse

                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendar.goToPrevMonth()
                        }

                    }

                    Text {
                        anchors.centerIn: parent
                        text: calendar.monthNames[calendar.viewMonth] + " " + calendar.viewYear
                        color: WalColors.color7
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        id: nextBtn

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅂"
                        color: nextMouse.containsMouse ? WalColors.color4 : WalColors.color2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16

                        MouseArea {
                            id: nextMouse

                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendar.goToNextMonth()
                        }

                    }

                }

                Column {
                    id: gridArea

                    width: parent.width
                    spacing: 6

                    Grid {
                        columns: 7

                        Repeater {
                            model: calendar.weekdayLabels

                            delegate: Text {
                                width: calendar.cellWidth
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: WalColors.withAlpha(WalColors.color7, 0.45)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                font.bold: true
                            }

                        }

                    }

                    Grid {
                        columns: 7
                        rowSpacing: 4

                        Repeater {
                            model: calendar.cells

                            delegate: Item {
                                id: dayCell

                                readonly property var cell: modelData

                                width: calendar.cellWidth
                                height: calendar.cellSize

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: calendar.cellSize - 2
                                    height: width
                                    radius: width / 2
                                    color: dayCell.cell.isToday ? WalColors.color4 : (dayMouse.containsMouse && dayCell.cell.inMonth ? WalColors.withAlpha(WalColors.color2, 0.2) : "transparent")

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.cell.day
                                        color: dayCell.cell.isToday ? WalColors.color0 : (dayCell.cell.inMonth ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.25))
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.bold: dayCell.cell.isToday
                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 100
                                        }

                                    }

                                }

                                MouseArea {
                                    id: dayMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: dayCell.cell.inMonth
                                }

                            }

                        }

                    }

                }

            }

            HoverHandler {
                onHoveredChanged: {
                    CalendarState.dropdownHovered = hovered;
                    CalendarState.updateHoverTimer();
                }
            }

        }

        Behavior on height {
            enabled: calendar.heightAnimOn

            Anim {
            }

        }

    }

    // Nur das sichtbare Menü nimmt Eingaben an, der transparente Bereich
    // über der Bar (links) blockiert die Bar nicht.
    mask: Region {
        x: calendar.cornerRadius
        y: calendar.barHeight
        width: container.height > 0 ? calendar.menuWidth : 0
        height: Math.max(0, container.height - calendar.barHeight)

        Region {
            x: calendar.implicitWidth - calendar.cornerRadius - calendar.currentFillWidth
            y: 0
            width: container.height > 0 ? calendar.currentFillWidth : 0
            height: container.height > 0 ? calendar.barHeight : 0
        }

    }

}
