import QtQuick
pragma Singleton

QtObject {
    readonly property bool pickerVisible: PickerManager.isOpen("music")

    function toggle() {
        PickerManager.toggle("music");
    }

    function close() {
        if (PickerManager.isOpen("music"))
            PickerManager.close();

    }

    function open() {
        PickerManager.open("music");
    }

}
