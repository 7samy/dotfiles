import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io

PanelWindow {
    id: dropdown

    required property var screen
    readonly property real cornerRadius: 20
    readonly property real menuWidth: 220
    readonly property real edgePadding: 8
    readonly property real coverSize: 120
    // ---- Visualizer (cava) ----
    readonly property int cavaBars: 20
    readonly property int barCount: cavaBars * 2
    readonly property real barWidth: 4
    readonly property real barGap: 3
    readonly property real barMinLen: 5
    readonly property real barMaxLen: 25
    readonly property real cavaGamma: 0.45
    readonly property real cavaNoiseFloor: 0.05
    property var cavaValues: new Array(cavaBars).fill(0)
    // Volle Zielhöhe – wird für Container und Panel-Höhe gebraucht.
    readonly property real fullHeight: content.implicitHeight + 24

    implicitWidth: menuWidth + 2 * cornerRadius
    // Panel folgt der Container-Höhe. Bei geschlossenem Menü -> 0 px hoch,
    // dadurch blockiert es keinen Hover für andere Dropdowns.
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
        height: AudioState.dropdownOpen ? dropdown.fullHeight : 0
        clip: true

        Process {
            id: cavaProcess

            running: AudioState.dropdownOpen && AudioState.isPlaying
            command: ["sh", "-c", "printf '%s\\n' '[general]' 'bars=" + dropdown.cavaBars + "' 'framerate=40' 'sleep_timer=3' '[output]' 'method=raw' 'raw_target=/dev/stdout' 'data_format=ascii' 'ascii_max_range=100' 'channels=mono' > /tmp/qs-cava-audio.conf && exec cava -p /tmp/qs-cava-audio.conf"]
            onRunningChanged: {
                if (!running)
                    dropdown.cavaValues = new Array(dropdown.cavaBars).fill(0);

            }

            stdout: SplitParser {
                onRead: (line) => {
                    const parts = line.split(";");
                    const values = [];
                    for (const p of parts) {
                        if (p !== "")
                            values.push(Number(p) / 100);

                    }
                    if (values.length >= dropdown.cavaBars)
                        dropdown.cavaValues = values;

                }
            }

        }

        RoundedDropShape {
            anchors.top: parent.top
            cornerRadius: dropdown.cornerRadius
            menuWidth: dropdown.menuWidth
            menuHeight: dropdown.fullHeight
        }

        Column {
            id: content

            spacing: 6
            topPadding: 16

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }

            Item {
                id: coverArea

                readonly property real outerSize: coverSize + 2 * (dropdown.barGap + dropdown.barMaxLen)

                width: outerSize
                height: outerSize
                anchors.horizontalCenter: parent.horizontalCenter

                Item {
                    id: visualizerLayer

                    anchors.fill: parent
                    visible: AudioState.hasPlayer
                    layer.enabled: true
                    layer.samples: 4
                    layer.smooth: true

                    Repeater {
                        model: dropdown.barCount

                        delegate: Item {
                            readonly property real rawLevel: {
                                const v = dropdown.cavaValues[index < dropdown.cavaBars ? index : dropdown.barCount - 1 - index] ?? 0;
                                return Math.max(0, Math.min(1, v));
                            }
                            readonly property real cleanedLevel: {
                                const nf = dropdown.cavaNoiseFloor;
                                if (rawLevel <= nf)
                                    return 0;

                                return Math.min(1, (rawLevel - nf) / (1 - nf));
                            }
                            readonly property real level: Math.pow(cleanedLevel, dropdown.cavaGamma)

                            x: coverArea.outerSize / 2
                            y: coverArea.outerSize / 2
                            width: 0
                            height: 0
                            rotation: 180 + (index + 0.5) * 360 / dropdown.barCount

                            Rectangle {
                                anchors.bottom: parent.top
                                anchors.bottomMargin: coverSize / 2 + dropdown.barGap
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: dropdown.barWidth
                                height: dropdown.barMinLen + parent.level * (dropdown.barMaxLen - dropdown.barMinLen)
                                radius: width / 2
                                antialiasing: true
                                color: WalColors.color4
                                opacity: 0.45 + 0.55 * parent.cleanedLevel

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 60
                                        easing.type: Easing.OutQuad
                                    }

                                }

                            }

                        }

                    }

                }

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
                        // Cover auf 200x200 runterskalieren statt in
                        // Originalgroesse (oft 1000x1000) im RAM halten.
                        sourceSize: Qt.size(200, 200)
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
                        // Webseiten-Icon ist nur 60x60 -> 96x96 reicht mit Puffer.
                        sourceSize: Qt.size(96, 96)
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

            Row {
                width: menuWidth - 70
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                bottomPadding: 8
                visible: AudioState.hasPlayer

                Item {
                    width: parent.width
                    height: 15
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: volTrack

                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.12)
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: Math.max(0, Math.min(AudioState.volume, 1)) * parent.width
                            height: parent.height
                            radius: 2
                            color: WalColors.color4
                        }

                    }

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: WalColors.color0
                        border.color: WalColors.color4
                        border.width: 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(AudioState.volume, 1)) * volTrack.width - width / 2
                        scale: volMouse.pressed ? 1.3 : (volMouse.containsMouse ? 1.1 : 1)

                        Behavior on scale {
                            Anim {
                                duration: Appearance.anim.durations.fast
                            }

                        }

                    }

                    MouseArea {
                        id: volMouse

                        function updateVol(mouseEvent) {
                            let val = mouseEvent.x / width;
                            AudioState.setVolume(val);
                        }

                        anchors.fill: parent
                        anchors.margins: -6
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
