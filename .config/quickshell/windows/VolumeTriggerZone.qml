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

    // Komplett unsichtbar: nur eine klickbare Fläche ohne jede Darstellung
    MouseArea {
        id: triggerMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        // Toggle: offen -> schließen, geschlossen -> öffnen
        onClicked: VolumeSliderState.toggle()
    }

}
