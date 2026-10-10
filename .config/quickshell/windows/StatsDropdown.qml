import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
    // ===== Animierte Werte (mit Behavior) =====

    id: dropdown

    // Oeffnen: Hoehen-Animation wie bisher (Behavior on height).
    // Schliessen: Huelle bleibt an der Bar haengen und schrumpft von unten
    // nach oben (Fenster behaelt seine Groesse), nur der Ring blendet aus.
    // Erst danach wird die Hoehe ohne Animation auf 0 gesetzt.
    property bool expanded: false
    property bool heightAnimOn: false
    property real closeFactor: 1
    required property var screen
    readonly property real cornerRadius: 20
    readonly property real menuWidth: 275
    readonly property real edgePadding: 8
    readonly property real ringSize: 180
    readonly property real ringThickness: 8
    property string activeMetric: "cpu"
    readonly property real fullHeight: content.implicitHeight + 24
    readonly property int activePercent: usagePercent(activeMetric)
    readonly property real ringProgress: activePercent / 100
    readonly property color ringColor: {
        const t = tempCelsius(activeMetric);
        if (t >= 80)
            return WalColors.color1;

        if (t >= 65)
            return WalColors.color3;

        return WalColors.color4;
    }
    // Die angezeigte Prozentzahl folgt activePercent smooth.
    // Dadurch "rollt" die Zahl beim Wechsel und beim Live-Update.
    property real displayPercent: activePercent
    // Der angezeigte Ring-Fortschritt folgt ringProgress smooth.
    property real displayProgress: ringProgress
    // Die Ring-Farbe morphen smooth (z.B. rot <-> blau bei Temp-Wechsel).
    property color displayRingColor: ringColor
    // Tip-Position basierend auf dem animierten Fortschritt,
    // damit der Punkt mit dem Bogen mitwandert.
    readonly property real displayTipAngleRad: (-90 + 360 * displayProgress) * Math.PI / 180
    readonly property real displayTipRadius: ringSize / 2 - ringThickness / 2
    readonly property real displayTipX: ringSize / 2 + displayTipRadius * Math.cos(displayTipAngleRad)
    readonly property real displayTipY: ringSize / 2 + displayTipRadius * Math.sin(displayTipAngleRad)

    function numFrom(s) {
        if (s === undefined || s === null)
            return 0;

        const m = String(s).match(/(-?\d+(?:\.\d+)?)/);
        return m ? parseFloat(m[1]) : 0;
    }

    function fmtSize(gb, unit) {
        let num;
        let suffix;
        if (unit === "TB") {
            num = (gb / 1024).toFixed(2);
            suffix = "TB";
        } else {
            num = gb.toFixed(1);
            suffix = "GB";
        }
        num = num.replace(/\.?0+$/, "");
        return num + suffix;
    }

    function parseMemory(s, unit) {
        unit = unit || "GB";
        const empty = {
            "text": "",
            "used": 0,
            "total": 0,
            "ratio": 0
        };
        if (s === undefined || s === null)
            return empty;

        let str = String(s).trim();
        str = str.replace(/[\(\[]?\s*\d+(?:\.\d+)?\s*%\s*[\)\]]?/g, " ").trim();
        const values = [];
        const re = /(\d+(?:\.\d+)?)\s*(GB|MB|GIB|MIB|TB|TIB|G|M|T)?/gi;
        let m;
        while ((m = re.exec(str)) !== null) {
            const val = parseFloat(m[1]);
            const u = (m[2] || "GB").toUpperCase();
            let gb = val;
            if (u.indexOf("M") === 0)
                gb = val / 1024;
            else if (u.indexOf("T") === 0)
                gb = val * 1024;
            values.push(gb);
        }
        if (values.length >= 2) {
            const used = values[0];
            const total = values[1];
            return {
                "text": fmtSize(used, unit) + " / " + fmtSize(total, unit),
                "used": used,
                "total": total,
                "ratio": total > 0 ? Math.max(0, Math.min(1, used / total)) : 0
            };
        } else if (values.length === 1) {
            return {
                "text": fmtSize(values[0], unit),
                "used": values[0],
                "total": 0,
                "ratio": 0
            };
        }
        return {
            "text": str,
            "used": 0,
            "total": 0,
            "ratio": 0
        };
    }

    function usagePercent(metric) {
        switch (metric) {
        case "cpu":
            return Math.max(0, Math.min(100, StatsProvider.cpuPercent));
        case "gpu":
            return Math.max(0, Math.min(100, numFrom(StatsProvider.gpuUsage)));
        case "ram":
            return Math.round(parseMemory(StatsProvider.ramText, "GB").ratio * 100);
        case "ssd":
            return Math.round(parseMemory(StatsProvider.diskText, "TB").ratio * 100);
        }
        return 0;
    }

    function tempCelsius(metric) {
        switch (metric) {
        case "cpu":
            return numFrom(StatsProvider.cpuTemp);
        case "gpu":
            return numFrom(StatsProvider.gpuTemp);
        }
        return 0;
    }

    function secondaryString(metric) {
        switch (metric) {
        case "cpu":
            return StatsProvider.cpuTemp;
        case "gpu":
            return StatsProvider.gpuTemp;
        case "ram":
            return parseMemory(StatsProvider.ramText, "GB").text;
        case "ssd":
            return parseMemory(StatsProvider.diskText, "TB").text;
        }
        return "";
    }

    function metricName(metric) {
        switch (metric) {
        case "cpu":
            return "CPU";
        case "gpu":
            return "GPU";
        case "ram":
            return "RAM";
        case "ssd":
            return "SSD";
        }
        return "";
    }

    function secondaryColor(metric) {
        if (metric === "cpu" || metric === "gpu") {
            const t = tempCelsius(metric);
            if (t >= 80)
                return WalColors.color1;

            if (t >= 65)
                return WalColors.color3;

            return WalColors.withAlpha(WalColors.color7, 0.65);
        }
        return WalColors.withAlpha(WalColors.color7, 0.75);
    }

    function secondaryFontSize(metric) {
        if (metric === "ram" || metric === "ssd")
            return 10;

        return 11;
    }

    implicitWidth: menuWidth + 2 * cornerRadius
    implicitHeight: container.height
    color: "transparent"
    exclusiveZone: -1
    anchors.top: true
    anchors.left: true

    Connections {
        function onDropdownOpenChanged() {
            if (StatsState.dropdownOpen) {
                closeAnim.stop();
                dropdown.heightAnimOn = true;
                dropdown.expanded = true;
                if (dropdown.closeFactor !== 1 || ringArea.opacity !== 1)
                    reopenAnim.restart();

            } else if (dropdown.expanded) {
                reopenAnim.stop();
                closeAnim.restart();
            }
        }

        target: StatsState
    }

    // Puls bei jedem Metric-Wechsel: kurzes Aufatmen des Rings
    Connections {
        function onActiveMetricChanged() {
            ringPulse.restart();
        }

        target: dropdown
    }

    ParallelAnimation {
        id: reopenAnim

        NumberAnimation {
            target: dropdown
            property: "closeFactor"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: ringArea
            property: "opacity"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }

    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation {
                target: dropdown
                property: "closeFactor"
                to: 0
                duration: 280
                easing.type: Easing.InOutCubic
            }

            NumberAnimation {
                target: ringArea
                property: "opacity"
                to: 0
                duration: 280
                easing.type: Easing.InOutQuad
            }

        }

        ScriptAction {
            script: {
                dropdown.heightAnimOn = false;
                dropdown.expanded = false;
                dropdown.closeFactor = 1;
                ringArea.opacity = 1;
            }
        }

    }

    SequentialAnimation {
        id: ringPulse

        NumberAnimation {
            target: ringArea
            property: "scale"
            to: 1.04
            duration: 160
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: ringArea
            property: "scale"
            to: 1
            duration: 320
            easing.type: Easing.OutCubic
        }

    }

    margins {
        top: 40
        left: {
            const desired = StatsState.dropdownX - implicitWidth / 2;
            return Math.max(edgePadding, Math.min(desired, screen.width - implicitWidth - edgePadding));
        }
    }

    Item {
        id: container

        width: parent.width
        height: dropdown.expanded ? dropdown.fullHeight : 0
        clip: true

        Item {
            id: body

            width: parent.width
            height: dropdown.fullHeight * dropdown.closeFactor
            clip: true

            RoundedDropShape {
                anchors.top: parent.top
                cornerRadius: dropdown.cornerRadius
                menuWidth: dropdown.menuWidth
                menuHeight: Math.max(2 * dropdown.cornerRadius, dropdown.fullHeight * dropdown.closeFactor)
            }

            Column {
                id: content

                spacing: 16
                topPadding: 18
                bottomPadding: 20

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }

                // ---------- Tab-Switcher (minimalistisch) ----------
                Item {
                    id: tabBar

                    readonly property var tabs: [{
                        "key": "cpu",
                        "label": "CPU"
                    }, {
                        "key": "gpu",
                        "label": "GPU"
                    }, {
                        "key": "ram",
                        "label": "RAM"
                    }, {
                        "key": "ssd",
                        "label": "SSD"
                    }]
                    readonly property int tabWidth: 44
                    readonly property int tabSpacing: 8
                    readonly property int activeIndex: {
                        for (let i = 0; i < tabs.length; ++i) {
                            if (tabs[i].key === dropdown.activeMetric)
                                return i;

                        }
                        return 0;
                    }
                    readonly property real slideTargetX: activeIndex * (tabWidth + tabSpacing) + (tabWidth / 2)

                    width: tabs.length * tabWidth + (tabs.length - 1) * tabSpacing
                    height: 32
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        anchors.fill: parent
                        spacing: tabBar.tabSpacing

                        Repeater {
                            model: tabBar.tabs

                            delegate: Item {
                                id: tabItem

                                readonly property bool active: dropdown.activeMetric === modelData.key
                                readonly property bool hovered: tabMouse.containsMouse && !active

                                width: tabBar.tabWidth
                                height: tabBar.height

                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -2
                                    text: modelData.label
                                    color: tabItem.active ? WalColors.color4 : (tabItem.hovered ? WalColors.withAlpha(WalColors.color7, 0.9) : WalColors.withAlpha(WalColors.color7, 0.45))
                                    font.family: "JetBrainsMono Nerd Font"
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
                                    onClicked: dropdown.activeMetric = modelData.key
                                }

                            }

                        }

                    }

                    // ---------- 3-Dot-Trail unter dem aktiven Tab ----------
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
                            opacity: 0.4

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
                            opacity: 0.4

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
                            layer.enabled: true
                            layer.samples: 4
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

                // ---------- Ring mit Instrumenten-Look ----------
                Item {
                    id: ringArea

                    width: dropdown.ringSize
                    height: dropdown.ringSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    transformOrigin: Item.Center

                    // Sanfter Farb-Glow im Hintergrund (pulsierend)
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.7
                        height: width
                        radius: width / 2
                        color: dropdown.displayRingColor
                        opacity: 0.06

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.1
                                duration: 2000
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 0.04
                                duration: 2000
                                easing.type: Easing.InOutSine
                            }

                        }

                    }

                    // Feiner matter Innenring (statisch)
                    Rectangle {
                        anchors.centerIn: parent
                        width: dropdown.ringSize - dropdown.ringThickness * 5
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.05)
                    }

                    // ---------- Gepunktete Hintergrund-Marker ----------
                    Repeater {
                        model: 36

                        delegate: Rectangle {
                            readonly property real angleRad: (index * 10 - 90) * Math.PI / 180
                            readonly property real r: dropdown.ringSize / 2 - dropdown.ringThickness / 2
                            readonly property bool major: (index % 3 === 0)

                            width: major ? 3 : 2
                            height: major ? 3 : 2
                            radius: width / 2
                            color: WalColors.withAlpha(WalColors.color7, major ? 0.35 : 0.18)
                            x: dropdown.ringSize / 2 + r * Math.cos(angleRad) - width / 2
                            y: dropdown.ringSize / 2 + r * Math.sin(angleRad) - height / 2
                        }

                    }

                    // ---------- Fortschrittsbogen (animiert) ----------
                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        smooth: true
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeColor: dropdown.displayRingColor
                            strokeWidth: dropdown.ringThickness
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: dropdown.ringSize / 2
                                centerY: dropdown.ringSize / 2
                                radiusX: dropdown.ringSize / 2 - dropdown.ringThickness / 2
                                radiusY: dropdown.ringSize / 2 - dropdown.ringThickness / 2
                                startAngle: -90
                                sweepAngle: Math.max(0.001, 360 * dropdown.displayProgress)
                            }

                        }

                    }

                    // ---------- Leucht-Punkt am Ende des Bogens ----------
                    Item {
                        id: tipContainer

                        x: dropdown.displayTipX
                        y: dropdown.displayTipY
                        width: 0
                        height: 0
                        visible: dropdown.displayProgress > 0.005

                        // Aussen-Glow (pulsierend)
                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: 10
                            color: dropdown.displayRingColor
                            opacity: 0.3
                            layer.enabled: true
                            layer.samples: 4

                            SequentialAnimation on scale {
                                loops: Animation.Infinite

                                NumberAnimation {
                                    to: 1.4
                                    duration: 1400
                                    easing.type: Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 1
                                    duration: 1400
                                    easing.type: Easing.InOutSine
                                }

                            }

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite

                                NumberAnimation {
                                    to: 0.15
                                    duration: 1400
                                    easing.type: Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 0.35
                                    duration: 1400
                                    easing.type: Easing.InOutSine
                                }

                            }

                        }

                        // Innerer heller Kern
                        Rectangle {
                            anchors.centerIn: parent
                            width: dropdown.ringThickness + 2
                            height: width
                            radius: width / 2
                            color: dropdown.displayRingColor
                            border.width: 2
                            border.color: WalColors.withAlpha(WalColors.color0, 0.8)
                        }

                    }

                    // ---------- Inhalt in der Mitte ----------
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        width: dropdown.ringSize - 60

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dropdown.metricName(dropdown.activeMetric)
                            color: WalColors.withAlpha(WalColors.color7, 0.5)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11

                            Behavior on color {
                                ColorAnimation {
                                    duration: 300
                                }

                            }

                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(dropdown.displayPercent) + "%"
                            color: dropdown.displayRingColor
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 32
                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: dropdown.secondaryString(dropdown.activeMetric)
                            visible: text !== ""
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            color: dropdown.secondaryColor(dropdown.activeMetric)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: dropdown.secondaryFontSize(dropdown.activeMetric)
                        }

                    }

                }

            }

        }

        HoverHandler {
            id: dropdownHover

            onHoveredChanged: {
                StatsState.dropdownHovered = hovered;
                StatsState.updateHoverTimer();
            }
        }

        Behavior on height {
            enabled: dropdown.heightAnimOn

            Anim {
            }

        }

    }

    Behavior on displayPercent {
        NumberAnimation {
            duration: 480
            easing.type: Easing.OutCubic
        }

    }

    Behavior on displayProgress {
        NumberAnimation {
            duration: 480
            easing.type: Easing.OutCubic
        }

    }

    Behavior on displayRingColor {
        ColorAnimation {
            duration: 480
            easing.type: Easing.OutCubic
        }

    }

}
