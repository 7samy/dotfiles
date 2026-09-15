import "../components"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: pickerWindow

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

    // Eigener Namespace - für die Hyprland layerrule:
    //   hl.layer_rule({ match = { namespace = "quickshell:musicpicker" },
    //                   blur = true, ignore_alpha = 0.3 })
    WlrLayershell.namespace: "quickshell:musicpicker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: -1
    screen: currentScreen
    visible: MusicPickerState.pickerVisible
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
        opacity: pickerWindow.visible ? 1 : 0

        MusicPicker {
            id: musicPicker

            anchors.fill: parent
            focus: true
            scale: pickerWindow.visible ? 1 : 0.85

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
