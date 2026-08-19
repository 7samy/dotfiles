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
    readonly property real maxMenuHeight: content.implicitHeight + 24

    implicitWidth: menuWidth + 2 * cornerRadius
    implicitHeight: container.height
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
        height: AudioState.dropdownOpen ? dropdown.maxMenuHeight : 0
        clip: true

        Shape {
            width: parent.width
            height: dropdown.maxMenuHeight
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
                    y: dropdown.maxMenuHeight - cornerRadius
                }

                PathArc {
                    x: 2 * cornerRadius
                    y: dropdown.maxMenuHeight
                    radiusX: cornerRadius
                    radiusY: cornerRadius
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: cornerRadius + menuWidth - cornerRadius
                    y: dropdown.maxMenuHeight
                }

                PathArc {
                    x: cornerRadius + menuWidth
                    y: dropdown.maxMenuHeight - cornerRadius
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

        Connections {
            function onColorsUpdated() {
                mainPath.fillColor = "transparent";
                redrawTimer.start();
            }

            target: WalColors
        }

        Timer {
            id: redrawTimer

            interval: 10
            onTriggered: mainPath.fillColor = WalColors.withAlpha(WalColors.color0, 0.9)
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
                width: coverSize
                height: coverSize
                anchors.horizontalCenter: parent.horizontalCenter

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

                // Zurück-Button
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
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // Play / Pause-Button
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
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // Weiter-Button
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
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
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
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutCubic
            }

        }

    }

    // Haupt-MouseArea für das gesamte Menü – jetzt ÜBER allen anderen Elementen
    MouseArea {
        anchors.fill: parent
        anchors.topMargin: 6
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: {
            AudioState.dropdownHovered = containsMouse;
            AudioState.updateHoverTimer();
        }
    }

}
