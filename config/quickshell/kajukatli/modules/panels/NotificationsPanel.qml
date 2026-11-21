import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

Item {
    id: root
    implicitWidth: 384
    implicitHeight: col.implicitHeight + 6
    focus: true
    Keys.onEscapePressed: Ui.panel = ""

    // opening the list means you've seen the toasts
    Component.onCompleted: Notifs.popups = []

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Txt {
                text: Notifs.count === 0 ? "nothing new." : Notifs.count === 1 ? "one thing." : Notifs.count + " things."
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: Theme.xl - 4
                Layout.fillWidth: true
            }
            Btn { text: Notifs.dnd ? "quiet: on" : "quiet: off"; active: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
            Btn { text: "clear"; visible: Notifs.count > 0; onClicked: Notifs.clearAll() }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 520)
            visible: Notifs.count > 0
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            // newest first
            model: Notifs.history.slice().reverse()
            delegate: NotifCard {
                required property var modelData
                notif: modelData
                width: list.width
            }
            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal } }
            removeDisplaced: Transition { NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }
        }

        Txt {
            visible: Notifs.count === 0
            text: Notifs.dnd ? "quiet is on. only urgent things get through." : "the world can wait."
            color: Theme.muted
            font.family: Theme.mono
            font.pixelSize: Theme.sm
            Layout.bottomMargin: 4
        }
    }
}
