import QtQuick
import Quickshell

Item {
    id: root

    // Optional: das Suchfeld, das nach einem Klick wieder
    // Fokus bekommen soll. Der Parent setzt das per Binding.
    property Item searchInput: null
    // Icons für die Picker. Reihenfolge muss zu PickerManager.pickers
    // passen. Neue Picker hier ebenfalls eintragen.
    readonly property var items: [{
        "name": "app",
        "icon": "󰀻"
    }, {
        "name": "music",
        "icon": "󰝚"
    }, {
        "name": "wallpaper",
        "icon": "󰋩"
    }]

    implicitWidth: row.implicitWidth
    implicitHeight: 32

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.items

            delegate: Rectangle {
                id: btn

                required property var modelData
                readonly property bool isActive: PickerManager.isOpen(modelData.name)
                readonly property bool isHovered: mArea.containsMouse

                width: 32
                height: 32
                radius: 8
                color: isActive ? WalColors.withAlpha(WalColors.color2, 0.3) : (isHovered ? WalColors.withAlpha(WalColors.color2, 0.18) : "transparent")
                border.width: isActive ? 2 : 0
                border.color: WalColors.withAlpha(WalColors.color4, 0.6)

                Text {
                    anchors.centerIn: parent
                    text: btn.modelData.icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: btn.isActive ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, btn.isHovered ? 0.85 : 0.55)

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }

                    }

                }

                MouseArea {
                    id: mArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        PickerManager.open(btn.modelData.name);
                        if (root.searchInput)
                            root.searchInput.forceActiveFocus();

                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }

                }

            }

        }

    }

}
