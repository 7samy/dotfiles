import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    // Aktualisiert die Dropdown-Position dynamisch
    function updateDropdownX() {
        var absolutePos = root.mapToItem(null, 0, 0);
        // Zieht die halbe Breite des Dropdowns ab (hier ca. 120, basierend auf Standard-1080p),
        // damit es mittig sitzt. Diesen Wert "120" kannst du bei Bedarf anpassen.
        VpnState.dropdownX = absolutePos.x + (root.width / 2) - 120;
    }

    width: vpnText.implicitWidth + 16
    height: parent.height
    color: "transparent"
    onXChanged: updateDropdownX()
    onWidthChanged: updateDropdownX()
    Component.onCompleted: {
        updateDropdownX();
        statusProcess.running = true;
        geoProcess.running = true;
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: statusProcess.running = true
    }

    Process {
        id: statusProcess

        command: ["bash", "-c", "nmcli connection show --active | grep -q 'proton' && echo 'on' || echo 'off'"]

        stdout: StdioCollector {
            onStreamFinished: {
                VpnState.connected = text.trim() === "on";
            }
        }

    }

    Process {
        id: geoProcess

        command: ["bash", "-c", "curl -s http://ip-api.com/json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    VpnState.vpnCity = data.city ?? "";
                    VpnState.vpnCountry = data.country ?? "";
                    VpnState.vpnOrg = data.isp ?? "";
                    VpnState.vpnIp = data.query ?? "";
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: toggleProcess

        command: VpnState.connected ? ["nmcli", "connection", "down", "proton"] : ["nmcli", "connection", "up", "proton"]
        onRunningChanged: {
            if (!running) {
                statusProcess.running = true;
                geoRefreshTimer.start();
            }
        }
    }

    Timer {
        id: geoRefreshTimer

        interval: 2000
        repeat: false
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
        repeat: false
        onTriggered: VpnState.dropdownOpen = false
    }

}
