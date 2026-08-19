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

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    StatsState.stopHideTimer();
                    StatsState.dropdownOpen = true;
                } else {
                    StatsState.startHideTimer();
                }
            }
        }

        Shape {
            width: parent.width
            height: dropdown.implicitHeight
            anchors.top: parent.top
            smooth: true
            antialiasing: true
            layer.enabled: true
            layer.smooth: true
            layer.samples: 16

            ShapePath {
                id: mainPath

                fillColor: WalColors.withAlpha(WalColors.color0, 0.9)
                strokeColor: "transparent"
                strokeWidth: 0

                PathMove {
                    x: 0
                    y: 0
                }

                PathArc {
                    x: cornerRadius
                    y: cornerRadius
                    radiusX: cornerRadius
                    radiusY: cornerRadius
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: cornerRadius
                    y: dropdown.implicitHeight - cornerRadius
                }

                PathArc {
                    x: 2 * cornerRadius
                    y: dropdown.implicitHeight
                    radiusX: cornerRadius
                    radiusY: cornerRadius
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: cornerRadius + menuWidth - cornerRadius
                    y: dropdown.implicitHeight
                }

                PathArc {
                    x: cornerRadius + menuWidth
                    y: dropdown.implicitHeight - cornerRadius
                    radiusX: cornerRadius
                    radiusY: cornerRadius
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: cornerRadius + menuWidth
                    y: cornerRadius
                }

                PathArc {
                    x: cornerRadius + menuWidth + cornerRadius
                    y: 0
                    radiusX: cornerRadius
                    radiusY: cornerRadius
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: 0
                    y: 0
                }

            }

        }

        Connections {
            function onColorsUpdated() {
                mainPath.fillColor = "transparent";
                redrawTimer.start();
            }

            target: WalColors
        }

        Timer {
            id: redrawTimer

            interval: 10
            onTriggered: mainPath.fillColor = WalColors.withAlpha(WalColors.color0, 0.9)
        }

        Column {
            id: content

            spacing: 8
            topPadding: 16
            bottomPadding: 10
            leftPadding: 20
            rightPadding: 20

            anchors {
                top: parent.top
                left: parent.left
            }

            // RAM
            Row {
                spacing: 10
                leftPadding: 20

                Text {
                    text: "RAM"
                    color: WalColors.color4
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    width: 55
                }

                Text {
                    text: StatsProvider.ramText !== "" ? StatsProvider.ramText : "--"
                    color: WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

            }

            // CPU-Auslastung
            Row {
                spacing: 10
                leftPadding: 20

                Text {
                    text: "CPU"
                    color: WalColors.color4
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    width: 55
                }

                Text {
                    text: StatsProvider.cpuPercent + "%"
                    color: WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

            }

            // CPU-Temperatur
            Row {
                spacing: 10
                leftPadding: 20

                Text {
                    text: "CPU "
                    color: WalColors.color4
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    width: 55
                }

                Text {
                    text: StatsProvider.cpuTemp
                    color: WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

            }

            // GPU-Auslastung
            Row {
                spacing: 10
                leftPadding: 20

                Text {
                    text: "GPU"
                    color: WalColors.color4
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    width: 55
                }

                Text {
                    text: StatsProvider.gpuUsage
                    color: WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

            }

            // GPU-Temperatur
            Row {
                spacing: 10
                leftPadding: 20

                Text {
                    text: "GPU "
                    color: WalColors.color4
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    width: 55
                }

                Text {
                    text: StatsProvider.gpuTemp
                    color: WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

            }

            // Speicher
            Row {
                spacing: 10
                leftPadding: 20

                Text {
                    text: "SSD"
                    color: WalColors.color4
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    width: 55
                }

                Text {
                    text: StatsProvider.diskText !== "" ? StatsProvider.diskText : "--"
                    color: WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

            }

        }

        Behavior on height {
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutCubic
            }

        }

    }

}
