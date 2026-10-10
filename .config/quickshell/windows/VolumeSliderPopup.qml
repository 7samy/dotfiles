import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popup

    required property var screen
    readonly property real panelWidth: 420
    readonly property real panelHeight: 88
    readonly property real cornerR: 20
    readonly property real sideMargin: 28

    WlrLayershell.namespace: "quickshell:volume-slider"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    screen: screen
    visible: VolumeSliderState.open || wrapper.shown > 0.01
    color: "transparent"
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    anchors.bottom: true
    anchors.left: true

    margins {
        bottom: 0
        left: (screen.width - panelWidth) / 2
    }

    Item {
        id: wrapper

        property real shown: VolumeSliderState.open ? 1 : 0

        anchors.fill: parent
        opacity: shown

        // ==================== Panel-Shape ====================
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                id: shapePath

                fillColor: WalColors.withAlpha(WalColors.color0, 0.97)
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0
                startY: popup.panelHeight

                PathArc {
                    x: popup.cornerR
                    y: popup.panelHeight - popup.cornerR
                    radiusX: popup.cornerR
                    radiusY: popup.cornerR
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: popup.cornerR
                    y: popup.cornerR
                }

                PathArc {
                    x: 2 * popup.cornerR
                    y: 0
                    radiusX: popup.cornerR
                    radiusY: popup.cornerR
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: popup.panelWidth - 2 * popup.cornerR
                    y: 0
                }

                PathArc {
                    x: popup.panelWidth - popup.cornerR
                    y: popup.cornerR
                    radiusX: popup.cornerR
                    radiusY: popup.cornerR
                    direction: PathArc.Clockwise
                }

                PathLine {
                    x: popup.panelWidth - popup.cornerR
                    y: popup.panelHeight - popup.cornerR
                }

                PathArc {
                    x: popup.panelWidth
                    y: popup.panelHeight
                    radiusX: popup.cornerR
                    radiusY: popup.cornerR
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: 0
                    y: popup.panelHeight
                }

            }

            Connections {
                function onColorsUpdated() {
                    shapePath.fillColor = "transparent";
                    redrawTimer.start();
                }

                target: WalColors
            }

            Timer {
                id: redrawTimer

                interval: 10
                onTriggered: shapePath.fillColor = WalColors.withAlpha(WalColors.color0, 0.97)
            }

        }

        // ==================== Inhalt ====================
        Row {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: popup.sideMargin
            anchors.rightMargin: popup.sideMargin
            spacing: 18

            // ---------- Mute-Toggle links ----------
            Item {
                id: muteBtn

                readonly property bool isMuted: AudioState.volume <= 0.01
                readonly property bool isLow: AudioState.volume > 0.01 && AudioState.volume < 0.5

                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36

                // Akzent-Kreis (Hintergrund)
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: WalColors.withAlpha(WalColors.color4, muteMouse.containsMouse ? 0.22 : 0.12)

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }

                    }

                }

                // Pulsierender Ring, wenn gemutet
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: WalColors.color1
                    opacity: muteBtn.isMuted ? 0.7 : 0
                    visible: opacity > 0.01
                    scale: muteBtn.isMuted ? 1 : 0.85

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: muteBtn.isMuted

                        NumberAnimation {
                            to: 1.1
                            duration: 1100
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            to: 1
                            duration: 1100
                            easing.type: Easing.InOutSine
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    text: muteBtn.isMuted ? "󰖁" : (muteBtn.isLow ? "󰕿" : "󰕾")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 17
                    color: muteBtn.isMuted ? WalColors.color1 : WalColors.color4

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }

                    }

                }

                MouseArea {
                    id: muteMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AudioState.setVolume(AudioState.volume > 0.01 ? 0 : 0.5);
                        VolumeSliderState.restartAutoClose();
                    }
                }

            }

            // ---------- Slider (breiter Bereich) ----------
            Item {
                id: sliderArea

                readonly property real v: Math.max(0, Math.min(AudioState.volume, 1))
                readonly property bool dragging: volMouse.pressed
                readonly property bool hot: dragging || volMouse.containsMouse

                anchors.verticalCenter: parent.verticalCenter
                width: content.width - muteBtn.width - percentLabel.width - 2 * content.spacing
                height: 40

                // Track (Hintergrund)
                Rectangle {
                    id: track

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18
                    radius: height / 2
                    color: WalColors.withAlpha(WalColors.color7, 0.1)

                    // Feine Ticks als Gliederung (5 Marker)
                    Repeater {
                        model: 4

                        delegate: Rectangle {
                            readonly property real pos: (index + 1) / 5

                            x: track.width * pos - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2
                            height: 2
                            radius: 1
                            color: WalColors.withAlpha(WalColors.color7, 0.28)
                        }

                    }

                }

                // Filled (Fortschritt) mit Gradient
                Rectangle {
                    id: filled

                    anchors.left: track.left
                    anchors.verticalCenter: track.verticalCenter
                    width: track.width * sliderArea.v
                    height: track.height
                    radius: track.radius

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: WalColors.withAlpha(WalColors.color4, 0.75)
                        }

                        GradientStop {
                            position: 1
                            color: WalColors.color4
                        }

                    }

                }

                // Glow am Ende des Filled (folgt dem Handle)
                Rectangle {
                    anchors.verticalCenter: track.verticalCenter
                    x: track.width * sliderArea.v - width / 2
                    width: 34
                    height: 34
                    radius: width / 2
                    color: WalColors.color4
                    opacity: sliderArea.hot ? 0.35 : 0.15
                    layer.enabled: true
                    layer.samples: 4

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 250
                        }

                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.OutQuad
                        }

                    }

                }

                // Handle (Kreis)
                Rectangle {
                    id: handle

                    anchors.verticalCenter: parent.verticalCenter
                    x: track.width * sliderArea.v - width / 2
                    width: 32
                    height: 32
                    radius: width / 2
                    color: WalColors.color7
                    border.width: 2
                    border.color: WalColors.withAlpha(WalColors.color0, 0.8)
                    scale: sliderArea.dragging ? 1.15 : (volMouse.containsMouse ? 1.08 : 1)

                    Behavior on scale {
                        SpringAnimation {
                            spring: 5.5
                            damping: 0.4
                            epsilon: 0.1
                        }

                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.OutQuad
                        }

                    }

                }

                // Prozentzahl im Handle (nur beim Ziehen)
                Text {
                    anchors.centerIn: handle
                    text: Math.round(sliderArea.v * 100)
                    color: WalColors.color0
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    opacity: sliderArea.dragging ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // Icon im Handle (wenn nicht gezogen)
                Text {
                    anchors.centerIn: handle
                    text: AudioState.volume <= 0.01 ? "󰖁" : (AudioState.volume < 0.5 ? "󰕿" : "󰕾")
                    color: WalColors.color0
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    opacity: sliderArea.dragging ? 0 : 1
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                MouseArea {
                    id: volMouse

                    function updateVol(me) {
                        AudioState.setVolume(Math.max(0, Math.min(me.x / width, 1)));
                        VolumeSliderState.restartAutoClose();
                    }

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: (mouse) => {
                        if (pressed)
                            updateVol(mouse);

                    }
                    onPressed: (mouse) => {
                        updateVol(mouse);
                    }
                }

            }

            // ---------- Prozent rechts ----------
            Item {
                id: percentLabel

                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 36

                Text {
                    anchors.centerIn: parent
                    text: Math.round(sliderArea.v * 100)
                    color: WalColors.color4
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignRight

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 22
                    anchors.verticalCenterOffset: 6
                    text: "%"
                    color: WalColors.withAlpha(WalColors.color4, 0.6)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }

            }

        }

        HoverHandler {
            onHoveredChanged: {
                VolumeSliderState.hovered = hovered;
                if (hovered)
                    VolumeSliderState.restartAutoClose();

            }
        }

        transform: Translate {
            y: (1 - wrapper.shown) * 30
        }

        Behavior on shown {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }

        }

    }

}
