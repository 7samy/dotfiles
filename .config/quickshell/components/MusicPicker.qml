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
    // Link-Download-Drawer unter der Suchleiste
    property bool addOpen: false
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

    // ==== Link-Download ====
    function openAdd(prefill) {
        root.addOpen = true;
        if (prefill)
            linkInput.text = prefill;
        else if (linkInput.text === "")
            clipPaste.running = true; // Link aus der Zwischenablage vorschlagen
        Qt.callLater(linkInput.forceActiveFocus);
    }

    function closeAdd() {
        root.addOpen = false;
        searchInput.forceActiveFocus();
    }

    function toggleAdd() {
        if (root.addOpen)
            closeAdd();
        else
            openAdd("");
    }

    function submitLink() {
        if (MusicPickerState.dlBusy)
            return ;

        MusicPickerState.downloadUrl(linkInput.text);
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

    // Zwischenablage lesen (wl-clipboard); nur gueltige Links werden uebernommen
    Process {
        id: clipPaste

        command: ["wl-paste", "-n"]

        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (MusicPickerState.serviceOf(t) !== "" && linkInput.text === "")
                    linkInput.text = t;

            }
        }

    }

    Connections {
        function onDlDoneCounterChanged() {
            linkInput.text = "";
            // Erfolg kurz zeigen, dann den Drawer einfahren
            if (MusicPickerState.pickerVisible) {
                root.addOpen = true;
                doneTimer.restart();
            }
        }

        target: MusicPickerState
    }

    Timer {
        id: doneTimer

        interval: 3200
        onTriggered: {
            if (MusicPickerState.dlPhase === "done") {
                MusicPickerState.dlAck();
                if (root.addOpen)
                    root.closeAdd();

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
            anchors.rightMargin: 140
            verticalAlignment: Text.AlignVCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: WalColors.color7
            text: PickerManager.searchText
            onTextChanged: {
                // Wird ein Spotify-/SoundCloud-Link eingefuegt: in den Drawer verschieben
                if (MusicPickerState.serviceOf(text) !== "") {
                    const link = text.trim();
                    text = "";
                    root.openAdd(link);
                    return ;
                }
                PickerManager.searchText = text;
            }
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

    // ==== + Button: Song per Link hinzufuegen ====
    Rectangle {
        id: addButton

        readonly property bool hot: addMouse.containsMouse || root.addOpen
        readonly property bool busy: MusicPickerState.dlBusy

        anchors.left: searchBar.right
        anchors.leftMargin: 14
        anchors.verticalCenter: searchBar.verticalCenter
        width: 56
        height: 56
        radius: width / 2
        color: hot ? WalColors.withAlpha(WalColors.color4, 0.2) : WalColors.withAlpha(WalColors.color7, 0.12)
        border.width: 2
        border.color: busy ? WalColors.withAlpha(WalColors.color4, 0.8) : (hot ? WalColors.withAlpha(WalColors.color4, 0.6) : WalColors.withAlpha(WalColors.color2, 0.25))
        scale: addMouse.pressed ? 0.92 : (addMouse.containsMouse ? 1.06 : 1)

        // Plus (dreht sich beim Oeffnen zum X); waehrend des Downloads ein huepfender Pfeil
        Text {
            id: plusIcon

            anchors.centerIn: parent
            text: addButton.busy && !root.addOpen ? "󰇚" : "󰐕"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22
            color: addButton.hot || addButton.busy ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.7)
            rotation: root.addOpen ? 135 : 0

            SequentialAnimation on anchors.verticalCenterOffset {
                running: addButton.busy && !root.addOpen
                loops: Animation.Infinite

                NumberAnimation {
                    to: 4
                    duration: 380
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    to: -4
                    duration: 380
                    easing.type: Easing.InOutSine
                }

            }

            Behavior on rotation {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }

            }

        }

        MouseArea {
            id: addMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleAdd()
        }

        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
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

    // ==== Download-Drawer: faehrt unter der Suchleiste aus ====
    // Liegt ueber dem Grid (z), verschiebt das Grid aber nicht -> kein Relayout.
    Item {
        id: addPanel

        readonly property string phase: MusicPickerState.dlPhase
        readonly property bool busy: phase === "busy"
        readonly property bool done: phase === "done"
        readonly property bool failed: phase === "error"
        readonly property string svc: MusicPickerState.serviceOf(linkInput.text)
        readonly property real prog: MusicPickerState.dlProgress
        readonly property color accent: failed ? WalColors.color1 : (done ? WalColors.color2 : WalColors.color4)
        property real t: root.addOpen ? 1 : 0

        width: searchBar.width
        height: 40
        anchors.horizontalCenter: searchBar.horizontalCenter
        y: searchBar.y + searchBar.height + 6 - (1 - t) * 16
        z: 20
        opacity: Math.min(1, t)
        scale: 0.96 + 0.04 * Math.min(1, t)
        visible: t > 0.01

        Rectangle {
            id: pill

            anchors.fill: parent
            radius: height / 2
            color: WalColors.withAlpha(WalColors.color0, 0.95)
            border.width: 2
            border.color: WalColors.withAlpha(addPanel.accent, addPanel.busy ? 0.75 : 0.4)
            clip: true

            // Fortschritt als sanfte Fuellung (wie in den Mixer-Zeilen)
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: pill.width * Math.max(0, addPanel.prog)
                color: WalColors.withAlpha(addPanel.accent, 0.2)
                visible: addPanel.busy && addPanel.prog >= 0

                Behavior on width {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // Unbekannter Fortschritt: ein Lichtstreifen laeuft durch (nur waehrend busy)
            Rectangle {
                id: shimmer

                width: 110
                height: parent.height
                color: WalColors.withAlpha(addPanel.accent, 0.16)
                visible: addPanel.busy && addPanel.prog < 0

                NumberAnimation on x {
                    running: shimmer.visible
                    from: -110
                    to: pill.width
                    duration: 1200
                    loops: Animation.Infinite
                }

            }

            Text {
                id: stateIcon

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: addPanel.failed ? "󰀦" : (addPanel.done ? "󰄬" : (addPanel.busy ? "󰇚" : "󰌷"))
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: addPanel.accent

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }

                }

            }

            TextInput {
                id: linkInput

                anchors.fill: parent
                anchors.leftMargin: 44
                anchors.rightMargin: 100
                verticalAlignment: Text.AlignVCenter
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: WalColors.color7
                clip: true
                selectByMouse: true
                readOnly: addPanel.phase !== "idle"
                // Text bleibt im Hintergrund erhalten, waehrend die Statuszeile darueber liegt
                opacity: addPanel.phase === "idle" ? 1 : 0
                onTextEdited: MusicPickerState.dlAck()
                onAccepted: root.submitLink()
                Keys.onEscapePressed: (event) => {
                    root.closeAdd();
                    event.accepted = true;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }

                }

            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 44
                anchors.verticalCenter: parent.verticalCenter
                text: "Spotify- oder SoundCloud-Link einfügen"
                color: WalColors.withAlpha(WalColors.color7, 0.35)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                visible: addPanel.phase === "idle" && linkInput.text === ""
            }

            // Status / Ergebnis / Fehler
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 44
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: addPanel.busy ? (MusicPickerState.dlStatus + (addPanel.prog >= 0 ? "  " + Math.round(addPanel.prog * 100) + "%" : "")) : (addPanel.done ? "Hinzugefügt: " + MusicPickerState.dlName : MusicPickerState.dlError)
                color: addPanel.failed ? WalColors.color1 : WalColors.color7
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                elide: Text.ElideRight
                visible: addPanel.phase !== "idle"
            }

            // Dienst-Badge + Start-Pfeil (nur wenn ein gueltiger Link drin steht)
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                opacity: addPanel.phase === "idle" && addPanel.svc !== "" ? 1 : 0
                visible: opacity > 0.01

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: svcText.implicitWidth + 16
                    height: 20
                    radius: 10
                    color: WalColors.withAlpha(WalColors.color4, 0.16)

                    Text {
                        id: svcText

                        anchors.centerIn: parent
                        text: addPanel.svc === "spotify" ? "Spotify" : "SoundCloud"
                        color: WalColors.color4
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.bold: true
                    }

                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: goMouse.containsMouse ? WalColors.color4 : WalColors.withAlpha(WalColors.color4, 0.25)
                    scale: goMouse.pressed ? 0.9 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰁔"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: goMouse.containsMouse ? WalColors.color0 : WalColors.color4
                    }

                    MouseArea {
                        id: goMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitLink()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }

                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                }

            }

        }

        Behavior on t {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }

        }

    }

}
