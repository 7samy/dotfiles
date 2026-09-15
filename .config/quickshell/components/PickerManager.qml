import QtQuick
pragma Singleton

QtObject {
    id: root

    readonly property var pickers: ["app", "music", "wallpaper"]
    property string activePicker: ""
    property string searchText: ""
    // true, wenn gerade frisch geöffnet wird (keiner war aktiv)
    // Wird von den Pickern benutzt, um beim ersten Öffnen keinen
    // Slide, sondern einen Bounce zu zeigen.
    property bool openingFresh: false
    readonly property bool anyOpen: activePicker !== ""
    // Wird nur für die Richtungs-Info beim Wechseln gebraucht
    property string switchDirection: "none"
    // Nach ~60ms darf wieder geslidet werden (Wechsel-Animationen)
    property Timer _releaseFreshTimer

    _releaseFreshTimer: Timer {
        id: releaseFreshTimer

        interval: 60
        onTriggered: root.openingFresh = false
    }

    function isOpen(name) {
        return activePicker === name;
    }

    function _doOpen(name, direction) {
        if (pickers.indexOf(name) === -1) {
            console.warn("PickerManager: unbekannter Picker:", name);
            return ;
        }
        if (activePicker === name)
            return ;

        const wasOpen = activePicker !== "";
        if (!wasOpen) {
            openingFresh = true;
            releaseFreshTimer.restart();
        }
        switchDirection = wasOpen ? direction : "none";
        searchText = "";
        activePicker = name;
    }

    function open(name) {
        if (activePicker === "") {
            _doOpen(name, "none");
            return ;
        }
        const fromIdx = pickers.indexOf(activePicker);
        const toIdx = pickers.indexOf(name);
        _doOpen(name, toIdx > fromIdx ? "forward" : "backward");
    }

    function close() {
        activePicker = "";
        searchText = "";
        switchDirection = "none";
    }

    function toggle(name) {
        if (activePicker === name)
            close();
        else
            open(name);
    }

    function cycle() {
        if (activePicker === "") {
            _doOpen(pickers[0], "none");
            return ;
        }
        const idx = pickers.indexOf(activePicker);
        _doOpen(pickers[(idx + 1) % pickers.length], "forward");
    }

    function cycleBackward() {
        if (activePicker === "") {
            _doOpen(pickers[pickers.length - 1], "none");
            return ;
        }
        const idx = pickers.indexOf(activePicker);
        _doOpen(pickers[(idx - 1 + pickers.length) % pickers.length], "backward");
    }

}
