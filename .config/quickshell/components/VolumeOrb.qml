import "../components"
import QtQuick

Item {
    id: root

    readonly property real level: Math.max(0, Math.min(VolumeSliderState.systemVolume, 1))
    readonly property bool muted: VolumeSliderState.systemMuted
    readonly property bool hot: mouseArea.containsMouse
    readonly property bool expanded: VolumeSliderState.expanded
    property real t: 0

    signal clicked()
    signal rightClicked()

    width: 40
    height: 40

    Timer {
        interval: 30
        running: true
        repeat: true
        onTriggered: root.t += 0.018
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 8
        height: parent.height + 8
        radius: width / 2
        color: root.muted ? WalColors.color1 : WalColors.color4
        opacity: 0.05 + 0.15 * root.level
        layer.enabled: true
        layer.samples: 4

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }

        }

    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 2
        height: parent.height - 2
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: WalColors.color1
        opacity: root.muted ? 0.5 : 0
        visible: opacity > 0.01
        scale: root.muted ? 1 : 0.85

        SequentialAnimation on scale {
            loops: Animation.Infinite
            running: root.muted

            NumberAnimation {
                to: 1.15
                duration: 1400
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                to: 1
                duration: 100
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }

        }

    }

    Item {
        anchors.centerIn: parent
        width: parent.width - 4
        height: parent.height - 4
        rotation: root.muted ? rotation : root.t * 20

        Repeater {
            model: 8

            delegate: Rectangle {
                readonly property real angleRad: index * Math.PI / 4
                readonly property real r: parent.width / 2 - 1

                x: parent.width / 2 + r * Math.cos(angleRad) - width / 2
                y: parent.height / 2 + r * Math.sin(angleRad) - height / 2
                width: 3
                height: 1.2
                radius: height / 2
                color: root.muted ? WalColors.color1 : WalColors.color4
                opacity: root.muted ? 0.5 : 0.35 + 0.35 * root.level

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }

                }

            }

        }

    }

    Item {
        anchors.centerIn: parent
        width: parent.width - 14
        height: parent.height - 14
        rotation: root.muted ? rotation : -root.t * 30

        Repeater {
            model: 6

            delegate: Rectangle {
                readonly property real angleRad: index * Math.PI / 3
                readonly property real r: parent.width / 2 - 1

                x: parent.width / 2 + r * Math.cos(angleRad) - width / 2
                y: parent.height / 2 + r * Math.sin(angleRad) - height / 2
                width: 2.5
                height: 1.2
                radius: height / 2
                color: root.muted ? WalColors.color1 : WalColors.color4
                opacity: root.muted ? 0.55 : 0.45 + 0.35 * root.level

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }

                }

            }

        }

    }

    Rectangle {
        id: core

        anchors.centerIn: parent
        width: 5 + 7 * root.level
        height: width
        radius: width / 2
        color: root.muted ? WalColors.color1 : WalColors.color4

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.45
            height: width
            radius: width / 2
            color: WalColors.color0
            opacity: 0.6
        }

        SequentialAnimation on scale {
            loops: Animation.Infinite
            running: !root.muted

            NumberAnimation {
                to: 1.15
                duration: 900
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }

        }

        Behavior on width {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 200
            }

        }

    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 2
        height: parent.height - 2
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: WalColors.color4
        opacity: root.hot ? 0.4 : 0
        scale: root.hot ? 1 : 0.9

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }

        }

    }

    // Kleiner Aufklapp-Indikator wenn expanded
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 2
        text: "⌃"
        color: WalColors.withAlpha(WalColors.color4, 0.6)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 9
        rotation: root.expanded ? 180 : 0
        visible: root.hot || root.expanded
        opacity: (root.hot || root.expanded) ? 1 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }

        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }

}
