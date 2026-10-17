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
    property int selectedIndex: 0
    property bool intro: true
    property real shown: 0
    // --- Stats State ---
    property string activePeriod: "day"
    readonly property var currentStats: parseTime(JapaneseAudioState.getStatsForPeriod(activePeriod))
    readonly property real currentMinutes: (parseInt(currentStats.h) * 60) + parseInt(currentStats.m)
    // Maximalwerte für den Fortschrittsbalken (anpassbar)
    readonly property real maxMinutes: {
        switch (activePeriod) {
        case "day":
            return 60; // 1 Stunde pro Tag
        case "week":
            return 300; // 5 Stunden pro Woche
        case "month":
            return 1200; // 20 Stunden pro Monat
        case "year":
            return 14400; // 240 Stunden pro Jahr
        }
        return 60;
    }
    readonly property real progress: Math.min(1, currentMinutes / maxMinutes)
    property real displayProgress: progress
    // --- Animations Progress (Unfold) ---
    property real statsProgress: filter === "stats" ? 1 : 0
    property real libraryProgress: filter === "library" ? 1 : 0
    readonly property var entries: JapaneseAudioState.library

    // Parst "Xh Ym" in ein Objekt
    function parseTime(str) {
        const h = str.match(/(\d+)h/);
        const m = str.match(/(\d+)m/);
        return {
            "h": h ? h[1] : "0",
            "m": m ? m[1] : "0"
        };
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

            // ───────────── Header ─────────────
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
                        onAccepted: {
                            if (text !== "") {
                                JapaneseAudioState.searchAndDownload(text);
                                text = "";
                            }
                        }
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                if (text !== "")
                                    text = "";
                                else
                                    JapaneseAudioState.close();
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

            // Status Text
            Item {
                width: parent.width
                height: JapaneseAudioState.statusText !== "" ? 30 : 0
                opacity: JapaneseAudioState.statusText !== "" ? 1 : 0
                visible: height > 0
                clip: true

                Text {
                    anchors.centerIn: parent
                    text: JapaneseAudioState.statusText
                    font.family: root.mono
                    font.pixelSize: 12
                    color: WalColors.color4
                }

                Behavior on height {
                    Smooth {
                    }

                }

                Behavior on opacity {
                    Smooth {
                    }

                }

            }

            // ───────────── Library View ─────────────
            Item {
                width: parent.width
                height: Math.min(entries.length * 52, 400) * root.libraryProgress
                opacity: root.libraryProgress
                visible: height > 0.5
                clip: true

                ListView {
                    id: list

                    width: parent.width
                    height: Math.min(entries.length * 52, 400)
                    model: entries
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: JapaneseAudioState.currentFile === modelData

                        width: list.width
                        height: 52

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: row.isCurrent ? WalColors.withAlpha(WalColors.color4, 0.13) : "transparent"

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: playBtn.left
                                anchors.rightMargin: 10
                                text: modelData.replace(".mp3", "")
                                font.family: root.mono
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                color: row.isCurrent ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.72)
                            }

                            Rectangle {
                                id: playBtn

                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                height: 34
                                radius: 11
                                color: row.isCurrent ? WalColors.withAlpha(WalColors.color4, 0.2) : WalColors.withAlpha(WalColors.color7, 0.07)

                                Text {
                                    anchors.centerIn: parent
                                    text: (row.isCurrent && JapaneseAudioState.isPlaying) ? "" : ""
                                    font.family: root.mono
                                    font.pixelSize: 14
                                    color: row.isCurrent ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.5)
                                }

                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: JapaneseAudioState.play(modelData)
                            }

                        }

                    }

                }

            }

            // ───────────── Stats View (Minimalist & Sleek) ─────────────
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

                    // ---------- Tab-Switcher (Unverändert) ----------
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

                        // 3-Dot-Trail
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

                    // ---------- NEUE MINIMALISTISCHE STATISTIK ----------
                    Item {
                        anchors.top: tabBar.bottom
                        anchors.bottom: parent.bottom
                        width: parent.width

                        Column {
                            anchors.centerIn: parent
                            spacing: 14

                            // Grosse Typografie
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

                            // Sleeker, glühender Fortschrittsbalken
                            Item {
                                width: 220
                                height: 6
                                anchors.horizontalCenter: parent.horizontalCenter

                                // Hintergrund
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    color: WalColors.withAlpha(WalColors.color7, 0.08)
                                }

                                // Füllung
                                Rectangle {
                                    width: parent.width * root.displayProgress
                                    height: parent.height
                                    radius: 3
                                    color: WalColors.color4

                                    // Glühende Spitze
                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: WalColors.color4
                                        opacity: 0.3

                                        // Pulsieren der Spitze
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

                                    // Harter Kern der Spitze
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

                            // Subtiler Text
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
