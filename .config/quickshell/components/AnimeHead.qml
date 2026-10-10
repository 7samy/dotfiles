import QtQuick
import Quickshell

Item {
    id: root

    // Reagiert auf die aktuelle Lautstaerke (0..1)
    readonly property real level: Math.max(0, Math.min(AudioState.volume, 1))
    readonly property bool muted: AudioState.volume <= 0.01
    readonly property bool hot: mouseArea.containsMouse
    // Bild-Pfad – hier anpassen falls dein Bild anders heisst
    readonly property string imageSource: "../resources/anime-head.png"

    signal clicked()

    width: 48
    height: 48
    scale: hot ? 1.08 : 1

    // ---------- Aeusserer Ring (pulsiert mit Lautstaerke) ----------
    Rectangle {
        id: ring

        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.muted ? WalColors.color1 : WalColors.color4
        opacity: root.muted ? 0.8 : 0.3 + 0.4 * root.level
        scale: 1 + 0.15 * root.level

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }

        }

    }

    // ---------- Glow (pulsiert staerker bei lauter Musik) ----------
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 4
        height: parent.height - 4
        radius: width / 2
        color: root.muted ? WalColors.color1 : WalColors.color4
        opacity: 0.08 + 0.25 * root.level
        layer.enabled: true
        layer.samples: 4

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }

        }

    }

    // ---------- Kopf-Bild (rund zugeschnitten) ----------
    Item {
        // Da Image kein clip mit radius kann, nutzen wir einen Trick:
        // Das Bild wird als Textur in einen runden Rahmen "gemalt".
        // Einfacher: wir setzen den radius direkt auf das Container-Item
        // und clippen das Image darin.
        // (Qt kann Image nicht direkt runden, deshalb der Umweg ueber
        // ein Rectangle mit Maske per ShaderEffectSource – aber fuer
        // den einfachen Fall reicht ein rundes Overlay.)
        // Fallback: wir nutzen das Image direkt und legen einen runden
        // Ring darueber, der die Ecken verdeckt.

        id: headContainer

        anchors.centerIn: parent
        width: parent.width - 10
        height: parent.height - 10
        clip: true

        // Runder Clip
        Rectangle {
            id: headMask

            anchors.fill: parent
            radius: width / 2
            visible: false
        }

        Image {
            id: headImg

            anchors.fill: parent
            source: root.imageSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize: Qt.size(96, 96)
            visible: false
        }

    }

    // ---------- Runde Maske (ueberdeckt die Ecken des Bildes) ----------
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 10
        height: parent.height - 10
        radius: width / 2
        color: "transparent"
        border.width: 10
        border.color: WalColors.withAlpha(WalColors.color0, 0.97)
    }

    // ---------- Augen-Leuchten (Farb-Overlay) ----------
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 10
        height: parent.height - 10
        radius: width / 2
        color: root.muted ? WalColors.color1 : WalColors.color4
        opacity: root.muted ? 0.2 : 0.05 + 0.2 * root.level
        visible: root.level > 0.02 || root.muted

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }

        }

    }

    // ---------- Bild (als letztes, damit es ueber den Overlays liegt) ----------
    Image {
        anchors.centerIn: parent
        width: parent.width - 10
        height: parent.height - 10
        source: root.imageSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize: Qt.size(96, 96)
    }

    // ---------- Klick-Handler ----------
    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // ---------- Hover-Skalierung ----------
    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }

    }

}
