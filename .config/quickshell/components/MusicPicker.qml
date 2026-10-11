import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Song list and cover cache come from the singleton.
    property var allSongs: MusicPickerState.allSongs
    property var filteredSongs: allSongs.filter((song) => {
        return song.toLowerCase().includes(PickerManager.searchText.toLowerCase());
    })
    property var coverCache: MusicPickerState.coverCache
    property real lastMouseX: -1
    property real lastMouseY: -1
    // Download view: replaces search bar + song grid
    property bool addOpen: false
    // Queue panel ("Up next") open = record stack fans out
    property bool queueOpen: false
    // Queue index under the mouse (record in the fan <-> row in the list)
    property int hoverQueueIndex: -1
    readonly property var queue: MusicPickerState.queue
    readonly property string nowPlaying: MusicPickerState.nowPlaying
    readonly property string musicDir: MusicPickerState.musicDir
    // The most recently downloaded song (empty when multiple songs)
    readonly property string resultPath: (MusicPickerState.dlName !== "" && MusicPickerState.dlName.indexOf(" Songs") === -1) ? MusicPickerState.dlName + ".mp3" : ""
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

    // Plays a song right away. The user's queue survives: the played song drops
    // out of it, the rest is inserted again behind the new song.
    function playSong(songPath, keepOpen) {
        if (!songPath)
            return ;

        const rest = MusicPickerState.queue.filter((p) => {
            return p !== songPath;
        });
        MusicPickerState.queue = rest;
        try {
            console.log("Selecting song:", songPath);
            addAllAndPlay.command = ["bash", "-c", 'song="$1"; shift; ' + 'mpc clear && mpc listall | mpc add && ' + 'position=$(mpc playlist -f "%file%" | grep -nxF "$song" | cut -d: -f1 | head -n 1) && ' + 'mpc play "$position" && mpc seek 0 && ' + 'for ((i=$#; i>=1; i--)); do mpc insert "${!i}" >/dev/null; done', "_", songPath].concat(rest);
            addAllAndPlay.running = true;
        } catch (e) {
            console.error("Error playing", songPath, ":", e);
        }
        if (!keepOpen)
            MusicPickerState.close();

    }

    function displayName(songPath) {
        return MusicPickerState.displayName(songPath);
    }

    // ==== Queue ====
    // Add to / remove from the queue. srcItem = item the record flies away from.
    function toggleQueue(songPath, srcItem) {
        if (!songPath)
            return ;

        const idx = MusicPickerState.queue.indexOf(songPath);
        if (idx !== -1) {
            MusicPickerState.removeFromQueue(idx);
            return ;
        }
        // Nothing is playing -> there is nothing to queue behind, just start it
        if (MusicPickerState.nowPlaying === "") {
            root.playSong(songPath, true);
            return ;
        }
        if (srcItem)
            root.flyToQueue(songPath, srcItem);

        MusicPickerState.addToQueue(songPath);
    }

    // A record flies in an arc from the song into the queue dock
    function flyToQueue(songPath, srcItem) {
        const from = srcItem.mapToItem(root, srcItem.width / 2, srcItem.height / 2);
        const to = queueDock.mapToItem(root, queueDock.width - 44, queueDock.height / 2);
        const cov = root.coverCache[songPath] ? "file://" + root.coverCache[songPath] : "";
        flyerComp.createObject(root, {
            "fromX": from.x,
            "fromY": from.y,
            "toX": to.x,
            "toY": to.y,
            "cover": cov
        });
    }

    // ==== Download view ====
    function openAdd(prefill) {
        root.addOpen = true;
        root.queueOpen = false;
        if (prefill)
            linkInput.text = prefill;
        else if (linkInput.text === "" && MusicPickerState.dlPhase === "idle")
            clipPaste.running = true; // Suggest link from clipboard
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

    // Acknowledge done/error and enter another link
    function another(clearText) {
        MusicPickerState.dlAck();
        if (clearText)
            linkInput.text = "";

        linkInput.forceActiveFocus();
    }

    Component.onCompleted: {
        // Ensure the song list is loaded,
        // in case the picker is opened first.
        MusicPickerState.loadSongs();
    }
    onFilteredSongsChanged: grid.currentIndex = 0
    Keys.onEscapePressed: {
        if (root.queueOpen)
            root.queueOpen = false;
        else if (root.addOpen)
            root.closeAdd();
        else
            MusicPickerState.close();
    }
    Keys.onReturnPressed: (event) => {
        // In download mode, Enter must not start a (hidden) song
        if (root.addOpen || root.filteredSongs.length === 0)
            return ;

        const song = root.filteredSongs[grid.currentIndex];
        // Ctrl+Enter = add to queue, Enter = play now
        if (event.modifiers & Qt.ControlModifier)
            root.toggleQueue(song, grid.currentItem);
        else
            root.playSong(song);
    }

    Process {
        id: addAllAndPlay
    }

    // Read clipboard (wl-clipboard); only valid links are accepted
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
            // Prepare cover of the new song for the result display
            if (root.resultPath !== "")
                MusicPickerState.requestCover(root.resultPath);

        }

        // Closing the picker also folds the record fan back into a stack
        function onPickerVisibleChanged() {
            if (!MusicPickerState.pickerVisible) {
                root.queueOpen = false;
                root.hoverQueueIndex = -1;
            }
        }

        target: MusicPickerState
    }

    // ==== Search bar (becomes the link field in download mode) ====
    Rectangle {
        id: searchBar

        readonly property color modeAccent: MusicPickerState.dlPhase === "error" ? WalColors.color1 : (MusicPickerState.dlPhase === "done" ? WalColors.color2 : WalColors.color4)

        width: Math.min(root.width * 0.4, 400)
        height: 56
        radius: height / 2
        anchors.top: parent.top
        anchors.topMargin: Math.max(root.height * 0.08, 48)
        anchors.horizontalCenter: parent.horizontalCenter
        color: root.addOpen ? WalColors.withAlpha(modeAccent, 0.1) : WalColors.withAlpha(WalColors.color7, 0.12)
        border.width: 2
        border.color: root.addOpen ? WalColors.withAlpha(modeAccent, linkInput.activeFocus || MusicPickerState.dlBusy ? 0.7 : 0.4) : (searchInput.activeFocus ? WalColors.withAlpha(WalColors.color4, 0.6) : WalColors.withAlpha(WalColors.color2, 0.25))

        // ---- Search mode ----
        Item {
            id: searchLayer

            anchors.fill: parent
            opacity: root.addOpen ? 0 : 1
            enabled: !root.addOpen
            visible: opacity > 0.01

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
                    // If a Spotify/SoundCloud link is pasted: move to the download view
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

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }

            }

        }

        // ---- Link mode ----
        Item {
            id: linkLayer

            anchors.fill: parent
            opacity: root.addOpen ? 1 : 0
            enabled: root.addOpen
            visible: opacity > 0.01

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌷"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                color: searchBar.modeAccent
            }

            TextInput {
                id: linkInput

                anchors.fill: parent
                anchors.leftMargin: 54
                anchors.rightMargin: 120
                verticalAlignment: Text.AlignVCenter
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: WalColors.color7
                clip: true
                selectByMouse: true
                readOnly: MusicPickerState.dlBusy
                onTextEdited: {
                    if (MusicPickerState.dlPhase !== "busy")
                        MusicPickerState.dlAck();

                }
                Keys.onReturnPressed: (event) => {
                    root.submitLink();
                    event.accepted = true;
                }
                Keys.onEnterPressed: (event) => {
                    root.submitLink();
                    event.accepted = true;
                }
                Keys.onEscapePressed: (event) => {
                    root.closeAdd();
                    event.accepted = true;
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 54
                anchors.verticalCenter: parent.verticalCenter
                text: "Paste a Spotify or SoundCloud link"
                color: WalColors.withAlpha(WalColors.color7, 0.35)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                visible: linkInput.text === ""
            }

            // Detected service
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: svcText.implicitWidth + 18
                height: 24
                radius: 12
                color: WalColors.withAlpha(searchBar.modeAccent, 0.16)
                opacity: dlCard.svc !== "" ? 1 : 0
                scale: dlCard.svc !== "" ? 1 : 0.8

                Text {
                    id: svcText

                    anchors.centerIn: parent
                    text: dlCard.svc === "spotify" ? "Spotify" : "SoundCloud"
                    color: searchBar.modeAccent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.6
                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }

            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 180
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }

        }

    }

    // ==== + Button: opens/closes the download view ====
    Rectangle {
        id: addButton

        readonly property bool hot: addMouse.containsMouse || root.addOpen
        readonly property bool busy: MusicPickerState.dlBusy
        readonly property bool doneBadge: MusicPickerState.dlPhase === "done" && !root.addOpen

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

        // Plus (rotates to an X when open); a bouncing arrow during download
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
                    duration: 300
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

        // Green dot: download is done, view was closed
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.rightMargin: 4
            width: 14
            height: 14
            radius: 7
            color: WalColors.color2
            border.width: 2
            border.color: WalColors.color0
            scale: addButton.doneBadge ? 1 : 0
            visible: scale > 0.01

            Behavior on scale {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                    easing.overshoot: 2
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

    // ==== Song grid ====
    Item {
        id: gridArea

        width: root.gridColumns * root.cellW
        anchors.top: searchBar.bottom
        anchors.topMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        // Completely hidden in download mode
        opacity: root.addOpen ? 0 : 1
        scale: root.addOpen ? 0.96 : 1
        enabled: !root.addOpen
        visible: opacity > 0.01

        // Loading indicator, in case the song list is still coming from the mpc scan
        Text {
            anchors.centerIn: parent
            text: "Loading songs…"
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
                text: "No songs found"
                color: WalColors.withAlpha(WalColors.color7, 0.4)
                font.family: "JetBrainsMono Nerd Font"
                visible: grid.count === 0 && MusicPickerState.songsLoaded
            }

            delegate: Item {
                id: cell

                readonly property bool isCurrent: GridView.isCurrentItem
                readonly property string songPath: modelData
                // Cover cache comes from the state – path remains after
                // closing, no need to re-extract.
                readonly property string coverPath: root.coverCache[songPath] ? ("file://" + root.coverCache[songPath]) : ""
                readonly property int qIndex: MusicPickerState.queue.indexOf(songPath)
                readonly property bool queued: qIndex !== -1

                width: grid.cellWidth
                height: grid.cellHeight
                Component.onCompleted: {
                    if (songPath)
                        MusicPickerState.requestCover(songPath);

                }

                // The record that slides out of the sleeve (selected song only).
                // Click it -> it flies into the queue.
                Component {
                    id: recordComp

                    Item {
                        id: rec

                        property bool out: false
                        readonly property real slide: out ? (recMouse.containsMouse ? 52 : 40) : 0

                        Component.onCompleted: Qt.callLater(() => {
                            rec.out = true;
                        })

                        VinylDisc {
                            id: recDisc

                            size: 86
                            cover: cell.coverPath
                            anchors.verticalCenter: parent.verticalCenter
                            x: (rec.width - width) / 2 + rec.slide
                            spin: rec.out && MusicPickerState.pickerVisible
                            spinDuration: 5000
                            shadow: true
                            scale: recMouse.containsMouse ? 1.05 : 1

                            Behavior on x {
                                NumberAnimation {
                                    duration: 340
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.4
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        // Hit area = only the part of the record that sticks out of the sleeve
                        MouseArea {
                            id: recMouse

                            x: rec.width + 4
                            y: (rec.height - 60) / 2
                            width: 40
                            height: 60
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleQueue(cell.songPath, recDisc)
                        }

                    }

                }

                // Queued: small spinning record with the queue position in the corner.
                // Click it -> take the song out of the queue again.
                Component {
                    id: badgeComp

                    VinylDisc {
                        id: badge

                        readonly property bool hot: badgeMouse.containsMouse
                        property bool born: false

                        size: 38
                        labelText: hot ? "×" : (cell.qIndex + 1)
                        labelColor: hot ? WalColors.color1 : WalColors.color2
                        spin: !hot && MusicPickerState.pickerVisible
                        spinDuration: 3500
                        shadow: true
                        scale: (born ? 1 : 0) * (hot ? 1.15 : 1)
                        Component.onCompleted: Qt.callLater(() => {
                            badge.born = true;
                        })

                        MouseArea {
                            id: badgeMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleQueue(cell.songPath, null)
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.2
                            }

                        }

                    }

                }

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    // Above the click area so the record gets its clicks
                    z: 1

                    // Sleeve = cover; the record sits behind it
                    Item {
                        id: sleeve

                        width: root.boxSize
                        height: root.boxSize
                        anchors.horizontalCenter: parent.horizontalCenter

                        Loader {
                            anchors.fill: parent
                            active: cell.isCurrent && !cell.queued
                            sourceComponent: recordComp
                        }

                        Rectangle {
                            id: iconBg

                            anchors.fill: parent
                            radius: root.boxRadius
                            color: WalColors.withAlpha(WalColors.color0, 0.3)
                            border.width: (isCurrent || queued) ? 2 : 0
                            border.color: queued ? WalColors.withAlpha(WalColors.color2, 0.85) : WalColors.withAlpha(WalColors.color4, 0.6)
                            scale: isCurrent ? 1.08 : 1

                            // Accent tint as overlay
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

                        Loader {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: -12
                            anchors.rightMargin: -12
                            z: 5
                            active: cell.queued
                            sourceComponent: badgeComp
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

                // Left click = play now, right click = add to / remove from queue
                MouseArea {
                    id: mArea

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: (mouse) => {
                        const p = mArea.mapToItem(null, mouse.x, mouse.y);
                        if (Math.abs(p.x - root.lastMouseX) < 3 && Math.abs(p.y - root.lastMouseY) < 3)
                            return ;

                        root.lastMouseX = p.x;
                        root.lastMouseY = p.y;
                        grid.currentIndex = index;
                    }
                    onClicked: (mouse) => {
                        grid.currentIndex = index;
                        if (mouse.button === Qt.RightButton)
                            root.toggleQueue(modelData, sleeve);
                        else
                            root.playSong(modelData);
                    }
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }

        }

    }

    // ==== Download card ====
    Item {
        id: dlCard

        readonly property string phase: MusicPickerState.dlPhase
        readonly property bool idle: phase === "idle"
        readonly property bool busy: phase === "busy"
        readonly property bool done: phase === "done"
        readonly property bool failed: phase === "error"
        readonly property string svc: MusicPickerState.serviceOf(linkInput.text)
        readonly property real prog: MusicPickerState.dlProgress
        readonly property int stage: MusicPickerState.dlStage
        readonly property color accent: failed ? WalColors.color1 : (done ? WalColors.color2 : WalColors.color4)
        readonly property var stageLabels: ["Search", "Download", "Convert", "Library"]
        readonly property bool hasCover: root.resultPath !== "" && !!root.coverCache[root.resultPath]
        // 0..1: ring fill level (done = full)
        readonly property real ringTarget: done ? 1 : (prog >= 0 ? prog : 0)
        property real t: root.addOpen ? 1 : 0
        property real doneT: done ? 1 : 0
        property real flashT: 1

        anchors.top: searchBar.bottom
        anchors.topMargin: 56
        anchors.horizontalCenter: parent.horizontalCenter
        width: 440
        height: 356
        opacity: Math.min(1, t)
        scale: 0.92 + 0.08 * Math.min(1.04, t)
        visible: t > 0.01
        enabled: root.addOpen
        onDoneChanged: {
            if (done)
                flashAnim.restart();

        }

        NumberAnimation {
            id: flashAnim

            target: dlCard
            property: "flashT"
            from: 0
            to: 1
            duration: 750
            easing.type: Easing.OutCubic
        }

        Rectangle {
            id: cardBg

            anchors.fill: parent
            radius: 30
            color: WalColors.withAlpha(WalColors.color0, 0.9)
            border.width: 2
            border.color: WalColors.withAlpha(dlCard.accent, dlCard.busy ? 0.55 : 0.3)
            clip: true

            // Equalizer bars at the bottom: dance during download
            Row {
                id: eq

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                height: 70
                spacing: 4

                Repeater {
                    model: 36

                    delegate: Rectangle {
                        required property int index
                        // Pseudo-random but fixed properties per bar
                        readonly property real peak: 0.35 + 0.65 * ((index * 37 % 11) / 10)
                        readonly property int dur: 380 + (index * 53 % 7) * 70
                        property real level: 0

                        width: (eq.width - 35 * eq.spacing) / 36
                        anchors.bottom: parent.bottom
                        height: 4 + level * (eq.height - 8)
                        radius: width / 2
                        color: WalColors.withAlpha(dlCard.accent, 0.1 + 0.2 * level)

                        SequentialAnimation on level {
                            running: dlCard.busy && dlCard.visible
                            loops: Animation.Infinite
                            onRunningChanged: {
                                if (!running)
                                    level = 0;

                            }

                            NumberAnimation {
                                to: peak
                                duration: dur
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 0.08
                                duration: dur
                                easing.type: Easing.InOutSine
                            }

                        }

                        Behavior on level {
                            enabled: !dlCard.busy

                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

            // ---- Ring ----
            Item {
                id: ring

                readonly property real size: 124
                readonly property real thick: 6
                readonly property real r: size / 2 - thick / 2
                property real v: dlCard.ringTarget

                anchors.top: parent.top
                anchors.topMargin: 26
                anchors.horizontalCenter: parent.horizontalCenter
                width: size
                height: size

                // Pulsing wave during download
                Rectangle {
                    id: pulse

                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: dlCard.accent
                    visible: dlCard.busy
                    opacity: 0

                    ParallelAnimation {
                        running: dlCard.busy && dlCard.visible
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: pulse
                            property: "scale"
                            from: 1
                            to: 1.38
                            duration: 1500
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: pulse
                            property: "opacity"
                            from: 0.5
                            to: 0
                            duration: 1500
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // One-shot flash on completion
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 3
                    border.color: WalColors.color2
                    opacity: (1 - dlCard.flashT) * 0.7
                    scale: 1 + 0.6 * dlCard.flashT
                    visible: dlCard.flashT < 1
                }

                // Track
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: WalColors.withAlpha(dlCard.accent, 0.06)
                    border.width: ring.thick
                    border.color: WalColors.withAlpha(WalColors.color7, 0.08)
                }

                // Determinate progress
                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    layer.enabled: true
                    layer.samples: 4
                    visible: dlCard.done || (dlCard.busy && dlCard.prog >= 0)

                    ShapePath {
                        strokeColor: dlCard.accent
                        strokeWidth: ring.thick
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: ring.size / 2
                            centerY: ring.size / 2
                            radiusX: ring.r
                            radiusY: ring.r
                            startAngle: -90
                            sweepAngle: Math.max(0.5, Math.min(359.9, 360 * ring.v))
                        }

                    }

                }

                // Indeterminate progress: rotating arc
                Item {
                    id: spinner

                    anchors.fill: parent
                    visible: dlCard.busy && dlCard.prog < 0

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeColor: dlCard.accent
                            strokeWidth: ring.thick
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: ring.size / 2
                                centerY: ring.size / 2
                                radiusX: ring.r
                                radiusY: ring.r
                                startAngle: -90
                                sweepAngle: 110
                            }

                        }

                    }

                    RotationAnimator on rotation {
                        running: spinner.visible && dlCard.visible
                        from: 0
                        to: 360
                        duration: 1100
                        loops: Animation.Infinite
                    }

                }

                // Core: cover (done), percent (download) or icon
                Item {
                    id: core

                    anchors.centerIn: parent
                    width: ring.size - 26
                    height: width

                    Image {
                        id: resultCover

                        anchors.fill: parent
                        source: dlCard.hasCover ? "file://" + root.coverCache[root.resultPath] : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(160, 160)
                        visible: false
                    }

                    Rectangle {
                        id: coverMask

                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: resultCover
                        maskSource: coverMask
                        opacity: dlCard.done && resultCover.status === Image.Ready ? dlCard.doneT : 0
                        scale: 0.7 + 0.3 * dlCard.doneT
                        visible: opacity > 0.01
                    }

                    // Icon / percent
                    Text {
                        id: coreText

                        readonly property bool showCheck: dlCard.done && resultCover.status !== Image.Ready

                        anchors.centerIn: parent
                        visible: !(dlCard.done && resultCover.status === Image.Ready)
                        text: dlCard.failed ? "󰀦" : (showCheck ? "󰄬" : (dlCard.busy && dlCard.prog >= 0 ? Math.round(dlCard.prog * 100) + "%" : "󰇚"))
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: (dlCard.busy && dlCard.prog >= 0) ? 26 : 40
                        font.bold: true
                        color: dlCard.accent
                        scale: showCheck ? 0.4 + 0.6 * dlCard.doneT : 1
                        opacity: dlCard.idle && dlCard.svc === "" ? 0.45 : 1

                        // Gentle floating when idle or searching
                        SequentialAnimation on anchors.verticalCenterOffset {
                            running: (dlCard.idle || (dlCard.busy && dlCard.prog < 0)) && dlCard.visible
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 4
                                duration: 900
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: -4
                                duration: 900
                                easing.type: Easing.InOutSine
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                    }

                }

                // Checkmark badge when a cover is in the core
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 32
                    height: 32
                    radius: 16
                    color: WalColors.color2
                    border.width: 3
                    border.color: WalColors.color0
                    scale: (dlCard.done && resultCover.status === Image.Ready) ? dlCard.doneT : 0
                    visible: scale > 0.01

                    Text {
                        anchors.centerIn: parent
                        text: "󰄬"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        font.bold: true
                        color: WalColors.color0
                    }

                }

                Behavior on v {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // ---- Title + subtitle ----
            Column {
                id: texts

                anchors.top: ring.bottom
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 28
                anchors.rightMargin: 28
                spacing: 4

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    font.bold: true
                    color: dlCard.failed ? WalColors.color1 : WalColors.color7
                    text: dlCard.busy ? MusicPickerState.dlStatus : (dlCard.done ? (MusicPickerState.dlName || "Done") : (dlCard.failed ? "That didn't work" : (dlCard.svc === "" ? "Add a song" : (dlCard.svc === "spotify" ? "Spotify song detected" : "SoundCloud song detected"))))
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: WalColors.withAlpha(WalColors.color7, 0.5)
                    text: dlCard.busy ? (dlCard.prog >= 0 ? Math.round(dlCard.prog * 100) + " % · saving as mp3" : "One moment …") : (dlCard.done ? "Added to library" : (dlCard.failed ? MusicPickerState.dlError : (dlCard.svc === "" ? "Paste a Spotify or SoundCloud link above" : "Ready to download as mp3")))
                }

            }

            // ---- Stage indicator ----
            Item {
                id: stepper

                readonly property real colW: width / 4

                anchors.top: texts.bottom
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                width: 360
                height: 42
                opacity: (dlCard.busy || dlCard.done) ? 1 : 0
                visible: opacity > 0.01

                // Connector line
                Rectangle {
                    x: stepper.colW / 2
                    y: 6
                    width: stepper.width - stepper.colW
                    height: 2
                    radius: 1
                    color: WalColors.withAlpha(WalColors.color7, 0.1)
                }

                Rectangle {
                    x: stepper.colW / 2
                    y: 6
                    width: (stepper.width - stepper.colW) * Math.min(1, dlCard.stage / 3)
                    height: 2
                    radius: 1
                    color: dlCard.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: 450
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Repeater {
                    model: 4

                    delegate: Item {
                        id: step

                        required property int index
                        readonly property bool complete: dlCard.stage > index || dlCard.done
                        readonly property bool current: dlCard.busy && dlCard.stage === index

                        x: index * stepper.colW
                        width: stepper.colW
                        height: stepper.height

                        Rectangle {
                            id: dot

                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 0
                            width: 14
                            height: 14
                            radius: 7
                            color: step.complete ? dlCard.accent : WalColors.color0
                            border.width: 2
                            border.color: (step.complete || step.current) ? dlCard.accent : WalColors.withAlpha(WalColors.color7, 0.2)
                            scale: step.current ? 1.2 : 1

                            Text {
                                anchors.centerIn: parent
                                visible: step.complete
                                text: "󰄬"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                                color: WalColors.color0
                            }

                            // Active stage pulses
                            SequentialAnimation on opacity {
                                running: step.current && dlCard.visible
                                loops: Animation.Infinite

                                NumberAnimation {
                                    to: 0.45
                                    duration: 520
                                    easing.type: Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 1
                                    duration: 520
                                    easing.type: Easing.InOutSine
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 250
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2
                                }

                            }

                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: dot.bottom
                            anchors.topMargin: 6
                            text: dlCard.stageLabels[step.index]
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.bold: step.current
                            color: (step.complete || step.current) ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.35)
                        }

                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                    }

                }

            }

            // ---- Buttons ----
            Row {
                id: buttons

                anchors.bottom: parent.bottom
                anchors.bottomMargin: 22
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                DlButton {
                    label: dlCard.done ? "Play" : (dlCard.failed ? "Retry" : "Download")
                    primary: true
                    accent: dlCard.accent
                    active: dlCard.done ? root.resultPath !== "" : (dlCard.failed || dlCard.svc !== "")
                    visible: !dlCard.busy
                    onClicked: {
                        if (dlCard.done)
                            root.playSong(root.resultPath);
                        else
                            root.submitLink();
                    }
                }

                DlButton {
                    label: dlCard.busy ? "In background" : (dlCard.done ? "Another" : "Back")
                    visible: !dlCard.idle
                    onClicked: {
                        if (dlCard.busy)
                            root.closeAdd();
                        else if (dlCard.done)
                            root.another(true);
                        else
                            root.another(false);
                    }
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 250
                }

            }

        }

        Behavior on t {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutBack
                easing.overshoot: 1
            }

        }

    }

    // ==== Queue dock (bottom right) ====
    // Closed: a tidy pile of records (the next song on top).
    // Open (panel visible): the records fan out like a hand of cards.
    Item {
        id: queueDock

        readonly property int count: root.queue.length
        readonly property int shown: Math.min(4, count)
        readonly property real discSize: 80
        readonly property real fanRadius: 240
        readonly property real fanStep: 12 // degrees between two records
        property int lastCount: 0
        property real bump: 1
        // 0 = pile, 1 = fan
        property real fan: root.queueOpen ? 1 : 0

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 56
        anchors.bottomMargin: 56
        width: 100
        height: 92
        z: 150
        opacity: root.addOpen ? 0.35 : 1
        scale: bump * ((dockHover.hovered && !root.queueOpen) ? 1.06 : 1)
        onCountChanged: {
            // The badge bumps when the flying record lands
            if (count > lastCount)
                bumpAnim.restart();

            lastCount = count;
        }

        HoverHandler {
            id: dockHover
        }

        SequentialAnimation {
            id: bumpAnim

            PauseAnimation {
                duration: 480
            }

            NumberAnimation {
                target: queueDock
                property: "bump"
                to: 1.18
                duration: 110
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: queueDock
                property: "bump"
                to: 1
                duration: 260
                easing.type: Easing.OutBack
                easing.overshoot: 2.5
            }

        }

        // Click on the dock (gaps between records, empty state) = open/close
        MouseArea {
            id: dockMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.queueOpen = !root.queueOpen
        }

        // Empty state: quiet circle with a note
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 80
            height: 80
            radius: 40
            color: WalColors.withAlpha(WalColors.color0, 0.8)
            border.width: 2
            border.color: root.queueOpen ? WalColors.withAlpha(WalColors.color4, 0.7) : (dockMouse.containsMouse ? WalColors.withAlpha(WalColors.color4, 0.5) : WalColors.withAlpha(WalColors.color2, 0.25))
            opacity: queueDock.count === 0 ? 1 : 0
            visible: opacity > 0.01

            Text {
                anchors.centerIn: parent
                text: "♫"
                font.pixelSize: 30
                color: root.queueOpen ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.5)
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }

            }

        }

        // The next four songs as records
        Repeater {
            model: queueDock.shown

            delegate: Item {
                id: disc

                required property int index
                readonly property string path: root.queue[index] ?? ""
                readonly property string cov: root.coverCache[path] ? "file://" + root.coverCache[path] : ""
                readonly property real a: index * queueDock.fanStep * Math.PI / 180
                // Pile pose: neat, each record a bit further up-left and smaller
                readonly property real sx: -index * 9
                readonly property real sy: -index * 4
                readonly property real ss: 1 - index * 0.045
                // Fan pose: arc around a pivot below the dock, records tilt outward
                readonly property real fx: -queueDock.fanRadius * Math.sin(a)
                readonly property real fy: queueDock.fanRadius * (1 - Math.cos(a)) - 12
                // Per-record progress, so they fan out one after another
                readonly property real p: Math.max(0, (queueDock.fan - index * 0.06) / 0.82)
                readonly property bool hovered: discMouse.containsMouse
                readonly property bool hot: root.queueOpen && root.hoverQueueIndex === index
                property real lift: hot ? 12 : 0
                property real pop: hot ? 1.08 : 1

                width: queueDock.discSize
                height: width
                x: queueDock.width - 44 - width / 2 + sx + (fx - sx) * p
                y: queueDock.height / 2 - height / 2 + sy + (fy - sy) * p - lift
                z: hot ? 60 : 10 - index
                scale: (ss + (1 - ss) * p) * pop
                onHoveredChanged: {
                    if (hovered)
                        root.hoverQueueIndex = index;
                    else if (root.hoverQueueIndex === index)
                        root.hoverQueueIndex = -1;
                }

                VinylDisc {
                    size: disc.width
                    cover: disc.cov
                    spin: MusicPickerState.pickerVisible
                    spinDuration: 6000 + disc.index * 1700
                    sheenPhase: disc.index * 70
                    dim: disc.index * 0.14 * (1 - 0.7 * disc.p)
                    shadow: true
                    rotation: -disc.index * queueDock.fanStep * disc.p
                }

                // Queue position on the fanned records (matches the list rows)
                Rectangle {
                    x: disc.width * 0.5 * 0.293 - 11 + 4
                    y: disc.width * 0.5 * 0.293 - 11 + 4
                    width: 22
                    height: 22
                    radius: 11
                    color: disc.index === 0 ? WalColors.color4 : WalColors.color0
                    border.width: 2
                    border.color: disc.index === 0 ? WalColors.color0 : WalColors.withAlpha(WalColors.color4, 0.7)
                    opacity: Math.min(1, disc.p)
                    scale: 0.6 + 0.4 * Math.min(1, disc.p)
                    visible: opacity > 0.01

                    Text {
                        anchors.centerIn: parent
                        text: disc.index + 1
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.bold: true
                        color: disc.index === 0 ? WalColors.color0 : WalColors.color4
                    }

                }

                // Round hit area (records overlap, a square one would steal clicks)
                MouseArea {
                    id: discMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    containmentMask: circleMask
                    onClicked: {
                        if (root.queueOpen)
                            MusicPickerState.playQueued(disc.index);
                        else
                            root.queueOpen = true;
                    }
                }

                QtObject {
                    id: circleMask

                    function contains(point) {
                        const r = disc.width / 2;
                        const dx = point.x - r;
                        const dy = point.y - r;
                        return dx * dx + dy * dy <= r * r;
                    }

                }

                Behavior on lift {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on pop {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        // Number of queued songs
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -4
            anchors.rightMargin: -6
            width: Math.max(26, badgeText.implicitWidth + 14)
            height: 26
            radius: 13
            color: WalColors.color4
            border.width: 3
            border.color: WalColors.color0
            z: 50
            scale: queueDock.count > 0 ? 1 : 0
            visible: scale > 0.01

            Text {
                id: badgeText

                anchors.centerIn: parent
                text: queueDock.count
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true
                color: WalColors.color0
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 2
                }

            }

        }

        Behavior on fan {
            NumberAnimation {
                duration: 560
                easing.type: Easing.OutBack
                easing.overshoot: 0.8
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }

        }

    }

    // ==== "Up next" panel: grows out of the dock ====
    Rectangle {
        id: queuePanel

        readonly property int rowH: 60
        readonly property int maxRows: 6

        anchors.right: queueDock.right
        anchors.bottom: queueDock.top
        anchors.bottomMargin: 26
        width: 380
        height: panelCol.implicitHeight + 36
        radius: 26
        color: WalColors.withAlpha(WalColors.color0, 0.92)
        border.width: 2
        border.color: WalColors.withAlpha(WalColors.color4, 0.3)
        z: 160
        opacity: root.queueOpen ? 1 : 0
        scale: root.queueOpen ? 1 : 0.88
        transformOrigin: Item.BottomRight
        visible: opacity > 0.01
        enabled: root.queueOpen

        // Swallows clicks so the picker does not close behind the panel
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: panelCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 12

            // ---- Header ----
            Item {
                width: parent.width
                height: 28

                Text {
                    id: panelTitle

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Up next"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    font.bold: true
                    color: WalColors.color7
                }

                Text {
                    anchors.left: panelTitle.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.queue.length === 0 ? "" : root.queue.length + (root.queue.length === 1 ? " song" : " songs")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: WalColors.withAlpha(WalColors.color7, 0.45)
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: clearText.implicitWidth + 24
                        height: 28
                        radius: 14
                        visible: root.queue.length > 0
                        color: clearMouse.containsMouse ? WalColors.withAlpha(WalColors.color1, 0.3) : WalColors.withAlpha(WalColors.color7, 0.08)

                        Text {
                            id: clearText

                            anchors.centerIn: parent
                            text: "Clear"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: clearMouse.containsMouse ? WalColors.color1 : WalColors.withAlpha(WalColors.color7, 0.7)
                        }

                        MouseArea {
                            id: clearMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MusicPickerState.clearQueue()
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }

                        }

                    }

                    MiniButton {
                        label: "×"
                        onClicked: root.queueOpen = false
                    }

                }

            }

            // ---- Now playing ----
            Item {
                width: parent.width
                height: 48
                visible: root.nowPlaying !== ""

                CoverThumb {
                    id: nowCover

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    source: root.coverCache[root.nowPlaying] ? "file://" + root.coverCache[root.nowPlaying] : ""

                    RotationAnimator on rotation {
                        running: root.queueOpen && MusicPickerState.pickerVisible
                        from: 0
                        to: 360
                        duration: 7000
                        loops: Animation.Infinite
                    }

                }

                Column {
                    anchors.left: nowCover.right
                    anchors.leftMargin: 12
                    anchors.right: nowBars.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "NOW PLAYING"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        color: WalColors.color4
                    }

                    Text {
                        width: parent.width
                        text: root.displayName(root.nowPlaying)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: WalColors.color7
                        elide: Text.ElideRight
                    }

                }

                // Little equalizer
                Row {
                    id: nowBars

                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18
                    spacing: 3

                    Repeater {
                        model: 3

                        delegate: Rectangle {
                            required property int index
                            property real lvl: 0.3

                            width: 4
                            height: 4 + lvl * 14
                            radius: 2
                            anchors.bottom: parent.bottom
                            color: WalColors.color4

                            SequentialAnimation on lvl {
                                running: root.queueOpen && MusicPickerState.pickerVisible
                                loops: Animation.Infinite

                                NumberAnimation {
                                    to: 1
                                    duration: 300 + index * 90
                                    easing.type: Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 0.15
                                    duration: 300 + index * 90
                                    easing.type: Easing.InOutSine
                                }

                            }

                        }

                    }

                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: WalColors.withAlpha(WalColors.color7, 0.1)
                visible: root.nowPlaying !== ""
            }

            // ---- Queue list ----
            Item {
                id: listWrap

                width: parent.width
                height: root.queue.length === 0 ? 84 : Math.min(queuePanel.maxRows, root.queue.length) * queuePanel.rowH

                Text {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "Queue is empty\npull a record out of its sleeve\nor right-click a song"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    lineHeight: 1.3
                    color: WalColors.withAlpha(WalColors.color7, 0.4)
                    visible: root.queue.length === 0
                }

                ListView {
                    id: queueList

                    anchors.fill: parent
                    model: root.queue
                    clip: true
                    interactive: contentHeight > height

                    delegate: Item {
                        id: row

                        required property int index
                        required property var modelData
                        readonly property bool realHover: rowMouse.containsMouse || upBtn.hovered || delBtn.hovered
                        // Also lit up when its record in the fan is hovered
                        readonly property bool hot: realHover || root.hoverQueueIndex === index

                        width: queueList.width
                        height: queuePanel.rowH
                        onRealHoverChanged: {
                            if (realHover)
                                root.hoverQueueIndex = index;
                            else if (root.hoverQueueIndex === index)
                                root.hoverQueueIndex = -1;
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 3
                            anchors.bottomMargin: 3
                            radius: 16
                            color: row.hot ? WalColors.withAlpha(WalColors.color7, 0.09) : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }

                            }

                        }

                        // Click a row = play this song right now
                        MouseArea {
                            id: rowMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MusicPickerState.playQueued(row.index)
                        }

                        Text {
                            id: numText

                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: row.index + 1
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                            color: row.index === 0 ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.4)
                        }

                        CoverThumb {
                            id: rowCover

                            anchors.left: numText.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 42
                            height: 42
                            corner: 11
                            source: root.coverCache[row.modelData] ? "file://" + root.coverCache[row.modelData] : ""
                        }

                        Text {
                            anchors.left: rowCover.right
                            anchors.leftMargin: 12
                            anchors.right: btnRow.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.displayName(row.modelData)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: WalColors.color7
                            elide: Text.ElideRight
                        }

                        Row {
                            id: btnRow

                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            opacity: row.hot ? 1 : 0

                            MiniButton {
                                id: upBtn

                                label: "↑"
                                visible: row.index > 0
                                onClicked: MusicPickerState.queueNext(row.index)
                            }

                            MiniButton {
                                id: delBtn

                                label: "×"
                                danger: true
                                onClicked: MusicPickerState.removeFromQueue(row.index)
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }

                            }

                        }

                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }

        }

    }

    // Flying record: from the sleeve into the queue dock (destroys itself on landing)
    Component {
        id: flyerComp

        Item {
            id: flyer

            property real fromX: 0
            property real fromY: 0
            property real toX: 0
            property real toY: 0
            property string cover: ""
            // 0..1 progress along the flight path
            property real p: 0

            width: 86
            height: 86
            z: 200
            // Straight line + sine hump = a nice arc
            x: fromX + (toX - fromX) * p - width / 2
            y: fromY + (toY - fromY) * p - Math.sin(Math.PI * p) * 140 - height / 2
            scale: 1 - 0.07 * p
            opacity: p < 0.9 ? 1 : Math.max(0, (1 - p) / 0.1)

            VinylDisc {
                size: 86
                cover: flyer.cover
                spin: true
                spinDuration: 800
                shadow: true
            }

            NumberAnimation {
                id: flight

                target: flyer
                property: "p"
                from: 0
                to: 1
                duration: 560
                easing.type: Easing.InOutCubic
                running: true
                onFinished: flyer.destroy()
            }

        }

    }

    // A vinyl record: dark disc, grooves, a light reflection that spins with it,
    // the cover as the label (or a number) and a spindle hole.
    component VinylDisc: Item {
        id: vd

        property real size: 80
        property string cover: ""
        // Shows this text (e.g. a queue position) instead of the cover on the label
        property string labelText: ""
        property color labelColor: WalColors.color2
        property bool spin: false
        property int spinDuration: 7000
        // Start angle of the reflection, so records do not all look identical
        property real sheenPhase: 0
        // 0..1: darkens the record (depth in the pile)
        property real dim: 0
        property bool shadow: false
        readonly property real labelSize: labelText !== "" ? size * 0.64 : size * 0.54

        width: size
        height: size

        // Cheap drop shadow
        Rectangle {
            visible: vd.shadow
            x: 2
            y: 4
            width: vd.size
            height: vd.size
            radius: width / 2
            color: "black"
            opacity: 0.35
        }

        // Vinyl body
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: WalColors.color0
            border.width: 1
            border.color: WalColors.withAlpha(WalColors.color7, 0.25)
        }

        // Grooves
        Repeater {
            model: 3

            delegate: Rectangle {
                required property int index

                anchors.centerIn: parent
                width: vd.size * (0.93 - index * 0.11)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: WalColors.withAlpha(WalColors.color7, 0.07)
            }

        }

        // Rotating part: reflection + cover label
        Item {
            anchors.fill: parent
            rotation: vd.sheenPhase

            Item {
                id: spinner

                anchors.fill: parent

                // Two opposite light bands, like light on real vinyl
                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    layer.enabled: true
                    layer.samples: 4

                    ShapePath {
                        strokeColor: Qt.rgba(1, 1, 1, 0.13)
                        strokeWidth: vd.size * 0.2
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap

                        PathAngleArc {
                            centerX: vd.size / 2
                            centerY: vd.size / 2
                            radiusX: vd.size * 0.355
                            radiusY: vd.size * 0.355
                            startAngle: 205
                            sweepAngle: 32
                        }

                    }

                    ShapePath {
                        strokeColor: Qt.rgba(1, 1, 1, 0.13)
                        strokeWidth: vd.size * 0.2
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap

                        PathAngleArc {
                            centerX: vd.size / 2
                            centerY: vd.size / 2
                            radiusX: vd.size * 0.355
                            radiusY: vd.size * 0.355
                            startAngle: 25
                            sweepAngle: 32
                        }

                    }

                }

                CoverThumb {
                    anchors.centerIn: parent
                    width: vd.labelSize
                    height: width
                    source: vd.cover
                    visible: vd.labelText === ""
                }

                RotationAnimator on rotation {
                    running: vd.spin
                    from: 0
                    to: 360
                    duration: vd.spinDuration
                    loops: Animation.Infinite
                }

            }

        }

        // Number label (static, so the digit does not spin)
        Rectangle {
            visible: vd.labelText !== ""
            anchors.centerIn: parent
            width: vd.labelSize
            height: width
            radius: width / 2
            color: vd.labelColor

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }

            }

        }

        Text {
            visible: vd.labelText !== ""
            anchors.centerIn: parent
            text: vd.labelText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(vd.size * 0.3)
            font.bold: true
            color: WalColors.color0
        }

        // Label rim
        Rectangle {
            anchors.centerIn: parent
            width: vd.labelSize + 2
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: WalColors.withAlpha(WalColors.color7, 0.3)
        }

        // Spindle hole
        Rectangle {
            visible: vd.labelText === ""
            anchors.centerIn: parent
            width: Math.max(4, vd.size * 0.09)
            height: width
            radius: width / 2
            color: WalColors.color0
            border.width: 1
            border.color: WalColors.withAlpha(WalColors.color7, 0.35)
        }

        // Depth dimming
        Rectangle {
            visible: vd.dim > 0.01
            anchors.fill: parent
            radius: width / 2
            color: WalColors.withAlpha(WalColors.color0, vd.dim)
        }

    }

    // Round or rounded-square cover with a "♪" fallback
    component CoverThumb: Item {
        id: thumb

        property string source: ""
        property real corner: width / 2
        property real glyphSize: width * 0.45

        Image {
            id: thumbImg

            anchors.fill: parent
            source: thumb.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(Math.max(thumb.width, 1) * 2, Math.max(thumb.height, 1) * 2)
            visible: false
        }

        Rectangle {
            id: thumbMask

            anchors.fill: parent
            radius: thumb.corner
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: thumbImg
            maskSource: thumbMask
            visible: thumbImg.status === Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            radius: thumb.corner
            color: WalColors.withAlpha(WalColors.color2, 0.16)
            visible: thumbImg.status !== Image.Ready

            Text {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: thumb.glyphSize
                color: WalColors.color2
            }

        }

    }

    // Small round button for rows in the queue list
    component MiniButton: Rectangle {
        id: mb

        property string label: ""
        property bool danger: false
        readonly property bool hovered: mbMouse.containsMouse

        signal clicked()

        width: 28
        height: 28
        radius: 14
        color: hovered ? (danger ? WalColors.color1 : WalColors.color4) : WalColors.withAlpha(WalColors.color7, 0.12)
        scale: mbMouse.pressed ? 0.9 : (hovered ? 1.1 : 1)

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: mb.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            font.bold: true
            color: mb.hovered ? WalColors.color0 : WalColors.withAlpha(WalColors.color7, 0.8)
        }

        MouseArea {
            id: mbMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.clicked()
        }

        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }

        }

    }

    // Small button for the download card
    component DlButton: Rectangle {
        id: btn

        property string label: ""
        property bool primary: false
        property bool active: true
        property color accent: WalColors.color4

        signal clicked()

        implicitWidth: btnText.implicitWidth + 44
        implicitHeight: 38
        radius: height / 2
        opacity: active ? 1 : 0.4
        color: primary ? (btnMouse.containsMouse ? accent : WalColors.withAlpha(accent, 0.85)) : (btnMouse.containsMouse ? WalColors.withAlpha(WalColors.color7, 0.16) : WalColors.withAlpha(WalColors.color7, 0.08))
        border.width: primary ? 0 : 1
        border.color: WalColors.withAlpha(WalColors.color7, 0.15)
        scale: btnMouse.pressed ? 0.94 : (btnMouse.containsMouse && active ? 1.05 : 1)

        Text {
            id: btnText

            anchors.centerIn: parent
            text: btn.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.bold: true
            color: btn.primary ? WalColors.color0 : WalColors.color7
        }

        MouseArea {
            id: btnMouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.active
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }

        }

    }

}
