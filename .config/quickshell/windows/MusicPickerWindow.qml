import Quickshell
import QtQuick
import "../components"

Window {
    id: pickerWindow

    width: 500
    height: 600
    color: "transparent"
    visible: MusicPickerState.pickerVisible
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    readonly property var screenGeometry: {
        if (Quickshell.screens.length > 0) {
            return Quickshell.screens[0].geometry
        }
        return Qt.rect(0, 0, 1920, 1080)
    }

    x: screenGeometry ? screenGeometry.x + (screenGeometry.width - width) / 2 : 100
    y: screenGeometry ? screenGeometry.y + (screenGeometry.height - height) / 2 : 100

    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    opacity: visible ? 1.0 : 0.0

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

    Component.onCompleted: {
        focus = true
    }
}
