import QtQuick
import Quickshell

Item {
    id: clockRoot

    // Eigener Zustand: wird beim Hover true, erst nach Ende der
    // Kalender-Schließanimation wieder false.
    property bool hideClock: false

    function updateTime() {
        timeText.text = Qt.formatDateTime(new Date(), "hh:mm AP");
        dateText.text = Qt.formatDateTime(new Date(), "MMMM d, yyyy");
    }

    // Wird vom Hover-Handler gesetzt und von CalendarState gelesen.
    implicitWidth: clockColumn.implicitWidth
    implicitHeight: parent.height
    Component.onCompleted: updateTime()
    // Alles zusammen ausblenden/einblenden beim Kalender-Öffnen
    opacity: hideClock ? 0 : 1

    Column {
        id: clockColumn

        anchors.centerIn: parent
        spacing: 0

        Text {
            id: timeText

            anchors.horizontalCenter: parent.horizontalCenter
            color: WalColors.color2
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            id: dateText

            anchors.horizontalCenter: parent.horizontalCenter
            color: WalColors.color2
            opacity: 0.7
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockRoot.updateTime()
    }

    // Verzögert das Öffnen des Kalenders leicht, damit die Uhr zuerst faded
    Timer {
        id: openDelay

        interval: 120
        repeat: false
        onTriggered: CalendarState.dropdownOpen = true
    }

    // Wartet das Ende der Kalender-Schließanimation ab,
    // bevor die Uhr wieder eingeblendet wird.
    Timer {
        id: showDelay

        interval: 220
        repeat: false
        onTriggered: clockRoot.hideClock = false
    }

    // Reagiert auf das tatsächliche Öffnen/Schließen des Kalenders
    Connections {
        function onDropdownOpenChanged() {
            if (CalendarState.dropdownOpen) {
                showDelay.stop();
                clockRoot.hideClock = true;
            } else {
                showDelay.restart();
            }
        }

        target: CalendarState
    }

    HoverHandler {
        onHoveredChanged: {
            CalendarState.buttonHovered = hovered;
            if (hovered) {
                clockRoot.hideClock = true;
                openDelay.restart();
            } else {
                openDelay.stop();
                if (!CalendarState.dropdownOpen)
                    showDelay.restart();

            }
            CalendarState.updateHoverTimer();
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.InOutCubic
        }

    }

}
