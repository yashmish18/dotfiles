import QtQuick
import qs.services

// a thin line slider: icon on the left (click it to mute), the number on the right.
// drag, click, or scroll.
Item {
    id: root
    property string label: ""
    property string icon: ""
    property real value: 0          // 0..1
    property real level: -1         // passed to meter icons; defaults to value
    property bool muted: false
    property string valueText: ""   // shown instead of the percentage when set
    signal moved(real v)
    signal labelClicked()

    implicitWidth: 320
    implicitHeight: label !== "" ? 48 : 32

    readonly property real v: Math.max(0, Math.min(1, value))

    Txt {
        visible: root.label !== ""
        text: root.label
        font.pixelSize: Theme.sm
        color: Theme.surfaceTextDim
    }

    Item {
        id: line
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 32

        Icon {
            id: ic
            visible: root.icon !== ""
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            level: root.level >= 0 ? root.level : root.value
            size: 16
            color: root.muted ? Theme.outline : Theme.surfaceTextDim
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.labelClicked() }
        }
        Txt {
            id: num
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: root.valueText !== "" ? root.valueText : Math.round(root.v * 100)
            font.family: Theme.mono
            font.pixelSize: Theme.sm
            color: Theme.surfaceTextDim
        }
        Item {
            id: track
            anchors.left: ic.visible ? ic.right : parent.left
            anchors.leftMargin: ic.visible ? 14 : 0
            anchors.right: num.left
            anchors.rightMargin: 12
            height: parent.height
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 3
                radius: 1.5
                color: Theme.alpha(Theme.surfaceText, 0.14)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.v
                height: 3
                radius: 1.5
                color: root.muted ? Theme.outline : Theme.primary
                Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                x: parent.width * root.v - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: drag.pressed || drag.containsMouse ? 14 : 10
                height: width
                radius: width / 2
                color: root.muted ? Theme.outline : Theme.primary
                Behavior on width { NumberAnimation { duration: Theme.fast } }
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                anchors.topMargin: -4
                anchors.bottomMargin: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function at(x) { return Math.max(0, Math.min(1, x / width)); }
                onPressed: e => root.moved(at(e.x))
                onPositionChanged: e => { if (pressed) root.moved(at(e.x)); }
                onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
    }
}
