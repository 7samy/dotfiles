import "../components"
import QtQuick
import Quickshell
import Quickshell.Hyprland

Window {
    id: pickerWindow

    readonly property var currentScreen: {
        const focused = Hyprland.focusedMonitor;
        if (focused) {
            const match = Quickshell.screens.find((s) => {
                return s.name === focused.name;
            });
            if (match)
                return match;

        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    title: "music_picker"
    width: currentScreen ? currentScreen.width * 0.1563 : 0
    height: currentScreen ? currentScreen.height * 0.4167 : 0
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
        radius: 8

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
