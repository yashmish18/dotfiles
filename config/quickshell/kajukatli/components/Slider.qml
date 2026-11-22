import QtQuick
import qs.services

// a fat pill slider: the filled part is the value, the icon sits inside it (click it to mute),
// the number lives at the far end. drag, click, or scroll.
Item {
    id: root
    property string label: ""
    property string icon: ""
    property real value: 0          // 0..1
    property real level: -1         // passed to meter icons (volume waves); defaults to value
    property bool muted: false
    signal moved(real v)
    signal labelClicked()

    implicitWidth: 320
    implicitHeight: label !== "" ? 50 : 34

    Txt {
        id: cap
        visible: root.label !== ""
        text: root.label
        font.pixelSize: Theme.sm
        font.weight: Font.Medium
        color: Theme.surfaceTextDim
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 34
        radius: 17
        color: Theme.surfaceHigh
        clip: true

        Rectangle {
            id: fill
            readonly property real v: Math.max(0, Math.min(1, root.value))
            width: Math.max(height, track.width * v)
            height: parent.height
            radius: 17
            color: root.muted ? Theme.outline : Theme.primary
            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            // the grip: a short bar near the end of the fill
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: drag.pressed ? 18 : 12
                radius: 1.5
                visible: fill.width > 44
                color: Theme.alpha(Theme.primaryText, 0.55)
                Behavior on height { NumberAnimation { duration: Theme.fast } }
            }
        }

        Icon {
            id: ic
            visible: root.icon !== ""
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            level: root.level >= 0 ? root.level : root.value
            size: 16
            color: fill.width > 30 ? Theme.primaryText : Theme.surfaceText
        }

        Txt {
            anchors.right: parent.right
            anchors.rightMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(fill.v * 100)
            font.family: Theme.mono
            font.pixelSize: Theme.sm
            color: fill.width > track.width - 40 ? Theme.primaryText : Theme.surfaceTextDim
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.leftMargin: root.icon !== "" ? 34 : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function at(x) { return Math.max(0, Math.min(1, (x + anchors.leftMargin) / track.width)); }
            onPressed: e => root.moved(at(e.x))
            onPositionChanged: e => { if (pressed) root.moved(at(e.x)); }
            onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
        MouseArea {
            visible: root.icon !== ""
            width: 34
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: root.labelClicked()
        }
    }
}
