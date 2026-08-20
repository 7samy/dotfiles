import "../components"
import QtQuick
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

        RoundedDropShape {
            anchors.top: parent.top
            cornerRadius: dropdown.cornerRadius
            menuWidth: dropdown.menuWidth
            menuHeight: dropdown.implicitHeight
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

        HoverHandler {
            onHoveredChanged: VpnState.dropdownOpen = hovered
        }

        Behavior on height {
            Anim {
            }

        }

    }

}
