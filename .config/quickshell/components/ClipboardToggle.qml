import "../components"
import QtQuick
import Quickshell

Rectangle {
    id: root

    // Wenn false: keine eigene Hover-Box (Morph-Pill im Parent übernimmt).
    property bool hoverBoxEnabled: true
    readonly property real globalCenterX: windowX(root) + width / 2
    readonly property bool hot: mouseArea.containsMouse
    readonly property color ink: WalColors.color2

    function windowX(item) {
        var x = 0;
        var it = item;
        while (it && it.parent) {
            x += it.x;
            it = it.parent;
        }
        return x;
    }

    width: 32
    height: 32
    radius: 6
    color: (root.hoverBoxEnabled && root.hot) ? WalColors.withAlpha(WalColors.color2, 0.2) : "transparent"

    // Selbstgezeichnetes Klemmbrett-Icon (keine Font-Abhängigkeit)
    Item {
        id: icon

        anchors.centerIn: parent
        width: 18
        height: 20
        scale: root.hot ? 1.1 : 1

        // Brett
        Rectangle {
            x: 1
            y: 3
            width: 16
            height: 16
            radius: 4
            color: "transparent"
            border.width: 1.6
            border.color: root.ink
        }

        // Textzeilen – wachsen beim Hover
        Rectangle {
            x: 5
            y: 9
            width: root.hot ? 8 : 5
            height: 1.6
            radius: 0.8
            color: root.ink

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

        }

        Rectangle {
            x: 5
            y: 13
            width: root.hot ? 5 : 8
            height: 1.6
            radius: 0.8
            color: WalColors.withAlpha(root.ink, 0.65)

            Behavior on width {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }

            }

        }

        // Klammer – hebt sich leicht, mit Aussparung zum Brett
        Rectangle {
            x: 5
            y: root.hot ? 0 : 1
            width: 8
            height: 5
            radius: 2.5
            color: root.ink
            border.width: 2
            border.color: root.color === "transparent" || root.color.a === 0 ? WalColors.color0 : root.color

            Behavior on y {
                SpringAnimation {
                    spring: 6
                    damping: 0.4
                    epsilon: 0.1
                }

            }

        }

        Behavior on scale {
            SpringAnimation {
                spring: 5.5
                damping: 0.4
                epsilon: 0.01
            }

        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ClipboardState.toggle()
    }

    Behavior on color {
        ColorAnimation {
            duration: 100
        }

    }

}
