import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../components"

PanelWindow {
    id: dropdown
    required property var screen
    anchors.top: true
    anchors.left: true

    readonly property real radius: 20
    readonly property real menuWidth: 220

    implicitWidth: menuWidth + (2 * radius)
    implicitHeight: 100
    color: "transparent"
    exclusiveZone: -1

    margins {
        top: 40
        left: AudioState.dropdownX
    }

    Process { id: setVolumeProcess }

    Item {
        id: container
        width: parent.width
        height: AudioState.dropdownOpen ? 100 : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutCubic
            }
        }

        Shape {
            id: backgroundShape
            width: parent.width
            height: 100
            anchors.top: parent.top
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
                PathLine { x: radius; y: 100 - radius }
                PathArc { x: radius + radius; y: 100; radiusX: radius; radiusY: radius; direction: PathArc.Counterclockwise }
                PathLine { x: radius + menuWidth - radius; y: 100 }
                PathArc { x: radius + menuWidth; y: 100 - radius; radiusX: radius; radiusY: radius; direction: PathArc.Counterclockwise }
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
            onTriggered: mainPath.fillColor = WalColors.barFillColor
        }

        Item {
            width: parent.width
            height: 100
            anchors.bottom: parent.bottom

            Column {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    leftMargin: radius + 14
                    rightMargin: radius + 14
                }
                
                // Hier wurden die Werte noch weiter verringert, 
                // um alles weiter nach oben zu ziehen:
                spacing: 6 
                topPadding: 8

                Row {
                    spacing: 8
                    width: parent.width

                }

                Slider {
                    id: volumeSlider
                    from: 0
                    to: 100
                    value: AudioState.volumePercent
                    width: parent.width
                    height: 24
                    z: 10

                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        implicitWidth: volumeSlider.width
                        implicitHeight: 4
                        width: volumeSlider.availableWidth
                        height: implicitHeight
                        radius: 2
                        color: WalColors.withAlpha(WalColors.color2, 0.3)

                        Rectangle {
                            width: volumeSlider.visualPosition * parent.width
                            height: parent.height
                            color: WalColors.color4
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: WalColors.color4
                        border.color: WalColors.withAlpha(WalColors.color2, 0.5)
                        border.width: 2
                    }

                    onMoved: {
                        AudioState.volumePercent = value
                        var frac = value / 100.0
                        setVolumeProcess.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", frac.toFixed(2)]
                        setVolumeProcess.running = true
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: WalColors.withAlpha(WalColors.color7, 0.15)
                }

                Text {
                    text: "󰓃  Default Audio Sink"
                    color: WalColors.withAlpha(WalColors.color2, 0.6)
                    font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = false
            onEntered: AudioState.menuHovered = true
            onExited: AudioState.menuHovered = false
        }
    }
}
