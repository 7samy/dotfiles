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

    function focusActivePicker() {
        if (PickerManager.isOpen("app"))
            appPicker.focusSearch();
        else if (PickerManager.isOpen("music"))
            musicPicker.focusSearch();
        else if (PickerManager.isOpen("wallpaper"))
            wallpaperPicker.focusSearch();
    }

    WlrLayershell.namespace: "quickshell:pickers"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: -1
    screen: currentScreen
    visible: PickerManager.anyOpen
    color: "transparent"
    onVisibleChanged: {
        if (visible) {
            freshOpenBounce.restart();
            Qt.callLater(() => {
                return focusActivePicker();
            });
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Connections {
        function onActivePickerChanged() {
            if (pickerWindow.visible)
                Qt.callLater(() => {
                return pickerWindow.focusActivePicker();
            });

        }

        target: PickerManager
    }

    Rectangle {
        id: backgroundRect

        anchors.fill: parent
        color: WalColors.withAlpha(WalColors.color0, 0.4)
        opacity: pickerWindow.visible ? 1 : 0

        Item {
            id: scaleWrapper

            anchors.fill: parent
            scale: 1
            transformOrigin: Item.Center

            SequentialAnimation {
                id: freshOpenBounce

                NumberAnimation {
                    target: scaleWrapper
                    property: "scale"
                    from: 0.85
                    to: 1
                    duration: 300
                    easing.type: Easing.OutBack
                }

            }

            Item {
                id: crossfadeContainer

                anchors.fill: parent

                AppLauncher {
                    id: appPicker

                    anchors.fill: parent
                    focus: false
                    opacity: PickerManager.activePicker === "app" ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        enabled: !PickerManager.openingFresh

                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                MusicPicker {
                    id: musicPicker

                    anchors.fill: parent
                    focus: false
                    opacity: PickerManager.activePicker === "music" ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        enabled: !PickerManager.openingFresh

                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                WallpaperPicker {
                    id: wallpaperPicker

                    anchors.fill: parent
                    focus: false
                    opacity: PickerManager.activePicker === "wallpaper" ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        enabled: !PickerManager.openingFresh

                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }

                    }

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
