import "../components"
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: calendar

    // Oeffnen: Hoehen-Animation (Behavior on height), wie bei den anderen
    // Dropdowns. Schliessen: Huelle bleibt an der Bar haengen und schrumpft
    // von unten nach oben (Fenster behaelt seine Groesse), nur das
    // Kalender-Raster blendet aus. Erst danach springt die Hoehe auf 0.
    property bool expanded: false
    property bool heightAnimOn: false
    property real closeFactor: 1
    required property var screen
    // ── Bar-Geometrie (identisch zu MainBar.qml) ─────────────────
    readonly property real barContainerWidth: screen.width / 1.333
    readonly property real barLeftX: (screen.width - barContainerWidth) / 2
    // Ende der flachen Bar-Unterkante (dort beginnt in der MainBar die
    // Rundung nach oben: PathLine x = screen.width / 1.361).
    readonly property real barFlatEndX: barLeftX + screen.width / 1.361
    // Abstand zwischen rechter Flare-Spitze des Menues und diesem Punkt.
    readonly property real rightInset: 8
    readonly property real panelRightX: barFlatEndX - rightInset
    // ── Menue-Geometrie ──────────────────────────────────────────
    readonly property real cornerRadius: 20
    readonly property real menuWidth: 284
    readonly property real edgePadding: 8
    readonly property real sidePadding: 18
    readonly property real topPadding: 14
    readonly property real contentWidth: menuWidth - 2 * sidePadding
    readonly property real cellWidth: contentWidth / 7
    readonly property real cellSize: 32
    // Volle Zielhoehe - Bezugsgroesse fuer Container und Panel-Hoehe.
    readonly property real fullHeight: contentColumn.implicitHeight + cornerRadius
    // ── Kalender-Daten ───────────────────────────────────────────
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

    // ── Fenster-Setup ────────────────────────────────────────────
    WlrLayershell.namespace: "quickshell:calendar"
    WlrLayershell.layer: WlrLayer.Top
    exclusiveZone: -1
    implicitWidth: menuWidth + 2 * cornerRadius
    // Panel folgt der Container-Hoehe. Bei geschlossenem Menue -> 0 px hoch,
    // dadurch blockiert es keinen Hover fuer andere Dropdowns.
    implicitHeight: container.height
    color: "transparent"

    anchors {
        top: true
        left: true
    }

    // Das Menue haengt rechtsbuendig unter der Uhr: seine rechte Flare-Spitze
    // endet kurz vor dem Ende der flachen Bar-Unterkante.
    margins {
        top: 40
        left: {
            const desired = panelRightX - implicitWidth;
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
                    // frisch geoeffnet: auf aktuellen Monat/Uhrzeit zuruecksetzen
                    calendar.displayDate = new Date();
                    calendar.cells = calendar.buildCells(calendar.displayDate.getFullYear(), calendar.displayDate.getMonth());
                    calendarClock.updateTime();
                }
                // Hover waehrend des Schliessens: wieder aufklappen + Raster einblenden
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
            // Huelle (mit Rundungen an der Bar) schrumpft nach oben
            NumberAnimation {
                target: calendar
                property: "closeFactor"
                to: 0
                duration: 280
                easing.type: Easing.InOutCubic
            }

            // nur das Kalender-Raster blendet aus, der Rest des Menues bleibt
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
                calendar.heightAnimOn = false; // erst Animation aus ...
                calendar.expanded = false; // ... dann Hoehe auf 0
                calendar.closeFactor = 1;
                gridArea.opacity = 1;
            }
        }

    }

    Item {
        id: container

        width: parent.width
        // expanded (nicht dropdownOpen!), sonst schrumpft die Hoehe beim
        // Schliessen sofort und der Inhalt wird verzerrt.
        height: calendar.expanded ? calendar.fullHeight : 0
        clip: true

        // Huelle + Inhalt. Beim Oeffnen voll hoch (der Container clippt),
        // beim Schliessen schrumpft sie samt Rundungen von unten.
        Item {
            id: body

            width: parent.width
            height: calendar.fullHeight * calendar.closeFactor
            clip: true

            RoundedDropShape {
                anchors.top: parent.top
                cornerRadius: calendar.cornerRadius
                menuWidth: calendar.menuWidth
                // mindestens 2 * Radius, sonst bricht die Pfad-Geometrie
                menuHeight: Math.max(2 * calendar.cornerRadius, calendar.fullHeight * calendar.closeFactor)
            }

            Column {
                id: contentColumn

                width: calendar.contentWidth
                topPadding: calendar.topPadding
                spacing: 10

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }

                // Uhrzeit
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

                        // tickt nur, solange das Menue sichtbar ist
                        Timer {
                            interval: 1000
                            running: calendar.expanded
                            repeat: true
                            onTriggered: calendarClock.updateTime()
                        }

                    }

                }

                // Monats-Navigation
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

                // Kalender-Raster (blendet beim Schliessen aus)
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

            // Hover-Bereich folgt der sichtbaren (schrumpfenden) Huelle.
            HoverHandler {
                onHoveredChanged: {
                    CalendarState.dropdownHovered = hovered;
                    CalendarState.updateHoverTimer();
                }
            }

        }

        // Nur beim Oeffnen aktiv (heightAnimOn). Beim Schliessen springt die
        // Hoehe erst nach dem Schrumpfen ohne Animation auf 0.
        Behavior on height {
            enabled: calendar.heightAnimOn

            Anim {
            }

        }

    }

}
