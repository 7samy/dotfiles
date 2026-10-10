import QtQuick
pragma Singleton

QtObject {
    id: root

    property bool buttonHovered: false
    property bool dropdownHovered: false
    property bool dropdownOpen: false
    // X-Zentrum der Uhr in Bildschirmkoordinaten. Wird von Clock.qml
    // per Binding live aktualisiert, damit CalendarDropdown sich darunter
    // zentrieren kann.
    property real iconCenterX: 0
    property Timer hideTimer

    function updateHoverTimer() {
        if (!root.buttonHovered && !root.dropdownHovered)
            hideTimer.start();
        else
            hideTimer.stop();
    }

    function startHideTimer() {
        hideTimer.start();
    }

    function stopHideTimer() {
        hideTimer.stop();
    }

    hideTimer: Timer {
        interval: 400
        onTriggered: root.dropdownOpen = false
    }

}
