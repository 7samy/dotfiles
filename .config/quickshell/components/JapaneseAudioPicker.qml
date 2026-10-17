import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    readonly property real pad: 16
    readonly property real panelWidth: Math.min(680, width - 48)
    readonly property real innerWidth: panelWidth - 2 * pad
    readonly property string mono: "JetBrainsMono Nerd Font"
    property string filter: "library"
    property string searchQuery: ""
    property bool intro: true
    property real shown: 0
    readonly property bool isSearchMode: searchQuery !== "" && (JapaneseAudioState.isSearching || JapaneseAudioState.searchResults.length > 0)
    property string activePeriod: "day"
    readonly property var currentStats: parseTime(JapaneseAudioState.getStatsForPeriod(activePeriod))
    readonly property real currentMinutes: (parseInt(currentStats.h) * 60) + parseInt(currentStats.m)
    readonly property real maxMinutes: {
        switch (activePeriod) {
        case "day":
            return 60;
        case "week":
            return 300;
        case "month":
            return 1200;
        case "year":
            return 14400;
        }
        return 60;
    }
    readonly property real progress: Math.min(1, currentMinutes / maxMinutes)
    property real displayProgress: progress
    property real statsProgress: filter === "stats" ? 1 : 0
    property real libraryProgress: (filter === "library" && !isSearchMode) ? 1 : 0
    property real searchProgress: (filter === "library" && isSearchMode) ? 1 : 0
    readonly property var entries: JapaneseAudioState.library
    readonly property var results: JapaneseAudioState.searchResults

    function parseTime(str) {
        const h = str.match(/(\d+)h/);
        const m = str.match(/(\d+)m/);
        return {
            "h": h ? h[1] : "0",
            "m": m ? m[1] : "0"
        };
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0 || isNaN(seconds))
            return "0:00";

        const totalSecs = Math.floor(seconds);
        const h = Math.floor(totalSecs / 3600);
        const m = Math.floor((totalSecs % 3600) / 60);
        const s = totalSecs % 60;
        const sStr = s < 10 ? "0" + s : s.toString();
        if (h > 0) {
            const mStr = m < 10 ? "0" + m : m.toString();
            return h + ":" + mStr + ":" + sStr;
        }
        return m + ":" + sStr;
    }

    function playIntro() {
        intro = true;
        introTimer.restart();
        introAnim.restart();
    }

    Component.onCompleted: playIntro()
    onVisibleChanged: {
        if (visible) {
            playIntro();
        }
    }

    // NEU: Wenn Download erfolgreich abgeschlossen → Library öffnen
    Connections {
        function onDownloadCompleted() {
            searchInput.text = "";
            root.searchQuery = "";
            JapaneseAudioState.clearSearch();
            root.filter = "library";
        }

        target: JapaneseAudioState
    }

    Timer {
        id: introTimer

        interval: 700
        onTriggered: root.intro = false
    }

    NumberAnimation {
        id: introAnim

        target: root
        property: "shown"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    MouseArea {
        anchors.fill: parent
        onClicked: JapaneseAudioState.close()
    }

    Item {
        id: panel

        width: root.panelWidth
        height: column.implicitHeight + 2 * root.pad
        x: (root.width - width) / 2
        y: Math.max(40, root.height * 0.12) + (1 - root.shown) * 24
        opacity: Math.min(1, root.shown * 1.6)
        scale: 0.95 + 0.05 * root.shown
        transformOrigin: Item.Top

        Repeater {
            model: 5

            Rectangle {
                readonly property real grow: (index + 1) * 6

                x: -grow
                y: -grow + 14
                width: panel.width + 2 * grow
                height: panel.height + 2 * grow
                radius: 28 + grow
                color: "#000000"
                opacity: 0.05
            }

        }

        Rectangle {
            anchors.fill: parent
            radius: 28
            color: WalColors.withAlpha(WalColors.color0, 0.97)
            border.width: 1
            border.color: WalColors.withAlpha(WalColors.color7, 0.09)
        }

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            x: root.pad
            y: root.pad
            width: root.innerWidth
            spacing: 0

            // ═══════════ Header ═══════════
            Item {
                id: header

                width: parent.width
                height: 44

                Rectangle {
                    id: searchBox

                    anchors.left: parent.left
                    anchors.right: segmented.left
                    anchors.rightMargin: 12
                    height: parent.height
                    radius: height / 2
                    color: WalColors.withAlpha(WalColors.color7, searchInput.activeFocus ? 0.09 : 0.06)
                    border.width: 1.5
                    border.color: searchInput.activeFocus ? WalColors.withAlpha(WalColors.color4, 0.55) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌕"
                        font.pixelSize: 20
                        color: searchInput.activeFocus ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.45)
                    }

                    TextInput {
                        id: searchInput

                        anchors.fill: parent
                        anchors.leftMargin: 48
                        anchors.rightMargin: 44
                        verticalAlignment: Text.AlignVCenter
                        font.family: root.mono
                        font.pixelSize: 14
                        color: WalColors.color7
                        selectionColor: WalColors.withAlpha(WalColors.color4, 0.4)
                        clip: true
                        text: root.searchQuery
                        onTextChanged: {
                            root.searchQuery = text;
                            if (text === "")
                                JapaneseAudioState.clearSearch();

                        }
                        onAccepted: {
                            if (text !== "")
                                JapaneseAudioState.downloadFromInput(text);

                        }
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                if (text !== "") {
                                    text = "";
                                    JapaneseAudioState.clearSearch();
                                } else {
                                    JapaneseAudioState.close();
                                }
                                event.accepted = true;
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Paste YouTube link or search..."
                        font.family: root.mono
                        font.pixelSize: 14
                        color: WalColors.withAlpha(WalColors.color7, 0.3)
                        opacity: searchInput.text === "" ? 1 : 0
                    }

                }

                Rectangle {
                    id: segmented

                    readonly property real segW: 80
                    readonly property int idx: root.filter === "library" ? 0 : 1

                    anchors.right: parent.right
                    width: segW * 2 + 8
                    height: parent.height
                    radius: height / 2
                    color: WalColors.withAlpha(WalColors.color7, 0.06)

                    Rectangle {
                        x: 4 + segmented.idx * segmented.segW
                        y: 4
                        width: segmented.segW
                        height: parent.height - 8
                        radius: height / 2
                        color: WalColors.withAlpha(WalColors.color7, 0.15)

                        Behavior on x {
                            Springy {
                            }

                        }

                    }

                    Row {
                        x: 4

                        Repeater {
                            model: [{
                                "label": "Library",
                                "key": "library"
                            }, {
                                "label": "Stats",
                                "key": "stats"
                            }]

                            delegate: Item {
                                readonly property bool active: root.filter === modelData.key

                                width: segmented.segW
                                height: segmented.height

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: root.mono
                                    font.pixelSize: 12
                                    font.bold: active
                                    color: active ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.5)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.filter = modelData.key
                                }

                            }

                        }

                    }

                }

            }

            // ═══════════ Download Card ═══════════
            Item {
                width: parent.width
                height: JapaneseAudioState.isDownloading ? 72 : 0
                clip: true
                visible: height > 0.5

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.bottomMargin: 4
                    radius: 14
                    color: WalColors.withAlpha(WalColors.color4, 0.06)
                    border.width: 1
                    border.color: WalColors.withAlpha(WalColors.color4, 0.18)
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.topMargin: 16
                    anchors.bottomMargin: 12
                    spacing: 12

                    // Statisches Download-Icon (kein Pulsieren mehr)
                    Item {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "⬇"
                            font.pixelSize: 20
                            font.bold: true
                            color: WalColors.color4
                        }

                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        spacing: 6

                        Row {
                            width: parent.width

                            Text {
                                width: parent.width - 56
                                text: JapaneseAudioState.downloadTitle
                                font.family: root.mono
                                font.pixelSize: 12
                                color: WalColors.color7
                                elide: Text.ElideRight
                            }

                            Text {
                                width: 48
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(JapaneseAudioState.downloadProgress * 100) + "%"
                                font.family: root.mono
                                font.pixelSize: 12
                                font.bold: true
                                color: WalColors.color4
                            }

                        }

                        Item {
                            width: parent.width
                            height: 4

                            Rectangle {
                                anchors.fill: parent
                                radius: 2
                                color: WalColors.withAlpha(WalColors.color7, 0.08)
                            }

                            Rectangle {
                                width: parent.width * JapaneseAudioState.downloadProgress
                                height: parent.height
                                radius: 2
                                color: WalColors.color4

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: WalColors.color4
                                    opacity: 0.5

                                    SequentialAnimation on scale {
                                        running: JapaneseAudioState.isDownloading
                                        loops: Animation.Infinite

                                        NumberAnimation {
                                            to: 1.6
                                            duration: 800
                                        }

                                        NumberAnimation {
                                            to: 1
                                            duration: 800
                                        }

                                    }

                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 200
                                    }

                                }

                            }

                        }

                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // ═══════════ Library View ═══════════
            Item {
                width: parent.width
                height: Math.min(entries.length * 80, 420) * root.libraryProgress
                opacity: root.libraryProgress
                visible: height > 0.5
                clip: true

                ListView {
                    id: list

                    width: parent.width
                    height: Math.min(entries.length * 80, 420)
                    model: entries
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    topMargin: 8

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: JapaneseAudioState.currentFile === modelData
                        readonly property bool isPlayingNow: isCurrent && JapaneseAudioState.isPlaying
                        readonly property real positionProgress: isCurrent && JapaneseAudioState.currentDuration > 0 ? JapaneseAudioState.currentPosition / JapaneseAudioState.currentDuration : 0

                        width: list.width
                        height: 74

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: WalColors.withAlpha(WalColors.color4, 0.13)
                            opacity: row.isCurrent ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 220
                                }

                            }

                            SequentialAnimation on color {
                                running: row.isPlayingNow
                                loops: Animation.Infinite

                                ColorAnimation {
                                    to: WalColors.withAlpha(WalColors.color4, 0.2)
                                    duration: 1800
                                    easing.type: Easing.InOutSine
                                }

                                ColorAnimation {
                                    to: WalColors.withAlpha(WalColors.color4, 0.13)
                                    duration: 1800
                                    easing.type: Easing.InOutSine
                                }

                            }

                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: WalColors.withAlpha(WalColors.color7, 0.04)
                            opacity: (rowMouse.containsMouse && !row.isCurrent) ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }

                            }

                        }

                        Rectangle {
                            width: 3
                            height: 40
                            radius: 2
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: WalColors.color4
                            opacity: row.isCurrent ? 1 : 0
                            scale: row.isPlayingNow ? 1 : 0.6

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                }

                            }

                            Behavior on scale {
                                Springy {
                                }

                            }

                        }

                        Rectangle {
                            id: playBtn

                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 38
                            radius: 12
                            color: row.isCurrent ? WalColors.withAlpha(WalColors.color4, 0.25) : WalColors.withAlpha(WalColors.color7, 0.07)

                            Row {
                                anchors.centerIn: parent
                                spacing: 2
                                visible: row.isPlayingNow

                                Repeater {
                                    model: 3

                                    delegate: Rectangle {
                                        width: 3
                                        height: 6
                                        radius: 1.5
                                        color: WalColors.color4

                                        SequentialAnimation on height {
                                            loops: Animation.Infinite

                                            NumberAnimation {
                                                to: [10, 16, 12][index]
                                                duration: 400 + index * 100
                                                easing.type: Easing.InOutSine
                                            }

                                            NumberAnimation {
                                                to: 6
                                                duration: 400 + index * 100
                                                easing.type: Easing.InOutSine
                                            }

                                        }

                                    }

                                }

                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !row.isPlayingNow
                                text: row.isCurrent && JapaneseAudioState.isPlaying ? "" : ""
                                font.family: root.mono
                                font.pixelSize: 16
                                color: row.isCurrent ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.55)
                            }

                        }

                        Column {
                            anchors.left: playBtn.right
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                width: parent.width
                                text: modelData.replace(".mp3", "")
                                font.family: root.mono
                                font.pixelSize: 13
                                font.bold: row.isCurrent
                                elide: Text.ElideRight
                                color: row.isCurrent ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.72)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }

                                }

                            }

                            Item {
                                width: parent.width
                                height: row.isCurrent ? 16 : 0
                                opacity: row.isCurrent ? 1 : 0
                                visible: opacity > 0

                                Row {
                                    id: timeLabels

                                    width: parent.width
                                    height: 12

                                    Text {
                                        text: root.formatTime(JapaneseAudioState.currentPosition)
                                        font.family: root.mono
                                        font.pixelSize: 10
                                        color: WalColors.withAlpha(WalColors.color7, 0.5)
                                    }

                                    Item {
                                        width: parent.width - 60
                                        height: 1
                                    }

                                    Text {
                                        text: root.formatTime(JapaneseAudioState.currentDuration)
                                        font.family: root.mono
                                        font.pixelSize: 10
                                        color: WalColors.withAlpha(WalColors.color7, 0.5)
                                    }

                                }

                                Item {
                                    id: seekBar

                                    anchors.top: timeLabels.bottom
                                    anchors.topMargin: 2
                                    width: parent.width
                                    height: 10
                                    z: 2

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 4
                                        radius: 2
                                        color: WalColors.withAlpha(WalColors.color7, 0.12)
                                    }

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width * row.positionProgress
                                        height: 4
                                        radius: 2
                                        color: WalColors.color4

                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: seekMouse.containsMouse ? 14 : 10
                                            height: width
                                            radius: width / 2
                                            color: WalColors.color4
                                            border.width: 2
                                            border.color: WalColors.withAlpha(WalColors.color0, 0.9)

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 150
                                                }

                                            }

                                        }

                                    }

                                    MouseArea {
                                        id: seekMouse

                                        anchors.fill: parent
                                        anchors.topMargin: -4
                                        anchors.bottomMargin: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            JapaneseAudioState.seekToFraction(mouse.x / width);
                                        }
                                    }

                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                    }

                                }

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 200
                                    }

                                }

                            }

                        }

                        MouseArea {
                            id: rowMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: JapaneseAudioState.play(modelData)
                        }

                    }

                }

            }

            // ═══════════ Search Results ═══════════
            Item {
                width: parent.width
                height: Math.min(results.length * 80, 420) * root.searchProgress
                opacity: root.searchProgress
                visible: height > 0.5
                clip: true

                Item {
                    width: parent.width
                    height: 24
                    y: 8

                    Text {
                        text: JapaneseAudioState.isSearching ? "Searching..." : "Search Results"
                        font.family: root.mono
                        font.pixelSize: 11
                        color: WalColors.withAlpha(WalColors.color7, 0.5)
                    }

                }

                ListView {
                    id: searchList

                    anchors.top: parent.top
                    anchors.topMargin: 32
                    width: parent.width
                    height: Math.min(results.length * 80, 380)
                    model: results
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: searchRow

                        required property var modelData

                        width: searchList.width
                        height: 74

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: searchMouse.containsMouse ? WalColors.withAlpha(WalColors.color7, 0.06) : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                        }

                        Image {
                            id: thumb

                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 96
                            height: 58
                            source: modelData.thumbnail
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "transparent"
                                border.width: 1
                                border.color: WalColors.withAlpha(WalColors.color7, 0.1)
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 4
                                width: durText.width + 8
                                height: 14
                                radius: 7
                                color: WalColors.withAlpha(WalColors.color0, 0.85)

                                Text {
                                    id: durText

                                    anchors.centerIn: parent
                                    text: modelData.duration
                                    font.family: root.mono
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: WalColors.color7
                                }

                            }

                        }

                        Column {
                            anchors.left: thumb.right
                            anchors.leftMargin: 12
                            anchors.right: dlBtn.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                width: parent.width
                                text: modelData.title
                                font.family: root.mono
                                font.pixelSize: 12
                                color: WalColors.color7
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                            }

                            Text {
                                width: parent.width
                                text: modelData.uploader
                                font.family: root.mono
                                font.pixelSize: 10
                                color: WalColors.withAlpha(WalColors.color7, 0.5)
                                elide: Text.ElideRight
                            }

                        }

                        Rectangle {
                            id: dlBtn

                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 36
                            radius: 10
                            color: JapaneseAudioState.isDownloading ? WalColors.withAlpha(WalColors.color7, 0.05) : (dlMouse.containsMouse ? WalColors.color4 : WalColors.withAlpha(WalColors.color4, 0.2))

                            Text {
                                anchors.centerIn: parent
                                text: "⬇"
                                font.pixelSize: 20
                                font.bold: true
                                color: JapaneseAudioState.isDownloading ? WalColors.withAlpha(WalColors.color7, 0.2) : (dlMouse.containsMouse ? WalColors.color0 : WalColors.color4)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }

                                }

                            }

                            MouseArea {
                                id: dlMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: JapaneseAudioState.isDownloading ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    if (!JapaneseAudioState.isDownloading)
                                        JapaneseAudioState.downloadVideo(modelData.url, modelData.title);

                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                        }

                        MouseArea {
                            id: searchMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                    }

                }

            }

            // ═══════════ Stats View ═══════════
            Item {
                width: parent.width
                height: 280 * root.statsProgress
                clip: true
                visible: height > 0.5

                Item {
                    id: statsContent

                    width: parent.width
                    height: 280
                    opacity: Math.min(1, root.statsProgress * 1.4)

                    Item {
                        id: tabBar

                        readonly property var tabs: [{
                            "key": "day",
                            "label": "Day"
                        }, {
                            "key": "week",
                            "label": "Week"
                        }, {
                            "key": "month",
                            "label": "Month"
                        }, {
                            "key": "year",
                            "label": "Year"
                        }]
                        readonly property int tabWidth: 52
                        readonly property int tabSpacing: 8
                        readonly property int activeIndex: {
                            for (let i = 0; i < tabs.length; ++i) if (tabs[i].key === root.activePeriod) {
                                return i;
                            }
                            return 0;
                        }
                        readonly property real slideTargetX: activeIndex * (tabWidth + tabSpacing) + (tabWidth / 2)

                        width: tabs.length * tabWidth + (tabs.length - 1) * tabSpacing
                        height: 32
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 16

                        Row {
                            anchors.fill: parent
                            spacing: tabBar.tabSpacing

                            Repeater {
                                model: tabBar.tabs

                                delegate: Item {
                                    id: tabItem

                                    readonly property bool active: root.activePeriod === modelData.key
                                    readonly property bool hovered: tabMouse.containsMouse && !active

                                    width: tabBar.tabWidth
                                    height: tabBar.height

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -2
                                        text: modelData.label
                                        color: tabItem.active ? WalColors.color4 : (tabItem.hovered ? WalColors.withAlpha(WalColors.color7, 0.9) : WalColors.withAlpha(WalColors.color7, 0.45))
                                        font.family: root.mono
                                        font.pixelSize: 11
                                        font.bold: tabItem.active

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }

                                        }

                                    }

                                    MouseArea {
                                        id: tabMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activePeriod = modelData.key
                                    }

                                }

                            }

                        }

                        Item {
                            id: trailGroup

                            width: 1
                            height: 1
                            x: tabBar.slideTargetX
                            y: tabBar.height - 2

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4
                                height: 4
                                radius: 2
                                x: -14
                                color: WalColors.color4

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        to: 0.2
                                        duration: 1200
                                        easing.type: Easing.InOutSine
                                    }

                                    NumberAnimation {
                                        to: 0.5
                                        duration: 1200
                                        easing.type: Easing.InOutSine
                                    }

                                }

                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4
                                height: 4
                                radius: 2
                                x: 10
                                color: WalColors.color4

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        to: 0.5
                                        duration: 1200
                                        easing.type: Easing.InOutSine
                                    }

                                    NumberAnimation {
                                        to: 0.2
                                        duration: 1200
                                        easing.type: Easing.InOutSine
                                    }

                                }

                            }

                            Rectangle {
                                id: trailCenter

                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                radius: 3
                                color: WalColors.color4

                                SequentialAnimation on scale {
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        to: 1.3
                                        duration: 900
                                        easing.type: Easing.InOutSine
                                    }

                                    NumberAnimation {
                                        to: 1
                                        duration: 900
                                        easing.type: Easing.InOutSine
                                    }

                                }

                            }

                            Rectangle {
                                anchors.centerIn: trailCenter
                                width: 14
                                height: 14
                                radius: 7
                                color: WalColors.color4
                                opacity: 0.25
                            }

                            Behavior on x {
                                NumberAnimation {
                                    duration: 320
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.15
                                }

                            }

                        }

                    }

                    Item {
                        anchors.top: tabBar.bottom
                        anchors.bottom: parent.bottom
                        width: parent.width

                        Column {
                            anchors.centerIn: parent
                            spacing: 14

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                Text {
                                    text: root.currentStats.h
                                    font.family: root.mono
                                    font.pixelSize: 64
                                    font.bold: true
                                    color: WalColors.color7
                                }

                                Text {
                                    text: "h"
                                    font.family: root.mono
                                    font.pixelSize: 24
                                    color: WalColors.withAlpha(WalColors.color7, 0.4)
                                    anchors.baseline: parent.children[0].baseline
                                }

                                Text {
                                    text: root.currentStats.m
                                    font.family: root.mono
                                    font.pixelSize: 64
                                    font.bold: true
                                    color: WalColors.color7
                                    anchors.leftMargin: 8
                                }

                                Text {
                                    text: "m"
                                    font.family: root.mono
                                    font.pixelSize: 24
                                    color: WalColors.withAlpha(WalColors.color7, 0.4)
                                    anchors.baseline: parent.children[2].baseline
                                }

                            }

                            Item {
                                width: 220
                                height: 6
                                anchors.horizontalCenter: parent.horizontalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    color: WalColors.withAlpha(WalColors.color7, 0.08)
                                }

                                Rectangle {
                                    width: parent.width * root.displayProgress
                                    height: parent.height
                                    radius: 3
                                    color: WalColors.color4

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: WalColors.color4
                                        opacity: 0.3

                                        SequentialAnimation on scale {
                                            loops: Animation.Infinite

                                            NumberAnimation {
                                                to: 1.5
                                                duration: 1500
                                                easing.type: Easing.InOutSine
                                            }

                                            NumberAnimation {
                                                to: 1
                                                duration: 1500
                                                easing.type: Easing.InOutSine
                                            }

                                        }

                                    }

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: WalColors.color7
                                    }

                                }

                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "TOTAL LISTENED"
                                font.family: root.mono
                                font.pixelSize: 10
                                font.letterSpacing: 2
                                color: WalColors.withAlpha(WalColors.color7, 0.5)
                            }

                        }

                    }

                    transform: Translate {
                        y: (1 - root.statsProgress) * -16
                    }

                }

            }

        }

    }

    Behavior on displayProgress {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutCubic
        }

    }

    Behavior on statsProgress {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutQuart
        }

    }

    Behavior on libraryProgress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.InCubic
        }

    }

    Behavior on searchProgress {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutQuart
        }

    }

    component Smooth: NumberAnimation {
        duration: 320
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    component Springy: SpringAnimation {
        spring: 5.5
        damping: 0.4
        epsilon: 0.2
    }

}
