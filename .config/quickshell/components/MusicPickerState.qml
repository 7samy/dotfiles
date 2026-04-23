import QtQuick
pragma Singleton

QtObject {
    id: root
    property bool pickerVisible: false
    property string searchText: ""
    
    function toggle() {
        pickerVisible = !pickerVisible
        if (!pickerVisible) {
            searchText = ""
        }
    }
    
    function close() {
        pickerVisible = false
        searchText = ""
    }
}
