import QtQuick
pragma Singleton

QtObject {
    id: root

    property real dropdownX: 0
    property bool dropdownOpen: false
    property bool buttonHovered: false
    // Timer zum Schließen, wenn die Maus das Icon/Dropdown verlässt
    property Timer hideTimer

    hideTimer: Timer {
        interval: 200
        onTriggered: root.dropdownOpen = false
    }

    function startHideTimer() {
        hideTimer.start();
    }

    function stopHideTimer() {
        hideTimer.stop();
    }

}
