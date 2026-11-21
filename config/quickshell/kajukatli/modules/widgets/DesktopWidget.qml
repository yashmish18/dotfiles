import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.services
import qs.components

Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData
        visible: Config.s.desktopWidget
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "kajukatli-desktop-widget"
        exclusionMode: ExclusionMode.Ignore
        anchors { left: true; bottom: true }
        margins { left: 44; bottom: 44 }
        implicitWidth: 330
        implicitHeight: 210
        color: "transparent"

        SystemClock { id: clock; precision: SystemClock.Seconds }

        Column {
            anchors.fill: parent
            spacing: 6

            Txt {
                text: Config.s.clock24h
                    ? Qt.formatTime(clock.date, "HH:mm")
                    : Qt.formatTime(clock.date, "hh:mm AP")
                font.family: Theme.sans
                font.pixelSize: 82
                font.weight: Font.DemiBold
                color: Theme.paper
            }
            Txt {
                text: Qt.formatDate(clock.date, "dddd · dd MMMM")
                font.family: Theme.mono
                font.pixelSize: Theme.sm
                color: Theme.accent
            }

            Row {
                spacing: 4
                height: 42
                anchors.topMargin: 18
                Repeater {
                    model: 18
                    Rectangle {
                        required property int index
                        width: 7
                        height: 8 + ((index * 11 + 17) % 34)
                        radius: 3
                        y: 42 - height
                        color: index % 4 === 0 ? Theme.accent : Theme.muted
                        opacity: 0.75
                        SequentialAnimation on height {
                            running: Mpris.players.values.some(p => p.isPlaying)
                            loops: Animation.Infinite
                            NumberAnimation { to: 10 + (index * 7 % 32); duration: 420 + (index * 61 % 380); easing.type: Easing.InOutSine }
                            NumberAnimation { to: 8 + (index * 13 % 34); duration: 520 + (index * 37 % 260); easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }
}
