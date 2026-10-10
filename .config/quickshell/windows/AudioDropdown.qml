import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io

PanelWindow {
    id: dropdown

    // Oeffnen: Hoehen-Animation wie bisher (Behavior on height).
    // Schliessen: Huelle bleibt an der Bar haengen und schrumpft von unten
    // nach oben (Fenster behaelt seine Groesse), nur das Cover blendet aus.
    property bool expanded: false
    property bool heightAnimOn: false
    property real closeFactor: 1
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
    readonly property real cavaGamma: 0.3
    readonly property real cavaNoiseFloor: 0.05
    property var cavaValues: new Array(cavaBars).fill(0)
    readonly property real fullHeight: content.implicitHeight + 24

    implicitWidth: menuWidth + 2 * cornerRadius
    implicitHeight: container.height
    color: "transparent"
    exclusiveZone: -1
    anchors.top: true
    anchors.left: true

    Connections {
        function onDropdownOpenChanged() {
            if (AudioState.dropdownOpen) {
                closeAnim.stop();
                dropdown.heightAnimOn = true;
                dropdown.expanded = true;
                if (dropdown.closeFactor !== 1 || coverArea.opacity !== 1)
                    reopenAnim.restart();

            } else if (dropdown.expanded) {
                reopenAnim.stop();
                closeAnim.restart();
            }
        }

        target: AudioState
    }

    ParallelAnimation {
        id: reopenAnim

        NumberAnimation {
            target: dropdown
            property: "closeFactor"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: coverArea
            property: "opacity"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }

    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation {
                target: dropdown
                property: "closeFactor"
                to: 0
                duration: 280
                easing.type: Easing.InOutCubic
            }

            NumberAnimation {
                target: coverArea
                property: "opacity"
                to: 0
                duration: 280
                easing.type: Easing.InOutQuad
            }

        }

        ScriptAction {
            script: {
                dropdown.heightAnimOn = false;
                dropdown.expanded = false;
                dropdown.closeFactor = 1;
                coverArea.opacity = 1;
            }
        }

    }

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
        height: dropdown.expanded ? dropdown.fullHeight : 0
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

        Item {
            id: body

            width: parent.width
            height: dropdown.fullHeight * dropdown.closeFactor
            clip: true

            RoundedDropShape {
                anchors.top: parent.top
                cornerRadius: dropdown.cornerRadius
                menuWidth: dropdown.menuWidth
                menuHeight: Math.max(2 * dropdown.cornerRadius, dropdown.fullHeight * dropdown.closeFactor)
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
                                        enabled: dropdown.heightAnimOn

                                        Anim {
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

                // ==================== Playback Controls ====================
                Row {
                    spacing: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 4

                    // ---------- Previous ----------
                    Item {
                        width: 36
                        height: 36
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: WalColors.color4
                            opacity: prevMouse.containsMouse ? 0.16 : 0
                            scale: prevMouse.containsMouse ? 1 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.2
                                }

                            }

                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒮"
                            color: prevMouse.containsMouse ? WalColors.color4 : WalColors.color2
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            scale: prevMouse.containsMouse ? 1.15 : 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        MouseArea {
                            id: prevMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioState.previous()
                        }

                    }

                    // ---------- Play / Pause (Accent-Kreis mit Glow) ----------
                    Item {
                        width: 46
                        height: 46
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 6
                            height: parent.height + 6
                            radius: width / 2
                            color: WalColors.color4
                            opacity: playMouse.containsMouse ? 0.35 : 0.15
                            layer.enabled: true
                            layer.samples: 4

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 220
                                }

                            }

                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: WalColors.withAlpha(WalColors.color4, playMouse.containsMouse ? 0.28 : 0.18)
                            border.width: 1.5
                            border.color: WalColors.withAlpha(WalColors.color4, playMouse.containsMouse ? 0.9 : 0.5)
                            scale: playMouse.pressed ? 0.94 : (playMouse.containsMouse ? 1.06 : 1)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.3
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 200
                                }

                            }

                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: AudioState.isPlaying ? 0 : 2
                            text: AudioState.isPlaying ? "󰏤" : "󰐊"
                            color: WalColors.color4
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                        }

                        MouseArea {
                            id: playMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioState.togglePlay()
                        }

                    }

                    // ---------- Next ----------
                    Item {
                        width: 36
                        height: 36
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: WalColors.color4
                            opacity: nextMouse.containsMouse ? 0.16 : 0
                            scale: nextMouse.containsMouse ? 1 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.2
                                }

                            }

                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒭"
                            color: nextMouse.containsMouse ? WalColors.color4 : WalColors.color2
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            scale: nextMouse.containsMouse ? 1.15 : 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        MouseArea {
                            id: nextMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioState.next()
                        }

                    }

                }

                // ==================== Volume Slider ====================
                Row {
                    width: menuWidth - 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    topPadding: 6
                    bottomPadding: 10
                    visible: AudioState.hasPlayer

                    // ---------- Mute / Volume Icon ----------
                    Item {
                        readonly property bool isMuted: AudioState.volume <= 0.01
                        readonly property bool isLow: AudioState.volume > 0.01 && AudioState.volume < 0.5

                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: parent.isMuted ? "󰖁" : (parent.isLow ? "󰕿" : "󰕾")
                            color: (volumeIconMouse.containsMouse || parent.isMuted) ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.7)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                        }

                        MouseArea {
                            id: volumeIconMouse

                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioState.setVolume(AudioState.volume > 0.01 ? 0 : 0.5)
                        }

                    }

                    // ---------- Slider ----------
                    Item {
                        id: sliderArea

                        readonly property real v: Math.max(0, Math.min(AudioState.volume, 1))

                        width: parent.width - 30
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: volTrack

                            width: parent.width
                            height: 5
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: volTrack.width * sliderArea.v
                                height: parent.height
                                radius: parent.radius
                                color: WalColors.color4
                            }

                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: (volTrack.width - width) * sliderArea.v
                            width: 22
                            height: 22
                            radius: width / 2
                            color: WalColors.color4
                            opacity: (volMouse.pressed || volMouse.containsMouse) ? 0.35 : 0
                            layer.enabled: true
                            layer.samples: 4

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                }

                            }

                        }

                        Rectangle {
                            id: volThumb

                            width: 13
                            height: 13
                            radius: width / 2
                            color: WalColors.color0
                            border.color: WalColors.color4
                            border.width: 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: (volTrack.width - width) * sliderArea.v
                            scale: volMouse.pressed ? 1.35 : (volMouse.containsMouse ? 1.15 : 1)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.4
                                }

                            }

                        }

                        Text {
                            id: percentText

                            readonly property bool visibleNow: volMouse.pressed || volMouse.containsMouse

                            x: {
                                const cx = (volTrack.width - width / 2) * sliderArea.v - width / 2;
                                return Math.max(-4, Math.min(parent.width - width + 4, cx));
                            }
                            y: -14
                            text: Math.round(sliderArea.v * 100) + "%"
                            color: WalColors.color4
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.bold: true
                            opacity: visibleNow ? 1 : 0
                            visible: opacity > 0.01
                            scale: visibleNow ? 1 : 0.85

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.3
                                }

                            }

                        }

                        MouseArea {
                            id: volMouse

                            function updateVol(mouseEvent) {
                                const val = Math.max(0, Math.min(mouseEvent.x / width, 1));
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
            enabled: dropdown.heightAnimOn

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
