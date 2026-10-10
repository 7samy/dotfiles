import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Song-Liste und Cover-Cache kommen aus dem Singleton.
    property var allSongs: MusicPickerState.allSongs
    property var filteredSongs: allSongs.filter((song) => {
        return song.toLowerCase().includes(PickerManager.searchText.toLowerCase());
    })
    property var coverCache: MusicPickerState.coverCache
    property real lastMouseX: -1
    property real lastMouseY: -1
    readonly property string musicDir: MusicPickerState.musicDir
    readonly property real cellW: 210
    readonly property real cellH: 190
    readonly property int gridColumns: 5
    readonly property real boxSize: 108
    readonly property real boxRadius: 22
    readonly property real coverSize: 84
    readonly property real coverRadius: 15

    function focusSearch() {
        searchInput.forceActiveFocus();
    }

    function playSong(songPath) {
        if (!songPath)
            return ;

        try {
            console.log("Wähle Song:", songPath);
            addAllAndPlay.command = ["bash", "-c", 'mpc clear && mpc listall | mpc add && ' + 'position=$(mpc playlist -f "%file%" | grep -nF "$1" | cut -d: -f1 | head -n 1) && ' + 'mpc play "$position" && mpc seek 0', "_", songPath];
            addAllAndPlay.running = true;
        } catch (e) {
            console.error("Fehler beim Abspielen von", songPath, ":", e);
        }
        MusicPickerState.close();
    }

    function displayName(songPath) {
        return MusicPickerState.displayName(songPath);
    }

    Component.onCompleted: {
        // Sicherstellen, dass die Song-Liste geladen wird,
        // falls der Picker als erstes geoeffnet wird.
        MusicPickerState.loadSongs();
    }
    onFilteredSongsChanged: grid.currentIndex = 0
    Keys.onEscapePressed: MusicPickerState.close()
    Keys.onReturnPressed: {
        if (root.filteredSongs.length > 0)
            root.playSong(root.filteredSongs[grid.currentIndex]);

    }

    Process {
        id: addAllAndPlay
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

    // ==== Song-Grid ====
    Item {
        id: gridArea

        width: root.gridColumns * root.cellW
        anchors.top: searchBar.bottom
        anchors.topMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter

        // Ladeanzeige, falls die Song-Liste noch vom mpc-Scan kommt
        Text {
            anchors.centerIn: parent
            text: "Lade Songs…"
            color: WalColors.withAlpha(WalColors.color7, 0.45)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            visible: !MusicPickerState.songsLoaded && grid.count === 0
        }

        GridView {
            id: grid

            anchors.fill: parent
            model: root.filteredSongs
            cellWidth: root.cellW
            cellHeight: root.cellH
            currentIndex: 0
            clip: true

            Text {
                anchors.centerIn: parent
                text: "Keine Songs gefunden"
                color: WalColors.withAlpha(WalColors.color7, 0.4)
                font.family: "JetBrainsMono Nerd Font"
                visible: grid.count === 0 && MusicPickerState.songsLoaded
            }

            delegate: Item {
                readonly property bool isCurrent: GridView.isCurrentItem
                readonly property string songPath: modelData
                // Cover-Cache kommt aus dem State – Pfad bleibt beim
                // Schliessen erhalten, kein Re-Extrahieren noetig.
                readonly property string coverPath: root.coverCache[songPath] ? ("file://" + root.coverCache[songPath]) : ""

                width: grid.cellWidth
                height: grid.cellHeight
                Component.onCompleted: {
                    if (songPath)
                        MusicPickerState.requestCover(songPath);

                }

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        id: iconBg

                        width: root.boxSize
                        height: root.boxSize
                        radius: root.boxRadius
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: WalColors.withAlpha(WalColors.color0, 0.3)
                        border.width: isCurrent ? 2 : 0
                        border.color: WalColors.withAlpha(WalColors.color4, 0.6)
                        scale: isCurrent ? 1.08 : 1

                        // Akzent-Tönung als Overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: WalColors.withAlpha(WalColors.color2, isCurrent ? 0.28 : 0.14)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }

                            }

                        }

                        Image {
                            id: coverImage

                            anchors.centerIn: parent
                            width: root.coverSize
                            height: root.coverSize
                            source: coverPath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize: Qt.size(root.coverSize * 2, root.coverSize * 2)
                            visible: false
                        }

                        Rectangle {
                            id: coverMaskShape

                            anchors.centerIn: parent
                            width: root.coverSize
                            height: root.coverSize
                            radius: root.coverRadius
                            visible: false
                        }

                        OpacityMask {
                            anchors.centerIn: parent
                            width: root.coverSize
                            height: root.coverSize
                            source: coverImage
                            maskSource: coverMaskShape
                            visible: coverImage.status === Image.Ready
                        }

                        Text {
                            id: fallback

                            visible: coverImage.status !== Image.Ready
                            anchors.centerIn: parent
                            text: "♪"
                            font.pixelSize: 44
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
                        text: root.displayName(modelData)
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
                        root.playSong(modelData);
                    }
                }

            }

        }

    }

}
