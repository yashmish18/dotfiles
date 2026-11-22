import QtQuick
import qs.services

// a quick-settings tile: an icon in a circle, a name, what it's doing. the whole tile lights up
// in the wallpaper's colour when it's on. click toggles; the chevron (when `more`) opens its page.
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
        anchors.right: chevron.visible ? chevron.left : parent.right
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

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => (e.button === Qt.RightButton && root.more) ? root.opened() : root.toggled()
    }

    // its own hit area, so the chevron opens the page instead of toggling
    Rectangle {
        id: chevron
        visible: root.more
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        radius: 13
        color: chevArea.containsMouse ? Theme.alpha(root.on ? Theme.primaryContainerText : Theme.surfaceText, 0.12) : "transparent"
        Icon {
            anchors.centerIn: parent
            name: "right"
            size: 14
            color: root.on ? Theme.primaryContainerText : Theme.surfaceTextDim
        }
        MouseArea {
            id: chevArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.opened()
        }
    }
}
