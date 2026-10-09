import "../components"
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string terminalCommand: "kitty"
    // Apps kommen aus dem Singleton, nicht mehr aus eigenem Process.
    property var allApps: AppLauncherState.allApps
    property var filteredApps: allApps.filter((app) => {
        return app.name.toLowerCase().includes(PickerManager.searchText.toLowerCase());
    })
    property real lastMouseX: -1
    property real lastMouseY: -1
    readonly property real cellW: 190
    readonly property real cellH: 168
    readonly property int gridColumns: 5

    function focusSearch() {
        searchInput.forceActiveFocus();
    }

    function launchApp(app) {
        if (!app)
            return ;

        try {
            let command = [];
            if (app.terminal)
                command = [terminalCommand, "-e", "sh", "-c", app.exec + "; exec sh"];
            else
                command = ["sh", "-c", app.exec];
            console.log("Starte:", app.name, "mit Befehl:", command);
            Quickshell.execDetached(command);
        } catch (e) {
            console.error("Fehler beim Starten von", app.name, ":", e);
        }
        AppLauncherState.close();
    }

    Component.onCompleted: {
        // Sicherstellen, dass der Scan laeuft, falls er noch nicht gestartet ist
        AppLauncherState.loadApps();
    }
    onFilteredAppsChanged: grid.currentIndex = 0
    Keys.onEscapePressed: AppLauncherState.close()
    Keys.onReturnPressed: {
        if (root.filteredApps.length > 0)
            root.launchApp(root.filteredApps[grid.currentIndex]);

    }

    // Suchleiste, oben mittig
    Rectangle {
        id: searchBar

        width: Math.min(root.width * 0.4, 400)
        height: 56
        radius: height / 2
        anchors.top: parent.top
        anchors.topMargin: Math.max(root.height * 0.08, 48)
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
            anchors.rightMargin: 140
            verticalAlignment: Text.AlignVCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: WalColors.color7
            text: PickerManager.searchText
            onTextChanged: PickerManager.searchText = text
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier)
                        PickerManager.cycleBackward();
                    else
                        PickerManager.cycle();
                    event.accepted = true;
                    return ;
                }
                switch (event.key) {
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
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 54
            anchors.verticalCenter: parent.verticalCenter
            text: "Search"
            color: WalColors.withAlpha(WalColors.color7, 0.35)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            visible: searchInput.text === ""
        }

        PickerSwitcher {
            id: pickerSwitcher

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            searchInput: searchInput
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }

        }

    }

    // App-Grid
    Item {
        id: gridArea

        width: root.gridColumns * root.cellW
        anchors.top: searchBar.bottom
        anchors.topMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter

        // Ladeanzeige, falls der Scan noch laeuft
        Text {
            anchors.centerIn: parent
            text: "Lade Anwendungen…"
            color: WalColors.withAlpha(WalColors.color7, 0.45)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            visible: !AppLauncherState.appsLoaded && grid.count === 0
        }

        GridView {
            id: grid

            anchors.fill: parent
            model: root.filteredApps
            cellWidth: root.cellW
            cellHeight: root.cellH
            currentIndex: 0
            clip: true

            Text {
                anchors.centerIn: parent
                text: "Keine Anwendungen gefunden"
                color: WalColors.withAlpha(WalColors.color7, 0.4)
                font.family: "JetBrainsMono Nerd Font"
                visible: grid.count === 0 && AppLauncherState.appsLoaded
            }

            delegate: Item {
                readonly property bool isCurrent: GridView.isCurrentItem

                width: grid.cellWidth
                height: grid.cellHeight

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        id: iconBg

                        width: 88
                        height: 88
                        radius: 18
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: isCurrent ? WalColors.withAlpha(WalColors.color2, 0.25) : WalColors.withAlpha(WalColors.color2, 0.08)
                        border.width: isCurrent ? 2 : 0
                        border.color: WalColors.withAlpha(WalColors.color4, 0.6)
                        scale: isCurrent ? 1.08 : 1

                        Image {
                            id: appIcon

                            anchors.centerIn: parent
                            width: 60
                            height: 60
                            source: modelData.icon ? "image://icon/" + modelData.icon : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            onStatusChanged: {
                                if (status === Image.Error)
                                    fallback.visible = true;

                            }
                        }

                        Text {
                            id: fallback

                            visible: appIcon.status !== Image.Ready
                            anchors.centerIn: parent
                            text: "󰈙"
                            font.pixelSize: 38
                            color: WalColors.color2
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }

                        }

                    }

                    Text {
                        width: grid.cellWidth - 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.name
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: WalColors.color7
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }

                }

                MouseArea {
                    id: mArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: (mouse) => {
                        const p = mArea.mapToItem(null, mouse.x, mouse.y);
                        if (Math.abs(p.x - root.lastMouseX) < 3 && Math.abs(p.y - root.lastMouseY) < 3)
                            return ;

                        root.lastMouseX = p.x;
                        root.lastMouseY = p.y;
                        grid.currentIndex = index;
                    }
                    onClicked: {
                        grid.currentIndex = index;
                        root.launchApp(modelData);
                    }
                }

            }

        }

    }

}
