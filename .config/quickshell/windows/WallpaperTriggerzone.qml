import "../components"
import QtQuick
import Quickshell

PanelWindow {
    id: triggerZone

    required property var screen

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 4
    color: "transparent"
    exclusiveZone: -1

    MouseArea {
        anchors.fill: parent
        onClicked: {
            wallpaperPicker.visible = !wallpaperPicker.visible;
            if (wallpaperPicker.visible) {
                wallpaperPicker.raise();
                wallpaperPicker.requestActivate();
            }
        }
    }

}
