import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// "← wi-fi                     scan  turn off"
RowLayout {
    id: root
    property string title: ""
    default property alias actions: tail.data
    signal back()
    Layout.fillWidth: true
    spacing: 6

    Btn {
        glyph: ""
        size: 9
        onClicked: root.back()
    }
    Txt {
        text: root.title
        font.family: Theme.serif
        font.italic: true
        font.pixelSize: Theme.xl - 4
        Layout.fillWidth: true
    }
    Row {
        id: tail
        spacing: 2
    }
}
