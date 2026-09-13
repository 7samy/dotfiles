import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
    id: dropdown

    required property var screen
    readonly property real cornerRadius: 20
    readonly property real menuWidth: 220
    readonly property real edgePadding: 8
    readonly property real coverSize: 120

    implicitWidth: menuWidth + 2 * cornerRadius
    implicitHeight: content.implicitHeight + 24
    color: "transparent"
    exclusiveZone: -1
    anchors.top: true
    anchors.left: true

    margins {
        top: 40
        left: {
            const desired = AudioState.iconCenterX - implicitWidth / 2;
            return Math.max(edgePadding, Math.min(desired, screen.width - implicitWidth - edgePadding));
        }
    }

    Item {
        id: container

        width: parent.width
        height: AudioState.dropdownOpen ? dropdown.implicitHeight : 0
        clip: true

        RoundedDropShape {
            anchors.top: parent.top
            cornerRadius: dropdown.cornerRadius
            menuWidth: dropdown.menuWidth
            menuHeight: dropdown.implicitHeight
        }

        Column {
            id: content

            spacing: 12
            topPadding: 16

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }

            Item {
                id: coverArea

                readonly property real ringPadding: 10
                readonly property real ringThickness: 3
                readonly property real outerSize: coverSize + 2 * (ringPadding + ringThickness)
                readonly property real ringRadius: outerSize / 2 - ringThickness / 2
                readonly property real trackLength: AudioState.length > 0 ? AudioState.length : 0
                readonly property real displayProgress: dragging ? dragProgress : (trackLength > 0 ? Math.max(0, Math.min(1, livePosition / trackLength)) : 0)
                property real livePosition: AudioState.position
                property bool dragging: false
                property real dragProgress: 0

                width: outerSize
                height: outerSize
                anchors.horizontalCenter: parent.horizontalCenter

                Timer {
                    interval: 250
                    repeat: true
                    triggeredOnStart: true
                    running: AudioState.hasPlayer && AudioState.dropdownOpen
                    onTriggered: coverArea.livePosition = AudioState.position
                }

                // Beide Ringe in einen gemeinsamen Layer packen.
                // layer.samples = 8 aktiviert echtes Multisampling (MSAA),
                // wodurch die Kurven glatt statt pixelig erscheinen.
                Item {
                    id: ringLayer

                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 8
                    layer.smooth: true

                    // Hintergrund-Ring (ungespielter Teil)
                    Shape {
                        anchors.fill: parent
                        // antialiasing hier nicht nötig, da layer.samples übernimmt.
                        // Schadet aber auch nicht und hilft, wenn jemand den Layer entfernt.
                        antialiasing: true
                        smooth: true
                        visible: AudioState.hasPlayer

                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.12)
                            strokeWidth: coverArea.ringThickness
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: coverArea.outerSize / 2
                                centerY: coverArea.outerSize / 2
                                radiusX: coverArea.ringRadius
                                radiusY: coverArea.ringRadius
                                startAngle: -90
                                sweepAngle: 359.999
                            }

                        }

                    }

                    // Fortschritts-Ring
                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        smooth: true
                        visible: AudioState.hasPlayer

                        ShapePath {
                            strokeColor: WalColors.color4
                            strokeWidth: coverArea.ringThickness
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: coverArea.outerSize / 2
                                centerY: coverArea.outerSize / 2
                                radiusX: coverArea.ringRadius
                                radiusY: coverArea.ringRadius
                                startAngle: -90
                                sweepAngle: Math.max(0.001, 360 * coverArea.displayProgress)
                            }

                        }

                    }

                }

                // Griff auf dem Ring
                Rectangle {
                    id: seekHandle

                    readonly property real angleRad: (-90 + 360 * coverArea.displayProgress) * Math.PI / 180

                    visible: AudioState.hasPlayer
                    width: coverArea.ringThickness + 6
                    height: width
                    radius: width / 2
                    color: WalColors.color0
                    border.color: WalColors.color4
                    border.width: 2
                    scale: coverArea.dragging ? 1.3 : 1
                    x: coverArea.outerSize / 2 + coverArea.ringRadius * Math.cos(angleRad) - width / 2
                    y: coverArea.outerSize / 2 + coverArea.ringRadius * Math.sin(angleRad) - height / 2

                    Behavior on scale {
                        Anim {
                            duration: Appearance.anim.durations.fast
                        }

                    }

                }

                // Eigentliches Cover, mittig im vergrößerten Ring-Bereich
                Item {
                    id: artContainer

                    width: coverSize
                    height: coverSize
                    anchors.centerIn: parent

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#111111"
                    }

                    Image {
                        id: coverImg

                        anchors.centerIn: parent
                        width: coverSize * 0.9
                        height: width
                        source: AudioState.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }

                    Rectangle {
                        id: maskShape

                        width: coverImg.width
                        height: coverImg.height
                        radius: width / 2
                        visible: false
                        anchors.centerIn: parent
                    }

                    OpacityMask {
                        id: coverMask

                        anchors.centerIn: parent
                        width: coverImg.width
                        height: coverImg.height
                        source: coverImg
                        maskSource: maskShape
                        visible: AudioState.artUrl !== "" && !AudioState.showWebsiteIcon
                    }

                    Image {
                        anchors.centerIn: parent
                        width: coverSize * 0.5
                        height: width
                        source: AudioState.showWebsiteIcon ? AudioState.websiteIconSource : ""
                        visible: AudioState.showWebsiteIcon && AudioState.websiteIconSource !== ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: (AudioState.showWebsiteIcon && AudioState.websiteIconSource === "") || (!AudioState.showWebsiteIcon && AudioState.artUrl === "")
                        text: "󰝚"
                        color: WalColors.color4
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 28
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        radius: 5
                        color: WalColors.color0
                        visible: AudioState.artUrl !== "" && !AudioState.showWebsiteIcon
                    }

                }

                // Drag-/Klick-Bereich für den Ring
                MouseArea {
                    id: seekArea

                    function angleFromPoint(px, py) {
                        const cx = coverArea.outerSize / 2;
                        const cy = coverArea.outerSize / 2;
                        let deg = Math.atan2(py - cy, px - cx) * 180 / Math.PI + 90;
                        if (deg < 0)
                            deg += 360;

                        return deg;
                    }

                    function applySeek(px, py) {
                        const progress = angleFromPoint(px, py) / 360;
                        coverArea.dragProgress = progress;
                        AudioState.seekTo(progress * coverArea.trackLength);
                    }

                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    enabled: AudioState.hasPlayer && coverArea.trackLength > 0
                    onPressed: (mouse) => {
                        const cx = coverArea.outerSize / 2;
                        const cy = coverArea.outerSize / 2;
                        const dist = Math.hypot(mouse.x - cx, mouse.y - cy);
                        if (Math.abs(dist - coverArea.ringRadius) > coverArea.ringThickness * 3) {
                            mouse.accepted = false;
                            return ;
                        }
                        coverArea.dragging = true;
                        applySeek(mouse.x, mouse.y);
                    }
                    onPositionChanged: (mouse) => {
                        if (coverArea.dragging)
                            applySeek(mouse.x, mouse.y);

                    }
                    onReleased: coverArea.dragging = false
                    onCanceled: coverArea.dragging = false
                }

            }

            Text {
                width: menuWidth - 28
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                text: AudioState.hasPlayer ? AudioState.title : "Kein Player aktiv"
                color: WalColors.color2
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                width: menuWidth - 28
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                text: AudioState.artist
                color: WalColors.color4
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                elide: Text.ElideRight
                visible: text !== ""
            }

            Row {
                spacing: 24
                anchors.horizontalCenter: parent.horizontalCenter
                bottomPadding: 12

                Text {
                    text: "󰒮"
                    color: prevMouse.containsMouse ? WalColors.color4 : WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    scale: prevMouse.containsMouse ? 1.3 : 1
                    transformOrigin: Item.Center

                    MouseArea {
                        id: prevMouse

                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AudioState.previous()
                    }

                    Behavior on scale {
                        Anim {
                            duration: Appearance.anim.durations.fast
                        }

                    }

                }

                Text {
                    text: AudioState.isPlaying ? "󰏤" : "󰐊"
                    color: playMouse.containsMouse ? WalColors.color4 : WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    scale: playMouse.containsMouse ? 1.3 : 1
                    transformOrigin: Item.Center

                    MouseArea {
                        id: playMouse

                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AudioState.togglePlay()
                    }

                    Behavior on scale {
                        Anim {
                            duration: Appearance.anim.durations.fast
                        }

                    }

                }

                Text {
                    text: "󰒭"
                    color: nextMouse.containsMouse ? WalColors.color4 : WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    scale: nextMouse.containsMouse ? 1.3 : 1
                    transformOrigin: Item.Center

                    MouseArea {
                        id: nextMouse

                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AudioState.next()
                    }

                    Behavior on scale {
                        Anim {
                            duration: Appearance.anim.durations.fast
                        }

                    }

                }

            }

        }

        Timer {
            interval: 16
            repeat: true
            running: AudioState.isPlaying && AudioState.dropdownOpen && coverMask.visible
            onTriggered: {
                if (coverMask.visible) {
                    coverMask.rotation += 0.75;
                    if (coverMask.rotation >= 360)
                        coverMask.rotation -= 360;

                }
            }
        }

        Behavior on height {
            Anim {
            }

        }

    }

    HoverHandler {
        id: dropdownHover

        onHoveredChanged: {
            AudioState.dropdownHovered = hovered;
            AudioState.updateHoverTimer();
        }
    }

}
