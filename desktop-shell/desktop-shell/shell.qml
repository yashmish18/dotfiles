import QtQuick
import Quickshell
import Quickshell.Io
import "./theme" as Theme
import "./dock"

ShellRoot {
    // TOP BAR
    PanelWindow {
        id: topBar

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 58
        exclusiveZone: 58
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 7

            radius: Theme.Design.radiusMedium
            color: Theme.Design.glass
            border.width: 1
            border.color: "#35FFFFFF"

            // BRAND
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter

                text: "KAJUKATLI"
                color: Theme.Design.primary
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
            }

            // WORKSPACE SWITCHER
            Row {
                id: workspaceRow

                anchors.centerIn: parent
                spacing: 7

                Repeater {
                    model: 5

                    delegate: Item {
                        id: workspaceItem

                        required property int index

                        width: 36
                        height: 36

                        property bool hovered: false

                        Process {
                            id: workspaceProcess

                            command: [
                                "hyprctl",
                                "dispatch",
                                "hl.dsp.focus({ workspace = \"" +
                                (workspaceItem.index + 1) + "\" })"
                            ]
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 11

                            color: workspaceItem.hovered
                                   ? "#45FFFFFF"
                                   : "#00000000"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                text: workspaceItem.index + 1
                                color: Theme.Design.primary
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: workspaceItem.hovered = true
                            onExited: workspaceItem.hovered = false

                            onClicked: workspaceProcess.startDetached()
                        }
                    }
                }
            }

            // CLOCK
            Text {
                id: clock

                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter

                property string displayTime:
                    Qt.formatDateTime(new Date(), "ddd, dd MMM  •  hh:mm")

                text: displayTime
                color: Theme.Design.primary
                font.pixelSize: 12

                Timer {
                    interval: 1000
                    running: true
                    repeat: true

                    onTriggered: {
                        clock.displayTime =
                            Qt.formatDateTime(new Date(), "ddd, dd MMM  •  hh:mm")
                    }
                }
            }
        }
    }

    // SINGLE DOCK INSTANCE
    Dock {}
}
