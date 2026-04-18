import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property var barScreen

    width: statsText.implicitWidth + 16
    height: parent.height
    color: "transparent"

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
        text: ""
        color: WalColors.color2
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
        scale: mouseArea.containsMouse ? 1.3 : 1
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
    }

}
