import QtQuick
pragma Singleton

QtObject {
    id: root
    property bool launcherVisible: false
    property string searchText: ""
    
    function toggle() {
        launcherVisible = !launcherVisible
        if (!launcherVisible) {
            searchText = ""
        }
    }
    
    function close() {
        launcherVisible = false
        searchText = ""
    }
}
