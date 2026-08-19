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

        // HoverHandler für das gesamte Dropdown – hält es offen
        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    AudioState.stopHideTimer();
                    AudioState.dropdownOpen = true;
                } else {
                    AudioState.startHideTimer();
                }
            }
        }

        Shape {
            width: parent.width
            height: dropdown.implicitHeight
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
                    y: dropdown.implicitHeight - cornerRadius
                }

                PathArc {
                    x: 2 * cornerRadius
                    y: dropdown.implicitHeight
                    radiusX: cornerRadius
                    radiusY: cornerRadius
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: cornerRadius + menuWidth - cornerRadius
                    y: dropdown.implicitHeight
                }

                PathArc {
                    x: cornerRadius + menuWidth
                    y: dropdown.implicitHeight - cornerRadius
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

                // Albumcover (rotierende Schallplatte) – nur für Nicht-Browser-Player
                OpacityMask {
                    id: coverMask

                    anchors.centerIn: parent
                    width: coverImg.width
                    height: coverImg.height
                    source: coverImg
                    maskSource: maskShape
                    visible: AudioState.artUrl !== "" && !AudioState.showWebsiteIcon
                }

                // SVG-Icon für Browser (YouTube, Twitch, TikTok, Firefox, Chrome)
                Image {
                    anchors.centerIn: parent
                    width: coverSize * 0.5
                    height: width
                    source: AudioState.showWebsiteIcon ? AudioState.websiteIconSource : ""
                    visible: AudioState.showWebsiteIcon && AudioState.websiteIconSource !== ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                // Fallback-Text (generisches Musik-Icon), wenn weder Cover noch SVG verfügbar
                Text {
                    anchors.centerIn: parent
                    visible: (AudioState.showWebsiteIcon && AudioState.websiteIconSource === "") || (!AudioState.showWebsiteIcon && AudioState.artUrl === "")
                    text: "󰝚"
                    color: WalColors.color4
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 28
                }

                // Kleiner Mittelpunkt – nur wenn das Cover sichtbar ist
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

                Text {
                    text: "󰒮"
                    color: prevHoverHandler.hovered ? WalColors.color4 : WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    scale: prevHoverHandler.hovered ? 1.3 : 1
                    transformOrigin: Item.Center

                    HoverHandler {
                        id: prevHoverHandler

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: AudioState.previous()
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Text {
                    text: AudioState.isPlaying ? "󰏤" : "󰐊"
                    color: playHoverHandler.hovered ? WalColors.color4 : WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    scale: playHoverHandler.hovered ? 1.3 : 1
                    transformOrigin: Item.Center

                    HoverHandler {
                        id: playHoverHandler

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: AudioState.togglePlay()
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Text {
                    text: "󰒭"
                    color: nextHoverHandler.hovered ? WalColors.color4 : WalColors.color2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    scale: nextHoverHandler.hovered ? 1.3 : 1
                    transformOrigin: Item.Center

                    HoverHandler {
                        id: nextHoverHandler

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: AudioState.next()
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

        // Timer für die Rotation des Albumcovers – läuft nur, wenn Cover sichtbar und Wiedergabe aktiv
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

}
