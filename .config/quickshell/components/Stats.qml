import "../components"
import QtQuick
import Quickshell

Rectangle {
    id: root

    readonly property real globalCenterX: windowX(root) + width / 2

    function windowX(item) {
        var x = 0;
        var it = item;
        while (it && it.parent) {
            x += it.x;
            it = it.parent;
        }
        return x;
    }

    width: statsText.implicitWidth + 16
    height: parent.height
    color: "transparent"

    Binding {
        target: StatsState
        property: "dropdownX"
        value: root.globalCenterX
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: WalColors.withAlpha(WalColors.color2, 1)
        opacity: mouseArea.containsMouse ? 0.15 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }

        }

    }

    Text {
        id: statsText

        anchors.centerIn: parent
        text: "󰆼"
        color: WalColors.color2
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
        scale: mouseArea.containsMouse ? 1.3 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }

        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            StatsState.stopHideTimer();
            StatsState.buttonHovered = true;
            StatsState.dropdownOpen = true;
        }
        onExited: {
            StatsState.buttonHovered = false;
            StatsState.startHideTimer();
        }
    }

}
