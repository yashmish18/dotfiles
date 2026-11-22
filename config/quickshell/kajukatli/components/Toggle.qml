import QtQuick
import qs.services

// a row: icon, name, its state in small type, and a dot on the right that fills when on.
// click toggles; the chevron (when `more`) opens its page.
Item {
    id: root
    property string title: ""
    property string detail: ""
    property string icon: ""
    property real level: -1
    property bool on: false
    property bool more: false
    signal toggled()
    signal opened()

    implicitWidth: 320
    implicitHeight: 40
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: area.containsMouse ? Theme.alpha(Theme.surfaceText, 0.06) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    Icon {
        id: ic
        visible: root.icon !== ""
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        level: root.level
        size: 16
        color: root.on ? Theme.primary : Theme.surfaceTextDim
    }
    Txt {
        id: name
        anchors.left: ic.visible ? ic.right : parent.left
        anchors.leftMargin: ic.visible ? 12 : 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Theme.surfaceText
    }
    Txt {
        anchors.left: name.right
        anchors.leftMargin: 10
        anchors.right: chevron.visible ? chevron.left : dot.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.detail
        font.family: Theme.mono
        font.pixelSize: Theme.sm
        color: Theme.outline
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => (e.button === Qt.RightButton && root.more) ? root.opened() : root.toggled()
    }

    // opens the row's page
    Item {
        id: chevron
        visible: root.more
        anchors.right: dot.left
        anchors.rightMargin: 4
        width: 24
        height: parent.height
        Icon {
            anchors.centerIn: parent
            name: "right"
            size: 12
            color: chevArea.containsMouse ? Theme.surfaceText : Theme.outline
        }
        MouseArea {
            id: chevArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.opened()
        }
    }
    // on / off
    Rectangle {
        id: dot
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 10
        radius: 5
        color: root.on ? Theme.primary : "transparent"
        border.width: root.on ? 0 : 1.5
        border.color: Theme.outline
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
}
