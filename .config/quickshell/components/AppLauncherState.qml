import QtQuick
pragma Singleton

QtObject {
    readonly property bool launcherVisible: PickerManager.isOpen("app")

    function toggle() {
        PickerManager.toggle("app");
    }

    function close() {
        if (PickerManager.isOpen("app"))
            PickerManager.close();

    }

    function open() {
        PickerManager.open("app");
    }

}
