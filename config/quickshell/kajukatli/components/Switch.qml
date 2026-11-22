import QtQuick
import qs.services

// an on/off switch: a track and a knob that slides, filled with the accent when on
Rectangle {
    id: root
    property bool on: false
    signal toggled()

    implicitWidth: 46
    implicitHeight: 26
    radius: 13
    color: on ? Theme.primary : Theme.surfaceHighest
    border.width: on ? 0 : 1.5
    border.color: Theme.outline
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Rectangle {
        width: root.on ? 18 : 14
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.on ? root.width - width - 4 : 6
        color: root.on ? Theme.primaryText : Theme.outline
        Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
        Behavior on width { NumberAnimation { duration: Theme.fast } }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
