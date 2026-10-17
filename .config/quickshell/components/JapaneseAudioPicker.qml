import "../components"
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    // ───────────────────────── Layout / state ─────────────────────────
    readonly property real pad: 16
    readonly property real panelWidth: Math.min(680, width - 48)
    readonly property real innerWidth: panelWidth - 2 * pad
    readonly property string mono: "JetBrainsMono Nerd Font"
    property string filter: "library"
    property string searchQuery: ""
    property bool intro: true
    property real shown: 0
    property string activePeriod: "day"
    readonly property bool isSearchMode: searchQuery !== "" && (JapaneseAudioState.isSearching || JapaneseAudioState.searchResults.length > 0)
    // ── aktuell spielende Datei immer ganz oben ──
    readonly property var entries: {
        const lib = JapaneseAudioState.library;
        const cur = JapaneseAudioState.currentFile;
        if (!cur || lib.length === 0)
            return lib;

        const idx = lib.indexOf(cur);
        if (idx <= 0)
            return lib;

        const out = [cur];
        for (let i = 0; i < lib.length; i++) {
            if (i !== idx)
                out.push(lib[i]);

        }
        return out;
    }
    readonly property var results: JapaneseAudioState.searchResults
    // ───────────────────────── Stats data ─────────────────────────
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
    readonly property string goalLabel: Math.round(maxMinutes / 60) + "h"
    readonly property real progress: Math.min(1, currentMinutes / maxMinutes)
    property real shownMinutes: currentMinutes
    property real displayProgress: progress
    readonly property real introK: stage(statsProgress, 0.1)
    readonly property real heroMinutes: shownMinutes * introK
    readonly property real heroProgress: displayProgress * introK
    readonly property var weekData: {
        const s = JapaneseAudioState.stats || ({
        });
        const out = [];
        for (let i = 6; i >= 0; i--) {
            const d = new Date();
            d.setDate(d.getDate() - i);
            out.push({
                "label": Qt.formatDate(d, "ddd"),
                "secs": s[Qt.formatDate(d, "yyyy-MM-dd")] || 0,
                "today": i === 0
            });
        }
        return out;
    }
    readonly property real weekMaxSecs: {
        let m = 1;
        for (let i = 0; i < weekData.length; i++) m = Math.max(m, weekData[i].secs)
        return m;
    }
    readonly property real weekAvgMinutes: {
        let t = 0;
        for (let i = 0; i < weekData.length; i++) t += weekData[i].secs
        return t / 7 / 60;
    }
    readonly property int streak: {
        const s = JapaneseAudioState.stats || ({
        });
        let n = 0;
        for (let i = 0; i < 3650; i++) {
            const d = new Date();
            d.setDate(d.getDate() - i);
            const v = s[Qt.formatDate(d, "yyyy-MM-dd")] || 0;
            if (v > 0)
                n++;
            else if (i > 0)
                break;
        }
        return n;
    }
    // ───────────────────────── Body sizing ─────────────────────────
    readonly property real libH: entries.length > 0 ? Math.min(entries.length * 80 + 8, 420) : 84
    readonly property real searchH: Math.min(results.length * 80, 380) + 32
    readonly property real statsH: 336
    readonly property real bodyTarget: filter === "stats" ? statsH : (isSearchMode ? searchH : libH)
    property real bodyH: bodyTarget
    property real statsProgress: filter === "stats" ? 1 : 0
    property real libraryProgress: (filter === "library" && !isSearchMode) ? 1 : 0
    property real searchProgress: (filter === "library" && isSearchMode) ? 1 : 0
    readonly property bool showDl: JapaneseAudioState.isDownloading || JapaneseAudioState.downloadError !== ""

    // ───────────────────────── Helpers ─────────────────────────
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

    function formatMinutes(mins) {
        const t = Math.round(mins);
        if (t < 60)
            return t + "m";

        return Math.floor(t / 60) + "h " + (t % 60) + "m";
    }

    function stage(p, d) {
        return Math.max(0, Math.min(1, (p - d) / (1 - d)));
    }

    function playIntro() {
        intro = true;
        introTimer.restart();
        introAnim.restart();
    }

    Component.onCompleted: playIntro()
    onVisibleChanged: {
        if (visible)
            playIntro();

    }

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

    // ═════════════════════════ Panel ═════════════════════════
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

            // ═══════════ Download card ═══════════
            Item {
                id: dlCard

                readonly property bool failed: JapaneseAudioState.downloadError !== "" && !JapaneseAudioState.isDownloading
                readonly property bool converting: JapaneseAudioState.isConverting
                readonly property bool waiting: JapaneseAudioState.isDownloading && (converting || JapaneseAudioState.downloadProgress < 0.005)
                readonly property color accent: failed ? WalColors.color1 : WalColors.color4
                readonly property color accentDark: Qt.darker(accent, 1.25)
                readonly property color accentLight: Qt.lighter(accent, 1.45)
                readonly property color sheenColor: Qt.lighter(accent, 1.9)
                property real dlValue: JapaneseAudioState.downloadProgress

                function tint(a) {
                    return failed ? WalColors.withAlpha(WalColors.color1, a) : WalColors.withAlpha(WalColors.color4, a);
                }

                width: parent.width
                height: root.showDl ? 92 : 0
                opacity: root.showDl ? 1 : 0
                visible: height > 0.5
                clip: true

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 10
                    anchors.bottomMargin: 4
                    radius: 18
                    color: dlCard.tint(0.08)
                    border.width: 1
                    border.color: dlCard.tint(0.22)
                }

                Item {
                    anchors.fill: parent
                    anchors.topMargin: 10
                    anchors.bottomMargin: 4

                    Rectangle {
                        anchors.centerIn: dlRingBox
                        width: 56
                        height: 56
                        radius: 28
                        color: dlCard.tint(0.13)
                        opacity: JapaneseAudioState.isDownloading ? 1 : 0

                        SequentialAnimation on scale {
                            running: JapaneseAudioState.isDownloading
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 1.2
                                duration: 1100
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 0.95
                                duration: 1100
                                easing.type: Easing.InOutSine
                            }

                        }

                    }

                    Item {
                        id: dlRingBox

                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 54
                        height: 54

                        Ring {
                            anchors.fill: parent
                            thickness: 4
                            color: dlCard.accent
                            trackColor: dlCard.tint(0.16)
                            value: dlCard.failed ? 1 : dlCard.dlValue
                            spinning: dlCard.waiting
                        }

                        Text {
                            anchors.centerIn: parent
                            text: dlCard.failed ? "!" : (dlCard.converting ? "mp3" : Math.round(dlCard.dlValue * 100) + "%")
                            font.family: root.mono
                            font.pixelSize: dlCard.converting ? 11 : 13
                            font.bold: true
                            color: dlCard.accent
                        }

                    }

                    Column {
                        anchors.left: dlRingBox.right
                        anchors.leftMargin: 16
                        anchors.right: parent.right
                        anchors.rightMargin: JapaneseAudioState.isDownloading ? 44 : 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            text: dlCard.failed ? "DOWNLOAD FAILED" : (dlCard.converting ? "CONVERTING TO MP3" : "DOWNLOADING")
                            font.family: root.mono
                            font.pixelSize: 9
                            font.letterSpacing: 2
                            font.bold: true
                            color: dlCard.accent
                        }

                        Text {
                            width: parent.width
                            text: dlCard.failed ? JapaneseAudioState.downloadError : JapaneseAudioState.downloadTitle
                            font.family: root.mono
                            font.pixelSize: dlCard.failed ? 11 : 13
                            color: WalColors.withAlpha(WalColors.color7, dlCard.failed ? 0.65 : 0.85)
                            wrapMode: dlCard.failed ? Text.Wrap : Text.NoWrap
                            elide: Text.ElideRight
                            maximumLineCount: dlCard.failed ? 3 : 1
                        }

                        Item {
                            width: parent.width
                            height: 6
                            visible: !dlCard.failed

                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: dlCard.tint(0.14)
                            }

                            Item {
                                id: fillClip

                                width: dlCard.converting ? parent.width : parent.width * dlCard.dlValue
                                height: parent.height
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3

                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal

                                        GradientStop {
                                            position: 0
                                            color: dlCard.accentDark
                                        }

                                        GradientStop {
                                            position: 1
                                            color: dlCard.accentLight
                                        }

                                    }

                                }

                                Rectangle {
                                    id: sheen

                                    width: 70
                                    height: parent.height
                                    x: -width

                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal

                                        GradientStop {
                                            position: 0
                                            color: Qt.rgba(dlCard.sheenColor.r, dlCard.sheenColor.g, dlCard.sheenColor.b, 0)
                                        }

                                        GradientStop {
                                            position: 0.5
                                            color: Qt.rgba(dlCard.sheenColor.r, dlCard.sheenColor.g, dlCard.sheenColor.b, 0.7)
                                        }

                                        GradientStop {
                                            position: 1
                                            color: Qt.rgba(dlCard.sheenColor.r, dlCard.sheenColor.g, dlCard.sheenColor.b, 0)
                                        }

                                    }

                                    SequentialAnimation on x {
                                        running: JapaneseAudioState.isDownloading
                                        loops: Animation.Infinite

                                        NumberAnimation {
                                            from: -70
                                            to: Math.max(fillClip.width, 70)
                                            duration: dlCard.converting ? 900 : 1500
                                            easing.type: Easing.InOutSine
                                        }

                                        PauseAnimation {
                                            duration: 250
                                        }

                                    }

                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                        }

                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        width: 22
                        height: 22
                        radius: 11
                        color: cancelArea.containsMouse ? WalColors.withAlpha(WalColors.color1, 0.9) : WalColors.withAlpha(WalColors.color4, 0.15)
                        opacity: JapaneseAudioState.isDownloading ? 1 : 0
                        visible: opacity > 0.01
                        scale: cancelArea.pressed ? 0.9 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 9
                            color: cancelArea.containsMouse ? WalColors.color0 : WalColors.withAlpha(WalColors.color7, 0.6)
                        }

                        MouseArea {
                            id: cancelArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: JapaneseAudioState.cancelDownload()
                        }

                        Behavior on scale {
                            Springy {
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }

                        }

                    }

                }

                Behavior on height {
                    Smooth {
                    }

                }

                Behavior on opacity {
                    Smooth {
                        duration: 220
                    }

                }

                Behavior on dlValue {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // ═══════════ Body ═══════════
            Item {
                id: body

                width: parent.width
                height: root.bodyH
                clip: true

                // ───────── Library ─────────
                Item {
                    id: libView

                    width: parent.width
                    height: root.libH
                    opacity: root.libraryProgress
                    visible: opacity > 0.01

                    ListView {
                        id: list

                        width: parent.width
                        height: parent.height
                        model: root.entries
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        topMargin: 8
                        clip: true

                        delegate: Item {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property bool isCurrent: JapaneseAudioState.currentFile === modelData
                            readonly property bool isPlayingNow: isCurrent && JapaneseAudioState.isPlaying
                            readonly property real positionProgress: isCurrent && JapaneseAudioState.currentDuration > 0 ? Math.min(1, JapaneseAudioState.currentPosition / JapaneseAudioState.currentDuration) : 0
                            // ── Entrance animation ──
                            property real enter: 1

                            width: list.width
                            height: 74
                            opacity: enter
                            Component.onCompleted: {
                                if (root.intro) {
                                    enter = 0;
                                    rowEnter.start();
                                }
                            }

                            SequentialAnimation {
                                id: rowEnter

                                PauseAnimation {
                                    duration: Math.min(row.index, 9) * 30 + 60
                                }

                                NumberAnimation {
                                    target: row
                                    property: "enter"
                                    to: 1
                                    duration: 460
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                                }

                            }

                            // Current-row background
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

                            }

                            // Hover background
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

                            // Accent bar
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

                            // Play button
                            Item {
                                id: playBtn

                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                width: 42
                                height: 42

                                Rectangle {
                                    id: ping

                                    anchors.centerIn: parent
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: WalColors.color4
                                    opacity: 0
                                    visible: row.isPlayingNow

                                    ParallelAnimation {
                                        running: row.isPlayingNow
                                        loops: Animation.Infinite

                                        NumberAnimation {
                                            target: ping
                                            property: "scale"
                                            from: 1
                                            to: 1.55
                                            duration: 1800
                                            easing.type: Easing.OutCubic
                                        }

                                        NumberAnimation {
                                            target: ping
                                            property: "opacity"
                                            from: 0.5
                                            to: 0
                                            duration: 1800
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: row.isCurrent ? WalColors.withAlpha(WalColors.color4, 0.22) : WalColors.withAlpha(WalColors.color7, 0.07)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }

                                    }

                                }

                                Ring {
                                    anchors.fill: parent
                                    thickness: 2.5
                                    color: WalColors.color4
                                    trackColor: WalColors.withAlpha(WalColors.color7, 0.08)
                                    value: row.positionProgress
                                    opacity: row.isCurrent ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }

                                    }

                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    opacity: row.isPlayingNow ? 1 : 0
                                    scale: row.isPlayingNow ? 1 : 0.6

                                    Rectangle {
                                        width: 3.5
                                        height: 12
                                        radius: 1.5
                                        color: WalColors.color4
                                    }

                                    Rectangle {
                                        width: 3.5
                                        height: 12
                                        radius: 1.5
                                        color: WalColors.color4
                                    }

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 160
                                        }

                                    }

                                    Behavior on scale {
                                        Springy {
                                        }

                                    }

                                }

                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 1
                                    text: "▶"
                                    font.pixelSize: 12
                                    color: row.isCurrent ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.55)
                                    opacity: row.isPlayingNow ? 0 : 1
                                    scale: row.isPlayingNow ? 0.6 : 1

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 160
                                        }

                                    }

                                    Behavior on scale {
                                        Springy {
                                        }

                                    }

                                }

                            }

                            MouseArea {
                                id: rowMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: JapaneseAudioState.play(row.modelData)
                            }

                            Row {
                                id: skipRow

                                z: 2
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                opacity: row.isCurrent ? 1 : 0
                                visible: opacity > 0.01

                                SkipBtn {
                                    label: "‹10"
                                    onClicked: JapaneseAudioState.seekRelative(-10)
                                }

                                SkipBtn {
                                    label: "10›"
                                    onClicked: JapaneseAudioState.seekRelative(10)
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                    }

                                }

                            }

                            Column {
                                z: 2
                                anchors.left: playBtn.right
                                anchors.leftMargin: 14
                                anchors.right: parent.right
                                anchors.rightMargin: row.isCurrent ? skipRow.width + 24 : 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    width: parent.width
                                    text: row.modelData.replace(".mp3", "")
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
                                    height: row.isCurrent ? 30 : 0
                                    opacity: row.isCurrent ? 1 : 0
                                    visible: opacity > 0.01

                                    Item {
                                        id: seekBar

                                        readonly property bool hovered: seekMouse.containsMouse
                                        readonly property bool dragging: seekMouse.pressed
                                        property real dragFrac: 0
                                        readonly property real frac: dragging ? dragFrac : row.positionProgress

                                        width: parent.width
                                        height: 14

                                        Rectangle {
                                            id: track

                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width
                                            height: (seekBar.hovered || seekBar.dragging) ? 6 : 4
                                            radius: height / 2
                                            color: WalColors.withAlpha(WalColors.color7, 0.12)

                                            Behavior on height {
                                                NumberAnimation {
                                                    duration: 120
                                                }

                                            }

                                        }

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width * seekBar.frac
                                            height: track.height
                                            radius: height / 2
                                            color: WalColors.color4
                                        }

                                        Rectangle {
                                            id: handle

                                            x: seekBar.width * seekBar.frac - width / 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: seekBar.dragging ? 16 : (seekBar.hovered ? 13 : 10)
                                            height: width
                                            radius: width / 2
                                            color: WalColors.color4
                                            border.width: 2
                                            border.color: WalColors.withAlpha(WalColors.color0, 0.9)

                                            Behavior on width {
                                                Springy {
                                                }

                                            }

                                        }

                                        Rectangle {
                                            x: Math.max(0, Math.min(seekBar.width - width, seekBar.width * seekBar.frac - width / 2))
                                            y: -26
                                            width: bubbleText.implicitWidth + 14
                                            height: 20
                                            radius: 10
                                            color: WalColors.color4
                                            opacity: seekBar.dragging ? 1 : 0
                                            scale: seekBar.dragging ? 1 : 0.7
                                            visible: opacity > 0.01

                                            Text {
                                                id: bubbleText

                                                anchors.centerIn: parent
                                                text: root.formatTime(seekBar.dragFrac * JapaneseAudioState.currentDuration)
                                                font.family: root.mono
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: WalColors.color0
                                            }

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 120
                                                }

                                            }

                                            Behavior on scale {
                                                Springy {
                                                }

                                            }

                                        }

                                        MouseArea {
                                            id: seekMouse

                                            anchors.fill: parent
                                            anchors.topMargin: -6
                                            anchors.bottomMargin: -6
                                            hoverEnabled: true
                                            preventStealing: true
                                            cursorShape: Qt.PointingHandCursor
                                            onPressed: (mouse) => {
                                                seekBar.dragFrac = Math.max(0, Math.min(1, mouse.x / width));
                                            }
                                            onPositionChanged: (mouse) => {
                                                if (pressed)
                                                    seekBar.dragFrac = Math.max(0, Math.min(1, mouse.x / width));

                                            }
                                            onReleased: JapaneseAudioState.seekToFraction(seekBar.dragFrac)
                                        }

                                    }

                                    Item {
                                        anchors.top: seekBar.bottom
                                        anchors.topMargin: 2
                                        width: parent.width
                                        height: 12

                                        Text {
                                            anchors.left: parent.left
                                            text: root.formatTime(seekBar.dragging ? seekBar.dragFrac * JapaneseAudioState.currentDuration : JapaneseAudioState.currentPosition)
                                            font.family: root.mono
                                            font.pixelSize: 10
                                            color: seekBar.dragging ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.5)
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            text: root.formatTime(JapaneseAudioState.currentDuration)
                                            font.family: root.mono
                                            font.pixelSize: 10
                                            color: WalColors.withAlpha(WalColors.color7, 0.5)
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

                            Behavior on anchors.rightMargin {
                                Smooth {
                                    duration: 240
                                }

                            }

                            transform: Translate {
                                y: (1 - row.enter) * 12
                            }

                        }

                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.entries.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: "No audios yet\nPaste a YouTube link above and press Enter"
                        font.family: root.mono
                        font.pixelSize: 12
                        lineHeight: 1.4
                        color: WalColors.withAlpha(WalColors.color7, 0.35)
                    }

                    transform: Translate {
                        y: (1 - root.libraryProgress) * 8
                    }

                }

                // ───────── Search results ─────────
                Item {
                    id: searchView

                    width: parent.width
                    height: root.searchH
                    opacity: root.searchProgress
                    visible: opacity > 0.01

                    Text {
                        y: 10
                        text: JapaneseAudioState.isSearching ? "Searching..." : "Search Results"
                        font.family: root.mono
                        font.pixelSize: 11
                        color: WalColors.withAlpha(WalColors.color7, 0.5)
                    }

                    ListView {
                        id: searchList

                        anchors.top: parent.top
                        anchors.topMargin: 32
                        width: parent.width
                        height: Math.min(root.results.length * 80, 380)
                        model: root.results
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

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
                                source: searchRow.modelData.thumbnail
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
                                        text: searchRow.modelData.duration
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
                                    text: searchRow.modelData.title
                                    font.family: root.mono
                                    font.pixelSize: 12
                                    color: WalColors.color7
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }

                                Text {
                                    width: parent.width
                                    text: searchRow.modelData.uploader
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
                                            JapaneseAudioState.downloadVideo(searchRow.modelData.url, searchRow.modelData.title);

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

                    transform: Translate {
                        y: (1 - root.searchProgress) * 8
                    }

                }

                // ───────── Stats ─────────
                Item {
                    id: statsView

                    width: parent.width
                    height: root.statsH
                    opacity: Math.min(1, root.statsProgress * 2.5)
                    visible: opacity > 0.01

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
                        readonly property real st: root.stage(root.statsProgress, 0)

                        width: tabs.length * tabWidth + (tabs.length - 1) * tabSpacing
                        height: 32
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 16
                        opacity: st

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

                        transform: Translate {
                            y: (1 - tabBar.st) * -10
                        }

                    }

                    Row {
                        id: hero

                        readonly property real st: root.stage(root.statsProgress, 0.12)

                        anchors.top: tabBar.bottom
                        anchors.topMargin: 18
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 40
                        opacity: st

                        Item {
                            width: 156
                            height: 156

                            Ring {
                                anchors.fill: parent
                                thickness: 9
                                color: WalColors.color4
                                trackColor: WalColors.withAlpha(WalColors.color7, 0.08)
                                value: root.heroProgress
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 3

                                    Text {
                                        id: hTxt

                                        text: Math.floor(root.heroMinutes / 60)
                                        font.family: root.mono
                                        font.pixelSize: 34
                                        font.bold: true
                                        color: WalColors.color7
                                    }

                                    Text {
                                        anchors.baseline: hTxt.baseline
                                        text: "h"
                                        font.family: root.mono
                                        font.pixelSize: 13
                                        color: WalColors.withAlpha(WalColors.color7, 0.4)
                                    }

                                    Text {
                                        id: mTxt

                                        leftPadding: 6
                                        text: Math.floor(root.heroMinutes % 60)
                                        font.family: root.mono
                                        font.pixelSize: 34
                                        font.bold: true
                                        color: WalColors.color7
                                    }

                                    Text {
                                        anchors.baseline: mTxt.baseline
                                        text: "m"
                                        font.family: root.mono
                                        font.pixelSize: 13
                                        color: WalColors.withAlpha(WalColors.color7, 0.4)
                                    }

                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.progress >= 1 ? "GOAL REACHED" : "OF " + root.goalLabel + " GOAL"
                                    font.family: root.mono
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.5
                                    font.bold: root.progress >= 1
                                    color: root.progress >= 1 ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.45)
                                }

                            }

                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            StatTile {
                                label: "STREAK"
                                value: root.streak + (root.streak === 1 ? " day" : " days")
                            }

                            StatTile {
                                label: "7-DAY AVERAGE"
                                value: root.formatMinutes(root.weekAvgMinutes) + " / day"
                            }

                        }

                        transform: Translate {
                            y: (1 - hero.st) * 16
                        }

                    }

                    Item {
                        id: chart

                        readonly property real colW: (width - 6 * 10) / 7
                        readonly property real st: root.stage(root.statsProgress, 0.3)

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        height: 84
                        opacity: st

                        Row {
                            spacing: 10

                            Repeater {
                                model: root.weekData

                                delegate: Item {
                                    id: dayCol

                                    required property var modelData
                                    required property int index
                                    readonly property bool hovered: dayMouse.containsMouse
                                    property real g: root.filter === "stats" ? 1 : 0

                                    width: chart.colW
                                    height: chart.height

                                    Rectangle {
                                        id: bar

                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: dayLabel.top
                                        anchors.bottomMargin: 6
                                        width: Math.min(34, dayCol.width - 10)
                                        height: Math.max(4, (dayCol.modelData.secs / root.weekMaxSecs) * 50) * dayCol.g
                                        radius: Math.min(8, height / 2)
                                        color: dayCol.modelData.today ? WalColors.color4 : WalColors.withAlpha(WalColors.color4, dayCol.hovered ? 0.55 : 0.28)

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }

                                        }

                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: bar.top
                                        anchors.bottomMargin: 4
                                        text: dayCol.modelData.secs > 0 ? root.formatMinutes(dayCol.modelData.secs / 60) : "–"
                                        font.family: root.mono
                                        font.pixelSize: 9
                                        color: WalColors.withAlpha(WalColors.color7, 0.7)
                                        opacity: dayCol.hovered ? 1 : 0

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 120
                                            }

                                        }

                                    }

                                    Text {
                                        id: dayLabel

                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        text: dayCol.modelData.label
                                        font.family: root.mono
                                        font.pixelSize: 10
                                        font.bold: dayCol.modelData.today
                                        color: dayCol.modelData.today ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.4)
                                    }

                                    MouseArea {
                                        id: dayMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    Behavior on g {
                                        SequentialAnimation {
                                            PauseAnimation {
                                                duration: root.filter === "stats" ? 260 + dayCol.index * 55 : 0
                                            }

                                            NumberAnimation {
                                                duration: root.filter === "stats" ? 600 : 150
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 1.1
                                            }

                                        }

                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

    }

    // ───────────────────────── Behaviors ─────────────────────────
    Behavior on bodyH {
        Smooth {
            duration: 420
        }

    }

    Behavior on displayProgress {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutCubic
        }

    }

    Behavior on shownMinutes {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutCubic
        }

    }

    Behavior on statsProgress {
        NumberAnimation {
            duration: root.filter === "stats" ? 760 : 200
            easing.type: root.filter === "stats" ? Easing.OutCubic : Easing.InCubic
        }

    }

    Behavior on libraryProgress {
        NumberAnimation {
            duration: (root.filter === "library" && !root.isSearchMode) ? 380 : 160
            easing.type: Easing.OutCubic
        }

    }

    Behavior on searchProgress {
        NumberAnimation {
            duration: (root.filter === "library" && root.isSearchMode) ? 380 : 160
            easing.type: Easing.OutCubic
        }

    }

    // ───────────────────────── Reusable components ─────────────────────────
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

    component Ring: Item {
        id: ring

        property real value: 0
        property real thickness: 4
        property color color: WalColors.color4
        property color trackColor: WalColors.withAlpha(WalColors.color7, 0.1)
        property bool spinning: false
        property real spin: 0
        readonly property real r: (Math.min(width, height) - thickness) / 2

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                strokeColor: ring.trackColor
                strokeWidth: ring.thickness
                fillColor: "transparent"

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.r
                    radiusY: ring.r
                    startAngle: -90
                    sweepAngle: 360
                }

            }

            ShapePath {
                strokeColor: (ring.value > 0.002 || ring.spinning) ? ring.color : "transparent"
                strokeWidth: ring.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.r
                    radiusY: ring.r
                    startAngle: -90 + (ring.spinning ? ring.spin : 0)
                    sweepAngle: ring.spinning ? 100 : 360 * Math.min(1, ring.value)
                }

            }

        }

        NumberAnimation on spin {
            running: ring.spinning
            from: 0
            to: 360
            duration: 1100
            loops: Animation.Infinite
        }

    }

    component SkipBtn: Rectangle {
        id: skip

        property string label: ""

        signal clicked()

        width: 36
        height: 26
        radius: 13
        color: skipArea.containsMouse ? WalColors.withAlpha(WalColors.color4, 0.25) : WalColors.withAlpha(WalColors.color7, 0.07)
        scale: skipArea.pressed ? 0.92 : 1

        Text {
            anchors.centerIn: parent
            text: skip.label
            font.family: root.mono
            font.pixelSize: 10
            font.bold: true
            color: skipArea.containsMouse ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.6)
        }

        MouseArea {
            id: skipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: skip.clicked()
        }

        Behavior on scale {
            Springy {
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }

        }

    }

    component StatTile: Rectangle {
        id: tile

        property string label: ""
        property string value: ""

        width: 190
        height: 68
        radius: 16
        color: WalColors.withAlpha(WalColors.color7, 0.05)
        border.width: 1
        border.color: WalColors.withAlpha(WalColors.color7, 0.06)

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                text: tile.label
                font.family: root.mono
                font.pixelSize: 9
                font.letterSpacing: 1.5
                color: WalColors.withAlpha(WalColors.color7, 0.45)
            }

            Text {
                text: tile.value
                font.family: root.mono
                font.pixelSize: 17
                font.bold: true
                color: WalColors.color7
            }

        }

    }

}
