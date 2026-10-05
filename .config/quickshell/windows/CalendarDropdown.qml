import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: calendar

    required property var screen
    // ── Geometrie ─────────────────────────────────────────────────────
    // Bar-Geometrie (aus MainBar.qml abgeleitet)
    readonly property real barContainerWidth: screen.width / 1.333
    readonly property real barHeight: screen.width / 64
    readonly property real barRightEdgeX: (screen.width + barContainerWidth) / 2
    // Kalender-Geometrie
    readonly property real dropdownWidth: 450
    readonly property real panelLeftX: screen.width - dropdownWidth
    readonly property real barOffset: barRightEdgeX - panelLeftX
    readonly property real topRadius: 20
    readonly property real cornerRadius: 20
    readonly property real hugRadius: 20
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
    implicitHeight: content.implicitHeight + 24 + hugRadius + barHeight
    color: "transparent"
    visible: container.revealProgress > 0.001

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

        property real revealProgress: CalendarState.dropdownOpen ? 1 : 0

        anchors.fill: parent

        HoverHandler {
            onHoveredChanged: {
                CalendarState.dropdownHovered = hovered;
                CalendarState.updateHoverTimer();
            }
        }

        // ── Reveal-Fenster ────────────────────────────────────────────
        // Anker liegt an der linken Kante der Hug-Kurve, also dort,
        // wo der Kalender an die Bar anschließt. Der Clip wächst von
        // hier auschließlich nach rechts und unten - wie wenn man die
        // Ecke greift und das Kaugummi diagonal nach unten-rechts zieht.
        Item {
            id: revealClip

            // ★ Fester Anker: Startpunkt der Hug-Kurve an der Bar-Unterkante
            readonly property real anchorX: calendar.barOffset - calendar.topRadius
            readonly property real anchorY: calendar.barHeight

            clip: true
            // ★ Anker bleibt stehen, nur Größe wächst
            x: anchorX
            y: anchorY
            width: (calendar.implicitWidth - anchorX) * container.revealProgress
            height: (calendar.implicitHeight - anchorY) * container.revealProgress

            // ── Hintergrund-Form ──────────────────────────────────────
            Shape {
                id: bgShape

                property color bgColor: WalColors.withAlpha(WalColors.color0, 1)

                // Shape liegt in Fensterkoordinaten, relativ zum Anker
                x: -revealClip.anchorX
                y: -revealClip.anchorY
                width: calendar.implicitWidth
                height: calendar.implicitHeight
                smooth: true
                antialiasing: true
                // ★ Shape als Textur backen - eliminiert Sub-Pixel-Wobbeln
                layer.enabled: true
                layer.smooth: true
                layer.samples: 16

                ShapePath {
                    // ★ Kein Top-Strip mehr. Die Form beginnt direkt an
                    //   der Bar-Unterkante und hat nur die Hug-Kurve
                    //   oben links, damit's sauber an die Bar anschließt.

                    fillColor: bgShape.bgColor
                    strokeColor: "transparent"
                    strokeWidth: 0

                    // Start: obere rechte Ecke des Kalenderkörpers
                    PathMove {
                        x: bgShape.width
                        y: calendar.barHeight
                    }

                    // Nach links bis zum Start der Hug-Kurve
                    PathLine {
                        x: calendar.barOffset - calendar.topRadius
                        y: calendar.barHeight
                    }

                    // Konkave Hug-Kurve runter zur Körper-Linkkante
                    PathQuad {
                        x: calendar.barOffset
                        y: calendar.barHeight + calendar.topRadius
                        controlX: calendar.barOffset
                        controlY: calendar.barHeight
                    }

                    // Linke Außenkante des Kalenders nach unten
                    PathLine {
                        x: calendar.barOffset
                        y: bgShape.height - calendar.hugRadius - calendar.cornerRadius
                    }

                    // Konvexe Abrundung unten links
                    PathQuad {
                        x: calendar.barOffset + calendar.cornerRadius
                        y: bgShape.height - calendar.hugRadius
                        controlX: calendar.barOffset
                        controlY: bgShape.height - calendar.hugRadius
                    }

                    // Untere Kante nach rechts
                    PathLine {
                        x: bgShape.width - calendar.hugRadius
                        y: bgShape.height - calendar.hugRadius
                    }

                    // Konkave Anschmiegung unten rechts an den Rand
                    PathQuad {
                        x: bgShape.width
                        y: bgShape.height
                        controlX: bgShape.width
                        controlY: bgShape.height - calendar.hugRadius
                    }

                    // Rechte Kante hoch zur Startposition
                    PathLine {
                        x: bgShape.width
                        y: calendar.barHeight
                    }

                }

            }

            // ── Inhalt ────────────────────────────────────────────────
            Column {
                id: content

                // Content in Fensterkoordinaten positionieren, aber
                // um den Anker-Versatz korrigiert.
                x: calendar.barOffset + (calendar.implicitWidth - calendar.barOffset - width) / 2 - revealClip.anchorX
                y: calendar.barHeight - revealClip.anchorY
                width: calendar.dropdownWidth - calendar.barOffset - 28
                spacing: 10
                topPadding: 10
                bottomPadding: 16

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
                            running: true
                            repeat: true
                            onTriggered: calendarClock.updateTime()
                        }

                    }

                }

                Row {
                    width: parent.width
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
                    width: parent.width
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

        }

        Behavior on revealProgress {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }

        }

    }

}
