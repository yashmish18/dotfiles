import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// every app running for you, in one place: with windows, in the tray, or with nothing on
// screen at all. tap one for everything about it: go to it, its own menu, close its windows,
// quit, force quit, and whether it may keep running in the background.
Item {
    id: root
    implicitWidth: 400
    implicitHeight: col.implicitHeight
    focus: true
    Keys.onEscapePressed: Ui.panel = ""
    Uses { service: Apps }
    Component.onCompleted: Hyprland.refreshToplevels()

    property string open: ""        // the app whose controls are showing

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        PageHead {
            backButton: false
            title: "Running"
            subtitle: Apps.count + (Apps.count === 1 ? " app" : " apps")
                + (Apps.hiddenCount > 0 ? " · " + Apps.hiddenCount + " without a window" : "")
            Btn { icon: "cpu"; onClicked: Ui.toggleOverlay("system") }
        }

        ListView {
            id: apps
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 460)
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: Apps.list
            delegate: ColumnLayout {
                id: app
                required property var modelData
                readonly property var g: modelData
                readonly property bool expanded: root.open === g.key
                width: apps.width
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: Theme.radiusSmall + 4
                    color: app.expanded ? Theme.alpha(Theme.primary, 0.16) : rowArea.containsMouse ? Theme.surfaceHigh : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    IconImage {
                        id: ico
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 28
                        source: app.g.icon
                    }
                    Column {
                        anchors.left: ico.right
                        anchors.leftMargin: 12
                        anchors.right: badge.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        Txt { width: parent.width; text: app.g.name; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Txt {
                            width: parent.width
                            elide: Text.ElideRight
                            font.pixelSize: Theme.xs + 1
                            color: Theme.surfaceTextDim
                            text: (app.g.windows.length ? app.g.windows.length + (app.g.windows.length === 1 ? " window" : " windows")
                                   : app.g.tray ? "in the tray" : "in the background")
                                + (app.g.mem > 0 ? " · " + (app.g.mem > 1048576 ? (app.g.mem / 1048576).toFixed(1) + " GB" : Math.round(app.g.mem / 1024) + " MB") : "")
                                + (app.g.cpu >= 1 ? " · " + Math.round(app.g.cpu) + "% cpu" : "")
                        }
                    }
                    // how it's running, at a glance
                    Rectangle {
                        id: badge
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: badgeTxt.implicitWidth + 14
                        height: 20
                        radius: 10
                        color: app.g.kind === "background" ? Theme.alpha(Theme.error, 0.16) : Theme.alpha(Theme.surfaceText, 0.07)
                        Txt {
                            id: badgeTxt
                            anchors.centerIn: parent
                            text: app.g.kind === "window" ? "open" : app.g.kind === "tray" ? "tray" : "hidden"
                            font.pixelSize: Theme.xs
                            font.family: Theme.mono
                            color: app.g.kind === "background" ? Theme.error : Theme.surfaceTextDim
                        }
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.open = app.expanded ? "" : app.g.key
                    }
                }

                // everything about it
                Rectangle {
                    visible: app.expanded
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 4
                    implicitHeight: ctl.implicitHeight + 20
                    radius: Theme.radiusSmall + 4
                    color: Theme.surfaceHigh
                    ColumnLayout {
                        id: ctl
                        x: 10; y: 10
                        width: parent.width - 20
                        spacing: 6
                        // its windows, each one a click away
                        Repeater {
                            model: app.g.windows
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 8
                                color: wArea.containsMouse ? Theme.surfaceHighest : "transparent"
                                Txt {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.right: wClose.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.sm
                                    text: (modelData.ws > 0 ? modelData.ws + "  " : "") + (modelData.title || "window")
                                }
                                MouseArea {
                                    id: wArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { Hypr.focusWindow(parent.modelData.address); Ui.panel = ""; }
                                }
                                Btn {
                                    id: wClose
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    flat: true
                                    icon: "close"
                                    onClicked: Hypr.closeWindow(parent.modelData.address)
                                }
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Btn { text: app.g.windows.length ? "Go to it" : "Open"; onClicked: { Apps.focus(app.g); Ui.panel = ""; } }
                            Btn {
                                id: menuBtn
                                text: "Its menu"
                                visible: app.g.tray !== null && app.g.tray.hasMenu
                                onClicked: trayMenu.open()
                                QsMenuAnchor {
                                    id: trayMenu
                                    menu: app.g.tray ? app.g.tray.menu : null
                                    anchor.item: menuBtn
                                    anchor.edges: Edges.Bottom
                                    anchor.gravity: Edges.Bottom
                                }
                            }
                            Btn { text: "Close windows"; visible: app.g.windows.length > 0; onClicked: Apps.closeWindows(app.g) }
                            Btn { text: "Quit"; visible: app.g.pids.length > 0; onClicked: Apps.quit(app.g) }
                            Btn { text: "Force quit"; danger: true; visible: app.g.pids.length > 0; onClicked: { Apps.forceQuit(app.g); root.open = ""; } }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Txt { Layout.fillWidth: true; text: "May keep running without a window"; font.pixelSize: Theme.sm; wrapMode: Text.WordWrap }
                            Switch { on: Apps.allowed(app.g); onToggled: Apps.setAllowed(app.g, !Apps.allowed(app.g)) }
                        }
                        Txt {
                            Layout.fillWidth: true
                            visible: app.g.pids.length > 0
                            font.family: Theme.mono
                            font.pixelSize: Theme.xs
                            color: Theme.outline
                            text: "pid " + app.g.pids.join(" ")
                        }
                    }
                }
            }
        }
    }
}
