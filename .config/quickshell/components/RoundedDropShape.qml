import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    property real cornerRadius: 20
    property real menuWidth: 200
    property real menuHeight: 120
    property color fillColor: WalColors.withAlpha(WalColors.color0, 0.9)

    width: menuWidth + 2 * cornerRadius
    height: menuHeight
    smooth: true
    antialiasing: true
    layer.enabled: true
    layer.smooth: true
    layer.samples: 16

    ShapePath {
        id: path

        fillColor: root.fillColor
        strokeColor: "transparent"
        strokeWidth: 0

        PathMove {
            x: 0
            y: 0
        }

        PathArc {
            x: root.cornerRadius
            y: root.cornerRadius
            radiusX: root.cornerRadius
            radiusY: root.cornerRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: root.cornerRadius
            y: root.menuHeight - root.cornerRadius
        }

        PathArc {
            x: 2 * root.cornerRadius
            y: root.menuHeight
            radiusX: root.cornerRadius
            radiusY: root.cornerRadius
            direction: PathArc.Counterclockwise
        }

        PathLine {
            x: root.cornerRadius + root.menuWidth - root.cornerRadius
            y: root.menuHeight
        }

        PathArc {
            x: root.cornerRadius + root.menuWidth
            y: root.menuHeight - root.cornerRadius
            radiusX: root.cornerRadius
            radiusY: root.cornerRadius
            direction: PathArc.Counterclockwise
        }

        PathLine {
            x: root.cornerRadius + root.menuWidth
            y: root.cornerRadius
        }

        PathArc {
            x: root.cornerRadius + root.menuWidth + root.cornerRadius
            y: 0
            radiusX: root.cornerRadius
            radiusY: root.cornerRadius
            direction: PathArc.Clockwise
        }

        PathLine {
            x: 0
            y: 0
        }

    }

    // Der Workaround aus deinen bisherigen Dropdowns – hier zentral einmal
    // implementiert statt in jeder Dropdown-Datei dupliziert.
    Connections {
        function onColorsUpdated() {
            path.fillColor = "transparent";
            redrawTimer.start();
        }

        target: WalColors
    }

    Timer {
        id: redrawTimer

        interval: 10
        onTriggered: path.fillColor = root.fillColor
    }

}
