import QtQuick
pragma Singleton

QtObject {
    id: root

    property bool open: false
    property bool hovered: false
    property Timer autoCloseTimer

    function toggle() {
        if (open)
            close();
        else
            openPopup();
    }

    function openPopup() {
        open = true;
        restartAutoClose();
    }

    function close() {
        open = false;
        hovered = false;
        autoCloseTimer.stop();
    }

    function restartAutoClose() {
        autoCloseTimer.restart();
    }

    // Schliesst nach 4s Inaktivitaet. Solange die Maus drueber ist,
    // wird der Timer immer wieder zurueckgesetzt.
    autoCloseTimer: Timer {
        interval: 4000
        onTriggered: {
            if (!root.hovered)
                root.close();
            else
                root.restartAutoClose();
        }
    }

}
