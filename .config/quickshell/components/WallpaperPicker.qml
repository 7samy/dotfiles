import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Wandert aus dem State, nicht mehr aus eigenem Process
    property var allWallpapers: WallpaperPickerState.allWallpapers
    property var filteredWallpapers: allWallpapers.filter((w) => {
        return w.name.toLowerCase().includes(PickerManager.searchText.toLowerCase());
    })
    property real lastMouseX: -1
    property real lastMouseY: -1
    readonly property string wallpaperDir: WallpaperPickerState.wallpaperDir
    readonly property real cellW: 630
    readonly property real cellH: 350
    readonly property int visibleCols: 2
    readonly property int visibleRows: 3

    function focusSearch() {
        searchInput.forceActiveFocus();
    }

    function setWallpaper(url) {
        let path = url.toString().replace(/^file:\/\//, "");
        path = decodeURIComponent(path);
        let cmd = `awww img "${path}" --transition-type simple --transition-duration 0.8 --transition-fps 60 && wal -n -i "${path}" && wpg -s "${path}"; /usr/bin/killall -SIGUSR1 nvim; spicetify apply --no-restart; nohup /home/azu/.config/hypr/scripts/wallpaper-spotify.sh "${path}" >/dev/null 2>&1 & disown`;
        wallpaperSetter.command = ["sh", "-c", cmd];
        wallpaperSetter.running = true;
        PickerManager.close();
    }

    Component.onCompleted: {
        // Sicherstellen, dass die Liste geladen ist (falls der Picker
        // als erstes geoeffnet wird und der Singleton noch nichts hat)
        WallpaperPickerState.loadWallpapers();
    }
    onFilteredWallpapersChanged: grid.currentIndex = 0
    Keys.onEscapePressed: PickerManager.close()
    Keys.onReturnPressed: {
        if (root.filteredWallpapers.length > 0)
            root.setWallpaper(root.filteredWallpapers[grid.currentIndex].url);

    }

    Process {
        id: wallpaperSetter
    }

    // ==== Suchleiste mit Switcher ====
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

    // ==== Wallpaper-Grid ====
    Item {
        id: gridArea

        width: root.cellW * root.visibleCols
        height: root.cellH * root.visibleRows
        anchors.top: searchBar.bottom
        anchors.topMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            anchors.centerIn: parent
            text: "Lade Wallpaper…"
            color: WalColors.withAlpha(WalColors.color7, 0.45)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            visible: !WallpaperPickerState.wallpapersLoaded && grid.count === 0
        }

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
            cacheBuffer: 200

            Text {
                anchors.centerIn: parent
                text: "Keine Wallpaper gefunden"
                color: WalColors.withAlpha(WalColors.color7, 0.4)
                font.family: "JetBrainsMono Nerd Font"
                visible: grid.count === 0 && WallpaperPickerState.wallpapersLoaded
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
                    onPositionChanged: (mouse) => {
                        const p = imageMouseArea.mapToItem(null, mouse.x, mouse.y);
                        if (Math.abs(p.x - root.lastMouseX) < 3 && Math.abs(p.y - root.lastMouseY) < 3)
                            return ;

                        root.lastMouseX = p.x;
                        root.lastMouseY = p.y;
                        grid.currentIndex = index;
                    }
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
