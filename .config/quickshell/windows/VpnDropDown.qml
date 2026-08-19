import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
    id: dropdown

    required property var screen
    readonly property real radius: 20
    // Dynamische Größen basierend auf dem Screen
    readonly property real menuWidth: screen.width * 0.104
    readonly property real boxHeight: screen.height * 0.111
    readonly property real fullHeight: screen.height * 0.137

    anchors.top: true
    anchors.left: true
    implicitWidth: menuWidth + (2 * radius)
    implicitHeight: boxHeight
    color: "transparent"
    exclusiveZone: -1

    margins {
        top: 40
        left: VpnState.dropdownX !== undefined ? VpnState.dropdownX : 0
    }

    Item {
        id: container

        width: parent.width
        height: VpnState.dropdownOpen ? fullHeight : 0
        clip: true

        Shape {
            id: backgroundShape

            width: parent.width
            height: boxHeight
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
                    x: radius
                    y: radius
                    radiusX: radius
                    radiusY: radius
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: radius
                    y: boxHeight - radius
                }

                PathArc {
                    x: radius + radius
                    y: boxHeight
                    radiusX: radius
                    radiusY: radius
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: radius + menuWidth - radius
                    y: boxHeight
                }

                PathArc {
                    x: radius + menuWidth
                    y: boxHeight - radius
                    radiusX: radius
                    radiusY: radius
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: radius + menuWidth
                    y: radius
                }

                PathArc {
                    x: radius + menuWidth + radius
                    y: 0
                    radiusX: radius
                    radiusY: radius
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
                forceRedrawTimer.start();
            }

            target: WalColors
        }

        Timer {
            id: forceRedrawTimer

            interval: 10
            onTriggered: mainPath.fillColor = WalColors.withAlpha(WalColors.color0, 0.9)
        }

        Item {
            width: parent.width
            height: fullHeight
            anchors.bottom: parent.bottom

            Column {
                spacing: 8
                topPadding: 12

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    leftMargin: radius + 14
                    rightMargin: radius + 14
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: WalColors.withAlpha(WalColors.color7, 0.15)
                }

                Row {
                    spacing: 8

                    Text {
                        text: "󰇧"
                        color: WalColors.color4
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    Text {
                        text: VpnState.vpnCountry
                        color: WalColors.color2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        width: parent.width - 30
                        elide: Text.ElideRight
                    }

                }

                Row {
                    spacing: 8

                    Text {
                        text: "󰖟"
                        color: WalColors.color4
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    Text {
                        text: VpnState.vpnOrg !== "" ? VpnState.vpnOrg : "—"
                        color: WalColors.color2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        width: parent.width - 30
                        elide: Text.ElideRight
                    }

                }

                Row {
                    spacing: 8

                    Text {
                        text: "󰩟"
                        color: WalColors.color4
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    Text {
                        text: VpnState.vpnIp !== "" ? VpnState.vpnIp : "—"
                        color: WalColors.color2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        width: parent.width - 30
                        elide: Text.ElideRight
                    }

                }

            }

        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: VpnState.dropdownOpen = true
            onExited: VpnState.dropdownOpen = false
        }

        Behavior on height {
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutCubic
            }

        }

    }

}
