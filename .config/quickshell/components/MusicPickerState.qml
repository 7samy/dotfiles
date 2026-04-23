import QtQuick
pragma Singleton

QtObject {
    id: root
    property bool pickerVisible: false
    property string searchText: ""
    property string currentSongPath: ""
    
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
