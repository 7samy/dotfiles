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
            layer.samples: 4

            ShapePath {
                id: barShape

                fillColor: WalColors.withAlpha(WalColors.color0, 1)
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
            onTriggered: barShape.fillColor = WalColors.withAlpha(WalColors.color0, 1)
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

                // ---- Icon-Gruppe mit flüssigem Sliding-Pill ----
                Item {
                    id: iconGroup

                    property int hoveredIndex: -1
                    property real targetCenterX: innerRow.x + innerRow.width / 2
                    readonly property real pillWidth: 34

                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: innerRow.implicitWidth + 28

                    // Statischer Gruppen-Hintergrund
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 32
                        radius: height / 2
                        color: WalColors.withAlpha(WalColors.color4, 0.12)
                    }

                    Row {
                        id: innerRow

                        anchors.centerIn: parent
                        spacing: 10
                        height: parent.height

                        PowerMenuButton {
                            id: pmBtn

                            hoverBoxEnabled: false
                        }

                        AudioToggle {
                            id: atBtn

                            hoverBoxEnabled: false
                        }

                        Stats {
                            id: stBtn

                            hoverBoxEnabled: false
                        }

                        VpnToggle {
                            id: vpnBtn

                            hoverBoxEnabled: false
                        }

                    }

                    // ---- Perfekt gedämpftes Sliding Pill ----
                    Rectangle {
                        id: sliderPill

                        anchors.verticalCenter: parent.verticalCenter
                        height: 32
                        width: iconGroup.pillWidth
                        radius: height / 2
                        color: WalColors.withAlpha(WalColors.color4, 0.28)
                        // Position aus targetCenterX
                        x: iconGroup.targetCenterX - width / 2
                        // Sichtbarkeit
                        visible: opacity > 0.01
                        opacity: iconGroup.hoveredIndex >= 0 ? 1 : 0

                        // Diese X-Animation macht den "Magie"-Effekt aus:
                        // Eine starke Federung (spring), die aber fast perfekt abgedämpft wird (damping).
                        // Das sorgt dafür, dass sie schnell startet und samtweich einrastet, ohne zu wackeln.
                        Behavior on x {
                            enabled: sliderPill.opacity === 1

                            SpringAnimation {
                                spring: 7.5 // Reaktionsgeschwindigkeit (snappy)
                                damping: 0.95 // Sehr starke Dämpfung (verhindert den Bounce, sorgt für smoothen Slide)
                                mass: 1
                            }

                        }

                        // Opacity: Fade In ist sehr schnell, Fade Out minimal verzögert.
                        // So bleibt die Box präsenter, wenn man leicht vom Icon abrutscht.
                        Behavior on opacity {
                            NumberAnimation {
                                duration: iconGroup.hoveredIndex >= 0 ? 100 : 250
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    // ---- Hover-Handler ----
                    HoverHandler {
                        id: groupHover

                        onPointChanged: {
                            const px = point.position.x;
                            let found = -1;
                            let centerX = innerRow.x + innerRow.width / 2;
                            const kids = [pmBtn, atBtn, stBtn, vpnBtn];
                            for (let i = 0; i < kids.length; i++) {
                                const c = kids[i];
                                if (!c)
                                    continue;

                                const cx = innerRow.x + c.x;
                                if (px >= cx && px <= cx + c.width) {
                                    found = i;
                                    centerX = cx + c.width / 2;
                                    break;
                                }
                            }
                            if (iconGroup.hoveredIndex !== found)
                                iconGroup.hoveredIndex = found;

                            iconGroup.targetCenterX = centerX;
                        }
                        onHoveredChanged: {
                            if (!hovered) {
                                iconGroup.hoveredIndex = -1;
                                iconGroup.targetCenterX = innerRow.x + innerRow.width / 2;
                            }
                        }
                    }

                }

                Clock {
                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: Appearance.anim.durations.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.slow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.curves.standard
            }

        }

    }

}
