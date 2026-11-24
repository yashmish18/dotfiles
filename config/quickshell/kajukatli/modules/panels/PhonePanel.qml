import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import qs.services
import qs.components

// your phone (kk-phone, speaking the KDE Connect protocol): its battery, ring it, files and
// the clipboard both ways, its storage in the file manager. pair a new one from here too.
Item {
    id: root
    implicitWidth: 380
    implicitHeight: col.implicitHeight
    focus: true
    Keys.onEscapePressed: Ui.panel = ""
    Uses { service: Phone }
    Component.onCompleted: { if (!Phone.available) Phone.start(); else Phone.refresh(); }

    readonly property var d: Phone.current

    FileDialog {
        id: picker
        title: "Send to " + (root.d ? root.d.name : "phone")
        fileMode: FileDialog.OpenFiles
        onAccepted: Phone.sendPaths(root.d, selectedFiles.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))))
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        PageHead {
            backButton: false
            title: root.d ? root.d.name : "Phone"
            subtitle: !Phone.available ? "Starting the phone service…"
                : !root.d ? "No phone yet"
                : root.d.waiting ? "Accept on the phone"
                : !root.d.paired ? "Not paired"
                : !root.d.reachable ? "Paired · not nearby"
                : (root.d.battery >= 0 ? root.d.battery + "%" + (root.d.charging ? " · charging" : "") + " · " : "") + "connected"
            Btn { icon: "restart"; onClicked: Phone.available ? Phone.refresh() : Phone.start() }
        }

        // the phone asked to pair
        Repeater {
            model: Phone.requests
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 56
                radius: Theme.radius
                color: Theme.alpha(Theme.primary, 0.18)
                Txt { x: 14; anchors.verticalCenter: parent.verticalCenter; text: modelData.name + " wants to pair"; font.weight: Font.DemiBold }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Btn { text: "Accept"; primary: true; onClicked: Phone.accept(parent.parent.modelData) }
                    Btn { text: "No"; onClicked: Phone.reject(parent.parent.modelData) }
                }
            }
        }

        // not set up yet: how
        Txt {
            visible: Phone.devices.length === 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.surfaceTextDim
            font.pixelSize: Theme.sm
            text: "Put the free KDE Connect app on your phone (Play Store, F-Droid or App Store), same Wi-Fi as this computer. "
                + (Phone.selfName ? "“" + Phone.selfName + "” shows up in it; " : "This computer shows up in it; ")
                + "tap it, Request pairing, and accept here. Nothing from KDE is installed on this computer."
        }

        // the battery, big
        Rectangle {
            visible: root.d !== null && root.d.reachable && root.d.battery >= 0
            Layout.fillWidth: true
            implicitHeight: 54
            radius: Theme.radius
            color: Theme.surfaceHigh
            Rectangle {
                height: parent.height
                width: root.d && root.d.battery >= 0 ? parent.width * root.d.battery / 100 : 0
                radius: parent.radius
                color: Theme.alpha(root.d && root.d.battery <= 15 && !root.d.charging ? Theme.error : Theme.primary, 0.22)
            }
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Icon { anchors.verticalCenter: parent.verticalCenter; name: root.d && root.d.charging ? "battery-charging" : "battery"; level: root.d ? root.d.battery / 100 : 0; size: 22 }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: root.d ? root.d.battery + "%" : ""; font.pixelSize: Theme.lg; font.weight: Font.Bold; font.family: Theme.mono }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: root.d && root.d.charging ? "charging" : ""; color: Theme.surfaceTextDim; font.pixelSize: Theme.sm }
            }
        }

        // what you can do with it
        GridLayout {
            visible: root.d !== null && root.d.paired && root.d.reachable
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            Toggle { Layout.fillWidth: true; icon: "ring"; title: "Find it"; detail: "make it ring"; onToggled: Phone.ring(root.d) }
            Toggle { Layout.fillWidth: true; icon: "upload"; title: "Send files"; detail: "pick, and off they go"; onToggled: picker.open() }
            Toggle { Layout.fillWidth: true; icon: "clipboard"; title: "Clipboard"; detail: "send what you copied"; onToggled: Phone.sendClipboard(root.d) }
            Toggle { Layout.fillWidth: true; icon: "folder"; title: "Its files"; detail: root.d && root.d.mounted ? "open" : "browse its storage"; onToggled: { Ui.panel = ""; Phone.browse(root.d); } }
            Toggle { Layout.fillWidth: true; icon: "spark"; title: "Ping"; detail: "say hi"; onToggled: Phone.ping(root.d) }
            Toggle { Layout.fillWidth: true; icon: "battery"; title: "Battery"; detail: "ask again"; onToggled: Phone.battery(root.d) }
        }

        Txt {
            visible: Phone.message !== ""
            Layout.fillWidth: true
            text: Phone.message
            color: Theme.primary
            font.pixelSize: Theme.sm
        }

        // every phone it knows about
        Repeater {
            model: Phone.devices
            delegate: Rectangle {
                id: row
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 46
                radius: Theme.radiusSmall + 4
                color: Phone.current && Phone.current.id === modelData.id ? Theme.alpha(Theme.primary, 0.14) : rArea.containsMouse ? Theme.surfaceHigh : "transparent"
                Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "phone"; size: 18; color: row.modelData.reachable ? Theme.primary : Theme.outline }
                Column {
                    x: 42
                    anchors.verticalCenter: parent.verticalCenter
                    Txt { text: row.modelData.name; font.weight: Font.DemiBold }
                    Txt {
                        text: (row.modelData.paired ? "paired" : row.modelData.waiting ? "waiting for the phone" : "not paired") + (row.modelData.reachable ? " · nearby" : " · away")
                        font.pixelSize: Theme.xs + 1
                        color: Theme.surfaceTextDim
                    }
                }
                MouseArea { id: rArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Phone.selected = row.modelData.id }
                Btn {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.paired ? "Unpair" : "Pair"
                    danger: row.modelData.paired
                    enabled: row.modelData.paired || row.modelData.reachable
                    onClicked: row.modelData.paired ? Phone.unpair(row.modelData) : Phone.pair(row.modelData)
                }
            }
        }
    }
}
