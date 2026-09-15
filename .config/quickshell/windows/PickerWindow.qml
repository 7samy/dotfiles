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
    // Beim echten Öffnen: Bounce; beim Wechseln nicht
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

        // Bounce-Wrapper für den frischen Öffnen-Effekt
        Item {
            id: scaleWrapper

            anchors.fill: parent
            scale: 1
            transformOrigin: Item.Center
            layer.enabled: true // ← neu
            layer.smooth: true // ← neu
            layer.samples: 4

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

            // Carousel-Container
            Item {
                id: slideContainer

                readonly property int activeIndex: {
                    const idx = PickerManager.pickers.indexOf(PickerManager.activePicker);
                    return idx < 0 ? 0 : idx;
                }
                readonly property real slideWidth: pickerWindow.width
                // Beim frischen Öffnen: kein Slide (openingFresh = true)
                // Beim Wechseln: Slide mit menu_decel-Kurve
                // (entspricht Hyprlands workspaces-Animation)
                readonly property bool slideEnabled: !PickerManager.openingFresh && pickerWindow.visible

                function offsetFor(index) {
                    return (index - activeIndex) * slideWidth;
                }

                anchors.fill: parent
                clip: true

                AppLauncher {
                    id: appPicker

                    layer.enabled: true // ← neu
                    layer.smooth: true
                    width: slideContainer.slideWidth
                    height: pickerWindow.height
                    x: slideContainer.offsetFor(0)
                    focus: false

                    Behavior on x {
                        enabled: slideContainer.slideEnabled

                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.1, 1, 0, 1] // menu_decel
                        }

                    }

                }

                MusicPicker {
                    id: musicPicker

                    layer.enabled: true // ← neu
                    layer.smooth: true
                    width: slideContainer.slideWidth
                    height: pickerWindow.height
                    x: slideContainer.offsetFor(1)
                    focus: false

                    Behavior on x {
                        enabled: slideContainer.slideEnabled

                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.1, 1, 0, 1] // menu_decel
                        }

                    }

                }

                WallpaperPicker {
                    id: wallpaperPicker

                    layer.enabled: true // ← neu
                    layer.smooth: true
                    width: slideContainer.slideWidth
                    height: pickerWindow.height
                    x: slideContainer.offsetFor(2)
                    focus: false

                    Behavior on x {
                        enabled: slideContainer.slideEnabled

                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.1, 1, 0, 1] // menu_decel
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
