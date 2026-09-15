import QtQuick
pragma Singleton

QtObject {
    id: root

    // ============================================================
    // Hier neue Picker registrieren - Reihenfolge bestimmt
    // die Tab-Reihenfolge und die Reihenfolge im Switcher.
    // Der Name muss mit dem Namen im PickerSwitcher übereinstimmen.
    // ============================================================
    readonly property var pickers: ["app", "music", "wallpaper"]
    // Aktuell geöffneter Picker. Leerer String = nichts offen.
    property string activePicker: ""
    // Geteilter Suchtext über alle Picker. Wird beim Öffnen/
    // Wechseln auf "" zurückgesetzt.
    property string searchText: ""
    readonly property bool anyOpen: activePicker !== ""

    function isOpen(name) {
        return activePicker === name;
    }

    function open(name) {
        if (pickers.indexOf(name) === -1) {
            console.warn("PickerManager: unbekannter Picker:", name);
            return ;
        }
        if (activePicker === name)
            return ;

        searchText = "";
        activePicker = name;
    }

    function close() {
        activePicker = "";
        searchText = "";
    }

    function toggle(name) {
        if (activePicker === name)
            close();
        else
            open(name);
    }

    function cycle() {
        if (activePicker === "") {
            open(pickers[0]);
            return ;
        }
        const idx = pickers.indexOf(activePicker);
        open(pickers[(idx + 1) % pickers.length]);
    }

    function cycleBackward() {
        if (activePicker === "") {
            open(pickers[pickers.length - 1]);
            return ;
        }
        const idx = pickers.indexOf(activePicker);
        open(pickers[(idx - 1 + pickers.length) % pickers.length]);
    }

}
