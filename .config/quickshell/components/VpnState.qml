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
    property real dropdownX: 0
}
