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
    width: 1280
    height: 720
    onVisibleChanged: {
        if (visible)
            wallpaperGrid.forceActiveFocus();

    }

    Rectangle {
        id: background

        anchors.fill: parent
        color: WalColors.withAlpha(WalColors.color0, 0.9)
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape)
                wallpaperPicker.visible = false;

        }

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

    GridView {
        id: wallpaperGrid

        anchors.fill: parent
        anchors.margins: 10
        cellWidth: 622
        cellHeight: 350
        flow: GridView.FlowTopToBottom
        height: Math.min(parent.height - 40, 3 * (cellHeight + 5))
        model: wallpaperModel
        clip: false
        focus: true
        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_J:
                wallpaperGrid.moveCurrentIndexDown();
                event.accepted = true;
                break;
            case Qt.Key_K:
                wallpaperGrid.moveCurrentIndexUp();
                event.accepted = true;
                break;
            case Qt.Key_H:
                wallpaperGrid.moveCurrentIndexLeft();
                event.accepted = true;
                break;
            case Qt.Key_L:
                wallpaperGrid.moveCurrentIndexRight();
                event.accepted = true;
                break;
            }
        }

        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Item {
            id: delegateItem

            function setWallpaper() {
                let path = fileUrl.toString().replace(/^file:\/\//, "");
                path = decodeURIComponent(path);
                let cmd = `swww img "${path}" --transition-type simple --transition-duration 0.8 --transition-fps 60 && wal -n -i "${path}" && wpg -s "${path}"; /usr/bin/killall -SIGUSR1 nvim`;
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
                anchors.fill: parent
                anchors.margins: 10
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: (imageMouseArea.containsMouse || delegateItem.GridView.isCurrentItem) ? 1 : 1

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: WalColors.withAlpha(WalColors.color2, 1)
                    border.width: delegateItem.GridView.isCurrentItem ? 2 : 2
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
