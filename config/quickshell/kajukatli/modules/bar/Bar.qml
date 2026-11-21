import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.services
import qs.components
import qs.modules.panels

// a slim, full-width top bar. panels are anchored under their control button.
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
        implicitHeight: Theme.barHeight + 12
        exclusiveZone: Ui.barVisible ? Theme.barHeight : 0
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
            readonly property real panelH: loader.item ? loader.item.implicitHeight + 20 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            y: Ui.barVisible ? 0 : -height
            height: Theme.barHeight + (bar.open ? panelH : 0)
            color: Qt.rgba(0.045, 0.045, 0.045, 0.94)
            border.width: 0
            clip: true

            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }

            // ------------------------------------------------------ the row
            RowLayout {
                id: leftRow
                anchors.left: parent.left
                anchors.leftMargin: 12
                y: 0
                height: Theme.barHeight
                spacing: 12
                Workspaces { monitor: bar.monitor; Layout.alignment: Qt.AlignVCenter }
                Sep {}
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
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Ui.toggle("media") }
                }
                Sep { visible: media.visible }
            }

            Clock {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                height: Theme.barHeight
            }

            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: 0
                height: Theme.barHeight
                spacing: 12
                Txt {
                    visible: Ui.status !== ""
                    text: Ui.status
                    font.family: Theme.serif
                    font.italic: true
                    font.pixelSize: Theme.sm
                    color: Theme.accent
                }
                Status { Layout.alignment: Qt.AlignVCenter }
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
                x: (pill.width - (item ? item.implicitWidth : 384)) / 2
                y: Theme.barHeight + 10
                active: bar.shown !== ""
                opacity: bar.open && status === Loader.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutQuad } }
                focus: true
                sourceComponent: {
                    switch (bar.shown) {
                    case "control": return controlC;
                    case "settings": return settingsC;
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
            Component { id: settingsC; SettingsPanel {} }
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
