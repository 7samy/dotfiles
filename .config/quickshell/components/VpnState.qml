import QtQuick
pragma Singleton

QtObject {
    id: root

    property bool connected: false
    property bool dropdownOpen: false
    property string vpnCity: ""
    property string vpnCountry: ""
    property string vpnOrg: ""
    property string vpnIp: ""
    // X-Zentrum des VPN-Icons in Fenster-/Bildschirmkoordinaten,
    // wird live von VpnToggle.qml über eine Binding aktualisiert.
    // VpnDropDown.qml nutzt das, um sich unter dem Icon zu zentrieren.
    property real iconCenterX: 0
    // ==== Hover-State (analog zu AudioState / StatsState) ====
    // buttonHovered  = Maus über dem Toggle-Icon in der Bar
    // dropdownHovered = Maus über dem geöffneten Menü
    // Solange eines von beiden true ist, bleibt das Menü offen.
    property bool buttonHovered: false
    property bool dropdownHovered: false
    property Timer hideTimer

    function updateHoverTimer() {
        if (!root.buttonHovered && !root.dropdownHovered)
            hideTimer.start();
        else
            hideTimer.stop();
    }

    function startHideTimer() {
        hideTimer.start();
    }

    function stopHideTimer() {
        hideTimer.stop();
    }

    hideTimer: Timer {
        interval: 300
        onTriggered: root.dropdownOpen = false
    }

}
