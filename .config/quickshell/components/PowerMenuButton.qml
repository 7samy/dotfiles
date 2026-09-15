import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    width: 32
    height: 40
    radius: 6
    color: mouseArea.containsMouse ? WalColors.withAlpha(WalColors.color2, 0.2) : "transparent"

    Text {
        anchors.centerIn: parent
        text: "⏻"
        color: WalColors.color2
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
        scale: mouseArea.containsMouse ? 1.3 : 1
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["qs", "ipc", "call", "powermenu", "toggle"]);
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: 100
        }

    }

}
