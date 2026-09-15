import "../components"
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var allSongs: []
    property var filteredSongs: allSongs.filter((song) => {
        return song.toLowerCase().includes(MusicPickerState.searchText.toLowerCase());
    })
    // Songpfad -> lokaler Cover-Dateipfad. Delegates binden sich deklarativ
    // hieran, damit Recycling korrekt funktioniert.
    property var coverCache: ({
    })
    property var coverQueue: []
    property bool coverBusy: false
    readonly property string musicDir: "/home/azu/Music/"
    // Exakt die gleichen Maße wie im App Launcher
    readonly property real cellW: 190
    readonly property real cellH: 168
    readonly property int gridColumns: 8

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

    // ==== Cover-Queue: immer nur EIN ffmpeg-Aufruf gleichzeitig ====
    function requestCover(songPath) {
        if (!songPath || root.coverCache[songPath] || root.coverQueue.includes(songPath))
            return ;

        root.coverQueue.push(songPath);
        processCoverQueue();
    }

    function processCoverQueue() {
        if (root.coverBusy || root.coverQueue.length === 0)
            return ;

        root.coverBusy = true;
        const path = root.coverQueue.shift();
        const outFile = "/tmp/qs_cover_" + Qt.md5(path) + ".jpg";
        coverProcess.songPath = path;
        coverProcess.outFile = outFile;
        coverProcess.command = ["bash", "-c", 'ffmpeg -i "$1" -an -vcodec copy "$2" -y 2>/dev/null && echo "$2"', "_", root.musicDir + path, outFile];
        coverProcess.running = true;
    }

    // Songname ohne Pfad und ohne Dateiendung - für die Anzeige unter dem Cover
    function displayName(songPath) {
        if (!songPath)
            return "";

        const base = songPath.split("/").pop();
        return base.replace(/\.[^.]+$/, "");
    }

    Component.onCompleted: loadSongs()
    Keys.onEscapePressed: MusicPickerState.close()
    Keys.onReturnPressed: {
        if (root.filteredSongs.length > 0)
            root.playSong(root.filteredSongs[grid.currentIndex]);

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

    // Einzelner, sequenziell abgearbeiteter Cover-Extraktionsprozess.
    Process {
        id: coverProcess

        property string songPath: ""
        property string outFile: ""

        stdout: StdioCollector {
            id: coverOutput

            onStreamFinished: {
                const result = coverOutput.text.trim();
                const finishedPath = coverProcess.songPath;
                root.coverBusy = false;
                if (result) {
                    const updated = Object.assign({
                    }, root.coverCache);
                    updated[finishedPath] = result;
                    root.coverCache = updated;
                }
                processCoverQueue();
            }
        }

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
            text: MusicPickerState.searchText
            onTextChanged: MusicPickerState.searchText = text
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: (event) => {
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
            text: "Music"
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

    // ==== Song-Grid - 1:1 wie der App Launcher ====
    Item {
        id: gridArea

        width: root.gridColumns * root.cellW
        anchors.top: searchBar.bottom
        anchors.topMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter

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
                visible: grid.count === 0
            }

            delegate: Item {
                readonly property bool isCurrent: GridView.isCurrentItem
                readonly property string songPath: modelData
                readonly property string coverPath: root.coverCache[songPath] ? ("file://" + root.coverCache[songPath]) : ""

                width: grid.cellWidth
                height: grid.cellHeight
                // Cover asynchron anfordern (Queue-getrieben)
                Component.onCompleted: {
                    if (songPath)
                        root.requestCover(songPath);

                }

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        id: iconBg

                        width: 88
                        height: 88
                        radius: 18
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: (isCurrent || mArea.containsMouse) ? WalColors.withAlpha(WalColors.color2, 0.25) : WalColors.withAlpha(WalColors.color2, 0.08)
                        border.width: isCurrent ? 2 : 0
                        border.color: WalColors.withAlpha(WalColors.color4, 0.6)
                        scale: mArea.containsMouse ? 1.08 : 1
                        clip: true

                        Image {
                            id: coverImage

                            anchors.fill: parent
                            anchors.margins: 0
                            source: coverPath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize: Qt.size(176, 176)
                            visible: status === Image.Ready
                        }

                        // Cover füllt das ganze Rounded-Rechteck - oben drüber
                        // ein abgerundetes Overlay, damit die Ecken sauber bleiben.
                        Rectangle {
                            anchors.fill: parent
                            radius: iconBg.radius
                            color: "transparent"
                            border.width: 0
                            visible: coverImage.status === Image.Ready
                        }

                        Text {
                            id: fallback

                            visible: coverImage.status !== Image.Ready
                            anchors.centerIn: parent
                            text: "♪"
                            font.pixelSize: 38
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
                    onClicked: {
                        grid.currentIndex = index;
                        root.playSong(modelData);
                    }
                }

            }

        }

    }

}
