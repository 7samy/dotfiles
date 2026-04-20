import "../components"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Window {
    id: sidebarWindow

    width: 400
    color: "#ffffff"
    visible: true
    readonly property var screenGeometry: {
        if (Quickshell.screens.length > 0) {
            return Quickshell.screens[0].geometry
        }
        return Qt.rect(0, 0, 1920, 1080)
    }

    x: screenGeometry ? screenGeometry.x + screenGeometry.width - width : 0
    y: screenGeometry ? screenGeometry.y : 0
    height: screenGeometry ? screenGeometry.height : 1080

    Component.onCompleted: {
        console.log("OllamaSidebar created: x=", sidebarWindow.x, "y=", sidebarWindow.y, "w=", sidebarWindow.width, "h=", sidebarWindow.height, "visible=", sidebarWindow.visible);
    }

    // Wenn das Fenster sichtbar wird, Fokus anfordern
    onVisibleChanged: {
        if (visible) {
            sidebarWindow.raise();
            sidebarWindow.requestActivate();
        }
    }

    Rectangle {
        id: mainBox

        anchors.fill: parent
        anchors.margins: 10
        color: WalColors.withAlpha(WalColors.color0, 0.95)
        border.color: WalColors.color2
        border.width: 1
        radius: 12

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15

            Text {
                text: "🤖 " + OllamaState.currentModel
                color: WalColors.color7
                font.bold: true
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                TextArea {
                    text: OllamaState.chatHistory
                    color: WalColors.color7
                    wrapMode: Text.WordWrap
                    readOnly: true
                    background: null
                }

            }

            TextField {
                id: inputField

                Layout.fillWidth: true
                placeholderText: "Frag etwas..."
                color: WalColors.color7
                focus: true // Fokus beim Öffnen
                onAccepted: {
                    OllamaState.ask(text);
                    text = "";
                }

                background: Rectangle {
                    color: WalColors.withAlpha(WalColors.color8, 0.1)
                    radius: 4
                }

            }

        }

    }

}
