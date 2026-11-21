import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.services
import qs.components

Item {
    id: root
    implicitWidth: 400
    implicitHeight: col.implicitHeight + 8
    focus: true
    Keys.onEscapePressed: Ui.panel = ""
    Keys.onSpacePressed: if (card.player) card.player.togglePlaying()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        MediaCard {
            id: card
            big: true
            Layout.fillWidth: true
        }

        // position doesn't update by itself (mpris), so we tick it while visible
        Item {
            id: bar
            visible: card.player && card.player.positionSupported && card.player.length > 0
            Layout.fillWidth: true
            implicitHeight: 18
            property real pos: 0
            Timer {
                running: bar.visible && card.player && card.player.isPlaying
                interval: 1000
                repeat: true
                triggeredOnStart: true
                onTriggered: { card.player.positionChanged(); bar.pos = card.player.position; }
            }
            function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

            Txt { id: cur; text: bar.fmt(bar.pos); font.family: Theme.mono; font.pixelSize: Theme.xs; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
            Item {
                anchors.left: cur.right
                anchors.right: len.left
                anchors.margins: 10
                height: parent.height
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.line }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: card.player && card.player.length > 0 ? parent.width * Math.min(1, bar.pos / card.player.length) : 0
                    height: 2
                    color: Theme.accent
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: card.player && card.player.canSeek
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => {
                        const t = (e.x / width) * card.player.length;
                        card.player.position = t;
                        bar.pos = t;
                    }
                }
            }
            Txt { id: len; anchors.right: parent.right; text: card.player ? bar.fmt(card.player.length) : ""; font.family: Theme.mono; font.pixelSize: Theme.xs; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
        }

        // more than one player: pick which one the card follows
        Row {
            visible: Mpris.players.values.length > 1
            spacing: 2
            Repeater {
                model: Mpris.players.values
                delegate: Btn {
                    required property var modelData
                    text: (modelData.identity || "player").toLowerCase()
                    active: modelData === card.player
                    onClicked: modelData.raise()
                }
            }
        }

        Txt {
            visible: !card.player
            text: "silence, for now."
            font.family: Theme.serif
            font.italic: true
            color: Theme.muted
        }
    }
}
