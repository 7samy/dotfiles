import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
    id: dropdown

    required property var screen
    readonly property real radius: 20
    readonly property real menuWidth: 220

    anchors.top: true
    anchors.left: true
    implicitWidth: menuWidth + (2 * radius)
    implicitHeight: 100
    color: "transparent"
    exclusiveZone: -1
}
