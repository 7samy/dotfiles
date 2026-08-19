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
}
