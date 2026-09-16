import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: powerMenu

    property bool open: false
    property int currentIndex: 0
    // Aktiv: kräftiges Wal-Blau, Inaktiv: gleiche Farbe halbtransparent
    readonly property color iconActiveColor: WalColors.color4
    readonly property color iconInactiveColor: WalColors.withAlpha(WalColors.color4, 0.55)
    readonly property var actions: [{
        "label": "Shutdown",
        "icon": "../resources/icons/power.png",
        "cmd": ["systemctl", "poweroff"]
    }, {
        "label": "Reboot",
        "icon": "../resources/icons/rewind.png",
        "cmd": ["systemctl", "reboot"]
    }, {
        "label": "Lock",
        "icon": "../resources/icons/padlock.png",
        "cmd": ["/home/azu/.config/hypr/scripts/lock.sh"]
    }, {
        "label": "Logout",
        "icon": "../resources/icons/logout.png",
        "cmd": ["hyprctl", "dispatch", "exit"]
    }]
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

    function runAction(i) {
        const a = actions[i];
        if (!a)
            return ;

        console.log("PowerMenu:", a.label, a.cmd);
        Quickshell.execDetached(a.cmd);
        open = false;
    }

    function close() {
        open = false;
        currentIndex = 0;
    }

    WlrLayershell.namespace: "quickshell:powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1
    screen: currentScreen
    visible: open
    color: "transparent"
    onOpenChanged: {
        if (open)
            freshOpenBounce.restart();

    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    IpcHandler {
        function toggle() {
            powerMenu.open = !powerMenu.open;
        }

        function show() {
            powerMenu.open = true;
        }

        function hide() {
            powerMenu.close();
        }

        target: "powermenu"
    }

    Item {
        anchors.fill: parent
        focus: powerMenu.open
        Keys.onEscapePressed: powerMenu.close()
        Keys.onReturnPressed: powerMenu.runAction(powerMenu.currentIndex)
        Keys.onEnterPressed: powerMenu.runAction(powerMenu.currentIndex)
        Keys.onLeftPressed: powerMenu.currentIndex = (powerMenu.currentIndex + powerMenu.actions.length - 1) % powerMenu.actions.length
        Keys.onRightPressed: powerMenu.currentIndex = (powerMenu.currentIndex + 1) % powerMenu.actions.length
    }

    Rectangle {
        id: dimmer

        anchors.fill: parent
        color: WalColors.withAlpha(WalColors.color0, 0.55)
        opacity: powerMenu.open ? 1 : 0

        MouseArea {
            anchors.fill: parent
            onClicked: powerMenu.close()
        }

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

            Row {
                anchors.centerIn: parent
                spacing: 45

                Repeater {
                    model: powerMenu.actions

                    delegate: Item {
                        id: btnRoot

                        readonly property int idx: index
                        readonly property bool isCurrent: powerMenu.currentIndex === idx

                        width: 160
                        height: 180
                        scale: isCurrent ? 1.03 : 1
                        opacity: isCurrent ? 1 : 0.6

                        Rectangle {
                            id: btnBg

                            anchors.fill: parent
                            radius: 22
                            color: WalColors.withAlpha(WalColors.color0, 0.8)
                            border.width: isCurrent ? 2 : 0
                            border.color: WalColors.withAlpha(WalColors.color4, 0.6)

                            Column {
                                anchors.centerIn: parent
                                spacing: 16

                                Item {
                                    id: iconWrapper

                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 64
                                    height: 64

                                    Image {
                                        id: iconImg

                                        anchors.fill: parent
                                        source: modelData.icon
                                        sourceSize.width: 64
                                        sourceSize.height: 64
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                        visible: false
                                    }

                                    ColorOverlay {
                                        anchors.fill: iconImg
                                        source: iconImg
                                        color: isCurrent ? powerMenu.iconActiveColor : powerMenu.iconInactiveColor

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 200
                                            }

                                        }

                                    }

                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: WalColors.color7
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: powerMenu.currentIndex = btnRoot.idx
                            onClicked: powerMenu.runAction(btnRoot.idx)
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }

        }

    }

}
