import QtQuick
pragma Singleton

QtObject {
    id: root

    property real dropdownX: 0
    property bool dropdownOpen: false
    property bool buttonHovered: false
    property bool dropdownHovered: false
    // Timer zum Schließen, wenn die Maus Icon UND Dropdown verlassen hat
    property Timer hideTimer

    // Gemeinsamer Timer: laeuft nur, wenn WEDER Icon NOCH Dropdown gehovert sind.
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
        interval: 200
        onTriggered: root.dropdownOpen = false
    }

}
