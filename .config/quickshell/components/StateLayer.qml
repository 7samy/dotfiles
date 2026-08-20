import "../components"
import QtQuick

Rectangle {
    id: root

    property alias hoverHandler: hover
    readonly property bool hovered: hover.hovered
    property real hoverOpacity: 0.15

    color: WalColors.color2
    opacity: hovered ? hoverOpacity : 0
    radius: parent.radius ?? 0

    HoverHandler {
        id: hover
    }

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.fast
        }

    }

}
