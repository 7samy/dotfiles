import Quickshell
import "../components"
import QtQuick

PanelWindow {
    id: triggerZone
    required property var screen
    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    implicitWidth: 10
    color: "transparent"
    exclusiveZone: -1

    MouseArea {
        anchors.fill: parent
        onClicked: {
            console.log("Ollama trigger clicked!")
            OllamaState.toggle()
        }
    }
}
