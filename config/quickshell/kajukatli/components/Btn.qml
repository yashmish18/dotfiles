import QtQuick
import qs.services

// a word you can press. underlines on hover instead of lighting up.
Item {
    id: root
    property string text: ""
    property string glyph: ""
    property color color: Theme.paper
    property bool active: false
    property bool danger: false
    property int size: Theme.sm
    property bool mono: true
    readonly property bool hovered: mouse.containsMouse
    signal clicked()
    signal rightClicked()

    implicitWidth: row.implicitWidth + 12
    implicitHeight: Math.max(24, row.implicitHeight + 8)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Glyph {
            visible: root.glyph !== ""
            g: root.glyph
            font.pixelSize: root.size + 1
            color: label.color
            anchors.verticalCenter: parent.verticalCenter
        }
        Txt {
            id: label
            visible: root.text !== ""
            text: root.text
            font.family: root.mono ? Theme.mono : Theme.sans
            font.pixelSize: root.size
            color: root.danger && root.hovered ? Theme.danger : root.active ? Theme.accent : root.color
            opacity: root.enabled ? (root.active || root.hovered ? 1 : 0.78) : 0.35
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Rectangle {
        anchors.left: row.left
        anchors.right: row.right
        anchors.top: row.bottom
        anchors.topMargin: 1
        height: 1
        color: root.danger ? Theme.danger : Theme.accent
        scale: root.hovered && root.enabled ? 1 : 0
        transformOrigin: Item.Left
        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
