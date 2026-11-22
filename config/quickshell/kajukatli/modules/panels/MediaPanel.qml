import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components
import qs.modules.desktop

// now playing: the cover in full colour, the controls tinted by it.
// space: play / pause · ← →: previous / next
Item {
    id: root
    implicitWidth: 380
    implicitHeight: col.implicitHeight
    focus: true
    Keys.onEscapePressed: Ui.panel = ""
    Keys.onSpacePressed: Media.toggle()
    Keys.onLeftPressed: Media.prev()
    Keys.onRightPressed: Media.next()

    Uses { service: Media }
    readonly property color tint: Media.artColor

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        ClippingRectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width * 0.62
            radius: Theme.radius + 2
            color: Theme.surfaceHigh
            Image {
                id: art
                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(760, 760)
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                name: "music"
                size: 48
                color: Theme.outline
            }
            // the visualiser rising off the bottom edge of the cover
            Visualizer {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 46
                style: "bars"
                count: 48
                gap: 2
                color: "#ffffff"
                fillOpacity: 0.35
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Txt {
                Layout.fillWidth: true
                text: Media.active ? Media.title : ""
                font.pixelSize: Theme.lg + 3
                font.weight: Font.Bold
            }
            Txt {
                Layout.fillWidth: true
                text: [Media.artist, Media.album].filter(s => s).join("  ·  ")
                color: Theme.surfaceTextDim
            }
        }

        ColumnLayout {
            visible: Media.length > 0
            Layout.fillWidth: true
            spacing: 4
            WavyProgress {
                Layout.fillWidth: true
                value: Media.progress
                moving: Media.playing
                color: root.tint
                onSeek: f => Media.seek(f)
            }
            RowLayout {
                Layout.fillWidth: true
                Txt { text: Media.fmt(Media.position); font.family: Theme.mono; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                Item { Layout.fillWidth: true }
                Txt { text: Media.fmt(Media.length); font.family: Theme.mono; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            Btn { icon: "prev"; flat: true; implicitWidth: 44; implicitHeight: 44; onClicked: Media.prev() }
            Rectangle {
                implicitWidth: 60
                implicitHeight: 60
                radius: 30
                color: root.tint
                scale: playArea.pressed ? 0.93 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }
                Behavior on color { ColorAnimation { duration: Theme.slow } }
                Icon {
                    anchors.centerIn: parent
                    name: Media.playing ? "pause" : "play"
                    size: 24
                    color: Media.artText
                }
                MouseArea { id: playArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Media.toggle() }
            }
            Btn { icon: "next"; flat: true; implicitWidth: 44; implicitHeight: 44; onClicked: Media.next() }
        }

        // more than one player: pick which one this follows
        Flow {
            visible: Media.players.length > 1
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: Media.players
                Btn {
                    required property var modelData
                    text: modelData.identity
                    active: Media.player === modelData
                    onClicked: Media.pick(modelData)
                }
            }
        }
    }
}
