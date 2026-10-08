import "../components"
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    required property var screen
    readonly property real cellW: 380
    readonly property real cellH: 100
    readonly property int visibleCols: 2
    // Passt sich automatisch an die Bildschirmhöhe an (mind. 3 Zeilen)
    readonly property int visibleRows: Math.max(3, Math.floor((screen.height - 240) / cellH))
    readonly property var filtered: {
        const q = VpnPickerState.searchText.toLowerCase();
        return VpnPickerState.connections.filter((c) => {
            return c.label.toLowerCase().includes(q) || c.name.toLowerCase().includes(q) || c.code.includes(q);
        });
    }
    // 0 = zu, 1 = offen (fuer Ein-/Ausblenden)
    property real show: VpnPickerState.open ? 1 : 0

    WlrLayershell.namespace: "quickshell:vpn-picker"
    visible: VpnPickerState.open || show > 0.001
    color: "transparent"
    exclusiveZone: -1
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: VpnPickerState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onVisibleChanged: {
        if (visible && VpnPickerState.open) {
            searchInput.text = "";
            grid.currentIndex = 0;
            searchInput.forceActiveFocus();
        }
    }

    Connections {
        function onOpenChanged() {
            if (VpnPickerState.open) {
                searchInput.text = "";
                grid.currentIndex = 0;
                searchInput.forceActiveFocus();
                openBounce.restart();
            }
        }

        target: VpnPickerState
    }

    // Abdunkeln, Klick daneben schliesst
    Rectangle {
        anchors.fill: parent
        color: WalColors.withAlpha(WalColors.color0, 0.6)
        opacity: win.show

        MouseArea {
            anchors.fill: parent
            onClicked: VpnPickerState.close()
        }

    }

    Item {
        id: content

        anchors.fill: parent
        opacity: win.show
        scale: 1
        transformOrigin: Item.Center

        SequentialAnimation {
            id: openBounce

            NumberAnimation {
                target: content
                property: "scale"
                from: 0.85
                to: 1
                duration: 300
                easing.type: Easing.OutBack
            }

        }

        MouseArea {
            anchors.fill: parent
        }

        // ==== Suchleiste ====
        Rectangle {
            id: searchBar

            width: Math.min(win.width * 0.4, 400)
            height: 56
            radius: height / 2
            anchors.top: parent.top
            anchors.topMargin: Math.max(win.height * 0.08, 48)
            anchors.horizontalCenter: parent.horizontalCenter
            color: WalColors.withAlpha(WalColors.color7, 0.12)
            border.width: 2
            border.color: searchInput.activeFocus ? WalColors.withAlpha(WalColors.color4, 0.6) : WalColors.withAlpha(WalColors.color2, 0.25)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                color: WalColors.withAlpha(WalColors.color7, 0.5)
            }

            TextInput {
                id: searchInput

                anchors.fill: parent
                anchors.leftMargin: 54
                anchors.rightMargin: 22
                verticalAlignment: Text.AlignVCenter
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: WalColors.color7
                onTextChanged: {
                    VpnPickerState.searchText = text;
                    grid.currentIndex = 0;
                }
                Keys.onPressed: (event) => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        VpnPickerState.close();
                        event.accepted = true;
                        break;
                    case Qt.Key_Down:
                        grid.moveCurrentIndexDown();
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        grid.moveCurrentIndexUp();
                        event.accepted = true;
                        break;
                    case Qt.Key_Left:
                        grid.moveCurrentIndexLeft();
                        event.accepted = true;
                        break;
                    case Qt.Key_Right:
                        grid.moveCurrentIndexRight();
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (win.filtered.length > 0)
                            VpnPickerState.connectTo(win.filtered[grid.currentIndex].name);

                        event.accepted = true;
                        break;
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 54
                anchors.verticalCenter: parent.verticalCenter
                text: "Land suchen"
                color: WalColors.withAlpha(WalColors.color7, 0.35)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                visible: searchInput.text === ""
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 120
                }

            }

        }

        // ==== Verbindungs-Grid (2 Spalten) ====
        Item {
            id: gridArea

            width: win.cellW * win.visibleCols
            height: win.cellH * win.visibleRows
            anchors.top: searchBar.bottom
            anchors.topMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter

            GridView {
                id: grid

                anchors.fill: parent
                flow: GridView.FlowLeftToRight
                model: win.filtered
                cellWidth: win.cellW
                cellHeight: win.cellH
                currentIndex: 0
                clip: true
                cacheBuffer: 400

                Text {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: VpnPickerState.connections.length === 0 ? "Keine WireGuard-Verbindungen gefunden\nimport-vpn.sh ausführen" : "Kein Land gefunden"
                    color: WalColors.withAlpha(WalColors.color7, 0.45)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    visible: grid.count === 0
                }

                delegate: Item {
                    id: delegateItem

                    readonly property bool isCurrent: GridView.isCurrentItem
                    readonly property bool isActive: modelData.name === VpnPickerState.activeConnection

                    width: grid.cellWidth
                    height: grid.cellHeight
                    z: isCurrent ? 10 : 0
                    scale: isCurrent ? 1.03 : 1
                    opacity: isCurrent ? 1 : 0.75

                    Rectangle {
                        anchors.centerIn: parent
                        width: win.cellW - 20
                        height: win.cellH - 20
                        radius: 20
                        color: WalColors.withAlpha(WalColors.color7, delegateItem.isCurrent ? 0.16 : 0.08)
                        border.width: 2
                        border.color: delegateItem.isActive ? WalColors.color4 : (delegateItem.isCurrent ? WalColors.withAlpha(WalColors.color2, 0.45) : "transparent")

                        Item {
                            id: flagBox

                            width: 52
                            height: 52
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: flagImg

                                anchors.fill: parent
                                source: modelData.code !== "" ? "../resources/flags/" + modelData.code + ".svg" : ""
                                sourceSize: Qt.size(104, 104)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: WalColors.withAlpha(WalColors.color4, 0.2)
                                visible: flagImg.status !== Image.Ready

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.code !== "" ? modelData.code.toUpperCase() : "󰖂"
                                    color: WalColors.color4
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                            }

                        }

                        Column {
                            anchors.left: flagBox.right
                            anchors.leftMargin: 16
                            anchors.right: statusIcon.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                width: parent.width
                                text: modelData.label
                                color: WalColors.color7
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: delegateItem.isActive ? "Verbunden" : modelData.name
                                color: delegateItem.isActive ? WalColors.color2 : WalColors.withAlpha(WalColors.color7, 0.5)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                        }

                        Text {
                            id: statusIcon

                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰄬"
                            color: WalColors.color4
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 20
                            visible: delegateItem.isActive
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }

                        }

                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: grid.currentIndex = index
                        onClicked: {
                            grid.currentIndex = index;
                            VpnPickerState.connectTo(modelData.name);
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

    }

    Behavior on show {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }

    }

}
