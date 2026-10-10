import "../components"
import QtQuick
import QtQuick.Controls
import Quickshell

Item {
    id: root

    readonly property var allImages: entries.filter((e) => {
        return e.isImage && matchesSearch(e);
    })
    readonly property var allTexts: entries.filter((e) => {
        return !e.isImage && matchesSearch(e);
    })
    readonly property var entries: ClipboardState.entries
    property real lastMouseX: -1
    property real lastMouseY: -1
    readonly property real rowHeight: 48
    readonly property real listWidth: 640
    readonly property real imageCardSize: 108

    function matchesSearch(e) {
        const q = PickerManager.searchText.toLowerCase();
        return q === "" || e.preview.toLowerCase().includes(q);
    }

    function focusSearch() {
        searchInput.forceActiveFocus();
    }

    Component.onCompleted: {
        ClipboardState.refresh();
    }
    onAllTextsChanged: textList.currentIndex = 0
    Keys.onEscapePressed: PickerManager.close()
    Keys.onReturnPressed: {
        if (root.allTexts.length > 0)
            ClipboardState.copyEntry(root.allTexts[textList.currentIndex].id);

    }

    // ==================== Suchleiste ====================
    Rectangle {
        id: searchBar

        width: Math.min(root.width * 0.5, 480)
        height: 52
        radius: height / 2
        anchors.top: parent.top
        anchors.topMargin: Math.max(root.height * 0.06, 40)
        anchors.horizontalCenter: parent.horizontalCenter
        color: WalColors.withAlpha(WalColors.color7, 0.1)
        border.width: searchInput.activeFocus ? 2 : 1
        border.color: searchInput.activeFocus ? WalColors.withAlpha(WalColors.color4, 0.7) : WalColors.withAlpha(WalColors.color7, 0.15)

        // Lupe als Unicode-Zeichen
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "⌕"
            color: WalColors.withAlpha(WalColors.color7, 0.5)
            font.pixelSize: 18
        }

        TextInput {
            id: searchInput

            anchors.fill: parent
            anchors.leftMargin: 50
            anchors.rightMargin: 110
            verticalAlignment: Text.AlignVCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: WalColors.color7
            text: PickerManager.searchText
            onTextChanged: PickerManager.searchText = text
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Tab) {
                    if (event.modifiers & Qt.ShiftModifier)
                        PickerManager.cycleBackward();
                    else
                        PickerManager.cycle();
                    event.accepted = true;
                    return ;
                }
                switch (event.key) {
                case Qt.Key_Down:
                    textList.moveCurrentIndexDown();
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                    textList.moveCurrentIndexUp();
                    event.accepted = true;
                    break;
                case Qt.Key_Left:
                    imageStrip.moveCurrentIndexLeft();
                    event.accepted = true;
                    break;
                case Qt.Key_Right:
                    imageStrip.moveCurrentIndexRight();
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (root.allTexts.length > 0)
                        ClipboardState.copyEntry(root.allTexts[textList.currentIndex].id);

                    event.accepted = true;
                    break;
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 50
            anchors.verticalCenter: parent.verticalCenter
            text: "Search clipboard…"
            color: WalColors.withAlpha(WalColors.color7, 0.32)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            visible: searchInput.text === ""
        }

        // Counts
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.allImages.length > 0
                text: root.allImages.length + " img"
                color: WalColors.withAlpha(WalColors.color4, 0.7)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.allTexts.length + " txt"
                color: WalColors.withAlpha(WalColors.color7, 0.55)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: 180
            }

        }

    }

    // ==================== Inhalt ====================
    Column {
        id: contentColumn

        width: root.listWidth
        anchors.top: searchBar.bottom
        anchors.topMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 24

        // ---------- Bilder-Sektion ----------
        Column {
            id: imagesSection

            width: parent.width
            spacing: 12
            visible: root.allImages.length > 0

            Row {
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 12
                    radius: 2
                    color: WalColors.color4
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "IMAGES"
                    color: WalColors.withAlpha(WalColors.color7, 0.5)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.letterSpacing: 1.6
                    font.bold: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·  click to open in swayimg"
                    color: WalColors.withAlpha(WalColors.color7, 0.3)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }

            }

            Item {
                width: parent.width
                height: root.imageCardSize + 8

                ListView {
                    id: imageStrip

                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 12
                    clip: true
                    model: root.allImages
                    currentIndex: -1
                    cacheBuffer: 400

                    delegate: Item {
                        id: imgDelegate

                        width: root.imageCardSize
                        height: root.imageCardSize

                        Item {
                            id: cardWrapper

                            width: parent.width
                            height: parent.height

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 8
                                height: parent.height + 8
                                radius: 20
                                color: WalColors.color4
                                opacity: imgMouse.containsMouse ? 0.35 : 0
                                layer.enabled: true
                                layer.samples: 4

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                    }

                                }

                            }

                            Rectangle {
                                id: card

                                anchors.fill: parent
                                radius: 14
                                color: WalColors.withAlpha(WalColors.color0, 0.85)
                                border.width: imgMouse.containsMouse ? 2 : 1
                                border.color: imgMouse.containsMouse ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.12)
                                clip: true
                                scale: imgMouse.containsMouse ? 1.04 : 1

                                Image {
                                    id: cardImage

                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: imgDelegate.modelData.imageReady ? "file://" + imgDelegate.modelData.imagePath : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize: Qt.size(220, 220)
                                    visible: status === Image.Ready
                                    opacity: 0
                                    onStatusChanged: {
                                        if (status === Image.Ready)
                                            cardImage.opacity = 1;

                                    }

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 240
                                            easing.type: Easing.OutCubic
                                        }

                                    }

                                }

                                // Platzhalter – nur Symbol, garantiert vorhanden
                                Text {
                                    anchors.centerIn: parent
                                    visible: !imgDelegate.modelData.imageReady
                                    text: "◫"
                                    color: WalColors.withAlpha(WalColors.color4, 0.5)
                                    font.pixelSize: 32

                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: !imgDelegate.modelData.imageReady

                                        NumberAnimation {
                                            to: 0.3
                                            duration: 900
                                            easing.type: Easing.InOutSine
                                        }

                                        NumberAnimation {
                                            to: 0.7
                                            duration: 900
                                            easing.type: Easing.InOutSine
                                        }

                                    }

                                }

                                // Öffnen-Marker oben rechts
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: WalColors.withAlpha(WalColors.color0, 0.85)
                                    border.width: 1
                                    border.color: WalColors.withAlpha(WalColors.color4, 0.5)
                                    opacity: imgMouse.containsMouse ? 1 : 0
                                    visible: opacity > 0.01

                                    Text {
                                        anchors.centerIn: parent
                                        text: "↗"
                                        color: WalColors.color4
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 180
                                        }

                                    }

                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.1
                                    }

                                }

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: 180
                                    }

                                }

                            }

                        }

                        MouseArea {
                            id: imgMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onEntered: imageStrip.currentIndex = index
                            onExited: {
                                if (imageStrip.currentIndex === index)
                                    imageStrip.currentIndex = -1;

                            }
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.MiddleButton)
                                    ClipboardState.deleteEntry(imgDelegate.modelData.id);
                                else if (imgDelegate.modelData.imageReady)
                                    ClipboardState.openImage(imgDelegate.modelData.id);
                            }
                        }

                    }

                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: WalColors.withAlpha(WalColors.color7, 0.08)
            }

        }

        // ---------- Text-Sektion ----------
        Column {
            id: textSection

            width: parent.width
            spacing: 12
            visible: root.allTexts.length > 0 || (root.allImages.length === 0 && ClipboardState.loaded)

            Row {
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 12
                    radius: 2
                    color: WalColors.withAlpha(WalColors.color7, 0.5)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TEXT"
                    color: WalColors.withAlpha(WalColors.color7, 0.5)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.letterSpacing: 1.6
                    font.bold: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·  click to copy"
                    color: WalColors.withAlpha(WalColors.color7, 0.3)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }

            }

            Item {
                width: parent.width
                height: 120
                visible: root.allTexts.length === 0 && ClipboardState.loaded

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "○"
                        font.pixelSize: 32
                        color: WalColors.withAlpha(WalColors.color7, 0.15)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: PickerManager.searchText === "" ? "Noch nichts kopiert" : "Keine Treffer"
                        color: WalColors.withAlpha(WalColors.color7, 0.35)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                }

            }

            ListView {
                id: textList

                width: parent.width
                height: Math.min(contentHeight, 360)
                clip: true
                spacing: 6
                model: root.allTexts
                currentIndex: 0
                cacheBuffer: 400

                delegate: Item {
                    id: textDelegate

                    readonly property bool isCurrent: ListView.isCurrentItem
                    readonly property string preview: modelData.preview || ""

                    width: textList.width
                    height: root.rowHeight

                    Item {
                        id: rowContent

                        width: parent.width
                        height: parent.height

                        Rectangle {
                            id: rowBg

                            anchors.fill: parent
                            radius: 10
                            color: textDelegate.isCurrent ? WalColors.withAlpha(WalColors.color4, 0.16) : (textMouse.containsMouse ? WalColors.withAlpha(WalColors.color7, 0.06) : WalColors.withAlpha(WalColors.color7, 0.03))
                            border.width: textDelegate.isCurrent ? 1 : 0
                            border.color: WalColors.withAlpha(WalColors.color4, 0.4)

                            // Akzent-Balken links
                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: parent.height - 16
                                radius: 1.5
                                color: WalColors.color4
                                opacity: textDelegate.isCurrent ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }

                                }

                            }

                            // Copy-Marker – Unicode
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                text: "⎘"
                                color: textDelegate.isCurrent ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.45)
                                font.pixelSize: 16

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }

                                }

                            }

                            // Preview
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 46
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: textDelegate.preview.replace(/\s+/g, ' ').trim()
                                color: textDelegate.isCurrent ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.75)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }

                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }

                            }

                        }

                    }

                    MouseArea {
                        id: textMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onPositionChanged: (mouse) => {
                            const p = textMouse.mapToItem(null, mouse.x, mouse.y);
                            if (Math.abs(p.x - root.lastMouseX) < 3 && Math.abs(p.y - root.lastMouseY) < 3)
                                return ;

                            root.lastMouseX = p.x;
                            root.lastMouseY = p.y;
                            textList.currentIndex = index;
                        }
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton)
                                ClipboardState.deleteEntry(textDelegate.modelData.id);
                            else
                                ClipboardState.copyEntry(textDelegate.modelData.id);
                        }
                    }

                }

            }

        }

        Item {
            width: parent.width
            height: 120
            visible: !ClipboardState.loaded && ClipboardState.entries.length === 0

            Text {
                anchors.centerIn: parent
                text: "Lade Zwischenablage…"
                color: WalColors.withAlpha(WalColors.color7, 0.4)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
            }

        }

    }

}
