import QtQuick
import Quickshell

Text {
    id: clockText

    function updateTime() {
        clockText.text = Qt.formatDateTime(new Date(), "hh:mm:ss");
    }

    color: WalColors.color2
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14
    height: parent.height
    verticalAlignment: Text.AlignVCenter
    Component.onCompleted: updateTime()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockText.updateTime()
    }

    HoverHandler {
        onHoveredChanged: {
            CalendarState.buttonHovered = hovered;
            if (hovered)
                CalendarState.dropdownOpen = true;

            CalendarState.updateHoverTimer();
        }
    }

}
