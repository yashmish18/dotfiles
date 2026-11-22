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
                text: "Notifications"
                font.pixelSize: Theme.xl - 4
                Layout.fillWidth: true
            }
            Btn { icon: Notifs.dnd ? "bell-off" : "bell"; active: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
            Btn { text: "Clear"; visible: Notifs.count > 0; onClicked: Notifs.clearAll() }
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
            text: ""
            color: Theme.muted
            font.family: Theme.mono
            font.pixelSize: Theme.sm
            Layout.bottomMargin: 4
        }
    }
}
