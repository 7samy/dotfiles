import Quickshell
import "../components"
import QtQuick

PanelWindow {
    id: triggerZone
    required property var screen
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 4
    color: "transparent"
    exclusiveZone: -1

    MouseArea {
        anchors.fill: parent
        onClicked: BarState.barVisible = !BarState.barVisible
    }
}
