import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    // Nur noch fuer die Statuspruefung (greift auf alle "proton-xx" Verbindungen)
    readonly property string vpnPattern: "proton"
    readonly property real globalCenterX: windowX(root) + width / 2

    // Läuft die Parent-Kette hoch bis zum Fenster-Root (parent === null)
    // und summiert dabei die x-Offsets.
    function windowX(item) {
        var x = 0;
        var it = item;
        while (it && it.parent) {
            x += it.x;
            it = it.parent;
        }
        return x;
    }

    width: vpnText.implicitWidth + 16
    height: parent.height
    color: "transparent"
    Component.onCompleted: {
        statusProcess.running = true;
        geoProcess.running = true;
    }

    Binding {
        target: VpnState
        property: "iconCenterX"
        value: root.globalCenterX
    }

    // Nach einem Laenderwechsel im Picker Status und Standort neu laden
    Connections {
        function onSwitched() {
            statusProcess.running = true;
            geoRefreshTimer.restart();
        }

        target: VpnPickerState
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: statusProcess.running = true
    }

    Process {
        id: statusProcess

        command: ["bash", "-c", `nmcli connection show --active | grep -q '${root.vpnPattern}' && echo on || echo off`]

        stdout: StdioCollector {
            onStreamFinished: VpnState.connected = text.trim() === "on"
        }

    }

    Process {
        id: geoProcess

        command: ["curl", "-s", "http://ip-api.com/json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim());
                    VpnState.vpnCity = data.city ?? "";
                    VpnState.vpnCountry = data.country ?? "";
                    VpnState.vpnOrg = data.isp ?? "";
                    VpnState.vpnIp = data.query ?? "";
                } catch (e) {
                    console.warn("VpnToggle: Geo-Lookup konnte nicht geparst werden:", e);
                }
            }
        }

    }

    // Linksklick: an/aus. Aus = aktive Verbindung trennen,
    // an = zuletzt gewaehlte Verbindung starten.
    Process {
        id: toggleProcess

        command: VpnState.connected ? ["nmcli", "connection", "down", VpnPickerState.activeConnection !== "" ? VpnPickerState.activeConnection : "proton"] : ["nmcli", "connection", "up", VpnPickerState.lastConnection]
        onRunningChanged: {
            if (!running) {
                statusProcess.running = true;
                VpnPickerState.refresh();
                geoRefreshTimer.restart();
            }
        }
    }

    Timer {
        id: geoRefreshTimer

        interval: 2000
        onTriggered: geoProcess.running = true
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: geoProcess.running = true
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        border.width: 1
        color: WalColors.withAlpha(WalColors.color2, 1)
        opacity: mouseArea.containsMouse ? 0.15 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }

        }

    }

    Text {
        id: vpnText

        anchors.centerIn: parent
        text: VpnState.connected ? "󰦝" : "󱦚"
        color: VpnState.connected ? "#b8e0b8" : "#f0b8b8"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
        scale: mouseArea.containsMouse ? 1.3 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }

        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                hideTimer.stop();
                VpnState.dropdownOpen = false;
                VpnPickerState.toggle();
            } else {
                toggleProcess.running = true;
            }
        }
        onEntered: {
            hideTimer.stop();
            if (!VpnPickerState.open)
                VpnState.dropdownOpen = true;

        }
        onExited: hideTimer.start()
    }

    Timer {
        id: hideTimer

        interval: 200
        onTriggered: VpnState.dropdownOpen = false
    }

}
