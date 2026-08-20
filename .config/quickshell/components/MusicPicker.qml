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
    // song path -> lokaler Cover-Dateipfad. Delegates binden sich direkt
    // hieran statt sich über die Kinderliste des ListView zu suchen -
    // funktioniert dadurch auch korrekt bei Delegate-Recycling.
    property var coverCache: ({
    })
    property var coverQueue: []
    property bool coverBusy: false
    readonly property string musicDir: "/home/azu/Music/"

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
            // Songpfad wird als positionales Argument ("$1") übergeben statt
            // in den Skript-String interpoliert zu werden - sicher gegenüber
            // Anführungszeichen, $-Zeichen etc. im Dateinamen.
            addAllAndPlay.command = ["bash", "-c", 'mpc clear && mpc listall | mpc add && ' + 'position=$(mpc playlist -f "%file%" | grep -nF "$1" | cut -d: -f1 | head -n 1) && ' + 'mpc play "$position" && mpc seek 0', "_", songPath];
            addAllAndPlay.running = true;
        } catch (e) {
            console.error("Fehler beim Abspielen von", songPath, ":", e);
        }
        MusicPickerState.close();
    }

    // ==== Cover-Queue: garantiert immer nur EIN ffmpeg-Aufruf gleichzeitig,
    // dadurch keine Race Condition mehr zwischen mehreren Timern. ====
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
        // Songpfad als "$1" übergeben statt interpoliert - sicher bei
        // Sonderzeichen im Dateinamen.
        coverProcess.command = ["bash", "-c", 'ffmpeg -i "$1" -an -vcodec copy "$2" -y 2>/dev/null && echo "$2"', "_", root.musicDir + path, outFile];
        coverProcess.running = true;
    }

    Component.onCompleted: loadSongs()
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

    // Einzelner, sequentiell abgearbeiteter Cover-Extraktionsprozess.
    Process {
        id: coverProcess

        property string songPath: ""
        property string outFile: ""

        stdout: StdioCollector {
            id: coverOutput

            onStreamFinished: {
                const result = coverOutput.text.trim();
                const finishedPath = coverProcess.songPath; // sicher, da sequentiell abgearbeitet
                root.coverBusy = false;
                if (result) {
                    // Neue Objekt-Referenz nötig, damit QMLs Property-Binding
                    // die Änderung erkennt (reine Mutation würde nicht
                    // getrackt werden).
                    const updated = Object.assign({
                    }, root.coverCache);
                    updated[finishedPath] = result;
                    root.coverCache = updated;
                }
                processCoverQueue();
            }
        }

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
            height: parent.height - 86
            clip: true
            currentIndex: 0
            focus: true
            model: root.filteredSongs

            delegate: Rectangle {
                id: songItem

                width: parent.width
                height: 40
                color: songList.currentIndex === index ? WalColors.withAlpha(WalColors.color2, 0.4) : "transparent"
                radius: 4
                // Nur die ersten 20 sichtbaren Einträge fordern initial ein
                // Cover an - über die Queue, kein Timer-basiertes Rennen mehr.
                Component.onCompleted: {
                    if (index < 20)
                        root.requestCover(modelData);

                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: songList.currentIndex = index
                    onClicked: root.playSong(modelData)
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    Rectangle {
                        width: 32
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 4
                        color: WalColors.withAlpha(WalColors.color1, 0.5)

                        Image {
                            id: smallCover

                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            cache: false
                            visible: status === Image.Ready
                            sourceSize.width: 32
                            sourceSize.height: 32
                            // Rein deklarativ an den Cache gebunden - aktualisiert
                            // sich automatisch, egal welches Delegate gerade
                            // welchen Index/Pfad zeigt (kein manuelles Suchen
                            // in der Kinderliste mehr nötig).
                            source: root.coverCache[modelData] ? ("file://" + root.coverCache[modelData]) : ""
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "♪"
                            color: WalColors.withAlpha(WalColors.color7, 0.4)
                            font.pixelSize: 14
                            visible: smallCover.status !== Image.Ready
                        }

                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: WalColors.color7
                        font.pixelSize: 13
                        font.family: "Monospace"
                        elide: Text.ElideRight
                        width: parent.width - 42
                    }

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
