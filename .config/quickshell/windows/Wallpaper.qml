import "../components"
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls // ← wichtig für ScrollBar
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Window {
    id: wallpaperPicker

    title: "wallpaper-picker"
    width: 1000
    height: 600
    onVisibleChanged: {
        if (visible)
            wallpaperGrid.forceActiveFocus();

    }

    // Haupthintergrund
    Rectangle {
        id: background

        anchors.fill: parent
        color: WalColors.withAlpha(WalColors.color0, 0.7)
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape)
                wallpaperPicker.visible = false;

        }

        // Live-Update der Farbe (optional)
        Connections {
            function onColorsUpdated() {
                background.color = "transparent";
                redrawTimer.start();
            }

            target: WalColors
        }

        Timer {
            id: redrawTimer

            interval: 10
            onTriggered: background.color = WalColors.withAlpha(WalColors.color0, 0.9)
        }

    }

    FolderListModel {
        id: wallpaperModel

        folder: "file:///home/azu/Pictures/Wallpaper/"
        nameFilters: ["*.png", "*.jpg", "*.jpeg"]
        showDirs: false
    }

    // Horizontal scrollender GridView
    GridView {
        id: wallpaperGrid

        anchors.fill: parent
        anchors.margins: 10
        cellWidth: 500
        cellHeight: 350
        flow: GridView.FlowTopToBottom // vertikal füllen, dann horizontal
        // Maximal 3 Zeilen sichtbar, Rest horizontal scrollen
        height: Math.min(parent.height - 40, 3 * (cellHeight + 5))
        model: wallpaperModel
        clip: true
        focus: true

        // Horizontaler Scrollbalken
        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Item {
            function setWallpaper() {
                let path = fileUrl.toString().replace(/^file:\/\//, "");
                path = decodeURIComponent(path);
                let cmd = `swww img "${path}" && wal -n -i "${path}" && wpg -s "${path}"`;
                wallpaperSetter.command = ["sh", "-c", cmd];
                wallpaperSetter.running = true;
                wallpaperPicker.visible = false;
            }

            width: wallpaperGrid.cellWidth
            height: wallpaperGrid.cellHeight
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
                anchors.margins: 10
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: (imageMouseArea.containsMouse || GridView.isCurrentItem) ? 0.7 : 1

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: WalColors.withAlpha(WalColors.color2, 1)
                    border.width: 2
                    visible: parent.parent.GridView.isCurrentItem
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
        id: wallpaperSetter
    }

}
