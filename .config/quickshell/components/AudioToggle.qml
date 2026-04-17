import "../components"
import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property var barScreen

    width: iconText.implicitWidth + 16
    height: parent.height
    color: "transparent"
    Component.onCompleted: {
        AudioState.dropdownX = 1910;
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
        text: AudioState.muted ? "󰖁" : (AudioState.volumePercent > 50 ? "" : "")
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
        onClicked: {
            AudioState.muted = !AudioState.muted;
            muteProcess.running = true;
        }
        onEntered: AudioState.buttonHovered = true
        onExited: AudioState.buttonHovered = false
        cursorShape: Qt.PointingHandCursor
    }

}
