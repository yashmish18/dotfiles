import QtQuick
import qs.services

// a quick-settings tile: an icon in a circle, a name, what it's doing. the whole tile lights up
// in the wallpaper's colour when it's on. with a page behind it (`more`): tap the icon to switch
// it on or off, tap anywhere else on the tile for its page. without one, the whole tile switches.
Rectangle {
    id: root
    property string title: ""
    property string detail: ""
    property string icon: ""
    property bool on: false
    property bool more: false
    signal toggled()
    signal opened()

    implicitWidth: 172
    implicitHeight: 58
    radius: Theme.radius
    color: on ? Theme.primaryContainer : area.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh
    opacity: enabled ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: Theme.normal } }
    scale: area.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    Rectangle {
        id: badge
        visible: root.icon !== ""
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 18
        color: root.on ? Theme.primary : Theme.alpha(Theme.surfaceText, 0.07)
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: 18
            color: root.on ? Theme.primaryText : Theme.surfaceText
        }
    }

    Column {
        anchors.left: badge.visible ? badge.right : parent.left
        anchors.leftMargin: badge.visible ? 10 : 14
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Txt {
            width: parent.width
            text: root.title
            font.weight: Font.DemiBold
            color: root.on ? Theme.primaryContainerText : Theme.surfaceText
        }
        Txt {
            width: parent.width
            text: root.detail
            visible: text !== ""
            font.pixelSize: Theme.sm
            color: root.on ? Theme.alpha(Theme.primaryContainerText, 0.8) : Theme.surfaceTextDim
        }
    }

    // the tile: its page (when it has one), or the switch (when it doesn't)
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.more ? root.opened() : root.toggled()
    }

    // the icon: always the switch. a little larger than the circle, easy to hit
    MouseArea {
        visible: root.more
        x: badge.x - 6
        y: badge.y - 6
        width: badge.width + 12
        height: badge.height + 12
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
        onContainsMouseChanged: badge.scale = containsMouse ? 1.08 : 1
    }
}
