import "../components"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: launcherWindow

    readonly property var currentScreen: {
        const focused = Hyprland.focusedMonitor;
        if (focused) {
            const match = Quickshell.screens.find((s) => {
                return s.name === focused.name;
            });
            if (match)
                return match;

        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    WlrLayershell.namespace: "quickshell:applauncher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // WICHTIG: Ignoriert die Exclusive Zone der Bar (und anderer Layer),
    // damit der Launcher den GESAMTEN Bildschirm abdeckt - inkl. des
    // Bereichs, wo die Bar sitzt. Ohne das beginnt er erst unterhalb der Bar
    // und der obere Streifen bleibt ungeblurt.
    WlrLayershell.exclusiveZone: -1
    screen: currentScreen
    visible: AppLauncherState.launcherVisible
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        id: backgroundRect

        anchors.fill: parent
        color: WalColors.withAlpha(WalColors.color0, 0.4)
        opacity: launcherWindow.visible ? 1 : 0

        AppLauncher {
            id: appLauncher

            anchors.fill: parent
            focus: true
            scale: launcherWindow.visible ? 1 : 0.85

            Behavior on scale {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutBack
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }

        }

    }

}
