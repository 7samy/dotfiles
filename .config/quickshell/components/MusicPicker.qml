import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var allSongs: []
    property var filteredSongs: allSongs.filter((song) => {
        return song.toLowerCase().includes(PickerManager.searchText.toLowerCase());
    })
    // Songpfad -> lokaler Cover-Dateipfad. Delegates binden sich deklarativ
    // hieran, damit Recycling korrekt funktioniert.
    property var coverCache: ({
    })
    property var coverQueue: []
    property bool coverBusy: false
    // Letzte echte Mausposition (Szene-Koordinaten). Verhindert, dass ein
    // Scrollen per Pfeiltasten (Items wandern/skalieren unter dem stehenden
    // Cursor) die Auswahl an die Maus zurueckgibt. Kleine Abweichungen
    // (< 3px, z.B. Rundung bei Skalierung) zaehlen nicht als Mausbewegung.
    property real lastMouseX: -1
    property real lastMouseY: -1
    readonly property string musicDir: "/home/azu/Music/"
    // Raster: 5 Spalten, etwas größere Zellen
    readonly property real cellW: 210
    readonly property real cellH: 190
    readonly property int gridColumns: 5
    // Box und Cover (Cover sitzt zentriert in der Box)
    readonly property real boxSize: 108
    readonly property real boxRadius: 22
    readonly property real coverSize: 84
    readonly property real coverRadius: 15

    function focusSearch() {
        searchInput.forceActiveFocus();
    }

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
    // Grid-Auswahl bei neuer Suche immer auf den ersten Treffer zurücksetzen (wie im App Launcher)
    onFilteredSongsChanged: grid.currentIndex = 0
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
            anchors.rightMargin: 140 // Platz für den Switcher rechts
            verticalAlignment: Text.AlignVCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: WalColors.color7
            text: PickerManager.searchText
            onTextChanged: PickerManager.searchText = text
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: (event) => {
                // Tab / Shift+Tab: zwischen den Pickern wechseln
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
            text: "Search" // bei jedem Picker ggf. anpassen
            color: WalColors.withAlpha(WalColors.color7, 0.35)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            visible: searchInput.text === ""
        }

        // Switcher rechts in der Suchleiste
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

                    // Box im Stil des App Launchers
                    Rectangle {
                        id: iconBg

                        width: root.boxSize
                        height: root.boxSize
                        radius: root.boxRadius
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: isCurrent ? WalColors.withAlpha(WalColors.color2, 0.25) : WalColors.withAlpha(WalColors.color2, 0.08)
                        border.width: isCurrent ? 2 : 0
                        border.color: WalColors.withAlpha(WalColors.color4, 0.6)
                        scale: isCurrent ? 1.08 : 1

                        // Cover wird als Quelle fuer die Rundung genutzt
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

                        // Abgerundetes Cover in der Box
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
                    // Nur bei tatsaechlicher Mausbewegung die Auswahl uebernehmen
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
