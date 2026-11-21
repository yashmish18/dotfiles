import QtQuick
import Quickshell.Hyprland
import qs.services
import qs.components

// workspaces as film frame numbers: 01 02 03. the one you're on is lit.
// only workspaces that exist are shown; hyprland makes them on demand and drops empty ones.
Row {
    id: root
    property var monitor: null
    spacing: 10

    readonly property var list: Hypr.workspacesOn(monitor)

    Repeater {
        model: root.list

        delegate: Item {
            id: ws
            required property var modelData
            readonly property bool active: modelData.active
            readonly property bool named: modelData.name !== String(modelData.id)
            readonly property bool occupied: modelData.toplevels.values.length > 0
            implicitWidth: label.implicitWidth
            implicitHeight: Theme.barHeight

            Txt {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: ws.named ? ws.modelData.name : (ws.modelData.id < 10 ? "0" : "") + ws.modelData.id
                font.family: ws.named ? Theme.serif : Theme.mono
                font.italic: ws.named
                font.pixelSize: Theme.sm
                color: ws.active ? Theme.accent : ws.modelData.urgent ? Theme.danger : ws.occupied ? Theme.paper : Theme.faint
                Behavior on color { ColorAnimation { duration: Theme.normal } }
            }
            Rectangle {
                anchors.horizontalCenter: label.horizontalCenter
                anchors.top: label.bottom
                anchors.topMargin: 1
                width: ws.active ? label.width : 0
                height: 1
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => {
                    if (e.button === Qt.RightButton) {
                        Hypr.focusWorkspace(ws.modelData.id);
                        Ui.open("rename");
                    } else {
                        Hypr.focusWorkspace(ws.modelData.id);
                    }
                }
            }
        }
    }

    // a quiet "+" that opens a fresh workspace
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        text: "+"
        font.family: Theme.mono
        font.pixelSize: Theme.sm
        color: plus.containsMouse ? Theme.accent : Theme.faint
        MouseArea {
            id: plus
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Hypr.newWorkspace(false)
        }
    }
}
