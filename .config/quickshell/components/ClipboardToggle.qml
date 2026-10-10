import "../components"
import QtQuick
import Quickshell

Rectangle {
    id: root

    // Wenn false: keine eigene Hover-Box (Morph-Pill im Parent übernimmt).
    property bool hoverBoxEnabled: true
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

    width: 32
    height: 32
    radius: 6
    color: (root.hoverBoxEnabled && mouseArea.containsMouse) ? WalColors.withAlpha(WalColors.color2, 0.2) : "transparent"

    Text {
        id: clipText

        anchors.centerIn: parent
        text: "󰅇"
        color: WalColors.color2
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        scale: mouseArea.containsMouse ? 1.15 : 1

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
        onClicked: ClipboardState.toggle()
    }

    Behavior on color {
        ColorAnimation {
            duration: 100
        }

    }

}
