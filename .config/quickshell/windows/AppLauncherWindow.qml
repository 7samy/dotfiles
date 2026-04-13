import Quickshell
import QtQuick
import "../components"

Window {
    id: launcherWindow
    
    width: 450
    height: 500
    color: "transparent"
    visible: AppLauncherState.launcherVisible
    
    // WICHTIG: Quickshell Windows brauchen unter Hyprland oft W_TYPE_MENU oder ähnliches für sauberes Floating
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    
    readonly property var screenGeometry: {
        if (Quickshell.screens.length > 0) {
            return Quickshell.screens[0].geometry
        }
        return Qt.rect(0, 0, 1920, 1080)
    }
    
    x: screenGeometry ? screenGeometry.x + (screenGeometry.width - width) / 2 : 100
    y: screenGeometry ? screenGeometry.y + (screenGeometry.height - height) / 2 : 100
    
    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }
    
    opacity: visible ? 1.0 : 0.0
    
    Rectangle {
        anchors.fill: parent
        radius: 12
        
        // Nutze alpha direkt in der Farbe statt opacity: 0.8 auf dem ganzen Element
        // Das verhindert, dass die Border "dreckig" aussieht
        color: WalColors.withAlpha(WalColors.color0, 0.8)
        
        border.width: 2
        border.color: WalColors.withAlpha(WalColors.color2, 0.55)
        
        AppLauncher {
            anchors.fill: parent
            anchors.margins: 20
            focus: true
            Keys.onEscapePressed: AppLauncherState.close()
        }
    }
    
    Component.onCompleted: {
        focus = true
    }
}
