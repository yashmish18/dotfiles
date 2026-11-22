import QtQuick
import qs.services
import qs.components

// puts one desktop widget where the layout says, and lets you drag it in edit mode.
// the position is stored as a fraction of the room the widget has to move in, so it lands in
// the same place on any screen size and never hangs off an edge.
Item {
    id: root
    property string name: ""
    property var fallback: ({ x: 0.5, y: 0.5 })
    property bool editable: true
    property bool shown: true
    default property alias content: holder.data

    readonly property Item item: holder.children.length > 0 ? holder.children[0] : null
    readonly property bool editing: Ui.editing && editable && shown
    readonly property var p: Config.pos(name, fallback)

    visible: shown
    width: shown && item ? item.implicitWidth : 0
    height: shown && item ? item.implicitHeight : 0

    function place() {
        x = Qt.binding(() => Math.round(Math.max(0, parent.width - width) * p.x));
        y = Qt.binding(() => Math.round(Math.max(0, parent.height - height) * p.y));
    }
    Component.onCompleted: place()

    Item {
        id: holder
        anchors.fill: parent
    }

    // ---------------------------------------------------------------- edit mode
    Rectangle {
        visible: root.editing
        anchors.fill: parent
        anchors.margins: -8
        radius: Theme.radiusSmall
        color: drag.drag.active ? Theme.alpha(Theme.primary, 0.14) : Theme.alpha(Theme.primary, 0.06)
        border.width: 1.5
        border.color: Theme.primary

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            implicitWidth: tag.implicitWidth + 14
            implicitHeight: 20
            radius: 10
            color: Theme.primary
            Txt {
                id: tag
                anchors.centerIn: parent
                text: root.name
                font.family: Theme.mono
                font.pixelSize: Theme.xs
                color: Theme.primaryText
            }
        }
    }
    MouseArea {
        id: drag
        visible: root.editing
        anchors.fill: parent
        anchors.margins: -8
        cursorShape: drag.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: Math.max(0, root.parent.width - root.width)
        drag.maximumY: Math.max(0, root.parent.height - root.height)
        drag.threshold: 2
        onReleased: {
            const fx = root.parent.width - root.width > 0 ? root.x / (root.parent.width - root.width) : 0.5;
            const fy = root.parent.height - root.height > 0 ? root.y / (root.parent.height - root.height) : 0.5;
            Config.setPos(root.name, fx, fy);
            root.place();
        }
    }
}
