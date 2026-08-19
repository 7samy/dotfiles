import "../components"
import QtQuick
import Quickshell
import Quickshell.Io

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

    width: iconText.implicitWidth + 16
    height: parent.height
    color: "transparent"

    Binding {
        target: AudioState
        property: "iconCenterX"
        value: root.globalCenterX
    }

    Process {
        id: muteProcess

        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
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
        id: iconText

        anchors.centerIn: parent
        text: AudioState.muted ? "󰖁" : (AudioState.volumePercent > 50 ? "" : "")
        color: AudioState.muted ? "#f0b8b8" : WalColors.color2
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
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
        onClicked: {
            AudioState.muted = !AudioState.muted;
            muteProcess.running = true;
        }
        onEntered: {
            hideTimer.stop();
            AudioState.buttonHovered = true;
            AudioState.dropdownOpen = true;
        }
        onExited: {
            AudioState.buttonHovered = false;
            hideTimer.start();
        }
    }

    Timer {
        id: hideTimer

        interval: 200
        onTriggered: AudioState.dropdownOpen = false
    }

}
