import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.services
import qs.components

// tray · wifi · bluetooth · volume · battery · notifications. click → control center.
Row {
    id: root
    spacing: 12

    // system tray (left click activates, right click opens the app's menu)
    Row {
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: SystemTray.items
            delegate: TrayItem {}
        }
    }

    Item {
        implicitWidth: icons.implicitWidth
        implicitHeight: Theme.barHeight
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: icons
            anchors.verticalCenter: parent.verticalCenter
            spacing: 11

            Glyph {
                g: Net.ethernet ? "" : ""
                font.pixelSize: Theme.sm
                color: Net.connected ? Theme.paper : Theme.faint
                anchors.verticalCenter: parent.verticalCenter
            }
            Glyph {
                visible: Bt.enabled
                g: ""
                font.pixelSize: Theme.sm
                color: Bt.connectedDevices.length > 0 ? Theme.paper : Theme.faint
                anchors.verticalCenter: parent.verticalCenter
            }
            Glyph {
                g: Audio.muted || Audio.volume === 0 ? "" : Audio.volume < 0.45 ? "" : ""
                font.pixelSize: Theme.sm
                color: Audio.muted ? Theme.faint : Theme.paper
                anchors.verticalCenter: parent.verticalCenter
            }
            Txt {
                visible: Power.hasBattery
                text: (Power.charging ? "+" : "") + Power.percent + "%"
                font.family: Theme.mono
                font.pixelSize: Theme.sm
                color: Power.low ? Theme.danger : Power.charging ? Theme.ok : Theme.paper
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: Ui.toggle("control")
        }
    }

    // notifications: only shows itself when there's something, or when you asked for quiet
    Item {
        visible: Notifs.count > 0 || Notifs.dnd
        implicitWidth: bell.implicitWidth
        implicitHeight: Theme.barHeight
        anchors.verticalCenter: parent.verticalCenter
        Txt {
            id: bell
            anchors.verticalCenter: parent.verticalCenter
            text: Notifs.dnd ? "quiet" : String(Notifs.count)
            font.family: Notifs.dnd ? Theme.serif : Theme.mono
            font.italic: Notifs.dnd
            font.pixelSize: Theme.sm
            color: Ui.panel === "notifications" ? Theme.accent : Notifs.dnd ? Theme.muted : Theme.paper
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: Ui.toggle("notifications")
        }
    }

    // a red word while the screen recorder runs; click to stop it
    Item {
        visible: Ui.recording
        implicitWidth: rec.implicitWidth
        implicitHeight: Theme.barHeight
        anchors.verticalCenter: parent.verticalCenter
        Txt {
            id: rec
            anchors.verticalCenter: parent.verticalCenter
            text: "rec"
            font.family: Theme.mono
            font.pixelSize: Theme.sm
            color: Theme.danger
            SequentialAnimation on opacity {
                running: Ui.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 700 }
                NumberAnimation { to: 1; duration: 700 }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["kk-record"])
        }
    }
}
