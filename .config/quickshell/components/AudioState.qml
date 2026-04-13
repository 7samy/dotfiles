pragma Singleton
import QtQuick

QtObject {
    property real dropdownX: 0
    property bool dropdownOpen: false
    property int volumePercent: 50
    property bool muted: false

    // Beide Komponenten setzen ihre jeweilige Property –
    // Dropdown bleibt offen solange mindestens eine true ist
    property bool buttonHovered: false
    property bool menuHovered: false

    onButtonHoveredChanged: updateOpen()
    onMenuHoveredChanged: updateOpen()

    function updateOpen() {
        if (buttonHovered || menuHovered) {
            dropdownOpen = true
        } else {
            dropdownOpen = false
        }
    }
}
