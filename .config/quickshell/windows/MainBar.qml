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

                // ---- Icon-Gruppe mit morphing Pill ----
                Item {
                    id: iconGroup

                    // -1 = nichts gehovert
                    property int hoveredIndex: -1
                    readonly property real pillWidth: 34
                    // ---- lockedIndex: welches Dropdown ist gerade offen? ----
                    // Reihenfolge = Prioritaet, falls mehrere gleichzeitig
                    // offen sind (kommt durch Hover-Wechsel kurz vor).
                    // Zuordnung: 0=PowerMenu, 1=Audio, 2=Stats, 3=VPN
                    readonly property int lockedIndex: {
                        // VPN hat Prioritaet (seltener, deutlicher sichtbar)
                        if (typeof VpnState !== "undefined" && VpnState.dropdownOpen)
                            return 3;

                        if (typeof StatsState !== "undefined" && StatsState.dropdownOpen)
                            return 2;

                        if (typeof AudioState !== "undefined" && AudioState.dropdownOpen)
                            return 1;

                        // PowerMenu: hier ergänzen, falls ein State-Singleton
                        // existiert. Beispiel:
                        // if (PowerMenuState.open) return 0;
                        return -1;
                    }
                    // Effektiv: Hover schlaegt Lock, Lock schlaegt Idle.
                    readonly property int effectiveIndex: hoveredIndex >= 0 ? hoveredIndex : lockedIndex
                    readonly property bool focused: effectiveIndex >= 0
                    // Ziel-X (linker Rand) der Pille
                    readonly property real pillX: {
                        if (!focused)
                            return 0;

                        const kids = [pmBtn, atBtn, stBtn, vpnBtn];
                        const c = kids[effectiveIndex];
                        if (!c)
                            return 0;

                        return innerRow.x + c.x + c.width / 2 - pillWidth / 2;
                    }
                    readonly property real pillW: focused ? pillWidth : width

                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: innerRow.implicitWidth + 28

                    // ---------- Morphing Hintergrund-Pille ----------
                    Rectangle {
                        id: morphPill

                        anchors.verticalCenter: parent.verticalCenter
                        height: 32
                        radius: height / 2
                        color: WalColors.withAlpha(WalColors.color4, iconGroup.focused ? 0.3 : 0.12)
                        x: iconGroup.pillX
                        width: iconGroup.pillW

                        Behavior on x {
                            NumberAnimation {
                                duration: 320
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.08
                            }

                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 320
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.08
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Row {
                        id: innerRow

                        anchors.centerIn: parent
                        spacing: 10
                        height: parent.height

                        VpnToggle {
                            id: vpnBtn

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

                        PowerMenuButton {
                            id: pmBtn

                            hoverBoxEnabled: false
                        }

                    }

                    // ---- Hover-Handler ----
                    HoverHandler {
                        id: groupHover

                        onPointChanged: {
                            const px = point.position.x;
                            let found = -1;
                            const kids = [pmBtn, atBtn, stBtn, vpnBtn];
                            for (let i = 0; i < kids.length; i++) {
                                const c = kids[i];
                                if (!c)
                                    continue;

                                const cx = innerRow.x + c.x;
                                if (px >= cx && px <= cx + c.width) {
                                    found = i;
                                    break;
                                }
                            }
                            if (iconGroup.hoveredIndex !== found)
                                iconGroup.hoveredIndex = found;

                        }
                        onHoveredChanged: {
                            if (!hovered)
                                iconGroup.hoveredIndex = -1;

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
