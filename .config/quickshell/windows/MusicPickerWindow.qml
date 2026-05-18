import "../components"
import QtQuick
import Quickshell

Window {
    id: pickerWindow

    readonly property var currentScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    title: "music_picker"
    width: currentScreen ? currentScreen.width * 0.52 : 1000
    height: currentScreen ? currentScreen.height * 0.56 : 600
    color: "transparent"
    visible: MusicPickerState.pickerVisible
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    x: currentScreen ? (currentScreen.width - width) / 2 : 100
    y: currentScreen ? (currentScreen.height - height) / 2 : 100
    opacity: visible ? 1 : 0
    Component.onCompleted: {
        focus = true;
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: WalColors.withAlpha(WalColors.color0, 0.8)
        border.width: 2
        border.color: WalColors.withAlpha(WalColors.color2, 0.55)

        MusicPicker {
            anchors.fill: parent
            anchors.margins: 20
            focus: true
            Keys.onEscapePressed: MusicPickerState.close()
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }

    }

}
