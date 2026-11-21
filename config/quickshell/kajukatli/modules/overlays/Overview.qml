import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// every workspace on this screen as a little frame of film, with its windows inside.
//   click a frame: go there         click a window: focus it
//   drag a window onto a frame: move it        middle-click a window: close it
//   right-click a frame: rename it  "+": a fresh workspace
//   arrows + enter work too; n makes a new one.
Item {
    id: root
    property var screen: null
    focus: true

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var list: Hypr.workspacesOn(monitor)
    property int sel: Math.max(0, list.findIndex(w => w.active))
    readonly property int cols: Math.min(4, list.length + 1)
    readonly property real cardW: Math.min(380, (width - (cols - 1) * 24) / cols)
    readonly property real cardH: screen ? cardW * screen.height / screen.width : cardW * 0.625
    readonly property real scaleF: screen ? cardW / screen.width : 0.2

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        forceActiveFocus();
    }

    function go(ws) { Hypr.focusWorkspace(ws.id); Ui.overlay = ""; }
    Keys.onLeftPressed: sel = Math.max(0, sel - 1)
    Keys.onRightPressed: sel = Math.min(list.length, sel + 1)
    Keys.onUpPressed: sel = Math.max(0, sel - cols)
    Keys.onDownPressed: sel = Math.min(list.length, sel + cols)
    Keys.onReturnPressed: {
        if (sel < list.length) {
            go(list[sel]);
        } else {
            Hypr.newWorkspace(false);
            Ui.overlay = "";
        }
    }
    Keys.onPressed: e => {
        if (e.text === "n") { Hypr.newWorkspace(false); Ui.overlay = ""; e.accepted = true; }
        if (e.key === Qt.Key_Tab) { sel = (sel + 1) % (list.length + 1); e.accepted = true; }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 28

        RowLayout {
            Layout.fillWidth: true
            Txt {
                text: "workspaces"
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 40
                font.weight: Font.Light
            }
            Item { Layout.fillWidth: true }
            Txt {
                text: "drag windows between frames  ·  middle-click closes  ·  right-click renames  ·  n new"
                font.family: Theme.mono
                font.pixelSize: Theme.xs
                color: Theme.faint
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24

            Repeater {
                model: root.list

                delegate: Column {
                    id: frame
                    required property var modelData
                    required property int index
                    property int drags: 0      // windows of this frame being dragged right now
                    z: drags > 0 ? 10 : 0
                    spacing: 8

                    Rectangle {
                        id: card
                        width: root.cardW
                        height: root.cardH
                        radius: 6
                        color: Theme.surface
                        clip: frame.drags === 0   // let a dragged window travel over other frames
                        border.width: 1
                        border.color: drop.containsDrag ? Theme.accent : frame.index === root.sel ? Theme.accentDim : frame.modelData.active ? Theme.line : Qt.rgba(1, 1, 1, 0.04)
                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.sel = frame.index
                            onClicked: e => {
                                if (e.button === Qt.RightButton) {
                                    Hypr.focusWorkspace(frame.modelData.id);
                                    Ui.open("rename");
                                } else {
                                    root.go(frame.modelData);
                                }
                            }
                        }

                        DropArea {
                            id: drop
                            anchors.fill: parent
                            keys: ["kk-window"]
                            onDropped: d => {
                                if (d.source && d.source.address && d.source.wsId !== frame.modelData.id)
                                    Hypr.moveWindowTo(frame.modelData.id, d.source.address, false);
                            }
                        }

                        Repeater {
                            model: frame.modelData.toplevels.values

                            delegate: Item {
                                id: win
                                required property var modelData
                                readonly property var ipc: modelData.lastIpcObject || ({})
                                readonly property string address: ipc.address || ""
                                readonly property int wsId: frame.modelData.id
                                readonly property real ox: root.screen ? root.screen.x : 0
                                readonly property real oy: root.screen ? root.screen.y : 0
                                visible: ipc.at !== undefined && ipc.size !== undefined
                                x: visible ? (ipc.at[0] - ox) * root.scaleF : 0
                                y: visible ? (ipc.at[1] - oy) * root.scaleF : 0
                                width: visible ? Math.max(12, ipc.size[0] * root.scaleF) : 0
                                height: visible ? Math.max(12, ipc.size[1] * root.scaleF) : 0
                                z: dragArea.drag.active ? 10 : (ipc.floating ? 2 : 1)
                                readonly property bool dragging: dragArea.drag.active
                                onDraggingChanged: frame.drags += dragging ? 1 : -1

                                Drag.active: dragArea.drag.active
                                Drag.keys: ["kk-window"]
                                Drag.source: win
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    color: Theme.raised
                                    border.width: 1
                                    border.color: dragArea.containsMouse ? Theme.accent : Theme.line
                                    clip: true

                                    ScreencopyView {
                                        id: shot
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        captureSource: win.modelData.wayland
                                        live: false
                                        Component.onCompleted: captureFrame()
                                    }
                                    IconImage {
                                        visible: !shot.hasContent
                                        anchors.centerIn: parent
                                        implicitSize: Math.min(28, parent.height * 0.5)
                                        source: Quickshell.iconPath((DesktopEntries.heuristicLookup(win.ipc.class || "") || {}).icon || "", "application-x-executable")
                                    }
                                }

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    drag.target: win
                                    property point start
                                    onPressed: start = Qt.point(win.x, win.y)
                                    onReleased: {
                                        if (drag.active) {
                                            win.Drag.drop();
                                            win.x = start.x;
                                            win.y = start.y;
                                        }
                                    }
                                    onClicked: e => {
                                        if (e.button === Qt.MiddleButton) Hypr.closeWindow(win.address);
                                        else { Hypr.focusWindow(win.address); Ui.overlay = ""; }
                                    }
                                }
                            }
                        }

                        Txt {
                            visible: frame.modelData.toplevels.values.length === 0
                            anchors.centerIn: parent
                            text: "empty"
                            font.family: Theme.serif
                            font.italic: true
                            color: Theme.faint
                        }
                    }

                    Row {
                        spacing: 8
                        Txt {
                            text: (frame.modelData.id < 10 ? "0" : "") + frame.modelData.id
                            font.family: Theme.mono
                            font.pixelSize: Theme.sm
                            color: frame.modelData.active ? Theme.accent : Theme.muted
                        }
                        Txt {
                            visible: frame.modelData.name !== String(frame.modelData.id)
                            text: frame.modelData.name
                            font.family: Theme.serif
                            font.italic: true
                            font.pixelSize: Theme.md
                        }
                        Txt {
                            text: {
                                const n = frame.modelData.toplevels.values.length;
                                return n === 0 ? "" : n === 1 ? "· one window" : "· " + n + " windows";
                            }
                            font.family: Theme.mono
                            font.pixelSize: Theme.xs
                            color: Theme.faint
                        }
                    }
                }
            }

            // a fresh one
            Rectangle {
                width: root.cardW
                height: root.cardH
                radius: 6
                color: "transparent"
                border.width: 1
                border.color: root.sel === root.list.length || plusArea.containsMouse ? Theme.accentDim : Theme.line
                Txt {
                    anchors.centerIn: parent
                    text: "+ new"
                    font.family: Theme.serif
                    font.italic: true
                    font.pixelSize: Theme.lg
                    color: plusArea.containsMouse ? Theme.accent : Theme.muted
                }
                MouseArea {
                    id: plusArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.sel = root.list.length
                    onClicked: { Hypr.newWorkspace(false); Ui.overlay = ""; }
                }
            }
        }
    }
}
