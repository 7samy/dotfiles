import QtQuick
pragma Singleton

QtObject {
    readonly property QtObject
    anim: QtObject {
        readonly property QtObject
        durations: QtObject {
            readonly property int fast: 150
            readonly property int normal: 300
            readonly property int slow: 500
        }
        // Material Design 3 Motion-Kurven (offizielle Werte)

        readonly property QtObject
        curves: QtObject {
            readonly property var standard: [0.2, 0, 0, 1, 1, 1]
            readonly property var standardDecelerate: [0, 0, 0, 1, 1, 1]
            readonly property var standardAccelerate: [0.3, 0, 1, 1, 1, 1]
            readonly property var emphasized: [0.3, 0, 0.8, 0.15, 0.2, 1, 0.4, 0.99, 1, 1]
            readonly property var emphasizedDecelerate: [0.05, 0.7, 0.1, 1, 1, 1]
        }

    }

}
