import QtQuick
import Quickshell

// Uhr in der Bar. Ein Linksklick sendet `clicked()`; MainBar verwandelt sich dann in den Kalender.
Item {
    id: clockRoot

    signal clicked()

    function updateTime() {
        timeText.text = Qt.formatDateTime(new Date(), "hh:mm AP");
        dateText.text = Qt.formatDateTime(new Date(), "MMMM d, yyyy");
    }

    implicitWidth: clockColumn.implicitWidth
    implicitHeight: parent ? parent.height : 40
    Component.onCompleted: updateTime()

    // dezente Hover-Pille als Hinweis, dass die Uhr klickbar ist
    Rectangle {
        anchors.centerIn: parent
        width: clockColumn.implicitWidth + 24
        height: 32
        radius: height / 2
        color: WalColors.withAlpha(WalColors.color4, clockHover.hovered ? 0.07 : 0)

        Behavior on color {
            ColorAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }

        }

    }

    Column {
        id: clockColumn

        anchors.centerIn: parent
        spacing: 0

        Text {
            id: timeText

            anchors.horizontalCenter: parent.horizontalCenter
            color: WalColors.color2
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            id: dateText

            anchors.horizontalCenter: parent.horizontalCenter
            color: WalColors.color2
            opacity: 0.7
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockRoot.updateTime()
    }

    HoverHandler {
        id: clockHover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: clockRoot.clicked()
    }

}
