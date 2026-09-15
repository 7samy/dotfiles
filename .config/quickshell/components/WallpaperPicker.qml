import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var allWallpapers: []
    property var filteredWallpapers: allWallpapers.filter((w) => {
        return w.name.toLowerCase().includes(WallpaperPickerState.searchText.toLowerCase());
    })
    readonly property string wallpaperDir: "/home/azu/Pictures/Wallpaper/"
    // Wallpaper-Zellen bleiben exakt wie vorher (630×350)
    readonly property real cellW: 630
    readonly property real cellH: 350
    // 2 Spalten × 3 Reihen sichtbar, wie vorher
    readonly property int visibleCols: 2
    readonly property int visibleRows: 3

    function loadWallpapers() {
        listProcess.running = true;
    }

    function parseWallpapers() {
        const lines = listOutput.text.split('\n').filter((l) => {
            return l.trim();
        });
        allWallpapers = lines.map((name) => {
            return {
                "name": name,
                "url": "file://" + root.wallpaperDir + name
            };
        });
        console.log("Gefundene Wallpaper:", allWallpapers.length);
    }

    function setWallpaper(url) {
        let path = url.toString().replace(/^file:\/\//, "");
        path = decodeURIComponent(path);
        let cmd = `awww img "${path}" --transition-type simple --transition-duration 0.8 --transition-fps 60 && wal -n -i "${path}" && wpg -s "${path}"; /usr/bin/killall -SIGUSR1 nvim; spicetify apply --no-restart; nohup /home/azu/.config/hypr/scripts/wallpaper-spotify.sh "${path}" >/dev/null 2>&1 & disown`;
        wallpaperSetter.command = ["sh", "-c", cmd];
        wallpaperSetter.running = true;
        WallpaperPickerState.close();
    }

    Component.onCompleted: loadWallpapers()
    onFilteredWallpapersChanged: grid.currentIndex = 0
    Keys.onEscapePressed: WallpaperPickerState.close()
    Keys.onReturnPressed: {
        if (root.filteredWallpapers.length > 0)
            root.setWallpaper(root.filteredWallpapers[grid.currentIndex].url);

    }

    // Ordnerinhalt einlesen
    Process {
        id: listProcess

        command: ["bash", "-c", "find /home/azu/Pictures/Wallpaper -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\) -printf '%f\\n' | sort"]

        stdout: StdioCollector {
            id: listOutput

            onStreamFinished: parseWallpapers()
        }

    }

    Process {
        id: wallpaperSetter
    }

    // ==== Suchleiste - 1:1 wie im App Launcher ====
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
            anchors.rightMargin: 22
            verticalAlignment: Text.AlignVCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: WalColors.color7
            text: WallpaperPickerState.searchText
            onTextChanged: WallpaperPickerState.searchText = text
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: (event) => {
                switch (event.key) {
                case Qt.Key_Down:
                case Qt.Key_J:
                    grid.moveCurrentIndexDown();
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                case Qt.Key_K:
                    grid.moveCurrentIndexUp();
                    event.accepted = true;
                    break;
                case Qt.Key_Left:
                case Qt.Key_H:
                    grid.moveCurrentIndexLeft();
                    event.accepted = true;
                    break;
                case Qt.Key_Right:
                case Qt.Key_L:
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
            text: "Wallpaper"
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

    // ==== Wallpaper-Grid - exakt wie vorher, nur unter der Suchleiste ====
    Item {
        id: gridArea

        width: root.cellW * root.visibleCols
        height: root.cellH * root.visibleRows
        anchors.top: searchBar.bottom
        anchors.topMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter

        GridView {
            id: grid

            anchors.fill: parent
            flow: GridView.FlowLeftToRight
            model: root.filteredWallpapers
            cellWidth: root.cellW
            cellHeight: root.cellH
            currentIndex: 0
            clip: true
            focus: true
            cacheBuffer: 800

            Text {
                anchors.centerIn: parent
                text: "Keine Wallpaper gefunden"
                color: WalColors.withAlpha(WalColors.color7, 0.4)
                font.family: "JetBrainsMono Nerd Font"
                visible: grid.count === 0
            }

            delegate: Item {
                id: delegateItem

                readonly property bool isCurrent: GridView.isCurrentItem

                width: grid.cellWidth
                height: grid.cellHeight
                z: isCurrent ? 10 : 0
                scale: isCurrent ? 1.03 : 1
                opacity: isCurrent ? 1 : 0.6
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.setWallpaper(modelData.url);
                        event.accepted = true;
                    }
                }

                Image {
                    id: img

                    source: modelData.url
                    width: 600
                    height: 320
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(640, 360)
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: "transparent"
                        border.color: delegateItem.isCurrent ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                        border.width: delegateItem.isCurrent ? 2 : 0
                        visible: delegateItem.isCurrent
                    }

                    layer.effect: OpacityMask {

                        maskSource: Rectangle {
                            width: img.width
                            height: img.height
                            radius: 20
                        }

                    }

                }

                MouseArea {
                    id: imageMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        grid.currentIndex = index;
                        root.setWallpaper(modelData.url);
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
