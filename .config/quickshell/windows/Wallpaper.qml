import "../components"
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects
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
        cellWidth: 630
        cellHeight: 350
        width: cellWidth * 2
        height: cellHeight * 3
        flow: GridView.FlowLeftToRight
        model: wallpaperModel
        clip: true
        focus: true
        cacheBuffer: 800
        // --- NEU: Startwerte für die Animation abhängig von der Fenster-Sichtbarkeit ---
        scale: wallpaperPicker.visible ? 1 : 0.8
        opacity: wallpaperPicker.visible ? 1 : 0
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

        Behavior on scale {
            NumberAnimation {
                duration: 350
                easing.type: Easing.OutBack // Erzeugt einen leichten Bounce-Effekt
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
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
                width: 600
                height: 320
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(640, 360)
                opacity: (imageMouseArea.containsMouse || delegateItem.GridView.isCurrentItem) ? 1 : 1
                // --- HIER: Das Bild an den Ecken abrunden ---
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: "transparent"
                    // Hier ist das transparente Weiß (#80 ist der Alpha-Wert für 50% Transparenz)
                    border.color: delegateItem.GridView.isCurrentItem ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                    border.width: delegateItem.GridView.isCurrentItem ? 2 : 0
                    visible: delegateItem.GridView.isCurrentItem
                }

                layer.effect: OpacityMask {

                    maskSource: Rectangle {
                        width: img.width
                        height: img.height
                        radius: 20 // Selber Radius wie dein Rahmen unten!
                    }

                }
                // --------------------------------------------

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

        }

    }

    Process {
        id: wallpaperSetter
    }

}
