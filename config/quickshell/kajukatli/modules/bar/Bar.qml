import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.services
import qs.components
import qs.modules.panels

// the bar is one pill. click a part of it and the pill grows downward into that panel;
// the row you clicked stays where it was, so your eye never has to look for it.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar
        required property var modelData
        screen: modelData

        readonly property var monitor: Hyprland.monitorFor(modelData)
        readonly property bool focusedScreen: Hyprland.focusedMonitor === monitor
        readonly property bool open: Ui.panel !== "" && focusedScreen
        readonly property bool typing: ["launcher", "clipboard", "rename", "session"].indexOf(Ui.panel) !== -1

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "kajukatli-bar"
        WlrLayershell.keyboardFocus: !open ? WlrKeyboardFocus.None : typing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
        anchors { top: true; left: true; right: true }
        implicitHeight: Math.round(modelData.height * 0.86)
        exclusiveZone: Ui.barVisible ? Theme.barHeight + 8 : 0
        color: "transparent"
        mask: Region { item: pill }

        HyprlandFocusGrab {
            windows: [bar]
            active: bar.open
            onCleared: Ui.panel = ""
        }

        // the panel that's drawn: lags behind Ui.panel on close so the pill can shrink first
        property string shown: ""
        onOpenChanged: {
            if (open) { shown = Ui.panel; unload.stop(); }
            else unload.restart();
        }
        Connections {
            target: Ui
            function onPanelChanged() { if (bar.open) bar.shown = Ui.panel; }
        }
        Timer { id: unload; interval: Theme.slow; onTriggered: if (!bar.open) bar.shown = "" }

        Rectangle {
            id: pill
            readonly property int pad: 14
            readonly property real panelW: loader.item ? loader.item.implicitWidth + pad * 2 : 0
            readonly property real panelH: loader.item ? loader.item.implicitHeight + pad : 0

            anchors.horizontalCenter: parent.horizontalCenter
            y: (Ui.barVisible || bar.open) ? 6 : -height - 8
            width: Math.max(row.implicitWidth + 28, bar.open ? panelW : 0)
            height: Theme.barHeight + (bar.open ? panelH : 0)
            radius: bar.open ? 14 : Theme.barHeight / 2
            color: Theme.ink
            border.width: 1
            border.color: bar.open ? Theme.line : Qt.rgba(1, 1, 1, 0.06)
            clip: true

            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Theme.slow - 60; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }

            // ------------------------------------------------------ the row
            RowLayout {
                id: row
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                height: Theme.barHeight
                spacing: 14

                Workspaces {
                    monitor: bar.monitor
                    Layout.alignment: Qt.AlignVCenter
                }

                Sep {}

                // now playing (only while something plays)
                Item {
                    id: media
                    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null
                    visible: player !== null
                    Layout.preferredWidth: Math.min(mediaText.implicitWidth, 190)
                    Layout.preferredHeight: Theme.barHeight
                    Txt {
                        id: mediaText
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: media.player ? (media.player.trackTitle || media.player.identity) : ""
                        font.family: Theme.serif
                        font.italic: true
                        font.pixelSize: Theme.md
                        color: Ui.panel === "media" ? Theme.accent : Theme.paper
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.toggle("media")
                    }
                }
                Sep { visible: media.visible }

                Clock {
                    Layout.alignment: Qt.AlignVCenter
                }

                Sep {}

                Status {
                    Layout.alignment: Qt.AlignVCenter
                }

                // short-lived messages from the shell ("developing…")
                Txt {
                    visible: Ui.status !== ""
                    text: Ui.status
                    font.family: Theme.serif
                    font.italic: true
                    font.pixelSize: Theme.sm
                    color: Theme.accent
                    SequentialAnimation on opacity {
                        running: Ui.status !== ""
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
            }

            WheelHandler {
                target: null
                enabled: !bar.open
                onWheel: e => Hypr.step(e.angleDelta.y < 0 ? 1 : -1)
            }

            // ------------------------------------------------------ the panel
            Hair {
                y: Theme.barHeight
                x: pill.pad
                width: pill.width - pill.pad * 2
                opacity: bar.open ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            }

            Loader {
                id: loader
                x: pill.pad
                y: Theme.barHeight + 10
                active: bar.shown !== ""
                opacity: bar.open && status === Loader.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutQuad } }
                focus: true
                sourceComponent: {
                    switch (bar.shown) {
                    case "control": return controlC;
                    case "notifications": return notifC;
                    case "calendar": return calC;
                    case "media": return mediaC;
                    case "launcher": return launcherC;
                    case "clipboard": return clipC;
                    case "session": return sessionC;
                    case "rename": return renameC;
                    }
                    return null;
                }
                Keys.onEscapePressed: Ui.panel = ""
            }

            Component { id: controlC; ControlPanel {} }
            Component { id: notifC; NotificationsPanel {} }
            Component { id: calC; CalendarPanel {} }
            Component { id: mediaC; MediaPanel {} }
            Component { id: launcherC; LauncherPanel {} }
            Component { id: clipC; ClipboardPanel {} }
            Component { id: sessionC; SessionPanel {} }
            Component { id: renameC; RenamePanel {} }
        }
    }
}
