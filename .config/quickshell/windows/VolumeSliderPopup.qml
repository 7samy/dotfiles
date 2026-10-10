import "../components"
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: popup

    required property var screen
    readonly property real panelWidth: 440
    readonly property real baseHeight: 60
    readonly property real cornerR: 18
    readonly property real sideMargin: 32
    readonly property real streamRowHeight: 40
    readonly property int streamsMaxVisible: 5
    readonly property int streamsVisible: Math.min(VolumeSliderState.streams.length, streamsMaxVisible)
    // Ziel-Höhe je nach Expand-State
    readonly property real targetHeight: {
        if (!VolumeSliderState.expanded)
            return baseHeight;

        const contentH = VolumeSliderState.streams.length === 0 ? 44 : streamsVisible * streamRowHeight;
        return baseHeight + 14 + contentH + 10;
    }
    // Animierte Panel-Höhe
    property real panelHeight: targetHeight

    onTargetHeightChanged: panelHeight = targetHeight
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
        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: popup.sideMargin
            anchors.rightMargin: popup.sideMargin
            anchors.bottomMargin: 12
            spacing: 0

            // ---------- Streams-Sektion (nur wenn expanded) ----------
            Item {
                id: streamsSection

                width: parent.width
                height: VolumeSliderState.expanded ? streamsInner.implicitHeight : 0
                clip: true
                visible: height > 0.5

                Column {
                    id: streamsInner

                    width: parent.width
                    topPadding: 4
                    bottomPadding: 8
                    spacing: 2

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: WalColors.withAlpha(WalColors.color7, 0.1)
                        // Divider oben hat Abstand
                        anchors.topMargin: 4
                    }

                    // Leerer Zustand
                    Item {
                        width: parent.width
                        height: VolumeSliderState.streams.length === 0 ? 40 : 0
                        visible: height > 0.5

                        Text {
                            anchors.centerIn: parent
                            text: "No active audio streams"
                            color: WalColors.withAlpha(WalColors.color7, 0.4)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }

                    }

                    // Stream-Zeilen
                    Repeater {
                        model: VolumeSliderState.streams

                        delegate: Item {
                            id: streamRowItem

                            required property var modelData

                            width: streamsInner.width
                            height: popup.streamRowHeight

                            // Icon
                            Item {
                                id: iconBox

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24

                                Image {
                                    id: streamIcon

                                    anchors.fill: parent
                                    source: streamRowItem.modelData.icon !== "" ? "image://icon/" + streamRowItem.modelData.icon : ""
                                    sourceSize: Qt.size(48, 48)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                // Fallback-Kreis
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: WalColors.withAlpha(WalColors.color4, 0.15)
                                    visible: streamIcon.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: "♪"
                                        color: WalColors.color4
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                    }

                                }

                            }

                            // Mute-Toggle rechts
                            Item {
                                id: muteBox

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22

                                Text {
                                    anchors.centerIn: parent
                                    text: streamRowItem.modelData.muted ? "󰖁" : (streamRowItem.modelData.volume < 0.5 ? "󰕿" : "󰕾")
                                    color: streamRowItem.modelData.muted ? WalColors.color1 : (muteStreamMouse.containsMouse ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.6))
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }

                                    }

                                }

                                MouseArea {
                                    id: muteStreamMouse

                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: VolumeSliderState.toggleStreamMute(streamRowItem.modelData.id)
                                }

                            }

                            // Name
                            Text {
                                id: nameText

                                anchors.left: iconBox.right
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 120
                                text: streamRowItem.modelData.name
                                color: WalColors.color7
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            // Slider
                            Item {
                                id: streamSlider

                                readonly property real v: Math.max(0, Math.min(streamRowItem.modelData.volume, 1))

                                anchors.left: nameText.right
                                anchors.leftMargin: 10
                                anchors.right: muteBox.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 20

                                Rectangle {
                                    id: streamTrack

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 6
                                    radius: 3
                                    color: WalColors.withAlpha(WalColors.color7, 0.1)

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width * streamSlider.v
                                        height: parent.height
                                        radius: parent.radius
                                        color: streamRowItem.modelData.muted ? WalColors.withAlpha(WalColors.color1, 0.6) : WalColors.color4
                                    }

                                }

                                Rectangle {
                                    width: 11
                                    height: 11
                                    radius: 5.5
                                    color: WalColors.color7
                                    border.width: 1.5
                                    border.color: WalColors.withAlpha(WalColors.color0, 0.9)
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: streamTrack.width * streamSlider.v - width / 2
                                    scale: streamVolMouse.pressed ? 1.25 : (streamVolMouse.containsMouse ? 1.1 : 1)

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 1.3
                                        }

                                    }

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 60
                                            easing.type: Easing.OutQuad
                                        }

                                    }

                                }

                                MouseArea {
                                    id: streamVolMouse

                                    function update(me) {
                                        VolumeSliderState.setStreamVolume(streamRowItem.modelData.id, Math.max(0, Math.min(me.x / width, 1)));
                                        VolumeSliderState.restartAutoClose();
                                    }

                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPositionChanged: (mouse) => {
                                        if (pressed)
                                            update(mouse);

                                    }
                                    onPressed: (mouse) => {
                                        update(mouse);
                                    }
                                }

                            }

                        }

                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // ---------- Top-Row (Orb + Slider + %) ----------
            Row {
                id: topRow

                width: parent.width
                height: popup.baseHeight - 24
                spacing: 16

                VolumeOrb {
                    id: audioOrb

                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: VolumeSliderState.toggleSystemMute()
                    onRightClicked: VolumeSliderState.toggleExpanded()
                }

                // Slider (System-Volume)
                Item {
                    id: sliderArea

                    readonly property real v: Math.max(0, Math.min(VolumeSliderState.systemVolume, 1))
                    readonly property bool dragging: volMouse.pressed
                    readonly property bool hot: dragging || volMouse.containsMouse

                    anchors.verticalCenter: parent.verticalCenter
                    width: topRow.width - audioOrb.width - percentLabel.width - 2 * topRow.spacing
                    height: 34

                    Rectangle {
                        id: track

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 10
                        radius: height / 2
                        color: WalColors.withAlpha(WalColors.color7, 0.1)

                        Repeater {
                            model: 4

                            delegate: Rectangle {
                                readonly property real pos: (index + 1) / 5

                                x: track.width * pos - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1.5
                                height: 1.5
                                radius: 1
                                color: WalColors.withAlpha(WalColors.color7, 0.3)
                            }

                        }

                    }

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
                                color: WalColors.withAlpha(WalColors.color4, 0.7)
                            }

                            GradientStop {
                                position: 1
                                color: WalColors.color4
                            }

                        }

                    }

                    Rectangle {
                        anchors.verticalCenter: track.verticalCenter
                        x: track.width * sliderArea.v - width / 2
                        width: 26
                        height: 26
                        radius: width / 2
                        color: WalColors.color4
                        opacity: sliderArea.hot ? 0.3 : 0.1
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

                    Rectangle {
                        id: handle

                        anchors.verticalCenter: parent.verticalCenter
                        x: track.width * sliderArea.v - width / 2
                        width: 22
                        height: 22
                        radius: width / 2
                        color: WalColors.color7
                        border.width: 2
                        border.color: WalColors.withAlpha(WalColors.color0, 0.9)
                        scale: sliderArea.dragging ? 1.15 : (volMouse.containsMouse ? 1.08 : 1)

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            color: WalColors.color4
                            opacity: 0.85
                        }

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

                    Text {
                        anchors.centerIn: handle
                        text: Math.round(sliderArea.v * 100)
                        color: WalColors.color0
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
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

                    MouseArea {
                        id: volMouse

                        function updateVol(me) {
                            VolumeSliderState.setSystemVolume(Math.max(0, Math.min(me.x / width, 1)));
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

                // Prozent rechts
                Item {
                    id: percentLabel

                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    height: 26

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -4
                        text: Math.round(sliderArea.v * 100)
                        color: WalColors.color4
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                    }

                    Text {
                        anchors.left: parent.horizontalCenter
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 4
                        text: "%"
                        color: WalColors.withAlpha(WalColors.color4, 0.5)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                    }

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
            y: (1 - wrapper.shown) * 24
        }

        Behavior on shown {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }

        }

    }

    Behavior on panelHeight {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }

    }

}
