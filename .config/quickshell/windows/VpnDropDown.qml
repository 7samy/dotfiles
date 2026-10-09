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
    // Erst danach wird die Hoehe ohne Animation auf 0 gesetzt.
    property bool expanded: false
    property bool heightAnimOn: false
    property real closeFactor: 1
    required property var screen
    readonly property real cornerRadius: 20
    readonly property real menuWidth: 200
    readonly property real edgePadding: 8
    readonly property real contentBottomPadding: 16
    readonly property real globeSize: 100
    // Volle Zielhöhe – Bezugsgröße für Container und Panel-Höhe.
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

    implicitWidth: menuWidth + 2 * cornerRadius
    // Panel folgt der Container-Höhe. Bei geschlossenem Menü -> 0 px hoch.
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
                // Hover waehrend des Schliessens: wieder aufklappen + Globus einblenden
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
            // Huelle (mit Rundungen an der Bar) schrumpft nach oben
            NumberAnimation {
                target: dropdown
                property: "closeFactor"
                to: 0
                duration: 280
                easing.type: Easing.InOutCubic
            }

            // nur der Globus blendet aus, der Rest des Menues bleibt
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
                dropdown.heightAnimOn = false; // erst Animation aus ...
                dropdown.expanded = false; // ... dann Hoehe auf 0
                dropdown.closeFactor = 1;
                globe.opacity = 1;
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
        // expanded (nicht dropdownOpen!), sonst schrumpft die Hoehe beim
        // Schliessen sofort und der Inhalt wird verzerrt.
        height: dropdown.expanded ? dropdown.fullHeight : 0
        clip: true

        // Huelle + Inhalt. Beim Oeffnen voll hoch (der Container clippt wie
        // bisher), beim Schliessen schrumpft sie samt Rundungen von unten.
        Item {
            id: body

            width: parent.width
            height: dropdown.fullHeight * dropdown.closeFactor
            clip: true

            RoundedDropShape {
                anchors.top: parent.top
                cornerRadius: dropdown.cornerRadius
                menuWidth: dropdown.menuWidth
                // mindestens 2 * Radius, sonst bricht die Pfad-Geometrie
                menuHeight: Math.max(2 * dropdown.cornerRadius, dropdown.fullHeight * dropdown.closeFactor)
            }

            Column {
                id: infoColumn

                spacing: 10
                topPadding: 18

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    leftMargin: cornerRadius + 14
                    rightMargin: cornerRadius + 14
                }

                Item {
                    id: globe

                    width: dropdown.globeSize
                    height: dropdown.globeSize
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        id: pulseRing

                        anchors.centerIn: parent
                        width: globe.width + 12
                        height: globe.height + 12
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: WalColors.color4
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
                        id: globeFlag

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

                Rectangle {
                    width: parent.width
                    height: 1
                    color: WalColors.withAlpha(WalColors.color7, 0.15)
                }

                Repeater {
                    model: [{
                        "icon": "󰇧",
                        "value": VpnState.vpnCountry !== "" ? VpnState.vpnCountry : "—"
                    }, {
                        "icon": "󰖟",
                        "value": VpnState.vpnOrg !== "" ? VpnState.vpnOrg : "—"
                    }, {
                        "icon": "󰩟",
                        "value": VpnState.vpnIp !== "" ? VpnState.vpnIp : "—"
                    }]

                    delegate: Row {
                        required property var modelData

                        spacing: 8

                        Text {
                            text: modelData.icon
                            color: WalColors.color4
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                        }

                        Text {
                            text: modelData.value
                            color: WalColors.color2
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            width: 140
                            elide: Text.ElideRight
                        }

                    }

                }

            }

            // Hover-Bereich folgt der sichtbaren (schrumpfenden) Huelle, damit
            // der leere Bereich darunter beim Schliessen nicht wieder oeffnet.
            HoverHandler {
                onHoveredChanged: VpnState.dropdownOpen = hovered
            }

        }

        // Nur beim Oeffnen aktiv (heightAnimOn). Beim Schliessen springt die
        // Hoehe erst nach dem Schrumpfen ohne Animation auf 0.
        Behavior on height {
            enabled: dropdown.heightAnimOn

            Anim {
            }

        }

    }

}
