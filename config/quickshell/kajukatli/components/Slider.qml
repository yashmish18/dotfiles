import QtQuick
import qs.services

// a hairline you can drag. the label sits on the left, the number on the right.
Item {
    id: root
    property string label: ""
    property real value: 0          // 0..1
    property bool muted: false
    property string glyph: ""
    signal moved(real v)
    signal labelClicked()

    implicitWidth: 320
    implicitHeight: 30

    Item {
        id: head
        width: 78
        height: parent.height
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Glyph {
                visible: root.glyph !== ""
                g: root.glyph
                font.pixelSize: Theme.sm
                color: root.muted ? Theme.faint : Theme.muted
                anchors.verticalCenter: parent.verticalCenter
            }
            Txt {
                text: root.label
                color: root.muted ? Theme.faint : Theme.muted
                font.family: Theme.mono
                font.pixelSize: Theme.xs
                font.strikeout: root.muted
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.labelClicked()
        }
    }

    Item {
        id: track
        anchors.left: head.right
        anchors.right: num.left
        anchors.rightMargin: 10
        height: parent.height

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Theme.line
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: drag.pressed || drag.containsMouse ? 3 : 2
            radius: 1
            color: root.muted ? Theme.faint : Theme.accent
            Behavior on height { NumberAnimation { duration: Theme.fast } }
            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.fast } }
        }
        Rectangle {
            x: parent.width * Math.max(0, Math.min(1, root.value)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: drag.pressed || drag.containsMouse ? 12 : 8
            color: Theme.paper
            Behavior on height { NumberAnimation { duration: Theme.fast } }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function at(x) { return Math.max(0, Math.min(1, x / width)); }
            onPressed: e => root.moved(at(e.x))
            onPositionChanged: e => { if (pressed) root.moved(at(e.x)); }
            onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }

    Txt {
        id: num
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100)
        color: Theme.muted
        font.family: Theme.mono
        font.pixelSize: Theme.xs
    }
}
