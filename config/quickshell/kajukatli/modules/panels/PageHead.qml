import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components

// [←]  Wi-Fi                                   [scan] [off]
RowLayout {
    id: root
    property string title: ""
    property string subtitle: ""
    property bool backButton: true
    default property alias actions: tail.data
    signal back()
    Layout.fillWidth: true
    spacing: 10

    Btn {
        visible: root.backButton
        icon: "back"
        onClicked: root.back()
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Txt {
            Layout.fillWidth: true
            text: root.title.length ? root.title.charAt(0).toUpperCase() + root.title.slice(1) : ""
            font.pixelSize: Theme.lg + 2
            font.weight: Font.Bold
        }
        Txt {
            visible: root.subtitle !== ""
            Layout.fillWidth: true
            text: root.subtitle
            font.pixelSize: Theme.sm
            color: Theme.surfaceTextDim
        }
    }
    Row {
        id: tail
        spacing: 6
    }
}
