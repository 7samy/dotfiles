import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Widgets

Window {
    id: wallpaperPicker

    width: 1000
    height: 600
    WlrLayerShell.keyboardFocus: WlrLayerShell.OnDemand
    WlrLayerShell.layer: WlrLayerShell.Overlay
    WlrLayerShell.namespace: "wallpaper-picker"
    WlrLayerShell.anchor: WlrLayerShell.Center
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape)
            wallpaperPicker.visible = false;

    }

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        opacity: 0.9
        radius: 10
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
        anchors.margins: 10
        cellWidth: 200
        cellHeight: 150
        model: wallpaperModel
        clip: true

        delegate: Image {
            source: fileUrl
            width: wallpaperGrid.cellWidth - 10
            height: wallpaperGrid.cellHeight - 10
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: imageMouseArea.containsMouse ? 0.7 : 1

            MouseArea {
                id: imageMouseArea

                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    wallpaperSetter.arguments = [filePath];
                    wallpaperSetter.start();
                    wallpaperPicker.visible = false;
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }

            }

        }

    }

    Process {
        id: wallpaperSetter

        command: ["swww", "img"]
    }

}
