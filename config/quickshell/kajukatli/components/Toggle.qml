import QtQuick
import qs.services

// a control-center tile: a name, what it's doing, and a small square that fills when on.
// click toggles; the arrow (when `more` is set) opens its page.
Rectangle {
    id: root
    property string title: ""
    property string detail: ""
    property bool on: false
    property bool more: false
    signal toggled()
    signal opened()

    implicitWidth: 168
    implicitHeight: 52
    radius: 6
    color: area.containsMouse ? Theme.raised : Theme.surface
    border.width: 1
    border.color: on ? Theme.accentDim : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on border.color { ColorAnimation { duration: Theme.normal } }

    // the square
    Rectangle {
        id: box
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 9
        height: 9
        color: root.on ? Theme.accent : "transparent"
        border.width: 1
        border.color: root.on ? Theme.accent : Theme.faint
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }

    Column {
        anchors.left: box.right
        anchors.leftMargin: 10
        anchors.right: arrow.visible ? arrow.left : parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Txt {
            width: parent.width
            text: root.title
            font.pixelSize: Theme.md
        }
        Txt {
            width: parent.width
            text: root.detail
            visible: text !== ""
            color: root.on ? Theme.accent : Theme.muted
            font.family: Theme.mono
            font.pixelSize: Theme.xs
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => (e.button === Qt.RightButton && root.more) ? root.opened() : root.toggled()
    }

    // separate hit area so the arrow opens the page instead of toggling
    Item {
        id: arrow
        visible: root.more
        width: 28
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        Hair {
            vertical: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - 20
        }
        Glyph {
            anchors.centerIn: parent
            g: ""
            font.pixelSize: 9
            color: arrowArea.containsMouse ? Theme.accent : Theme.muted
        }
        MouseArea {
            id: arrowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.opened()
        }
    }
}
