import QtQuick
import Quickshell

Text {
    id: clockText
    color: WalColors.color2
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 14
    height: parent.height
    verticalAlignment: Text.AlignVCenter

    function updateTime() {
        clockText.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockText.updateTime()
    }

    Component.onCompleted: updateTime()
}
