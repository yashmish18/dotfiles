import QtQuick
import qs.services

// a button. tonal by default, filled when `active` (or `primary`), red when it's dangerous.
// text, an icon, or both.
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool active: false
    property bool primary: false
    property bool danger: false
    property bool flat: false          // no fill until hovered (for rows of small actions)
    property int size: Theme.sm + 1
    property bool mono: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool filled: active || primary
    signal clicked()
    signal rightClicked()

    implicitWidth: row.implicitWidth + (text !== "" ? 24 : 0) + (text === "" ? 30 - row.implicitWidth : 0)
    implicitHeight: 30
    radius: Theme.radiusSmall
    color: !enabled ? Theme.alpha(Theme.surfaceText, 0.05)
         : filled ? (danger ? Theme.error : Theme.primary)
         : danger && hovered ? Theme.alpha(Theme.error, 0.18)
         : hovered ? Theme.alpha(Theme.surfaceText, 0.12)
         : flat ? "transparent" : Theme.alpha(Theme.surfaceText, 0.06)
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    scale: mouse.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    readonly property color ink: !enabled ? Theme.alpha(Theme.surfaceText, 0.35)
                               : filled ? (danger ? Theme.errorText : Theme.primaryText)
                               : danger ? Theme.error : Theme.surfaceText

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Icon {
            visible: root.icon !== ""
            name: root.icon
            size: root.text !== "" ? 14 : 16
            color: root.ink
            anchors.verticalCenter: parent.verticalCenter
        }
        Txt {
            visible: root.text !== ""
            text: root.text
            font.family: root.mono ? Theme.mono : Theme.sans
            font.pixelSize: root.size
            font.weight: Font.Medium
            color: root.ink
            anchors.verticalCenter: parent.verticalCenter
        }
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
