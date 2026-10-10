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
        if (PickerManager.isOpen("clipboard") && clipboardLoader.item)
            clipboardLoader.item.focusSearch();
        else if (PickerManager.isOpen("app") && appLoader.item)
            appLoader.item.focusSearch();
        else if (PickerManager.isOpen("music") && musicLoader.item)
            musicLoader.item.focusSearch();
        else if (PickerManager.isOpen("wallpaper") && wallpaperLoader.item)
            wallpaperLoader.item.focusSearch();
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

                // ---- Clipboard Picker (lazy, keepAlive-Pattern) ----
                Loader {
                    id: clipboardLoader

                    property bool keepAlive: false

                    anchors.fill: parent
                    asynchronous: true
                    active: keepAlive
                    sourceComponent: clipboardComponent

                    Connections {
                        function onActivePickerChanged() {
                            if (PickerManager.activePicker === "clipboard")
                                clipboardLoader.keepAlive = true;
                            else if (clipboardLoader.item)
                                clipboardUnloadTimer.restart();
                        }

                        target: PickerManager
                    }

                    Timer {
                        id: clipboardUnloadTimer

                        interval: 320
                        onTriggered: clipboardLoader.keepAlive = false
                    }

                    Component {
                        id: clipboardComponent

                        ClipboardPicker {
                            id: clipboardPicker

                            anchors.fill: parent
                            focus: false
                            opacity: PickerManager.activePicker === "clipboard" ? 1 : 0
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

                // ---- App Launcher (lazy, keepAlive-Pattern) ----
                Loader {
                    id: appLoader

                    property bool keepAlive: false

                    anchors.fill: parent
                    asynchronous: true
                    active: keepAlive
                    sourceComponent: appComponent

                    Connections {
                        function onActivePickerChanged() {
                            if (PickerManager.activePicker === "app")
                                appLoader.keepAlive = true;
                            else if (appLoader.item)
                                appUnloadTimer.restart();
                        }

                        target: PickerManager
                    }

                    Timer {
                        id: appUnloadTimer

                        interval: 320
                        onTriggered: appLoader.keepAlive = false
                    }

                    Component {
                        id: appComponent

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

                    }

                }

                // ---- Music Picker (lazy, keepAlive-Pattern) ----
                Loader {
                    id: musicLoader

                    property bool keepAlive: false

                    anchors.fill: parent
                    asynchronous: true
                    active: keepAlive
                    sourceComponent: musicComponent

                    Connections {
                        function onActivePickerChanged() {
                            if (PickerManager.activePicker === "music")
                                musicLoader.keepAlive = true;
                            else if (musicLoader.item)
                                musicUnloadTimer.restart();
                        }

                        target: PickerManager
                    }

                    Timer {
                        id: musicUnloadTimer

                        interval: 320
                        onTriggered: musicLoader.keepAlive = false
                    }

                    Component {
                        id: musicComponent

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

                    }

                }

                // ---- Wallpaper Picker (lazy, keepAlive-Pattern) ----
                Loader {
                    id: wallpaperLoader

                    property bool keepAlive: false

                    anchors.fill: parent
                    asynchronous: true
                    active: keepAlive
                    sourceComponent: wallpaperComponent

                    Connections {
                        function onActivePickerChanged() {
                            if (PickerManager.activePicker === "wallpaper")
                                wallpaperLoader.keepAlive = true;
                            else if (wallpaperLoader.item)
                                wallpaperUnloadTimer.restart();
                        }

                        target: PickerManager
                    }

                    Timer {
                        id: wallpaperUnloadTimer

                        interval: 320
                        onTriggered: wallpaperLoader.keepAlive = false
                    }

                    Component {
                        id: wallpaperComponent

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
