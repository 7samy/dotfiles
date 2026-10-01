import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    // BR: CONCAVE

    id: calendar

    required property var screen
    // ── Geometrie ─────────────────────────────────────────────────────
    readonly property real topRadius: 20
    // TL: CONVEX
    readonly property real cornerRadius: 20
    // BL: CONVEX
    readonly property real hugRadius: 20
    readonly property real dropdownWidth: 380
    readonly property real barHeight: 40
    // ── Kalender-Daten ────────────────────────────────────────────────
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
        for (let i = 0; i < firstWeekday; i++) list.push({
            "day": prevMonthDays - firstWeekday + 1 + i,
            "inMonth": false,
            "isToday": false
        })
        for (let d = 1; d <= totalDays; d++) list.push({
            "day": d,
            "inMonth": true,
            "isToday": today.getFullYear() === year && today.getMonth() === month && today.getDate() === d
        })
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

    // ── Fenster-Setup ─────────────────────────────────────────────────
    WlrLayershell.namespace: "quickshell:calendar"
    WlrLayershell.layer: WlrLayer.Top
    exclusiveZone: -1
    implicitWidth: dropdownWidth
    implicitHeight: content.implicitHeight + 24
    color: "transparent"
    visible: CalendarState.dropdownOpen || container.width > 1

    anchors {
        top: true
        right: true
    }

    margins {
        top: 0
        right: 0
    }

    Connections {
        function onDropdownOpenChanged() {
            if (CalendarState.dropdownOpen) {
                calendar.displayDate = new Date();
                calendar.cells = calendar.buildCells(calendar.displayDate.getFullYear(), calendar.displayDate.getMonth());
            }
        }

        target: CalendarState
    }

    // ── Container ─────────────────────────────────────────────────────
    Item {
        id: container

        anchors.top: parent.top
        anchors.left: parent.left
        width: CalendarState.dropdownOpen ? calendar.implicitWidth : 0
        height: CalendarState.dropdownOpen ? calendar.implicitHeight : 0
        clip: true

        HoverHandler {
            onHoveredChanged: {
                CalendarState.dropdownHovered = hovered;
                CalendarState.updateHoverTimer();
            }
        }

        // ── Hintergrund ───────────────────────────────────────────────
        // TL und BL: convex (Kontrollpunkt in der äußeren Ecke)
        // BR: concave (Kontrollpunkt in der inneren Ecke → S-Kurve)
        Shape {
            id: bgShape

            property color bgColor: WalColors.withAlpha(WalColors.color0, 1)

            anchors.fill: parent
            smooth: true
            antialiasing: true

            ShapePath {
                fillColor: bgShape.bgColor
                strokeColor: "transparent"
                strokeWidth: 0

                // Start: oben-rechts (flush mit Bildschirmrand)
                PathMove {
                    x: bgShape.width
                    y: 0
                }

                // obere Kante nach links
                PathLine {
                    x: calendar.topRadius
                    y: 0
                }

                // ── TL: CONVEX ──
                // Kontrollpunkt in der äußeren Ecke (0,0) → runde Ecke
                PathQuad {
                    x: 0
                    y: calendar.topRadius
                    controlX: 0
                    controlY: 0
                }

                // linke Kante nach unten
                PathLine {
                    x: 0
                    y: bgShape.height - calendar.cornerRadius
                }

                // ── BL: CONVEX ──
                // Kontrollpunkt in der äußeren Ecke (0, H) → runde Ecke
                PathQuad {
                    x: calendar.cornerRadius
                    y: bgShape.height
                    controlX: 0
                    controlY: bgShape.height
                }

                // untere Kante nach rechts
                PathLine {
                    x: bgShape.width - calendar.hugRadius
                    y: bgShape.height
                }

                // ── BR: CONCAVE ──
                // Kontrollpunkt in der inneren Ecke (W-R, H-R) → S-Kurve nach innen
                PathQuad {
                    x: bgShape.width
                    y: bgShape.height - calendar.hugRadius
                    controlX: bgShape.width - calendar.hugRadius
                    controlY: bgShape.height - calendar.hugRadius
                }

                // rechte Kante nach oben (flush)
                PathLine {
                    x: bgShape.width
                    y: 0
                }

            }

        }

        // ── Inhalt ────────────────────────────────────────────────────
        Column {
            id: content

            x: (calendar.implicitWidth - width) / 2
            y: 0
            width: calendar.dropdownWidth - 28
            spacing: 10
            topPadding: 0
            bottomPadding: 16

            Item {
                width: parent.width
                height: calendar.barHeight

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
                        running: true
                        repeat: true
                        onTriggered: calendarClock.updateTime()
                    }

                }

            }

            Row {
                width: calendar.dropdownWidth - 28
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    id: prevBtn

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
                    width: parent.width - prevBtn.width - nextBtn.width - 16
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: calendar.monthNames[calendar.viewMonth] + " " + calendar.viewYear
                    color: WalColors.color7
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    id: nextBtn

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
                width: calendar.dropdownWidth - 28
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Grid {
                    width: parent.width
                    columns: 7

                    Repeater {
                        model: calendar.weekdayLabels

                        delegate: Text {
                            width: parent.width / 7
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
                    id: dayGrid

                    width: parent.width
                    columns: 7
                    rowSpacing: 4

                    Repeater {
                        model: calendar.cells

                        delegate: Rectangle {
                            id: dayCell

                            readonly property var cell: modelData

                            width: dayGrid.width / 7
                            height: width
                            radius: width / 2
                            color: cell.isToday ? WalColors.color4 : (dayMouse.containsMouse && cell.inMonth ? WalColors.withAlpha(WalColors.color2, 0.2) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: cell.day
                                color: cell.isToday ? WalColors.color0 : (cell.inMonth ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.25))
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.bold: cell.isToday
                            }

                            MouseArea {
                                id: dayMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: cell.inMonth
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }

                            }

                        }

                    }

                }

            }

        }

        Behavior on width {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }

        }

        Behavior on height {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }

        }

    }

}
