import QtQuick
import QtQuick.Shapes
import "../components"
import Quickshell

PanelWindow {
    id: dropdown
    required property var screen
    anchors.top: true
    anchors.left: true
    
    readonly property real radius: 20
    readonly property real menuWidth: 200
    
    implicitWidth: menuWidth + (2 * radius)
    implicitHeight: 148 
    color: "transparent"
    exclusiveZone: -1

    margins {
        top: 40 
        left: VpnState.dropdownX - radius
    }

    Item {
        id: container
        width: parent.width
        height: VpnState.dropdownOpen ? 148 : 0
        clip: true

        // Die Animation für das weiche Ein- und Ausfahren
        Behavior on height {
            NumberAnimation {
                duration: 300 // Etwas verlängert für einen Premium-Look
                easing.type: Easing.InOutCubic // Startet und endet sanft
            }
        }

        // ACHTUNG: Die Opacity-Animation ist hier komplett gelöscht! 
        // Das Zuklappen (clip: true) macht das Verstecken ganz natürlich.

        Shape {
            id: backgroundShape
            width: parent.width
            height: 148 // FESTE Höhe, damit die Kurven sich beim Schließen nicht stauchen
            anchors.top: parent.top // Bleibt oben an der Bar "kleben"
            
            smooth: true
            antialiasing: true
            layer.enabled: true
            layer.smooth: true
            layer.samples: 16

            ShapePath {
                id: mainPath
                fillColor: WalColors.barFillColor
                strokeColor: "transparent"
                strokeWidth: 0
                
                PathMove { x: 0; y: 0 }
                PathArc { x: radius; y: radius; radiusX: radius; radiusY: radius; direction: PathArc.Clockwise }
                PathLine { x: radius; y: 148 - radius }
                PathArc { x: radius + radius; y: 148; radiusX: radius; radiusY: radius; direction: PathArc.Counterclockwise }
                PathLine { x: radius + menuWidth - radius; y: 148 }
                PathArc { x: radius + menuWidth; y: 148 - radius; radiusX: radius; radiusY: radius; direction: PathArc.Counterclockwise }
                PathLine { x: radius + menuWidth; y: radius }
                PathArc { x: radius + menuWidth + radius; y: 0; radiusX: radius; radiusY: radius; direction: PathArc.Clockwise }
                PathLine { x: 0; y: 0 }
            }
        }

        Connections {
            target: WalColors
            function onBarFillColorChanged() {
                mainPath.fillColor = "transparent"
                forceRedrawTimer.start()
            }
        }

        Timer {
            id: forceRedrawTimer
            interval: 50
            repeat: false
            onTriggered: {
                mainPath.fillColor = WalColors.barFillColor
            }
        }

        // --- DER SCHUBLADEN-TRICK ---
        // Dieser Wrapper hat eine feste Höhe, ist aber UNTEN am Container verankert.
        // Wenn der Container auf Höhe 0 schrumpft, wird dieser Block physisch 
        // nach OBEN in die Mainbar gedrückt.
        Item {
            width: parent.width
            height: 148
            anchors.bottom: parent.bottom

            Column {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    leftMargin: radius + 14
                    rightMargin: radius + 14
                }
                spacing: 8
                topPadding: 12

                Row {
                    spacing: 8
                    Text {
                        color: VpnState.connected ? "#b8e0b8" : "#f0b8b8"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                    }
                    Text {
                        text: VpnState.connected ? "Connected" : "Disconnected"
                        color: VpnState.connected ? "#b8e0b8" : "#f0b8b8"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: WalColors.withAlpha(WalColors.color7, 0.15)
                }

                Row {
                    spacing: 8
                    Text { text: "󰍃"; color: WalColors.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                    Text { text: VpnState.vpnCity !== "" ? VpnState.vpnCity + ", " + VpnState.vpnCountry : "—"; color: WalColors.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; width: 50 }
                }
                Row {
                    spacing: 8
                    Text { text: "󰖟"; color: WalColors.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                    Text { text: VpnState.vpnOrg !== "" ? VpnState.vpnOrg : "—"; color: WalColors.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight; width: 140 }
                }
                Row {
                    spacing: 8
                    Text { text: "󰇧"; color: WalColors.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                    Text { text: VpnState.vpnIp !== "" ? VpnState.vpnIp : "—"; color: WalColors.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: VpnState.dropdownOpen = true
            onExited: VpnState.dropdownOpen = false
        }
    }
}
