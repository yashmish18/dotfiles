import QtQuick
import Quickshell
import Quickshell.Io
import "../theme" as Theme

PanelWindow {
    id: dockWindow

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: 100
    color: "transparent"

    Rectangle {
        id: dockBackground

        anchors.centerIn: parent

        width: 390
        height: 70
        radius: 26

        color: Theme.Design.glass
        border.width: 1
        border.color: "#35FFFFFF"

        Row {
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: [
                    { name: "Terminal", icon: "⌘", command: ["kitty"] },
                    { name: "Audio", icon: "♫", command: ["pavucontrol"] },
                    { name: "Monitor", icon: "◉", command: ["kitty", "-e", "btop"] },
                    { name: "Editor", icon: "✎", command: ["kitty", "-e", "nvim"] }
                ]

                delegate: Item {
                    id: dockItem

                    required property var modelData

                    width: 52
                    height: 52

                    property bool hovered: false

                    Process {
                        id: launcher
                        command: dockItem.modelData.command
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 17

                        color: dockItem.hovered
                            ? "#35FFFFFF"
                            : "#00000000"

                        scale: dockItem.hovered ? 1.12 : 1.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.Design.animationFast
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.Design.animationFast
                            }
                        }

                        Text {
                            anchors.centerIn: parent

                            text: dockItem.modelData.icon
                            color: Theme.Design.primary

                            font.pixelSize: 24
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: dockItem.hovered = true
                        onExited: dockItem.hovered = false
                        onClicked: launcher.startDetached()
                    }

                    Rectangle {
    visible: dockItem.hovered

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.top
    anchors.bottomMargin: 8

    width: tooltipText.implicitWidth + 20
    height: 28
    radius: 9

    color: "#EE202329"
    border.width: 1
    border.color: "#35FFFFFF"

    Text {
        id: tooltipText
        anchors.centerIn: parent

        text: dockItem.modelData.name
        color: "#FFFFFF"
        font.pixelSize: 11
    }
}
                }
            }
        }
    }
}
