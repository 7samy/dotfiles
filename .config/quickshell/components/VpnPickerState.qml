import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    // ---- Picker state ----
    property bool open: false
    property string searchText: ""
    // ---- VPN data ----
    // [{ name: "proton-nl", code: "nl", label: "Netherlands" }, ...]
    property var connections: []
    property string activeConnection: ""
    property string lastConnection: "proton"
    property bool busy: false
    readonly property var countryNames: ({
        "at": "Austria",
        "au": "Australia",
        "be": "Belgium",
        "br": "Brazil",
        "ca": "Canada",
        "ch": "Switzerland",
        "cz": "Czechia",
        "de": "Germany",
        "dk": "Denmark",
        "ee": "Estonia",
        "es": "Spain",
        "fi": "Finland",
        "fr": "France",
        "gb": "United Kingdom",
        "uk": "United Kingdom",
        "gr": "Greece",
        "hk": "Hong Kong",
        "hu": "Hungary",
        "ie": "Ireland",
        "il": "Israel",
        "in": "India",
        "is": "Iceland",
        "it": "Italy",
        "jp": "Japan",
        "kr": "South Korea",
        "li": "Liechtenstein",
        "lt": "Lithuania",
        "lu": "Luxembourg",
        "lv": "Latvia",
        "mx": "Mexico",
        "nl": "Netherlands",
        "no": "Norway",
        "nz": "New Zealand",
        "pl": "Poland",
        "pt": "Portugal",
        "ro": "Romania",
        "rs": "Serbia",
        "ru": "Russia",
        "se": "Sweden",
        "sg": "Singapore",
        "sk": "Slovakia",
        "tr": "Turkey",
        "ua": "Ukraine",
        "us": "USA",
        "za": "South Africa"
    })

    signal switched()

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

    // Switch to the selected connection (old one is taken down first)
    function connectTo(name) {
        if (busy || name === "")
            return ;

        lastConnection = name;
        if (name === activeConnection) {
            close();
            return ;
        }
        busy = true;
        switchProcess.command = ["bash", "-c", 'if [ -n "$1" ]; then nmcli connection down "$1" >/dev/null 2>&1; fi; nmcli connection up "$2"', "_", activeConnection, name];
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
                all.sort((a, b) => {
                    return a.label.localeCompare(b.label, "en");
                });
                root.connections = all;
                root.activeConnection = active;
                if (active !== "")
                    root.lastConnection = active;
                else if (!all.some((c) => {
                    return c.name === root.lastConnection;
                }) && all.length > 0)
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
