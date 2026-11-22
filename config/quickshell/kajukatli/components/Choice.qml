import QtQuick
import QtQuick.Layouts
import qs.services

// a label and a row of options, one of them chosen. used all over settings → looks.
ColumnLayout {
    id: root
    property string label: ""
    property var options: []          // strings, or { value, label }
    property var value
    signal picked(var value)

    Layout.fillWidth: true
    spacing: 4

    Txt {
        visible: root.label !== ""
        text: root.label
        color: Theme.muted
        font.family: Theme.mono
        font.pixelSize: Theme.xs
    }
    Flow {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: root.options
            delegate: Rectangle {
                id: opt
                required property var modelData
                readonly property var v: typeof modelData === "object" ? modelData.value : modelData
                readonly property bool on: v === root.value
                implicitWidth: lbl.implicitWidth + 18
                implicitHeight: 24
                radius: Theme.radiusSmall
                color: on ? Theme.primary : area.containsMouse ? Theme.surfaceHigh : Theme.surfaceContainer
                border.width: 1
                border.color: on ? Theme.primary : Theme.outlineVariant
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Txt {
                    id: lbl
                    anchors.centerIn: parent
                    text: typeof opt.modelData === "object" ? opt.modelData.label : opt.modelData
                    font.pixelSize: Theme.sm
                    color: opt.on ? Theme.primaryText : Theme.surfaceText
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(opt.v)
                }
            }
        }
    }
}
