import "../components"
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Window {
    id: wallpaperPicker

    title: "wallpaper-picker"
    width: 3000
    height: 2000
    color: "transparent"
    onVisibleChanged: {
        if (visible)
            wallpaperGrid.forceActiveFocus();

    }

    Rectangle {
        id: background

        anchors.fill: parent
        color: "transparent"
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

        anchors.centerIn: parent
        cellWidth: 660
        cellHeight: 380
        width: cellWidth * 2
        height: cellHeight * 3
        flow: GridView.FlowLeftToRight
        model: wallpaperModel
        clip: true
        focus: true
        cacheBuffer: 800
        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_J:
            case Qt.Key_Down:
                wallpaperGrid.moveCurrentIndexDown();
                event.accepted = true;
                break;
            case Qt.Key_K:
            case Qt.Key_Up:
                wallpaperGrid.moveCurrentIndexUp();
                event.accepted = true;
                break;
            case Qt.Key_H:
            case Qt.Key_Left:
                wallpaperGrid.moveCurrentIndexLeft();
                event.accepted = true;
                break;
            case Qt.Key_L:
            case Qt.Key_Right:
                wallpaperGrid.moveCurrentIndexRight();
                event.accepted = true;
                break;
            }
        }

        delegate: Item {
            id: delegateItem

            function setWallpaper() {
                let path = fileUrl.toString().replace(/^file:\/\//, "");
                path = decodeURIComponent(path);
                let cmd = `swww img "${path}" --transition-type simple --transition-duration 0.8 --transition-fps 60 && wal -n -i "${path}" && wpg -s "${path}"; /usr/bin/killall -SIGUSR1 nvim; spicetify apply --no-restart; nohup /home/azu/.config/hypr/scripts/wallpaper-spotify.sh "${path}" >/dev/null 2>&1 & disown`;
                wallpaperSetter.command = ["sh", "-c", cmd];
                wallpaperSetter.running = true;
                wallpaperPicker.visible = false;
            }

            width: wallpaperGrid.cellWidth
            height: wallpaperGrid.cellHeight
            z: GridView.isCurrentItem ? 10 : 0
            scale: GridView.isCurrentItem ? 1.015 : 1
            opacity: GridView.isCurrentItem ? 1 : 0.6
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    setWallpaper();
                    event.accepted = true;
                }
            }

            Image {
                id: img

                source: fileUrl
                width: 640
                height: 360
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(640, 360)
                opacity: (imageMouseArea.containsMouse || delegateItem.GridView.isCurrentItem) ? 1 : 1

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    // Hier ist das transparente Weiß (#80 ist der Alpha-Wert für 50% Transparenz)
                    border.color: delegateItem.GridView.isCurrentItem ? "#80FFFFFF" : "transparent"
                    border.width: delegateItem.GridView.isCurrentItem ? 3 : 0
                    visible: delegateItem.GridView.isCurrentItem
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }

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

            Behavior on scale {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    Process {
        id: wallpaperSetter
    }

}
