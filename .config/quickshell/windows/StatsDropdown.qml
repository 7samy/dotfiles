import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
    id: dropdown

    required property var screen
    readonly property real cornerRadius: 20
    readonly property real menuWidth: 260
    readonly property real edgePadding: 8
    readonly property real ringSize: 150
    readonly property real ringThickness: 8
    property string activeMetric: "cpu"
    readonly property bool showPercent: true // bleibt bei allen aktiv
    // ---------- Abgeleitete Werte ----------
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

    // ---------- Parsing-Helfer ----------
    function numFrom(s) {
        if (s === undefined || s === null)
            return 0;

        const m = String(s).match(/(-?\d+(?:\.\d+)?)/);
        return m ? parseFloat(m[1]) : 0;
    }

    function ratioFrom(s) {
        if (s === undefined || s === null)
            return 0;

        const m = String(s).match(/([\d.]+)\s*\/\s*([\d.]+)/);
        if (!m)
            return 0;

        const a = parseFloat(m[1]);
        const b = parseFloat(m[2]);
        if (!b)
            return 0;

        return Math.max(0, Math.min(1, a / b));
    }

    // Wandelt MB in GB um UND entfernt eine eventuell vorhandene
    // Prozentangabe aus dem String. Funktioniert fuer:
    //   "5200 MB"                        -> "5.1 GB"
    //   "5200 / 15600 MB"                -> "5.1 / 15.2 GB"
    //   "5200 MB / 15600 MB (34%)"       -> "5.1 GB / 15.2 GB"
    function cleanRamString(s) {
        if (s === undefined || s === null)
            return "";

        let out = String(s);
        // Prozentangabe in Klammern oder alleinstehend entfernen
        out = out.replace(/\s*[\(\[]?\s*\d+(?:\.\d+)?\s*%\s*[\)\]]?/g, "");
        // MB -> GB
        out = out.replace(/(\d+(?:\.\d+)?)\s*MB/gi, function(_, num) {
            return (parseFloat(num) / 1024).toFixed(1) + " GB";
        });
        // Mehrfache Leerzeichen aufraeumen
        out = out.replace(/\s+/g, " ").trim();
        return out;
    }

    function usagePercent(metric) {
        switch (metric) {
        case "cpu":
            return Math.max(0, Math.min(100, StatsProvider.cpuPercent));
        case "gpu":
            return Math.max(0, Math.min(100, numFrom(StatsProvider.gpuUsage)));
        case "ram":
            return Math.round(ratioFrom(StatsProvider.ramText) * 100);
        case "ssd":
            return Math.round(ratioFrom(StatsProvider.diskText) * 100);
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

    // Sekundaertext: Temp bei CPU/GPU, Speicherwert (in GB) bei RAM/SSD
    function secondaryString(metric) {
        switch (metric) {
        case "cpu":
            return StatsProvider.cpuTemp;
        case "gpu":
            return StatsProvider.gpuTemp;
        case "ram":
            return cleanRamString(StatsProvider.ramText);
        case "ssd":
            return cleanRamString(StatsProvider.diskText);
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
        if (showPercent) {
            const t = tempCelsius(metric);
            if (t >= 80)
                return WalColors.color1;

            if (t >= 65)
                return WalColors.color3;

            return WalColors.withAlpha(WalColors.color7, 0.65);
        }
        return WalColors.withAlpha(WalColors.color7, 0.75);
    }

    implicitWidth: menuWidth + 2 * cornerRadius
    implicitHeight: content.implicitHeight + 24
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
        height: StatsState.dropdownOpen ? dropdown.implicitHeight : 0
        clip: true

        RoundedDropShape {
            anchors.top: parent.top
            cornerRadius: dropdown.cornerRadius
            menuWidth: dropdown.menuWidth
            menuHeight: dropdown.implicitHeight
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

            // ---------- Tab-Switcher ----------
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

            // ---------- Ring mit Center-Content ----------
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
                    width: dropdown.ringSize - 30

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
                        font.pixelSize: 11
                    }

                }

            }

        }

        HoverHandler {
            onHoveredChanged: StatsState.dropdownOpen = hovered
        }

        Behavior on height {
            Anim {
            }

        }

    }

}
