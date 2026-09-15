import QtQuick
pragma Singleton

QtObject {
    readonly property bool pickerVisible: PickerManager.isOpen("wallpaper")

    function toggle() {
        PickerManager.toggle("wallpaper");
    }

    function close() {
        if (PickerManager.isOpen("wallpaper"))
            PickerManager.close();

    }

    function open() {
        PickerManager.open("wallpaper");
    }

}
