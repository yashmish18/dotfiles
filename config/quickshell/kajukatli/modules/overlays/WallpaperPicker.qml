import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// a contact sheet of your wallpapers. thumbnails are black & white until you look at one.
//   enter / click: use it      r: surprise me      p: parallax on/off
//   d: re-detect the subject   a: re-detect as anime / drawn art
Item {
    id: root
    focus: true
    property int sel: 0
    readonly property int cols: Math.max(2, Math.floor((width + 18) / (tileW + 18)))
    readonly property real tileW: 248
    readonly property real tileH: 155

    Component.onCompleted: {
        Wall.refreshLibrary();
        forceActiveFocus();
    }
    Connections {
        target: Wall
        function onLibraryChanged() {
            const i = Wall.current ? Wall.library.findIndex(w => w.path === Wall.current.source) : -1;
            root.sel = Math.max(0, i);
        }
    }

    function use(i) {
        const w = Wall.library[i];
        if (!w) return;
        Wall.set(w.path);
        Ui.overlay = "";
    }

    Keys.onLeftPressed: sel = Math.max(0, sel - 1)
    Keys.onRightPressed: sel = Math.min(Wall.library.length - 1, sel + 1)
    Keys.onUpPressed: sel = Math.max(0, sel - cols)
    Keys.onDownPressed: sel = Math.min(Wall.library.length - 1, sel + cols)
    Keys.onReturnPressed: use(sel)
    Keys.onPressed: e => {
        if (e.text === "r") { Wall.random(); Ui.overlay = ""; }
        else if (e.text === "p") Config.s.parallax = !Config.s.parallax;
        else if (e.text === "d") { Wall.redetect("birefnet-general-lite"); Ui.overlay = ""; }
        else if (e.text === "a") { Wall.redetect("isnet-anime"); Ui.overlay = ""; }
        else return;
        e.accepted = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 22

        RowLayout {
            Layout.fillWidth: true
            spacing: 18
            ColumnLayout {
                spacing: 2
                Txt {
                    text: "contact sheet"
                    font.family: Theme.serif
                    font.italic: true
                    font.pixelSize: 40
                    font.weight: Font.Light
                }
                Txt {
                    text: Config.s.wallpaperDir + "  ·  " + (Wall.listing ? "developing thumbnails…" : Wall.library.length + " frames")
                    font.family: Theme.mono
                    font.pixelSize: Theme.xs
                    color: Theme.faint
                }
            }
            Item { Layout.fillWidth: true }
            Btn { text: "parallax: " + (Config.s.parallax ? "on" : "off"); active: Config.s.parallax; onClicked: Config.s.parallax = !Config.s.parallax }
            Btn { text: "follow cursor: " + (Config.s.cursorParallax ? "on" : "off"); active: Config.s.cursorParallax; enabled: Config.s.parallax; onClicked: Config.s.cursorParallax = !Config.s.cursorParallax }
            Btn { text: "surprise me"; onClicked: { Wall.random(); Ui.overlay = ""; } }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: root.tileW + 18
            cellHeight: root.tileH + 44
            currentIndex: root.sel
            model: Wall.library
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool sel: index === root.sel
                readonly property bool current: Wall.current && Wall.current.source === modelData.path
                readonly property bool lit: sel || area.containsMouse
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    id: frame
                    width: root.tileW
                    height: root.tileH
                    radius: 4
                    color: Theme.surface
                    border.width: 1
                    border.color: tile.current ? Theme.accent : tile.sel ? Theme.accentDim : Theme.line
                    clip: true

                    Image {
                        id: thumb
                        anchors.fill: parent
                        anchors.margins: 1
                        source: tile.modelData.thumb ? "file://" + tile.modelData.thumb : ""
                        sourceSize: Qt.size(root.tileW * 1.5, root.tileH * 1.5)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: tile.lit
                    }
                    ShaderEffect {
                        anchors.fill: thumb
                        visible: !tile.lit && thumb.status === Image.Ready
                        property var src: thumb
                        fragmentShader: Qt.resolvedUrl("../../shaders/mono.frag.qsb")
                    }
                    // film rebate marks along the bottom, like a real contact sheet
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 6
                        spacing: 4
                        Repeater {
                            model: [tile.modelData.kind === "video" ? "moving" : "", tile.modelData.depth ? "3d" : "", tile.modelData.subject ? "drawn" : ""].filter(s => s)
                            delegate: Rectangle {
                                required property string modelData
                                color: Qt.rgba(0, 0, 0, 0.62)
                                radius: 2
                                width: badge.implicitWidth + 8
                                height: badge.implicitHeight + 2
                                Txt {
                                    id: badge
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    font.family: Theme.mono
                                    font.pixelSize: 9
                                    color: Theme.paper
                                }
                            }
                        }
                    }
                    Txt {
                        visible: thumb.status !== Image.Ready
                        anchors.centerIn: parent
                        text: tile.modelData.kind === "video" ? "a moving one" : "…"
                        font.family: Theme.serif
                        font.italic: true
                        color: Theme.faint
                    }
                }

                Row {
                    y: root.tileH + 8
                    spacing: 8
                    Txt {
                        text: String(tile.index + 1).padStart(2, "0")
                        font.family: Theme.mono
                        font.pixelSize: Theme.xs
                        color: tile.current ? Theme.accent : Theme.faint
                    }
                    Txt {
                        width: root.tileW - 30
                        text: tile.modelData.name.toLowerCase()
                        font.family: Theme.mono
                        font.pixelSize: Theme.xs
                        color: tile.lit ? Theme.paper : Theme.muted
                    }
                }

                MouseArea {
                    id: area
                    width: root.tileW
                    height: root.tileH
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.sel = tile.index
                    onClicked: root.use(tile.index)
                }
            }
        }

        Txt {
            visible: !Wall.listing && Wall.library.length === 0
            text: "this folder is empty. drop some pictures, gifs or videos into " + Config.s.wallpaperDir + "."
            font.family: Theme.serif
            font.italic: true
            font.pixelSize: Theme.lg
            color: Theme.muted
        }

        Txt {
            text: "enter use  ·  r surprise  ·  p parallax  ·  d re-detect subject  ·  a re-detect (anime / drawn art)  ·  esc close"
            font.family: Theme.mono
            font.pixelSize: Theme.xs
            color: Theme.faint
        }
    }
}
