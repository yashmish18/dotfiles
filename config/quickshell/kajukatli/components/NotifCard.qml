import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.services

// one notification: the app, a bold summary, the body, actions as buttons.
Rectangle {
    id: root
    required property var notif
    property bool popup: false
    signal done()

    implicitWidth: 360
    implicitHeight: col.implicitHeight + 28
    radius: Theme.radius
    color: popup ? Theme.glassStrong : Theme.surfaceHigh
    border.width: notif && notif.urgency === NotificationUrgency.Critical ? 1.5 : 1
    border.color: notif && notif.urgency === NotificationUrgency.Critical ? Theme.error : Theme.alpha(Theme.outlineVariant, popup ? 0.6 : 0)

    readonly property string appIcon: notif && notif.appIcon ? (notif.appIcon.indexOf("/") === 0 || notif.appIcon.indexOf("file:") === 0 ? notif.appIcon : Quickshell.iconPath(notif.appIcon, true)) : ""

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // picture (a contact photo, an album cover…)
        Image {
            visible: root.notif && root.notif.image !== ""
            source: root.notif ? root.notif.image : ""
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
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
                    implicitSize: 14
                }
                Txt {
                    Layout.fillWidth: true
                    text: root.notif ? (root.notif.appName || "") : ""
                    font.pixelSize: Theme.sm
                    font.weight: Font.Medium
                    color: Theme.primary
                }
                Icon {
                    name: "close"
                    size: 14
                    color: closeArea.containsMouse ? Theme.surfaceText : Theme.outline
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
                font.pixelSize: Theme.md + 1
                font.weight: Font.DemiBold
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notif ? root.notif.body : ""
                textFormat: Text.StyledText
                color: Theme.surfaceTextDim
                linkColor: Theme.primary
                font.family: Theme.sans
                font.pixelSize: Theme.sm + 1
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 4 : 8
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Row {
                visible: root.notif && root.notif.actions.length > 0
                spacing: 6
                Layout.topMargin: 6
                Repeater {
                    model: root.notif ? root.notif.actions : []
                    delegate: Btn {
                        required property var modelData
                        text: modelData.text
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
