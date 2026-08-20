import "../components"
import QtQuick
import Quickshell

Window {
    id: pickerWindow

    readonly property var currentScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    title: "music_picker"
    width: currentScreen ? currentScreen.width * 0.52 : 600
    height: currentScreen ? currentScreen.height * 0.56 : 400
    color: "transparent"
    visible: MusicPickerState.pickerVisible
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    opacity: visible ? 1 : 0
    Component.onCompleted: {
        focus = true;
    }

    Rectangle {
        anchors.fill: parent
        color: WalColors.withAlpha(WalColors.color0, 0.7)
        radius: 4
        border.width: 2
        border.color: WalColors.withAlpha(WalColors.color2, 0.35)

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
