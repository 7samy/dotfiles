import "../components"
import Qt5Compat.GraphicalEffects
import QtQuick

Item {
    id: root

    // ───────────────────────── Layout-Konstanten ─────────────────────────
    readonly property real pad: 16
    readonly property real bleed: 8
    readonly property real cardSize: 120
    readonly property real cardGap: 12
    readonly property real cardStride: cardSize + cardGap
    readonly property real rowH: 52
    readonly property real rowGap: 4
    readonly property real rowStride: rowH + rowGap
    readonly property real listMaxH: rowStride * 5.5
    readonly property real panelWidth: Math.min(680, width - 48)
    readonly property real innerWidth: panelWidth - 2 * pad
    readonly property string mono: "JetBrainsMono Nerd Font"
    // ───────────────────────── Zustand ─────────────────────────
    property string filter: "all"
    property string zone: "text" // "text" | "images"
    property int textIndex: 0
    property int imageIndex: 0
    property string flashId: ""
    property string dyingId: ""
    property bool confirmWipe: false
    property bool intro: true
    property real shown: 0
    property real lastMouseX: -1
    property real lastMouseY: -1
    // ───────────────────────── Daten ─────────────────────────
    readonly property string needle: PickerManager.searchText.toLowerCase()
    readonly property var entries: ClipboardState.entries
    readonly property var allImages: entries.filter((e) => {
        return e.isImage && matches(e);
    }).slice(0, ClipboardState.imageLimit)
    readonly property var allTexts: entries.filter((e) => {
        return !e.isImage && matches(e);
    }).slice(0, ClipboardState.textLimit)
    readonly property bool showImages: filter !== "text" && allImages.length > 0
    readonly property bool showTexts: filter !== "images" && allTexts.length > 0
    readonly property bool isEmpty: ClipboardState.loaded && !showImages && !showTexts
    readonly property real textTotal: allTexts.length * rowStride
    readonly property var filterModel: [{
        "key": "all",
        "label": "Alle"
    }, {
        "key": "text",
        "label": "Text"
    }, {
        "key": "images",
        "label": "Bilder"
    }]

    function matches(e) {
        return needle === "" || e.hay.indexOf(needle) !== -1;
    }

    function focusSearch() {
        searchInput.forceActiveFocus();
    }

    // ───────────────────────── Auswahl ─────────────────────────
    function normalizeZone() {
        if (zone === "images" && !showImages)
            zone = "text";
        else if (zone === "text" && !showTexts && showImages)
            zone = "images";
    }

    function clampSelection() {
        textIndex = Math.max(0, Math.min(textIndex, allTexts.length - 1));
        imageIndex = Math.max(0, Math.min(imageIndex, allImages.length - 1));
        normalizeZone();
    }

    function resetSelection() {
        listScroll.stop();
        stripScroll.stop();
        textIndex = 0;
        imageIndex = 0;
        textList.contentY = 0;
        strip.contentX = -strip.leftMargin;
        // Startet dort, wo der neueste Eintrag liegt.
        const fi = allImages.length > 0 ? entries.findIndex((e) => {
            return e.id === allImages[0].id;
        }) : 1e+09;
        const ft = allTexts.length > 0 ? entries.findIndex((e) => {
            return e.id === allTexts[0].id;
        }) : 1e+09;
        zone = (showImages && (!showTexts || fi < ft)) ? "images" : "text";
    }

    function setFilter(f) {
        if (filter === f)
            return ;

        filter = f;
        Qt.callLater(resetSelection);
    }

    function cycleFilter(dir) {
        const keys = ["all", "text", "images"];
        const i = keys.indexOf(filter);
        setFilter(keys[(i + dir + keys.length) % keys.length]);
    }

    function hoverSelect(target, mouse, zoneName, idx) {
        const p = target.mapToItem(null, mouse.x, mouse.y);
        if (Math.abs(p.x - lastMouseX) < 3 && Math.abs(p.y - lastMouseY) < 3)
            return ;

        lastMouseX = p.x;
        lastMouseY = p.y;
        zone = zoneName;
        if (zoneName === "text")
            textIndex = idx;
        else
            imageIndex = idx;
    }

    // ───────────────────────── Scrollen (animiert) ─────────────────────────
    function animateListTo(y) {
        const maxY = Math.max(0, textTotal - rowGap - textList.height);
        listScroll.stop();
        const to = Math.max(0, Math.min(y, maxY));
        if (Math.abs(to - textList.contentY) < 0.5)
            return ;

        listScroll.to = to;
        listScroll.start();
    }

    function animateStripTo(x) {
        const minX = -strip.leftMargin;
        const maxX = Math.max(minX, allImages.length * cardStride + strip.rightMargin - strip.width);
        const to = Math.max(minX, Math.min(x, maxX));
        const running = stripScroll.running;
        stripScroll.stop();
        if (!running && Math.abs(to - strip.contentX) < 0.5)
            return ;

        stripScroll.to = to;
        stripScroll.start();
    }

    function scrollTextTo(i) {
        const top = i * rowStride;
        const bottom = top + rowH;
        let to = textList.contentY;
        if (top - 6 < to)
            to = top - 6;
        else if (bottom + 6 > to + textList.height)
            to = bottom + 6 - textList.height;
        animateListTo(to);
    }

    function scrollStripTo(i) {
        const left = i * cardStride;
        const right = left + cardSize;
        let to = strip.contentX;
        if (left - 10 < to)
            to = left - 10;
        else if (right + 10 > to + strip.width)
            to = right + 10 - strip.width;
        animateStripTo(to);
    }

    // ───────────────────────── Navigation ─────────────────────────
    function moveVertical(dir) {
        if (dir > 0) {
            if (zone === "images") {
                if (showTexts) {
                    zone = "text";
                    scrollTextTo(textIndex);
                }
            } else if (textIndex < allTexts.length - 1) {
                textIndex++;
                scrollTextTo(textIndex);
            }
        } else if (zone === "text") {
            if (textIndex > 0) {
                textIndex--;
                scrollTextTo(textIndex);
            } else if (showImages) {
                zone = "images";
                scrollStripTo(imageIndex);
            }
        }
    }

    function moveHorizontal(dir) {
        const n = imageIndex + dir;
        if (n >= 0 && n < allImages.length) {
            imageIndex = n;
            scrollStripTo(n);
        }
    }

    // ───────────────────────── Aktionen ─────────────────────────
    function currentEntry() {
        if (zone === "images" && showImages)
            return allImages[imageIndex];

        if (showTexts)
            return allTexts[textIndex];

        return undefined;
    }

    function copyItem(e) {
        ClipboardState.copyEntry(e);
        flashId = e.id;
        closeTimer.restart();
    }

    function openImage(e) {
        if (!ClipboardState.readyIds[e.id])
            return ;

        ClipboardState.openImage(e);
        PickerManager.close();
    }

    function activateCurrent(alt) {
        const e = currentEntry();
        if (!e)
            return ;

        if (e.isImage && !alt)
            openImage(e);
        else
            copyItem(e);
    }

    function commitDelete() {
        if (dyingId !== "") {
            ClipboardState.deleteEntry(dyingId);
            dyingId = "";
        }
    }

    function requestDelete(e) {
        if (dyingId !== "")
            commitDelete();

        dyingId = e.id;
        deleteTimer.restart();
    }

    function deleteCurrent() {
        const e = currentEntry();
        if (e)
            requestDelete(e);

    }

    function playIntro() {
        intro = true;
        introTimer.restart();
        introAnim.restart();
        resetSelection();
    }

    Component.onCompleted: playIntro()
    onVisibleChanged: {
        if (visible)
            playIntro();

    }
    onAllTextsChanged: clampSelection()
    onAllImagesChanged: clampSelection()
    onEntriesChanged: {
        if (intro)
            Qt.callLater(resetSelection);

    }

    // ───────────────────────── Timer & Animationen ─────────────────────────
    Timer {
        id: introTimer

        interval: 700
        running: true
        onTriggered: root.intro = false
    }

    Timer {
        id: closeTimer

        // Nur noch Feedback-Dauer: nach dem Kopieren bleibt der Picker offen.
        interval: 900
        onTriggered: root.flashId = ""
    }

    Timer {
        id: deleteTimer

        interval: 230
        onTriggered: root.commitDelete()
    }

    Timer {
        id: wipeTimer

        interval: 2600
        onTriggered: root.confirmWipe = false
    }

    NumberAnimation {
        id: introAnim

        target: root
        property: "shown"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    NumberAnimation {
        id: listScroll

        target: textList
        property: "contentY"
        duration: 300
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    NumberAnimation {
        id: stripScroll

        target: strip
        property: "contentX"
        duration: 340
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    Connections {
        function onSearchTextChanged() {
            Qt.callLater(root.resetSelection);
        }

        target: PickerManager
    }

    // Klick neben das Panel schliesst den Picker.
    MouseArea {
        anchors.fill: parent
        onClicked: PickerManager.close()
    }

    // ═════════════════════════ Panel ═════════════════════════
    Item {
        id: panel

        width: root.panelWidth
        height: column.implicitHeight + 2 * root.pad
        x: (root.width - width) / 2
        y: Math.max(40, root.height * 0.12) + (1 - root.shown) * 24
        opacity: Math.min(1, root.shown * 1.6)
        scale: 0.95 + 0.05 * root.shown
        transformOrigin: Item.Top

        // weicher Schatten aus gestapelten Rechtecken (guenstiger als DropShadow)
        Repeater {
            model: 5

            Rectangle {
                readonly property real grow: (index + 1) * 6

                x: -grow
                y: -grow + 14
                width: panel.width + 2 * grow
                height: panel.height + 2 * grow
                radius: 28 + grow
                color: "#000000"
                opacity: 0.05
            }

        }

        Rectangle {
            anchors.fill: parent
            radius: 28
            color: WalColors.withAlpha(WalColors.color0, 0.97)
            border.width: 1
            border.color: WalColors.withAlpha(WalColors.color7, 0.09)
        }

        // schluckt Klicks auf dem Panel, damit der Backdrop nicht schliesst
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            x: root.pad
            y: root.pad
            width: root.innerWidth
            spacing: 0

            // ───────────── Header: Suche + Filter ─────────────
            Item {
                id: header

                width: parent.width
                height: 44

                Rectangle {
                    id: searchBox

                    anchors.left: parent.left
                    anchors.right: segmented.left
                    anchors.rightMargin: 12
                    height: parent.height
                    radius: height / 2
                    color: WalColors.withAlpha(WalColors.color7, searchInput.activeFocus ? 0.09 : 0.06)
                    border.width: 1.5
                    border.color: searchInput.activeFocus ? WalColors.withAlpha(WalColors.color4, 0.55) : WalColors.withAlpha(WalColors.color4, 0)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌕"
                        font.pixelSize: 20
                        color: searchInput.activeFocus ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.45)

                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }

                        }

                    }

                    TextInput {
                        id: searchInput

                        anchors.fill: parent
                        anchors.leftMargin: 48
                        anchors.rightMargin: 44
                        verticalAlignment: Text.AlignVCenter
                        font.family: root.mono
                        font.pixelSize: 14
                        color: WalColors.color7
                        selectionColor: WalColors.withAlpha(WalColors.color4, 0.4)
                        clip: true
                        text: PickerManager.searchText
                        onTextChanged: PickerManager.searchText = text
                        Component.onCompleted: forceActiveFocus()
                        Keys.onPressed: (event) => {
                            const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                            switch (event.key) {
                            case Qt.Key_Escape:
                                if (text !== "")
                                    text = "";
                                else
                                    PickerManager.close();
                                event.accepted = true;
                                break;
                            case Qt.Key_Tab:
                                if (shift)
                                    PickerManager.cycleBackward();
                                else
                                    PickerManager.cycle();
                                event.accepted = true;
                                break;
                            case Qt.Key_Backtab:
                                PickerManager.cycleBackward();
                                event.accepted = true;
                                break;
                            case Qt.Key_Down:
                                root.moveVertical(1);
                                event.accepted = true;
                                break;
                            case Qt.Key_Up:
                                root.moveVertical(-1);
                                event.accepted = true;
                                break;
                            case Qt.Key_Left:
                                if (ctrl) {
                                    root.cycleFilter(-1);
                                    event.accepted = true;
                                } else if (root.zone === "images" && root.showImages) {
                                    root.moveHorizontal(-1);
                                    event.accepted = true;
                                }
                                break;
                            case Qt.Key_Right:
                                if (ctrl) {
                                    root.cycleFilter(1);
                                    event.accepted = true;
                                } else if (root.zone === "images" && root.showImages) {
                                    root.moveHorizontal(1);
                                    event.accepted = true;
                                }
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.activateCurrent(shift);
                                event.accepted = true;
                                break;
                            case Qt.Key_D:
                                if (ctrl) {
                                    root.deleteCurrent();
                                    event.accepted = true;
                                }
                                break;
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Zwischenablage durchsuchen…"
                        font.family: root.mono
                        font.pixelSize: 14
                        color: WalColors.withAlpha(WalColors.color7, 0.3)
                        opacity: searchInput.text === "" ? 1 : 0

                        Behavior on opacity {
                            Smooth {
                                duration: 160
                            }

                        }

                    }

                    // Clear-Button
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        radius: 11
                        color: WalColors.withAlpha(WalColors.color7, clearArea.containsMouse ? 0.28 : 0.14)
                        opacity: searchInput.text !== "" ? 1 : 0
                        scale: searchInput.text !== "" ? 1 : 0.5
                        visible: opacity > 0.01

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 9
                            color: WalColors.color7
                        }

                        MouseArea {
                            id: clearArea

                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }

                        Behavior on opacity {
                            Smooth {
                                duration: 160
                            }

                        }

                        Behavior on scale {
                            Springy {
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }

                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }

                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 180
                        }

                    }

                }

                // iOS-Segmented-Control mit federnder Pille
                Rectangle {
                    id: segmented

                    readonly property real segW: 66
                    readonly property int idx: root.filter === "all" ? 0 : (root.filter === "text" ? 1 : 2)

                    anchors.right: parent.right
                    width: segW * 3 + 8
                    height: parent.height
                    radius: height / 2
                    color: WalColors.withAlpha(WalColors.color7, 0.06)

                    Rectangle {
                        x: 4 + segmented.idx * segmented.segW
                        y: 4
                        width: segmented.segW
                        height: parent.height - 8
                        radius: height / 2
                        color: WalColors.withAlpha(WalColors.color7, 0.15)

                        Behavior on x {
                            Springy {
                            }

                        }

                    }

                    Row {
                        x: 4

                        Repeater {
                            model: root.filterModel

                            delegate: Item {
                                id: seg

                                required property var modelData
                                required property int index
                                readonly property bool active: root.filter === modelData.key

                                width: segmented.segW
                                height: segmented.height

                                Text {
                                    anchors.centerIn: parent
                                    text: seg.modelData.label
                                    font.family: root.mono
                                    font.pixelSize: 12
                                    font.bold: seg.active
                                    color: seg.active ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.5)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 160
                                        }

                                    }

                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.setFilter(seg.modelData.key);
                                        searchInput.forceActiveFocus();
                                    }
                                }

                            }

                        }

                    }

                }

            }

            // ───────────── Bilder-Leiste ─────────────
            Item {
                id: imgSection

                x: -root.bleed
                width: parent.width + 2 * root.bleed
                height: root.showImages ? 14 + root.cardSize + 12 : 0
                opacity: root.showImages ? 1 : 0
                visible: height > 0.5
                clip: true

                ListView {
                    id: strip

                    y: 14
                    width: parent.width
                    height: root.cardSize + 12
                    orientation: ListView.Horizontal
                    leftMargin: root.bleed
                    rightMargin: root.bleed
                    spacing: 0
                    clip: true
                    model: root.allImages
                    currentIndex: root.imageIndex
                    cacheBuffer: 400
                    boundsBehavior: Flickable.StopAtBounds
                    onMovementStarted: stripScroll.stop()

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse
                        onWheel: (event) => {
                            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                            const base = stripScroll.running ? stripScroll.to : strip.contentX;
                            root.animateStripTo(base - d / 120 * root.cardStride);
                        }
                    }

                    delegate: Item {
                        id: card

                        required property var modelData
                        required property int index
                        readonly property var entry: modelData
                        readonly property bool selected: root.zone === "images" && root.imageIndex === index
                        readonly property bool ready: ClipboardState.readyIds[entry.id] === true
                        readonly property bool dying: root.dyingId === entry.id
                        readonly property bool flashing: root.flashId === entry.id
                        property real enter: 1

                        width: dying ? 0 : root.cardStride
                        height: strip.height
                        opacity: enter
                        clip: dying
                        Component.onCompleted: {
                            if (root.intro) {
                                enter = 0;
                                enterAnim.start();
                            }
                        }

                        SequentialAnimation {
                            id: enterAnim

                            PauseAnimation {
                                duration: Math.min(card.index, 8) * 35 + 60
                            }

                            NumberAnimation {
                                target: card
                                property: "enter"
                                to: 1
                                duration: 480
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                            }

                        }

                        Item {
                            id: body

                            anchors.verticalCenter: parent.verticalCenter
                            width: root.cardSize
                            height: root.cardSize
                            opacity: card.dying ? 0 : 1
                            scale: (card.selected ? 1.05 : 1) * (cardMouse.pressed ? 0.96 : 1)

                            // Platzhalter, bis das Bild geladen ist
                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: WalColors.withAlpha(WalColors.color7, 0.07)

                                SequentialAnimation on opacity {
                                    running: !card.ready
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        to: 0.45
                                        duration: 800
                                        easing.type: Easing.InOutSine
                                    }

                                    NumberAnimation {
                                        to: 1
                                        duration: 800
                                        easing.type: Easing.InOutSine
                                    }

                                }

                            }

                            Image {
                                id: thumb

                                anchors.fill: parent
                                visible: false
                                source: card.ready ? "file://" + card.entry.path : ""
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(260, 260)
                            }

                            Rectangle {
                                id: thumbMask

                                anchors.fill: parent
                                radius: 18
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: parent
                                source: thumb
                                maskSource: thumbMask
                                opacity: thumb.status === Image.Ready ? 1 : 0

                                Behavior on opacity {
                                    Smooth {
                                        duration: 360
                                    }

                                }

                            }

                            // Auswahlring
                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: "transparent"
                                border.width: 2
                                border.color: WalColors.color4
                                opacity: card.selected ? 1 : 0

                                Behavior on opacity {
                                    Smooth {
                                        duration: 180
                                    }

                                }

                            }

                            // Meta-Pille (Aufloesung · Groesse)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                width: metaText.implicitWidth + 10
                                height: 15
                                radius: 7.5
                                color: WalColors.withAlpha(WalColors.color0, 0.4)
                                opacity: card.selected && card.entry.meta !== "" ? 1 : 0
                                visible: opacity > 0.01

                                Text {
                                    id: metaText

                                    anchors.centerIn: parent
                                    text: card.entry.meta
                                    font.family: root.mono
                                    font.pixelSize: 8
                                    color: WalColors.withAlpha(WalColors.color7, 0.6)
                                }

                                Behavior on opacity {
                                    Smooth {
                                        duration: 180
                                    }

                                }

                            }

                            // Flash beim Kopieren
                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: WalColors.withAlpha(WalColors.color4, 0.55)
                                opacity: card.flashing ? 1 : 0

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 30
                                    font.bold: true
                                    color: WalColors.color0
                                    scale: card.flashing ? 1 : 0.4

                                    Behavior on scale {
                                        Springy {
                                        }

                                    }

                                }

                                Behavior on opacity {
                                    Smooth {
                                        duration: 140
                                    }

                                }

                            }

                            MouseArea {
                                id: cardMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onPositionChanged: (mouse) => {
                                    return root.hoverSelect(cardMouse, mouse, "images", card.index);
                                }
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.MiddleButton)
                                        root.requestDelete(card.entry);
                                    else if (mouse.button === Qt.RightButton)
                                        root.copyItem(card.entry);
                                    else
                                        root.openImage(card.entry);
                                }
                            }

                            Row {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                spacing: 0
                                opacity: card.selected && !card.flashing ? 1 : 0
                                visible: opacity > 0.01

                                IconButton {
                                    glyph: "✕"
                                    danger: true
                                    onClicked: root.requestDelete(card.entry)
                                }

                                Behavior on opacity {
                                    Smooth {
                                        duration: 160
                                    }

                                }

                            }

                            transform: Translate {
                                y: (1 - card.enter) * 16
                            }

                            Behavior on scale {
                                Springy {
                                }

                            }

                            Behavior on opacity {
                                Smooth {
                                    duration: 180
                                }

                            }

                        }

                        Behavior on width {
                            Smooth {
                                duration: 240
                            }

                        }

                    }

                }

                Behavior on height {
                    Smooth {
                    }

                }

                Behavior on opacity {
                    Smooth {
                        duration: 220
                    }

                }

            }

            // ───────────── Text-Liste ─────────────
            Item {
                id: textSection

                width: parent.width
                height: root.showTexts ? 14 + Math.min(root.textTotal - root.rowGap, root.listMaxH) : 0
                opacity: root.showTexts ? 1 : 0
                visible: height > 0.5
                clip: true

                ListView {
                    id: textList

                    y: 14
                    width: parent.width
                    height: Math.max(0, textSection.height - 14)
                    spacing: 0
                    model: root.allTexts
                    currentIndex: root.textIndex
                    cacheBuffer: 400
                    highlightFollowsCurrentItem: false
                    onMovementStarted: listScroll.stop()

                    // Eine einzige Auswahl-Pille, die per Feder zur aktuellen Zeile gleitet.
                    highlight: Rectangle {
                        y: root.textIndex * root.rowStride
                        width: textList.width
                        height: root.rowH
                        radius: 16
                        color: WalColors.withAlpha(WalColors.color4, 0.13)
                        opacity: root.zone === "text" ? 1 : 0

                        Behavior on y {
                            Springy {
                            }

                        }

                        Behavior on opacity {
                            Smooth {
                                duration: 160
                            }

                        }

                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property var entry: modelData
                        readonly property bool selected: root.zone === "text" && root.textIndex === index
                        readonly property bool dying: root.dyingId === entry.id
                        readonly property bool flashing: root.flashId === entry.id
                        property real enter: 1

                        width: textList.width
                        height: dying ? 0 : root.rowStride
                        opacity: enter
                        clip: dying
                        Component.onCompleted: {
                            if (root.intro) {
                                enter = 0;
                                rowEnter.start();
                            }
                        }

                        SequentialAnimation {
                            id: rowEnter

                            PauseAnimation {
                                duration: Math.min(row.index, 9) * 30 + 60
                            }

                            NumberAnimation {
                                target: row
                                property: "enter"
                                to: 1
                                duration: 460
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
                            }

                        }

                        Item {
                            id: rowBody

                            width: parent.width
                            height: root.rowH
                            opacity: row.dying ? 0 : 1
                            scale: rowMouse.pressed ? 0.985 : 1

                            Rectangle {
                                anchors.fill: parent
                                radius: 16
                                color: WalColors.withAlpha(WalColors.color4, 0.3)
                                opacity: row.flashing ? 1 : 0

                                Behavior on opacity {
                                    Smooth {
                                        duration: 140
                                    }

                                }

                            }

                            // Typ-Badge: Farbfeld, Link oder Text
                            Rectangle {
                                id: badge

                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                height: 34
                                radius: 11
                                color: row.selected ? WalColors.withAlpha(WalColors.color4, 0.2) : WalColors.withAlpha(WalColors.color7, 0.07)

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    radius: 6
                                    visible: row.entry.kind === "color"
                                    color: row.entry.kind === "color" ? row.entry.label : "transparent"
                                    border.width: 1
                                    border.color: WalColors.withAlpha(WalColors.color7, 0.25)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: row.entry.kind !== "color"
                                    text: row.entry.kind === "url" ? "//" : "Aa"
                                    font.family: root.mono
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: row.selected ? WalColors.color4 : WalColors.withAlpha(WalColors.color7, 0.5)

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

                            Text {
                                anchors.left: badge.right
                                anchors.leftMargin: 12
                                anchors.right: rightArea.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.entry.label
                                font.family: root.mono
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                                color: row.selected ? WalColors.color7 : WalColors.withAlpha(WalColors.color7, 0.72)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }

                                }

                            }

                            MouseArea {
                                id: rowMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onPositionChanged: (mouse) => {
                                    return root.hoverSelect(rowMouse, mouse, "text", row.index);
                                }
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.MiddleButton)
                                        root.requestDelete(row.entry);
                                    else
                                        root.copyItem(row.entry);
                                }
                            }

                            Row {
                                id: rightArea

                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: row.flashing
                                    text: "Kopiert ✓"
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: WalColors.color4
                                }

                                IconButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 20
                                    glyph: "✕"
                                    danger: true
                                    opacity: row.selected && !row.flashing ? 1 : 0
                                    visible: opacity > 0.01
                                    onClicked: root.requestDelete(row.entry)

                                    Behavior on opacity {
                                        Smooth {
                                            duration: 160
                                        }

                                    }

                                }

                            }

                            transform: Translate {
                                y: (1 - row.enter) * 12
                            }

                            Behavior on scale {
                                Springy {
                                }

                            }

                            Behavior on opacity {
                                Smooth {
                                    duration: 180
                                }

                            }

                        }

                        Behavior on height {
                            Smooth {
                                duration: 220
                            }

                        }

                    }

                }

                // Fade am unteren Rand, solange noch mehr Zeilen folgen
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 36
                    opacity: textList.contentY + textList.height < root.textTotal - root.rowGap - 4 ? 1 : 0

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: WalColors.withAlpha(WalColors.color0, 0)
                        }

                        GradientStop {
                            position: 1
                            color: WalColors.withAlpha(WalColors.color0, 0.97)
                        }

                    }

                    Behavior on opacity {
                        Smooth {
                            duration: 200
                        }

                    }

                }

                Behavior on height {
                    Smooth {
                    }

                }

                Behavior on opacity {
                    Smooth {
                        duration: 220
                    }

                }

            }

            // ───────────── Leerzustand ─────────────
            Item {
                id: emptyState

                width: parent.width
                height: root.isEmpty ? 150 : 0
                opacity: root.isEmpty ? 1 : 0
                visible: height > 0.5
                clip: true

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "◌"
                        font.pixelSize: 36
                        color: WalColors.withAlpha(WalColors.color7, 0.2)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: PickerManager.searchText === "" ? "Zwischenablage ist leer" : "Nichts gefunden"
                        font.family: root.mono
                        font.pixelSize: 12
                        color: WalColors.withAlpha(WalColors.color7, 0.38)
                    }

                }

                Behavior on height {
                    Smooth {
                    }

                }

                Behavior on opacity {
                    Smooth {
                        duration: 220
                    }

                }

            }

            // ───────────── Footer ─────────────
            Item {
                id: footer

                width: parent.width
                height: 14 + 18

                Text {
                    id: wipeLabel

                    anchors.right: parent.right
                    y: 14
                    height: 18
                    verticalAlignment: Text.AlignVCenter
                    text: root.confirmWipe ? "Nochmal klicken zum Löschen" : "Alles löschen"
                    font.family: root.mono
                    font.pixelSize: 10
                    color: root.confirmWipe ? WalColors.color1 : WalColors.withAlpha(WalColors.color7, wipeArea.containsMouse ? 0.75 : 0.32)

                    MouseArea {
                        id: wipeArea

                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.confirmWipe) {
                                ClipboardState.wipe();
                                root.confirmWipe = false;
                                wipeTimer.stop();
                            } else {
                                root.confirmWipe = true;
                                wipeTimer.restart();
                            }
                            searchInput.forceActiveFocus();
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }

                    }

                }

            }

        }

    }

    // ───────────────────────── Wiederverwendbare Bausteine ─────────────────────────
    component Smooth: NumberAnimation {
        duration: 320
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }

    component Springy: SpringAnimation {
        spring: 5.5
        damping: 0.4
        epsilon: 0.2
    }

    component IconButton: Rectangle {
        id: btn

        property string glyph: ""
        property bool danger: false
        property real size: 20

        signal clicked()

        width: size
        height: size
        radius: size / 2
        color: btnArea.containsMouse ? WalColors.withAlpha(danger ? WalColors.color1 : WalColors.color4, 0.9) : WalColors.withAlpha(WalColors.color0, 0.4)
        scale: btnArea.pressed ? 0.9 : 1

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            font.family: root.mono
            font.pixelSize: btn.size * 0.42
            color: btnArea.containsMouse ? WalColors.color0 : WalColors.withAlpha(WalColors.color7, 0.55)
        }

        MouseArea {
            id: btnArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }

        Behavior on scale {
            Springy {
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }

        }

    }

}
