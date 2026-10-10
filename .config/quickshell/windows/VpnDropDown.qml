import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes
import Quickshell

PanelWindow {
    id: dropdown

    // Oeffnen: Hoehen-Animation wie bisher (Behavior on height).
    // Schliessen: Huelle bleibt an der Bar haengen und schrumpft von unten
    // nach oben (Fenster behaelt seine Groesse), nur der Globus blendet aus.
    property bool expanded: false
    property bool heightAnimOn: false
    property real closeFactor: 1
    // IP-Anzeige: standardmaessig maskiert, per Klick auf die Zeile
    // in Klartext umschaltbar. Reset beim Schliessen.
    property bool ipRevealed: false
    required property var screen
    readonly property real cornerRadius: 20
    readonly property real menuWidth: 200
    readonly property real edgePadding: 8
    readonly property real contentBottomPadding: 20
    readonly property real globeSize: 100
    readonly property real fullHeight: infoColumn.implicitHeight + contentBottomPadding + 24
    readonly property string countryCode: {
        const c = (VpnState.vpnCountry || "").trim();
        if (c.length === 2)
            return c.toLowerCase();

        if (c.length === 3)
            return c.toLowerCase().substring(0, 2);

        const map = {
            "united states": "us",
            "usa": "us",
            "germany": "de",
            "deutschland": "de",
            "netherlands": "nl",
            "niederlande": "nl",
            "japan": "jp",
            "united kingdom": "gb",
            "uk": "gb",
            "france": "fr",
            "frankreich": "fr",
            "switzerland": "ch",
            "schweiz": "ch",
            "austria": "at",
            "oesterreich": "at",
            "sweden": "se",
            "schweden": "se",
            "norway": "no",
            "norwegen": "no",
            "canada": "ca",
            "kanada": "ca",
            "australia": "au",
            "australien": "au",
            "singapore": "sg",
            "singapur": "sg"
        };
        return map[c.toLowerCase()] || "";
    }
    readonly property string flagSource: countryCode !== "" ? "../resources/flags/" + countryCode + ".svg" : ""
    // Status-Farbe: gruen bei verbunden, rot bei getrennt.
    readonly property color statusColor: VpnState.connected ? "#8fd18f" : "#e08c8c"

    // Ersetzt jede Ziffer durch '*', laesst Punkte stehen.
    // Aus "185.123.45.67" wird "***.***.**.**".
    function maskIp(ip) {
        if (!ip)
            return "";

        return String(ip).replace(/\d/g, "*");
    }

    implicitWidth: menuWidth + 2 * cornerRadius
    implicitHeight: container.height
    color: "transparent"
    exclusiveZone: -1
    anchors.top: true
    anchors.left: true

    Connections {
        function onDropdownOpenChanged() {
            if (VpnState.dropdownOpen) {
                closeAnim.stop();
                dropdown.heightAnimOn = true;
                dropdown.expanded = true;
                if (dropdown.closeFactor !== 1 || globe.opacity !== 1)
                    reopenAnim.restart();

            } else if (dropdown.expanded) {
                reopenAnim.stop();
                closeAnim.restart();
            }
        }

        target: VpnState
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
            target: globe
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
                target: globe
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
                globe.opacity = 1;
                // IP beim naechsten Oeffnen wieder verstecken
                dropdown.ipRevealed = false;
            }
        }

    }

    margins {
        top: 40
        left: {
            const desired = VpnState.iconCenterX - implicitWidth / 2;
            return Math.max(edgePadding, Math.min(desired, screen.width - implicitWidth - edgePadding));
        }
    }

    Item {
        id: container

        width: parent.width
        height: dropdown.expanded ? dropdown.fullHeight : 0
        clip: true

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
                id: infoColumn

                spacing: 14
                topPadding: 22

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    leftMargin: cornerRadius + 16
                    rightMargin: cornerRadius + 16
                }

                // ---------- Globe with flag ----------
                Item {
                    id: globe

                    width: dropdown.globeSize
                    height: dropdown.globeSize
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        anchors.centerIn: parent
                        width: globe.width + 12
                        height: globe.height + 12
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: dropdown.statusColor
                        opacity: 0.5

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.15
                                duration: 1600
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 0.55
                                duration: 1600
                                easing.type: Easing.InOutSine
                            }

                        }

                    }

                    Rectangle {
                        id: globeBg

                        anchors.centerIn: parent
                        width: globe.width
                        height: globe.height
                        radius: width / 2
                        color: WalColors.withAlpha(WalColors.color0, 0.6)
                        border.width: 1
                        border.color: WalColors.withAlpha(WalColors.color4, 0.35)
                    }

                    Image {
                        id: flagRaw

                        anchors.fill: globeBg
                        source: dropdown.flagSource
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                        asynchronous: true
                        sourceSize: Qt.size(dropdown.globeSize * 2, dropdown.globeSize * 2)
                        smooth: true
                    }

                    Rectangle {
                        id: globeMask

                        anchors.fill: globeBg
                        radius: width / 2
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: globeBg
                        source: flagRaw
                        maskSource: globeMask
                        visible: flagRaw.status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: flagRaw.status !== Image.Ready
                        text: "󰖟"
                        color: WalColors.color4
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 44
                    }

                    Shape {
                        anchors.fill: globeBg
                        antialiasing: true
                        smooth: true
                        visible: flagRaw.status === Image.Ready
                        opacity: 0.45
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.55)
                            strokeWidth: 1
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathMove {
                                x: globeBg.width / 2
                                y: 6
                            }

                            PathLine {
                                x: globeBg.width / 2
                                y: globeBg.height - 6
                            }

                        }

                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.4)
                            strokeWidth: 1
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathMove {
                                x: globeBg.width * 0.25
                                y: globeBg.height * 0.06
                            }

                            PathQuad {
                                controlX: globeBg.width * 0.15
                                controlY: globeBg.height / 2
                                x: globeBg.width * 0.25
                                y: globeBg.height * 0.94
                            }

                        }

                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.4)
                            strokeWidth: 1
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathMove {
                                x: globeBg.width * 0.75
                                y: globeBg.height * 0.06
                            }

                            PathQuad {
                                controlX: globeBg.width * 0.85
                                controlY: globeBg.height / 2
                                x: globeBg.width * 0.75
                                y: globeBg.height * 0.94
                            }

                        }

                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.45)
                            strokeWidth: 1
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathMove {
                                x: 6
                                y: globeBg.height / 2
                            }

                            PathLine {
                                x: globeBg.width - 6
                                y: globeBg.height / 2
                            }

                        }

                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.3)
                            strokeWidth: 1
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathMove {
                                x: globeBg.width * 0.08
                                y: globeBg.height * 0.28
                            }

                            PathQuad {
                                controlX: globeBg.width / 2
                                controlY: globeBg.height * 0.22
                                x: globeBg.width * 0.92
                                y: globeBg.height * 0.28
                            }

                        }

                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.3)
                            strokeWidth: 1
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathMove {
                                x: globeBg.width * 0.08
                                y: globeBg.height * 0.72
                            }

                            PathQuad {
                                controlX: globeBg.width / 2
                                controlY: globeBg.height * 0.78
                                x: globeBg.width * 0.92
                                y: globeBg.height * 0.72
                            }

                        }

                    }

                    Rectangle {
                        anchors.left: globeBg.left
                        anchors.top: globeBg.top
                        anchors.leftMargin: globeBg.width * 0.12
                        anchors.topMargin: globeBg.height * 0.12
                        width: globeBg.width * 0.35
                        height: width
                        radius: width / 2
                        color: "white"
                        opacity: 0.12
                        visible: flagRaw.status === Image.Ready
                    }

                }

                // ---------- Country name ----------
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: VpnState.vpnCountry !== "" ? VpnState.vpnCountry : "Not connected"
                    color: WalColors.color7
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                }

                // ---------- Status indicator ----------
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: dropdown.statusColor

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: VpnState.connected

                            NumberAnimation {
                                to: 1.3
                                duration: 1200
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                to: 1
                                duration: 1200
                                easing.type: Easing.InOutSine
                            }

                        }

                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: VpnState.connected ? "CONNECTED" : "DISCONNECTED"
                        color: dropdown.statusColor
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                    }

                }

                // ---------- Divider ----------
                Rectangle {
                    width: parent.width
                    height: 1
                    color: WalColors.withAlpha(WalColors.color7, 0.1)
                }

                // ---------- PROVIDER ----------
                Column {
                    width: parent.width
                    spacing: 2

                    Text {
                        text: "PROVIDER"
                        color: WalColors.withAlpha(WalColors.color7, 0.35)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 8
                        font.letterSpacing: 1.2
                    }

                    Text {
                        width: parent.width
                        text: VpnState.vpnOrg !== "" ? VpnState.vpnOrg : "—"
                        color: WalColors.color2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                }

                // ---------- IP (click to toggle mask) ----------
                Item {
                    id: ipSection

                    width: parent.width
                    height: ipColumn.implicitHeight

                    Column {
                        id: ipColumn

                        width: parent.width
                        spacing: 2

                        Text {
                            text: "IP ADDRESS"
                            color: WalColors.withAlpha(WalColors.color7, 0.35)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 8
                            font.letterSpacing: 1.2
                        }

                        Item {
                            width: parent.width
                            height: 14

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: dropdown.maskIp(VpnState.vpnIp !== "" ? VpnState.vpnIp : "—")
                                color: WalColors.withAlpha(WalColors.color2, 0.6)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.letterSpacing: 1
                                opacity: dropdown.ipRevealed ? 0 : 1

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: VpnState.vpnIp !== "" ? VpnState.vpnIp : "—"
                                color: WalColors.color2
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                opacity: dropdown.ipRevealed ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                        }

                    }

                    // Klick-Toggle über der ganzen Section
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dropdown.ipRevealed = !dropdown.ipRevealed
                    }

                }

            }

            HoverHandler {
                onHoveredChanged: {
                    VpnState.dropdownHovered = hovered;
                    if (hovered)
                        VpnState.dropdownOpen = true;

                    VpnState.updateHoverTimer();
                }
            }

        }

        Behavior on height {
            enabled: dropdown.heightAnimOn

            Anim {
            }

        }

    }

}
