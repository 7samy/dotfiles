import Quickshell
import "../components"
import QtQuick

PanelWindow {
    id: triggerZone

    required property var screen

    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    implicitWidth: 50
    color: "#ffffffff"
    exclusiveZone: -1

    Component.onCompleted: {
        console.log("OllamaTriggerZone loaded with screen:", screen)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            console.log("Ollama trigger clicked!");
            OllamaState.toggle();
        }
    }

}
