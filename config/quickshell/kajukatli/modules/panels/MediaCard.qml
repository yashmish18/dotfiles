import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.services
import qs.components

// cover in black & white, title in italics, three words for controls.
Item {
    id: root
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
    property bool big: false
    implicitWidth: 360
    implicitHeight: big ? 136 : 64

    Image {
        id: art
        width: root.big ? 136 : 64
        height: width
        source: root.player ? root.player.trackArtUrl : ""
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    // desaturate so a loud album cover doesn't shout over the rest of the desktop
    ShaderEffect {
        id: artFx
        width: art.width
        height: art.height
        visible: art.status === Image.Ready
        property var src: art
        fragmentShader: Qt.resolvedUrl("../../shaders/mono.frag.qsb")
    }
    Rectangle {
        visible: art.status !== Image.Ready
        width: art.width
        height: art.height
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        Txt {
            anchors.centerIn: parent
            text: "♪"
            color: Theme.faint
            font.pixelSize: root.big ? 32 : 18
        }
    }

    ColumnLayout {
        anchors.left: art.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Txt {
            Layout.fillWidth: true
            text: root.player ? (root.player.trackTitle || "untitled") : ""
            font.family: Theme.serif
            font.italic: true
            font.pixelSize: root.big ? Theme.lg + 2 : Theme.md + 1
        }
        Txt {
            Layout.fillWidth: true
            text: root.player ? [root.player.trackArtist, root.big ? root.player.trackAlbum : ""].filter(s => s).join(" — ").toLowerCase() : ""
            color: Theme.muted
            font.pixelSize: Theme.sm
        }
        RowLayout {
            spacing: 0
            Layout.leftMargin: -6
            Btn { text: "prev"; enabled: root.player && root.player.canGoPrevious; onClicked: root.player.previous() }
            Btn { text: root.player && root.player.isPlaying ? "pause" : "play"; active: root.player && root.player.isPlaying; enabled: root.player && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
            Btn { text: "next"; enabled: root.player && root.player.canGoNext; onClicked: root.player.next() }
        }
    }
}
