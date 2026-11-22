import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// the wallpaper switcher: a carousel. the card in the middle is the one you'd get.
//   ← → / scroll   move           enter / click the middle card   use it
//   type           filter by name                   ctrl+r         surprise me
//   ctrl+a         re-detect the subject as drawn art     ctrl+p   parallax on/off
Item {
    id: root
    focus: true

    property string query: ""
    readonly property var items: {
        const q = query.toLowerCase().trim();
        return q === "" ? Wall.library : Wall.library.filter(w => w.name.toLowerCase().indexOf(q) !== -1);
    }
    readonly property var sel: items[strip.currentIndex] || null

    Component.onCompleted: {
        Wall.refreshLibrary();
        forceActiveFocus();
    }
    Connections {
        target: Wall
        function onLibraryChanged() { root.jumpToCurrent(); }
    }
    function jumpToCurrent() {
        const i = Wall.current ? items.findIndex(w => w.path === Wall.current.source) : -1;
        strip.currentIndex = Math.max(0, i);
        strip.positionViewAtIndex(strip.currentIndex, ListView.Center);
    }
    function use(w) {
        if (!w) return;
        Wall.set(w.path);
        Ui.overlay = "";
    }

    Keys.onLeftPressed: strip.decrementCurrentIndex()
    Keys.onRightPressed: strip.incrementCurrentIndex()
    Keys.onReturnPressed: use(sel)
    Keys.onEnterPressed: use(sel)
    Keys.onPressed: e => {
        const ctrl = e.modifiers & Qt.ControlModifier;
        if (ctrl && e.key === Qt.Key_R) { Wall.random(); Ui.overlay = ""; }
        else if (ctrl && e.key === Qt.Key_P) Config.s.parallax = !Config.s.parallax;
        else if (ctrl && e.key === Qt.Key_A) { Wall.redetect("isnet-anime"); Ui.overlay = ""; }
        else if (e.key === Qt.Key_Backspace) query = query.slice(0, -1);
        else if (e.text && e.text.length === 1 && e.text >= " " && !ctrl) query += e.text;
        else return;
        e.accepted = true;
    }
    onQueryChanged: { strip.currentIndex = 0; strip.positionViewAtBeginning(); }

    component Badge: Rectangle {
        id: bd
        property string label: ""
        property string icon: ""
        implicitWidth: br.implicitWidth + 16
        implicitHeight: 24
        radius: 12
        color: Theme.alpha("#000000", 0.45)
        Row {
            id: br
            anchors.centerIn: parent
            spacing: 5
            Icon { visible: bd.icon !== ""; name: bd.icon; size: 12; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: bd.label; font.pixelSize: Theme.xs + 1; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ------------------------------------------------------------ header
    RowLayout {
        id: head
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, 900)
        spacing: 12
        ColumnLayout {
            spacing: 2
            Txt {
                text: "Wallpapers"
                font.pixelSize: 28
                font.weight: Font.Bold
                color: "#ffffff"
            }
            Txt {
                text: Wall.listing && Wall.library.length === 0 ? "looking in " + Config.s.wallpaperDir + "…"
                    : root.items.length + (root.query ? " matching" : " in " + Config.s.wallpaperDir)
                font.pixelSize: Theme.sm
                color: Theme.alpha("#ffffff", 0.6)
            }
        }
        Item { Layout.fillWidth: true }
        // the filter, shown once you type
        Rectangle {
            visible: root.query !== ""
            implicitWidth: qrow.implicitWidth + 24
            implicitHeight: 34
            radius: 17
            color: Theme.alpha("#ffffff", 0.12)
            Row {
                id: qrow
                anchors.centerIn: parent
                spacing: 8
                Icon { name: "search"; size: 14; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: root.query; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Btn { icon: "shuffle"; text: "Surprise me"; onClicked: { Wall.random(); Ui.overlay = ""; } }
        Btn { icon: "external"; text: "Open folder"; onClicked: { Ui.overlay = ""; Quickshell.execDetached(["xdg-open", Config.wallpaperDir]); } }
    }

    // ------------------------------------------------------------ the strip
    ListView {
        id: strip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -10
        height: cardH + 40
        orientation: ListView.Horizontal
        spacing: 18
        model: root.items
        clip: false
        cacheBuffer: 600
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - cardW) / 2
        preferredHighlightEnd: (width + cardW) / 2
        highlightMoveDuration: 260
        snapMode: ListView.SnapToItem
        boundsBehavior: Flickable.StopAtBounds
        readonly property real cardW: Math.min(560, root.width * 0.42)
        reuseItems: true
        readonly property real cardH: cardW * 10 / 16

        WheelHandler {
            onWheel: e => (e.angleDelta.y || e.angleDelta.x) < 0 ? strip.incrementCurrentIndex() : strip.decrementCurrentIndex()
        }

        delegate: Item {
            id: card
            required property var modelData
            required property int index
            readonly property bool focused: ListView.isCurrentItem
            onFocusedChanged: if (!focused) sharp.wanted = false
            readonly property bool current: Wall.current && Wall.current.source === modelData.path
            width: strip.cardW
            height: strip.height
            z: focused ? 2 : 1

            Item {
                id: frame
                anchors.centerIn: parent
                width: strip.cardW
                height: strip.cardH
                scale: card.focused ? 1 : 0.8
                opacity: card.focused ? 1 : 0.55
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 300 } }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 22
                    color: Theme.surfaceHigh
                    Image {
                        id: thumb
                        anchors.fill: parent
                        source: card.modelData.thumb ? "file://" + card.modelData.thumb : ""
                        sourceSize: Qt.size(400, 250)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                    // the one in the middle gets a sharp preview on top: the prepared screen-size
                    // copy (not the original, which can be a huge png), and only once the strip
                    // has settled, so scrolling never waits on a decode
                    Timer { id: settle; interval: 220; running: card.focused; onTriggered: sharp.wanted = true }
                    Image {
                        id: sharp
                        property bool wanted: false
                        anchors.fill: parent
                        visible: card.focused && wanted && card.modelData.kind === "image"
                        source: visible ? "file://" + (card.modelData.meta && card.modelData.meta.display ? card.modelData.meta.display : card.modelData.path) : ""
                        sourceSize: Qt.size(strip.cardW * 1.5, strip.cardH * 1.5)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: thumb.status !== Image.Ready
                        name: card.modelData.kind === "video" ? "play" : "image"
                        size: 32
                        color: Theme.outline
                    }
                    // a soft floor so the badges read on bright pictures
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 70
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: Theme.alpha("#000000", 0.45) }
                        }
                    }
                }
                // the ring around the one you're on now
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -5
                    radius: 27
                    color: "transparent"
                    border.width: 2.5
                    border.color: Theme.primary
                    visible: card.current
                }
                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 14
                    spacing: 6
                    Badge { visible: card.current; icon: "check"; label: "in use" }
                    Badge { visible: card.modelData.kind === "video"; icon: "play"; label: "live" }
                    Badge { visible: card.modelData.subject; icon: "spark"; label: "depth" }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.focused ? root.use(card.modelData) : strip.currentIndex = card.index
                }
            }
        }
    }

    // ------------------------------------------------------------ what you're looking at
    ColumnLayout {
        anchors.top: strip.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        visible: root.sel !== null
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Rectangle {
                visible: root.sel && root.sel.seed
                width: 14
                height: 14
                radius: 7
                color: root.sel && root.sel.seed ? root.sel.seed : "transparent"
                border.width: 2
                border.color: Theme.alpha("#ffffff", 0.7)
            }
            Txt {
                text: root.sel ? root.sel.name.replace(/[-_]+/g, " ") : ""
                font.pixelSize: Theme.lg + 2
                font.weight: Font.DemiBold
                color: "#ffffff"
            }
        }
    }

    // nothing here yet
    ColumnLayout {
        anchors.centerIn: parent
        visible: !Wall.listing && Wall.library.length === 0
        spacing: 10
        Icon { Layout.alignment: Qt.AlignHCenter; name: "image"; size: 40; color: Theme.alpha("#ffffff", 0.6) }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: "No wallpapers yet"
            font.pixelSize: Theme.xl
            font.weight: Font.Bold
            color: "#ffffff"
        }
        Txt {
            Layout.alignment: Qt.AlignHCenter
            text: "Put pictures or videos in " + Config.s.wallpaperDir + ", or run ./install.sh --walls"
            color: Theme.alpha("#ffffff", 0.6)
        }
    }
}
