import "../components"
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: trigger

    required property var screen
    // Höhe der Trigger-Fläche (in px). 4 px reicht meist, damit man
    // nicht versehentlich beim Scrollen auslöst.
    readonly property real triggerHeight: 4

    WlrLayershell.namespace: "quickshell:volume-trigger"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    screen: screen
    color: "transparent"
    implicitWidth: screen.width
    implicitHeight: triggerHeight
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    margins {
        bottom: 0
    }

    // Visuelles Feedback: dünne Linie die beim Hover aufleuchtet
    Rectangle {
        anchors.fill: parent
        color: WalColors.color4
        opacity: triggerMouse.containsMouse ? 0.35 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }

        }

    }

    MouseArea {
        id: triggerMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                VolumeSliderState.openPopup();

        }
    }

}
