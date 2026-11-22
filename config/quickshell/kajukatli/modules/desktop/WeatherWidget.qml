import QtQuick
import qs.services
import qs.components

// the weather, written on the wallpaper: icon, temperature, the sky, high and low
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Uses { service: Weather }

    Row {
        id: row
        spacing: 16
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Weather.icon
            size: 54
            weight: 1.4
            color: Theme.wallText
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: Weather.ready ? Weather.temp + "°" : "—"
                font.family: Theme.display
                font.pixelSize: 56
                font.weight: Font.Bold
                color: Theme.wallText
                renderType: Text.QtRendering
            }
            Txt {
                text: Weather.desc
                font.pixelSize: Theme.md
                color: Theme.wallTextDim
            }
            Txt {
                visible: Weather.ready
                text: "↑" + Weather.high + "°  ↓" + Weather.low + "°"
                font.family: Theme.mono
                font.pixelSize: Theme.sm
                color: Theme.wallTextDim
            }
        }
    }
}
