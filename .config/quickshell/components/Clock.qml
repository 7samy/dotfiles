import QtQuick
import Quickshell

Text {
    id: clockText

    // Eigener Zustand: wird beim Hover true, erst nach Ende der
    // Kalender-Schließanimation wieder false.
    property bool hideClock: false

    function updateTime() {
        clockText.text = Qt.formatDateTime(new Date(), "hh:mm:ss");
    }

    color: WalColors.color2
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14
    height: parent.height
    verticalAlignment: Text.AlignVCenter
    opacity: hideClock ? 0 : 1
    Component.onCompleted: updateTime()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockText.updateTime()
    }

    // Verzögert das Öffnen des Kalenders leicht, damit die Uhr zuerst faded
    Timer {
        id: openDelay

        interval: 120
        repeat: false
        onTriggered: CalendarState.dropdownOpen = true
    }

    // Wartet das Ende der Kalender-Schließanimation (200 ms) ab,
    // bevor die Uhr wieder eingeblendet wird.
    Timer {
        id: showDelay

        interval: 120 // etwas mehr als die 200 ms Close-Animation
        repeat: false
        onTriggered: clockText.hideClock = false
    }

    // Reagiert auf das tatsächliche Öffnen/Schließen des Kalenders
    Connections {
        function onDropdownOpenChanged() {
            if (CalendarState.dropdownOpen) {
                // Kalender öffnet sich (oder ist offen) → Uhr bleibt weg
                showDelay.stop();
                clockText.hideClock = true;
            } else {
                // Kalender fängt an zu schließen → erst danach wieder einblenden
                showDelay.restart();
            }
        }

        target: CalendarState
    }

    HoverHandler {
        onHoveredChanged: {
            CalendarState.buttonHovered = hovered;
            if (hovered) {
                // Sofort ausblenden + Kalender leicht verzögert nachschieben
                clockText.hideClock = true;
                openDelay.restart();
            } else {
                // Hover weg: geplantes Öffnen abbrechen
                openDelay.stop();
                // Falls der Kalender nie aufging (schneller Rein/Raus-Hover),
                // direkt wieder einblenden – sonst übernimmt das Connections.
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
