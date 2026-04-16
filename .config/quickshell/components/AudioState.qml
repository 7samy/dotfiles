import QtQuick
pragma Singleton

QtObject {
    property real dropdownX: 0
    property bool dropdownOpen: false
    property int volumePercent: 50
    property bool muted: false
    property bool buttonHovered: false
    property bool menuHovered: false

    function updateOpen() {
        if (buttonHovered || menuHovered)
            dropdownOpen = true;
        else
            dropdownOpen = false;
    }

    onButtonHoveredChanged: updateOpen()
    onMenuHoveredChanged: updateOpen()
}
