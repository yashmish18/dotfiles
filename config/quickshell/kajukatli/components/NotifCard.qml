import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.services

// one notification: app in mono, title in serif italic, body in sans, actions as words.
Rectangle {
    id: root
    required property var notif
    property bool popup: false
    signal done()

    implicitWidth: 360
    implicitHeight: col.implicitHeight + 24
    radius: 8
    color: Theme.ink
    border.width: 1
    border.color: notif && notif.urgency === NotificationUrgency.Critical ? Theme.danger : Theme.line

    readonly property string appIcon: notif && notif.appIcon ? (notif.appIcon.indexOf("/") === 0 || notif.appIcon.indexOf("file:") === 0 ? notif.appIcon : Quickshell.iconPath(notif.appIcon, true)) : ""

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // picture (a contact photo, an album cover…)
        Image {
            visible: root.notif && root.notif.image !== ""
            source: root.notif ? root.notif.image : ""
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignTop
            sourceSize: Qt.size(88, 88)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        ColumnLayout {
            id: col
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                IconImage {
                    visible: root.appIcon !== ""
                    source: root.appIcon
                    implicitSize: 12
                }
                Txt {
                    Layout.fillWidth: true
                    text: root.notif ? (root.notif.appName || "").toLowerCase() : ""
                    font.family: Theme.mono
                    font.pixelSize: Theme.xs
                    color: Theme.faint
                }
                Txt {
                    text: "×"
                    font.pixelSize: Theme.lg
                    color: closeArea.containsMouse ? Theme.paper : Theme.faint
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.popup) root.done();
                            else if (root.notif) root.notif.dismiss();
                        }
                    }
                }
            }

            Txt {
                Layout.fillWidth: true
                text: root.notif ? root.notif.summary : ""
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: Theme.md + 2
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notif ? root.notif.body : ""
                textFormat: Text.StyledText
                color: Theme.muted
                linkColor: Theme.accent
                font.family: Theme.sans
                font.pixelSize: Theme.sm + 1
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 4 : 8
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Row {
                visible: root.notif && root.notif.actions.length > 0
                spacing: 4
                Layout.topMargin: 4
                Repeater {
                    model: root.notif ? root.notif.actions : []
                    delegate: Btn {
                        required property var modelData
                        text: modelData.text.toLowerCase()
                        onClicked: {
                            modelData.invoke();
                            root.done();
                        }
                    }
                }
            }
        }
    }
}
