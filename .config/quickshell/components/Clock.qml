import QtQuick
import Quickshell

Item {
    id: clockRoot

    // X-Zentrum der Uhr in Bildschirmkoordinaten – wird von CalendarDropdown
    // gelesen, um sich darunter zu zentrieren.
    readonly property real globalCenterX: windowX(clockRoot) + width / 2
    property bool hideClock: false

    function windowX(item) {
        var x = 0;
        var it = item;
        while (it && it.parent) {
            x += it.x;
            it = it.parent;
        }
        return x;
    }

    function updateTime() {
        timeText.text = Qt.formatDateTime(new Date(), "hh:mm AP");
        dateText.text = Qt.formatDateTime(new Date(), "MMMM d, yyyy");
    }

    implicitWidth: clockColumn.implicitWidth
    implicitHeight: parent ? parent.height : 40
    Component.onCompleted: updateTime()
    opacity: hideClock ? 0 : 1

    // Position live an CalendarState melden
    Binding {
        target: CalendarState
        property: "iconCenterX"
        value: clockRoot.globalCenterX
    }

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

    Timer {
        id: openDelay

        interval: 120
        repeat: false
        onTriggered: CalendarState.dropdownOpen = true
    }

    Timer {
        id: showDelay

        interval: 220
        repeat: false
        onTriggered: clockRoot.hideClock = false
    }

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
