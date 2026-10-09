import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
    id: dropdown

    required property var screen
    readonly property real cornerRadius: 20
    readonly property real menuWidth: 280
    readonly property real edgePadding: 8
    readonly property real ringSize: 180
    readonly property real ringThickness: 8
    property string activeMetric: "cpu"
    // Volle Zielhöhe – wird für Container und Panel-Höhe gebraucht.
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
    // Panel folgt der Container-Höhe. Bei geschlossenem Menü -> 0 px hoch,
    // dadurch blockiert es keinen Hover für andere Dropdowns.
    implicitHeight: container.height
    color: "transparent"
    exclusiveZone: -1
    anchors.top: true
    anchors.left: true

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
        height: StatsState.dropdownOpen ? dropdown.fullHeight : 0
        clip: true

        RoundedDropShape {
            anchors.top: parent.top
            cornerRadius: dropdown.cornerRadius
            menuWidth: dropdown.menuWidth
            menuHeight: dropdown.fullHeight
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

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: [{
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

                    delegate: Rectangle {
                        id: tab

                        readonly property bool active: dropdown.activeMetric === modelData.key

                        width: 52
                        height: 26
                        radius: 13
                        color: active ? WalColors.withAlpha(WalColors.color4, 0.22) : (tabMouse.containsMouse ? WalColors.withAlpha(WalColors.color7, 0.08) : "transparent")
                        border.width: 1
                        border.color: active ? WalColors.withAlpha(WalColors.color4, 0.55) : WalColors.withAlpha(WalColors.color7, 0.1)

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: tab.active ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.6)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.bold: tab.active
                        }

                        MouseArea {
                            id: tabMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dropdown.activeMetric = modelData.key
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

                }

            }

            Item {
                id: ringArea

                width: dropdown.ringSize
                height: dropdown.ringSize
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    height: width
                    radius: width / 2
                    color: dropdown.ringColor
                    opacity: 0.06
                }

                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    smooth: true
                    layer.enabled: true
                    layer.samples: 8

                    ShapePath {
                        strokeColor: Qt.rgba(1, 1, 1, 0.1)
                        strokeWidth: dropdown.ringThickness
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: dropdown.ringSize / 2
                            centerY: dropdown.ringSize / 2
                            radiusX: dropdown.ringSize / 2 - dropdown.ringThickness / 2
                            radiusY: dropdown.ringSize / 2 - dropdown.ringThickness / 2
                            startAngle: -90
                            sweepAngle: 359.999
                        }

                    }

                    ShapePath {
                        strokeColor: dropdown.ringColor
                        strokeWidth: dropdown.ringThickness
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: dropdown.ringSize / 2
                            centerY: dropdown.ringSize / 2
                            radiusX: dropdown.ringSize / 2 - dropdown.ringThickness / 2
                            radiusY: dropdown.ringSize / 2 - dropdown.ringThickness / 2
                            startAngle: -90
                            sweepAngle: Math.max(0.001, 360 * dropdown.ringProgress)
                        }

                    }

                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    width: dropdown.ringSize - 40

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dropdown.metricName(dropdown.activeMetric)
                        color: WalColors.withAlpha(WalColors.color7, 0.5)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dropdown.activePercent + "%"
                        color: dropdown.ringColor
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 30
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

        HoverHandler {
            id: dropdownHover

            onHoveredChanged: {
                StatsState.dropdownHovered = hovered;
                StatsState.updateHoverTimer();
            }
        }

        Behavior on height {
            Anim {
            }

        }

    }

}
