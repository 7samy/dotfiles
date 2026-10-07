pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- Picker-Zustand ----
    property bool open: false
    property string searchText: ""

    // ---- VPN-Daten ----
    // [{ name: "proton-nl", code: "nl", label: "Niederlande" }, ...]
    property var connections: []
    property string activeConnection: ""
    property string lastConnection: "proton"
    property bool busy: false

    signal switched()

    readonly property var countryNames: ({
        "at": "Österreich", "au": "Australien", "be": "Belgien", "br": "Brasilien",
        "ca": "Kanada", "ch": "Schweiz", "cz": "Tschechien", "de": "Deutschland",
        "dk": "Dänemark", "ee": "Estland", "es": "Spanien", "fi": "Finnland",
        "fr": "Frankreich", "gb": "Großbritannien", "uk": "Großbritannien",
        "gr": "Griechenland", "hk": "Hongkong", "hu": "Ungarn", "ie": "Irland",
        "il": "Israel", "in": "Indien", "is": "Island", "it": "Italien",
        "jp": "Japan", "kr": "Südkorea", "lt": "Litauen", "lu": "Luxemburg",
        "lv": "Lettland", "mx": "Mexiko", "nl": "Niederlande", "no": "Norwegen",
        "nz": "Neuseeland", "pl": "Polen", "pt": "Portugal", "ro": "Rumänien",
        "rs": "Serbien", "ru": "Russland", "se": "Schweden", "sg": "Singapur",
        "sk": "Slowakei", "tr": "Türkei", "ua": "Ukraine", "us": "USA",
        "za": "Südafrika"
    })

    // "proton-nl" -> "nl"
    function codeOf(name) {
        const m = /^proton-([a-z]{2})(?:[-_.]|$)/i.exec(name);
        return m ? m[1].toLowerCase() : "";
    }

    function labelOf(name, code) {
        if (code !== "")
            return countryNames[code] ?? code.toUpperCase();
        return name;
    }

    function openPicker() {
        searchText = "";
        refresh();
        open = true;
    }

    function close() {
        open = false;
    }

    function toggle() {
        if (open)
            close();
        else
            openPicker();
    }

    function refresh() {
        listProcess.running = true;
    }

    // Wechselt auf die gewaehlte Verbindung (alte wird vorher getrennt)
    function connectTo(name) {
        if (busy || name === "")
            return ;
        lastConnection = name;
        if (name === activeConnection) {
            close();
            return ;
        }
        busy = true;
        switchProcess.command = [
            "bash", "-c",
            'if [ -n "$1" ]; then nmcli connection down "$1" >/dev/null 2>&1; fi; nmcli connection up "$2"',
            "_", activeConnection, name
        ];
        switchProcess.running = true;
        close();
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: listProcess

        command: ["bash", "-c", "nmcli -t -f NAME,TYPE connection show; echo '---'; nmcli -t -f NAME,TYPE connection show --active"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                let inActive = false;
                const all = [];
                let active = "";
                for (const line of lines) {
                    if (line.trim() === "---") {
                        inActive = true;
                        continue;
                    }
                    if (!line.endsWith(":wireguard"))
                        continue;
                    const name = line.slice(0, line.length - ":wireguard".length);
                    if (inActive) {
                        if (active === "")
                            active = name;
                    } else {
                        const code = root.codeOf(name);
                        all.push({
                            "name": name,
                            "code": code,
                            "label": root.labelOf(name, code)
                        });
                    }
                }
                all.sort((a, b) => a.label.localeCompare(b.label, "de"));
                root.connections = all;
                root.activeConnection = active;
                if (active !== "")
                    root.lastConnection = active;
                else if (!all.some((c) => c.name === root.lastConnection) && all.length > 0)
                    root.lastConnection = all[0].name;
            }
        }
    }

    Process {
        id: switchProcess

        onRunningChanged: {
            if (!running) {
                root.busy = false;
                root.refresh();
                root.switched();
            }
        }
    }
}
