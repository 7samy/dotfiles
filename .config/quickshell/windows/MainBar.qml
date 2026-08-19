import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
    id: panelWindow

    required property var screen

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 40
    color: "transparent"
    exclusiveZone: BarState.barVisible ? 40 : 0

    margins {
        top: BarState.barVisible ? 0 : -40

        Behavior on top {
            NumberAnimation {
                duration: 400
                easing.type: BarState.barVisible ? Easing.OutBack : Easing.InQuad
            }

        }

    }

    Item {
        id: rootContainer

        anchors.centerIn: parent
        width: screen.width / 1.333
        height: parent.height
        opacity: BarState.barVisible ? 1 : 0

        Shape {
            anchors.fill: parent
            smooth: true
            antialiasing: true
            layer.enabled: true
            layer.smooth: true
            layer.samples: 16

            ShapePath {
                id: barShape

                fillColor: WalColors.withAlpha(WalColors.color0, 0.9)
                strokeColor: "transparent"
                strokeWidth: 0

                PathMove {
                    x: 0
                    y: 0
                }

                PathArc {
                    x: screen.width / 128
                    y: 20
                    radiusX: 20
                    radiusY: 20
                }

                PathLine {
                    x: screen.width / 128
                    y: screen.width / 128
                }

                PathArc {
                    x: screen.width / 64
                    y: screen.width / 64
                    radiusX: 20
                    radiusY: 20
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: screen.width / 1.361
                    y: screen.width / 64
                }

                PathArc {
                    x: screen.width / 1.347
                    y: screen.width / 128
                    radiusX: 20
                    radiusY: 20
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: screen.width / 1.347
                    y: screen.width / 128
                }

                PathArc {
                    x: screen.width / 1.333
                    y: 0
                    radiusX: 20
                    radiusY: 20
                }

                PathLine {
                    x: 0
                    y: 0
                }

            }

        }

        // NEUER Block: Erzwingt Neuzeichnen bei Farbänderung
        Connections {
            function onColorsUpdated() {
                barShape.fillColor = "transparent";
                forceRedrawTimer.start();
            }

            target: WalColors
        }

        Timer {
            id: forceRedrawTimer

            interval: 10
            onTriggered: barShape.fillColor = WalColors.withAlpha(WalColors.color0, 0.9)
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 35
            anchors.rightMargin: 35
            y: BarState.barVisible ? 0 : -5

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 30

                Text {
                    text: "󰣇"
                    color: WalColors.color2
                    font.pixelSize: 24
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: launcherMouse.containsMouse ? WalColors.withAlpha(WalColors.color2, 0.2) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰍉"
                        color: WalColors.color2
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: launcherMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            console.log("Launcher button clicked");
                            AppLauncherState.toggle();
                            console.log("Launcher visible:", AppLauncherState.launcherVisible);
                        }
                    }

                }

                ActiveWindow {
                }

            }

            Workspaces {
                anchors.centerIn: parent
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                spacing: 40

                Row {
                    spacing: 8
                    height: parent.height

                    PowerOff {
                    }

                    Stats {
                    }

                    AudioToggle {
                    }

                    VpnToggle {
                    }

                }

                Clock {
                }

            }

            Behavior on y {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutCubic
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 250
            }

        }

    }

}
