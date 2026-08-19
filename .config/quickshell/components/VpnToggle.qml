import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    readonly property string vpnConnectionName: "proton"
    readonly property real globalCenterX: windowX(root) + width / 2

    // Läuft die Parent-Kette hoch bis zum Fenster-Root (parent === null)
    // und summiert dabei die x-Offsets. Im Gegensatz zu mapToItem() sind
    // das alles normale QML-Property-Reads (item.x, item.parent), die der
    // Binding-Engine als Abhängigkeit bekannt sind – die Property aktualisiert
    // sich also automatisch, sobald sich irgendein Vorfahre bewegt
    // (z.B. wenn der Row-Positioner seine Kinder layoutet).
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

    // Binding statt onCompleted+onChanged: wird sofort UND bei jeder
    // Änderung von globalCenterX neu ausgewertet, kein Race-Condition-Risiko
    // beim ersten Layout-Pass.
    Binding {
        target: VpnState
        property: "iconCenterX"
        value: root.globalCenterX
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: statusProcess.running = true
    }

    Process {
        id: statusProcess

        command: ["bash", "-c", `nmcli connection show --active | grep -q '${root.vpnConnectionName}' && echo on || echo off`]

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

    Process {
        id: toggleProcess

        command: VpnState.connected ? ["nmcli", "connection", "down", root.vpnConnectionName] : ["nmcli", "connection", "up", root.vpnConnectionName]
        onRunningChanged: {
            if (!running) {
                statusProcess.running = true;
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
        cursorShape: Qt.PointingHandCursor
        onClicked: toggleProcess.running = true
        onEntered: {
            hideTimer.stop();
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
