import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Window {
    id: wallpaperPicker

    width: 1000
    height: 600
    // Automatisch den Fokus auf das Grid setzen, wenn das Fenster sichtbar wird
    onVisibleChanged: {
        if (visible)
            wallpaperGrid.forceActiveFocus();

    }

    // Haupthintergrund
    Rectangle {
        id: background

        anchors.fill: parent
        color: "#1e1e2e"
        opacity: 0.9
        radius: 10
        // Damit das Fenster auf Escape reagiert
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape)
                wallpaperPicker.visible = false;

        }
    }

    FolderListModel {
        id: wallpaperModel

        folder: "file:///home/azu/Pictures/Wallpaper/"
        nameFilters: ["*.png", "*.jpg", "*.jpeg"]
        showDirs: false
    }

    GridView {
        id: wallpaperGrid

        anchors.fill: parent
        anchors.margins: 20
        cellWidth: 200
        cellHeight: 150
        model: wallpaperModel
        clip: true
        // Ermöglicht Navigation mit Pfeiltasten
        focus: true

        delegate: Item {
            // Zentrale Funktion zum Ausführen von swww
            function setWallpaper() {
                // Sobald der Prozess fertig ist (running wird false)
                // HIER die Magie: Wir rufen die Funktion im Singleton auf

                let path = fileUrl.toString().replace(/^file:\/\//, "");
                path = decodeURIComponent(path);
                // Wir führen wal aus und danach rufen wir eine Funktion in Quickshell auf
                let cmd = `swww img "${path}" && wal -n -i "${path}" && wpg -s "${path}"`;
                wallpaperSetter.command = ["sh", "-c", cmd];
                wallpaperSetter.running = true;
                wallpaperPicker.visible = false;
            }

            width: wallpaperGrid.cellWidth
            height: wallpaperGrid.cellHeight
            // Reagiert auf Enter/Return wenn das Element markiert ist
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    setWallpaper();
                    event.accepted = true;
                }
            }

            Image {
                id: img

                source: fileUrl
                anchors.fill: parent
                anchors.margins: 5
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Highlight-Effekt bei Hover oder Tastatur-Fokus
                opacity: (imageMouseArea.containsMouse || GridView.isCurrentItem) ? 0.7 : 1

                // Rahmen um das aktuell mit der Tastatur gewählte Bild
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "#89b4fa" // Catppuccin Blue
                    border.width: 3
                    visible: parent.parent.GridView.isCurrentItem
                    radius: 5
                }

            }

            MouseArea {
                id: imageMouseArea

                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    wallpaperGrid.currentIndex = index;
                    parent.setWallpaper();
                }
            }

        }

    }

    Process {
        // Das Command wird dynamisch im Script gesetzt

        id: wallpaperSetter
    }

}
