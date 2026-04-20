import "../components"
import QtQuick
import Quickshell

PanelWindow {
    id: testTrigger
    required property var screen

    anchors.right: true
    anchors.top: true
    anchors.bottom: true
    implicitWidth: 50
    color: "#ffffffff"
    exclusiveZone: -1

    Component.onCompleted: {
        console.log("TestTrigger created on screen:", screen ? screen.name : screen, "x=", testTrigger.x, "y=", testTrigger.y, "w=", testTrigger.width, "h=", testTrigger.height);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            console.log("TestTrigger clicked on screen:", screen ? screen.name : screen);
            // toggle sidebar for quick check
            ollamaSidebar.visible = !ollamaSidebar.visible;
            if (ollamaSidebar.visible) {
                ollamaSidebar.raise();
                ollamaSidebar.requestActivate();
            }
        }
    }
}
