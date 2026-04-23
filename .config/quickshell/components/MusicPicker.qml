import "../components"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var allSongs: []
    property var filteredSongs: allSongs.filter((song) => {
        return song.toLowerCase().includes(MusicPickerState.searchText.toLowerCase());
    })

    function loadSongs() {
        try {
            songsProcess.running = true;
        } catch (e) {
            console.error("Error loading songs:", e);
        }
    }

    function parseSongs() {
        try {
            const lines = songsOutput.text.split('\n').filter((l) => {
                return l.trim();
            });
            allSongs = lines.sort((a, b) => {
                return a.localeCompare(b);
            });
            console.log("Gefundene Songs:", allSongs.length);
        } catch (e) {
            console.error("Error parsing songs:", e);
        }
    }

    function playSong(songPath) {
        if (!songPath)
            return;

        try {
            console.log("Wähle Song:", songPath);
            
            // Füge all Songs zur Playlist hinzu und spiele den ausgewählten ab
            addAllAndPlay.command = ["bash", "-c", "mpc clear && mpc listall | mpc add && position=$(mpc playlist -f '%file%' | grep -nF \"" + songPath + "\" | cut -d: -f1 | head -n 1) && mpc play \"$position\" && mpc seek 0"];
            addAllAndPlay.running = true;
        } catch (e) {
            console.error("Fehler beim Abspielen von", songPath, ":", e);
        }
        MusicPickerState.close();
    }

    Component.onCompleted: {
        loadSongs();
    }

    Keys.onEscapePressed: MusicPickerState.close()
    Keys.onReturnPressed: {
        if (root.filteredSongs.length > 0)
            root.playSong(root.filteredSongs[songList.currentIndex]);
    }

    Process {
        id: songsProcess

        command: ["mpc", "listall"]

        stdout: StdioCollector {
            id: songsOutput

            onStreamFinished: parseSongs()
        }
    }

    Process {
        id: addAllAndPlay
    }

    Column {
        anchors.fill: parent
        spacing: 16

        Rectangle {
            width: parent.width
            height: 50
            color: WalColors.withAlpha(WalColors.color7, 0.2)
            radius: 8
            border.width: 2
            border.color: WalColors.withAlpha(WalColors.color2, 0.3)

            TextInput {
                id: searchInput

                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: Text.AlignVCenter
                font.family: "Monospace"
                font.pixelSize: 14
                color: WalColors.withAlpha(WalColors.color7, 0.8)
                text: MusicPickerState.searchText
                onTextChanged: MusicPickerState.searchText = text
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Down)
                        songList.incrementCurrentIndex();
                    else if (event.key === Qt.Key_Up)
                        songList.decrementCurrentIndex();
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 20
            color: "transparent"
            
            Text {
                text: root.filteredSongs.length + " / " + root.allSongs.length + " songs"
                color: WalColors.withAlpha(WalColors.color7, 0.6)
                font.pixelSize: 12
                font.family: "Monospace"
            }
        }

        ListView {
            id: songList

            width: parent.width
            height: parent.height - 70 - 20
            clip: true
            currentIndex: 0
            focus: true

            model: root.filteredSongs

            delegate: Rectangle {
                width: parent.width
                height: 40
                color: songList.currentIndex === index ? WalColors.withAlpha(WalColors.color2, 0.4) : "transparent"
                radius: 4

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: songList.currentIndex = index
                    onClicked: root.playSong(modelData)
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: WalColors.color7
                    font.pixelSize: 13
                    font.family: "Monospace"
                    elide: Text.ElideRight
                    width: parent.width - 24
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                background: Rectangle {
                    color: WalColors.withAlpha(WalColors.color0, 0.3)
                    radius: 4
                }
                contentItem: Rectangle {
                    radius: 4
                    color: WalColors.withAlpha(WalColors.color2, 0.5)
                }
            }
        }
    }
}
