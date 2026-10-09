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
    // cava liefert cavaBars Werte; sie werden links/rechts gespiegelt,
    // dadurch entstehen barCount = 2 * cavaBars Balken rund ums Cover.
    readonly property int cavaBars: 25
    readonly property int barCount: cavaBars * 2
    readonly property real barWidth: 3
    readonly property real barGap: 3 // Abstand zwischen Cover und Balken
    readonly property real barMinLen: 3 // Balkenlaenge bei Stille
    readonly property real barMaxLen: 25 // Balkenlaenge bei voller Lautstaerke
    // Empfindlichkeit: < 1 = empfindlicher (kleine Pegel werden angehoben),
    // 1.0 = linear, 0.5 = Wurzel. Zum Justieren hier aendern.
    readonly property real cavaGamma: 0.5
    // Noise-Floor: Werte unterhalb dieses Pegels werden als 0 behandelt.
    // cava liefert bei Stille oft 2-5 statt 0.
    readonly property real cavaNoiseFloor: 0.03
    // Aktuelle Pegel 0..1 (Index 0 = tiefste Frequenz)
    property var cavaValues: new Array(cavaBars).fill(0)

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

        // cava laeuft nur, solange das Menue offen ist und Musik spielt.
        // Die Config wird in eine Datei geschrieben und cava per exec gestartet,
        // damit beim Stoppen wirklich cava (und kein Shell-Wrapper) beendet wird.
        Process {
            id: cavaProcess

            running: AudioState.dropdownOpen && AudioState.isPlaying
            command: ["sh", "-c", "printf '%s\\n' '[general]' 'bars=" + dropdown.cavaBars + "' 'framerate=40' 'sleep_timer=3' '[output]' 'method=raw' 'raw_target=/dev/stdout' 'data_format=ascii' 'ascii_max_range=100' 'channels=mono' > /tmp/qs-cava-audio.conf && exec cava -p /tmp/qs-cava-audio.conf"]
            onRunningChanged: {
                if (!running)
                    dropdown.cavaValues = new Array(dropdown.cavaBars).fill(0);

            }

            stdout: SplitParser {
                // Eine Zeile pro Frame: "12;45;7;...;"
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
            menuHeight: dropdown.implicitHeight
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

                // Kreisfoermiger Visualizer: Balken starten direkt am Coverrand
                Item {
                    id: visualizerLayer

                    anchors.fill: parent
                    visible: AudioState.hasPlayer
                    layer.enabled: true
                    layer.samples: 8
                    layer.smooth: true

                    Repeater {
                        model: dropdown.barCount

                        delegate: Item {
                            // Roh-Wert von cava, auf 0..1 begrenzt
                            readonly property real rawLevel: {
                                const v = dropdown.cavaValues[index < dropdown.cavaBars ? index : dropdown.barCount - 1 - index] ?? 0;
                                return Math.max(0, Math.min(1, v));
                            }
                            // Noise-Floor wegschneiden und Rest auf 0..1 neu skalieren
                            readonly property real cleanedLevel: {
                                const nf = dropdown.cavaNoiseFloor;
                                if (rawLevel <= nf)
                                    return 0;

                                return Math.min(1, (rawLevel - nf) / (1 - nf));
                            }
                            // Gamma-Korrektur: < 1 = empfindlicher
                            readonly property real level: Math.pow(cleanedLevel, dropdown.cavaGamma)

                            x: coverArea.outerSize / 2
                            y: coverArea.outerSize / 2
                            width: 0
                            height: 0
                            // Tiefe Toene unten, hohe oben
                            rotation: 180 + (index + 0.5) * 360 / dropdown.barCount

                            Rectangle {
                                // unterer Rand haengt fest am Cover, nur die Laenge aendert sich
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

            // NEU: Lautstärke-Slider
            Row {
                width: menuWidth - 70
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                bottomPadding: 8
                visible: AudioState.hasPlayer // Nur anzeigen, wenn etwas läuft

                Item {
                    width: parent.width
                    height: 15
                    anchors.verticalCenter: parent.verticalCenter

                    // Hintergrund-Linie
                    Rectangle {
                        id: volTrack

                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.12)
                        anchors.verticalCenter: parent.verticalCenter

                        // Gefüllte Linie (Fortschritt)
                        Rectangle {
                            width: Math.max(0, Math.min(AudioState.volume, 1)) * parent.width
                            height: parent.height
                            radius: 2
                            color: WalColors.color4
                        }

                    }

                    // Handle/Punkt für den Slider
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: WalColors.color0
                        border.color: WalColors.color4
                        border.width: 2
                        anchors.verticalCenter: parent.verticalCenter
                        // Position basierend auf dem Volume berechnen
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
                        anchors.margins: -6 // Etwas mehr Klickfläche
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
