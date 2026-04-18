import "../components"
import QtQuick
import Quickshell

Window {
    id: launcherWindow

    readonly property var screenGeometry: {
        if (Quickshell.screens.length > 0)
            return Quickshell.screens[0].geometry;

        return Qt.rect(0, 0, 1920, 1080);
    }

    width: 450
    height: 500
    color: "transparent"
    visible: AppLauncherState.launcherVisible
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    x: screenGeometry ? screenGeometry.x + (screenGeometry.width - width) / 2 : 100
    y: screenGeometry ? screenGeometry.y + (screenGeometry.height - height) / 2 : 100
    opacity: visible ? 1 : 0
    Component.onCompleted: {
        focus = true;
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: WalColors.withAlpha(WalColors.color0, 0.8)
        border.width: 2
        border.color: WalColors.withAlpha(WalColors.color2, 0.2)

        AppLauncher {
            anchors.fill: parent
            anchors.margins: 20
            focus: true
            Keys.onEscapePressed: AppLauncherState.close()
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }

    }

}
