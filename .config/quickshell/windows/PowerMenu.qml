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
    readonly property int cardW: 160
    readonly property int cardH: 200
    readonly property int cardSpacing: 28
    readonly property int rowWidth: cardW * 4 + cardSpacing * 3
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
    property string hoursText: ""
    property string minutesText: ""
    property string dateText: ""

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

    Timer {
        interval: 1000
        running: powerMenu.open
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            powerMenu.hoursText = Qt.formatTime(now, "HH");
            powerMenu.minutesText = Qt.formatTime(now, "mm");
            powerMenu.dateText = Qt.formatDate(now, "dddd, MMMM d");
        }
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
        Keys.onDigit1Pressed: powerMenu.runAction(0)
        Keys.onDigit2Pressed: powerMenu.runAction(1)
        Keys.onDigit3Pressed: powerMenu.runAction(2)
        Keys.onDigit4Pressed: powerMenu.runAction(3)
    }

    Rectangle {
        id: dimmer

        anchors.fill: parent
        color: WalColors.withAlpha(WalColors.color0, 0.72)
        opacity: powerMenu.open ? 1 : 0

        MouseArea {
            anchors.fill: parent
            onClicked: powerMenu.close()
        }

        // --- Alles in einem Bounce-Wrapper ---
        Item {
            id: contentWrapper

            anchors.fill: parent
            transformOrigin: Item.Center

            SequentialAnimation {
                id: freshOpenBounce

                NumberAnimation {
                    target: contentWrapper
                    property: "scale"
                    from: 0.85
                    to: 1
                    duration: 300
                    easing.type: Easing.OutBack
                }

            }

            // --- Uhr mit blinkendem Doppelpunkt ---
            Column {
                id: clockColumn

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -220
                spacing: 4

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 1

                    Text {
                        text: powerMenu.hoursText
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 42
                        font.weight: Font.Light
                        color: WalColors.color7
                    }

                    Text {
                        id: colonText

                        text: ":"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 42
                        font.weight: Font.Light
                        color: WalColors.color7

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: powerMenu.open

                            NumberAnimation {
                                to: 1
                                duration: 0
                            }

                            PauseAnimation {
                                duration: 500
                            }

                            NumberAnimation {
                                to: 0.2
                                duration: 120
                                easing.type: Easing.InOutQuad
                            }

                            PauseAnimation {
                                duration: 380
                            }

                            NumberAnimation {
                                to: 1
                                duration: 120
                                easing.type: Easing.InOutQuad
                            }

                        }

                    }

                    Text {
                        text: powerMenu.minutesText
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 42
                        font.weight: Font.Light
                        color: WalColors.color7
                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: powerMenu.dateText
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    color: WalColors.withAlpha(WalColors.color7, 0.55)
                }

            }

            // --- Menü ---
            Item {
                id: menuColumn

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 30
                width: powerMenu.rowWidth
                height: powerMenu.cardH + 32

                Row {
                    id: rowContainer

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: powerMenu.cardSpacing

                    Repeater {
                        model: powerMenu.actions

                        delegate: Item {
                            id: btnRoot

                            readonly property int idx: index
                            readonly property bool isCurrent: powerMenu.currentIndex === idx

                            width: powerMenu.cardW
                            height: powerMenu.cardH
                            z: isCurrent ? 10 : 1
                            scale: isCurrent ? 1.05 : 1
                            opacity: isCurrent ? 1 : 0.55

                            Rectangle {
                                anchors.fill: parent
                                radius: 20
                                color: WalColors.withAlpha(WalColors.color0, 0.85)
                                border.width: 1
                                border.color: btnRoot.isCurrent ? WalColors.withAlpha(WalColors.color4, 0.9) : WalColors.withAlpha(WalColors.color7, 0.1)

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 200
                                    }

                                }

                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 18

                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 52
                                    height: 52

                                    Image {
                                        id: iconImg

                                        anchors.fill: parent
                                        source: modelData.icon
                                        sourceSize.width: 52
                                        sourceSize.height: 52
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                        visible: false
                                    }

                                    ColorOverlay {
                                        anchors.fill: iconImg
                                        source: iconImg
                                        color: btnRoot.isCurrent ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.6)

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
                                    font.letterSpacing: 1
                                    color: btnRoot.isCurrent ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.6)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
                                        }

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

                // --- gleitender Unterstrich mit Squish-Bounce ---
                Rectangle {
                    id: selectionBar

                    readonly property real baseWidth: powerMenu.cardW - 40
                    property real squish: 1

                    width: baseWidth
                    height: 2
                    radius: 1
                    color: WalColors.color4
                    anchors.top: rowContainer.bottom
                    anchors.topMargin: 16
                    x: 20 + powerMenu.currentIndex * (powerMenu.cardW + powerMenu.cardSpacing)

                    SequentialAnimation {
                        id: squishAnim

                        NumberAnimation {
                            target: selectionBar
                            property: "squish"
                            to: 0.5
                            duration: 140
                            easing.type: Easing.OutQuad
                        }

                        NumberAnimation {
                            target: selectionBar
                            property: "squish"
                            to: 1
                            duration: 300
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.2
                        }

                    }

                    Connections {
                        function onCurrentIndexChanged() {
                            squishAnim.restart();
                        }

                        target: powerMenu
                    }

                    transform: Scale {
                        origin.x: selectionBar.width / 2
                        origin.y: selectionBar.height / 2
                        xScale: selectionBar.squish
                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }

                    }

                }

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
