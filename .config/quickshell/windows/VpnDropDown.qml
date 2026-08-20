import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
    id: dropdown

    required property var screen
    // --- Layout-Konstanten ---------------------------------------------
    readonly property real cornerRadius: 20
    readonly property real menuWidth: 200
    readonly property real edgePadding: 8 // Mindestabstand zum Bildschirmrand
    readonly property real contentBottomPadding: 16

    // --- Dynamische Größe -------------------------------------------------
    // Breite/Höhe leiten sich direkt aus dem Inhalt ab (infoColumn), damit
    // Fenstergröße und Hintergrund-Shape nie wieder auseinanderlaufen wie
    // vorher (120 vs. 148 → Content ohne Hintergrund).
    implicitWidth: menuWidth + 2 * cornerRadius
    implicitHeight: infoColumn.implicitHeight + contentBottomPadding
    color: "transparent"
    exclusiveZone: -1
    anchors.top: true
    anchors.left: true

    margins {
        top: 40
        // Zentriert das Menü unter dem VPN-Icon, geclampt an die
        // Bildschirmränder damit es nie abgeschnitten aus dem Screen ragt.
        left: {
            const desired = VpnState.iconCenterX - implicitWidth / 2;
            return Math.max(edgePadding, Math.min(desired, screen.width - implicitWidth - edgePadding));
        }
    }

    Item {
        id: container

        width: parent.width
        height: VpnState.dropdownOpen ? dropdown.implicitHeight : 0
        clip: true

        Shape {
            id: backgroundShape

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
                    y: backgroundShape.height - cornerRadius
                }

                PathArc {
                    x: 2 * cornerRadius
                    y: backgroundShape.height
                    radiusX: cornerRadius
                    radiusY: cornerRadius
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: cornerRadius + menuWidth - cornerRadius
                    y: backgroundShape.height
                }

                PathArc {
                    x: cornerRadius + menuWidth
                    y: backgroundShape.height - cornerRadius
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

        // Workaround: Qt Quick Shapes rendert eine reine
        // ShapePath.fillColor-Änderung nicht immer zuverlässig neu.
        // Kurz auf "transparent" setzen und einen Frame später zurücksetzen
        // erzwingt das Neuzeichnen.
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

        Column {
            id: infoColumn

            spacing: 8
            topPadding: 12

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: cornerRadius + 14
                rightMargin: cornerRadius + 14
            }

            Rectangle {
                width: parent.width
                height: 1
                color: WalColors.withAlpha(WalColors.color7, 0.15)
            }

            Repeater {
                model: [{
                    "icon": "󰇧",
                    "value": VpnState.vpnCountry !== "" ? VpnState.vpnCountry : "—"
                }, {
                    "icon": "󰖟",
                    "value": VpnState.vpnOrg !== "" ? VpnState.vpnOrg : "—"
                }, {
                    "icon": "󰩟",
                    "value": VpnState.vpnIp !== "" ? VpnState.vpnIp : "—"
                }]

                delegate: Row {
                    required property var modelData

                    spacing: 8

                    Text {
                        text: modelData.icon
                        color: WalColors.color4
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    Text {
                        text: modelData.value
                        color: WalColors.color2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        width: 150
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
                duration: 400
                easing.type: Easing.bezierCubic
                easing.bezierCurve: [0.22, 1, 0.36, 1]
            }

        }

    }

}
