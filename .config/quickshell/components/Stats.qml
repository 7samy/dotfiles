import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property var barScreen

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: WalColors.withAlpha(WalColors.color2, 1)
    }

    Text {
        id: statsText

        anchors.centerIn: parent
        text: "󱤟"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
    }

}
