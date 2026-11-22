import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// every workspace on this screen, with live pictures of its windows.
//   click a workspace: go there            click a window: focus it
//   drag a window onto a workspace: move it   …onto “new”: it gets a workspace of its own
//   middle-click a window: close it        right-click a workspace: rename it
//   ← → enter, n for new, esc to leave
Item {
    id: root
    property var screen: null
    focus: true

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var list: Hypr.workspacesOn(monitor)
    property int sel: Math.max(0, list.findIndex(w => w.active))
    property int dragging: 0            // windows being dragged right now
    readonly property int count: list.length + 1
    readonly property real gap: 22
    readonly property real cardW: Math.min(420, (width - (Math.min(count, 4) - 1) * gap) / Math.min(count, 4))
    readonly property real cardH: screen ? cardW * screen.height / screen.width : cardW * 0.625
    readonly property real scaleF: screen ? cardW / screen.width : 0.2

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        forceActiveFocus();
    }

    function go(ws) { Hypr.focusWorkspace(ws.id); Ui.overlay = ""; }
    function fresh() { Hypr.newWorkspace(false); Ui.overlay = ""; }
    Keys.onLeftPressed: sel = Math.max(0, sel - 1)
    Keys.onRightPressed: sel = Math.min(list.length, sel + 1)
    Keys.onReturnPressed: sel < list.length ? go(list[sel]) : fresh()
    Keys.onPressed: e => {
        if (e.text === "n") { fresh(); e.accepted = true; }
        else if (e.key === Qt.Key_Tab) { sel = (sel + 1) % count; e.accepted = true; }
    }

    // ------------------------------------------------------------ header
    RowLayout {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 14
        Txt {
            text: "Workspaces"
            font.pixelSize: 34
            font.weight: Font.Bold
            color: "#ffffff"
        }
        Txt {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 6
            text: root.list.length + (root.list.length === 1 ? " open" : " open")
            font.family: Theme.mono
            font.pixelSize: Theme.sm
            color: Theme.alpha("#ffffff", 0.55)
        }
        Item { Layout.fillWidth: true }
    }

    // ------------------------------------------------------------ the row of workspaces
    Flickable {
        id: strip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 20
        height: root.cardH + 70
        contentWidth: row.width
        contentHeight: height
        interactive: contentWidth > width && root.dragging === 0
        clip: root.dragging === 0
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: row
            x: Math.max(0, (strip.width - width) / 2)
            spacing: root.gap

            Repeater {
                model: root.list

                delegate: Column {
                    id: frame
                    required property var modelData
                    required property int index
                    property int drags: 0
                    readonly property bool active: modelData.active
                    readonly property bool hot: drop.containsDrag || root.sel === index
                    z: drags > 0 ? 10 : 0
                    spacing: 12

                    Item {
                        width: root.cardW
                        height: root.cardH

                        // the ring around the workspace you're on
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -5
                            radius: 21
                            color: "transparent"
                            border.width: frame.active ? 3 : drop.containsDrag ? 2 : 0
                            border.color: Theme.primary
                        }
                        ClippingRectangle {
                            id: card
                            anchors.fill: parent
                            radius: 16
                            color: Theme.surfaceLow
                            scale: frame.hot && !frame.active ? 1.02 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

                            // the wallpaper behind the windows, so each card looks like the screen
                            Image {
                                anchors.fill: parent
                                source: Wall.current ? "file://" + Wall.current.display : ""
                                sourceSize: Qt.size(root.cardW * 1.5, root.cardH * 1.5)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                opacity: 0.55
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.sel = frame.index
                                onClicked: e => {
                                    if (e.button === Qt.RightButton) { Hypr.focusWorkspace(frame.modelData.id); Ui.open("rename"); }
                                    else root.go(frame.modelData);
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
                        }

                        // windows, positioned like they are on screen
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
                                width: visible ? Math.max(16, ipc.size[0] * root.scaleF) : 0
                                height: visible ? Math.max(16, ipc.size[1] * root.scaleF) : 0
                                z: dragArea.drag.active ? 20 : (ipc.floating ? 2 : 1)
                                readonly property bool moving: dragArea.drag.active
                                onMovingChanged: { frame.drags += moving ? 1 : -1; root.dragging += moving ? 1 : -1; }
                                scale: moving ? 0.9 : dragArea.containsMouse ? 1.03 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.fast } }

                                Drag.active: dragArea.drag.active
                                Drag.keys: ["kk-window"]
                                Drag.source: win
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: 7
                                    color: Theme.surfaceHigh
                                    border.width: dragArea.containsMouse || win.moving ? 2 : 1
                                    border.color: dragArea.containsMouse || win.moving ? Theme.primary : Theme.alpha("#ffffff", 0.12)
                                    ScreencopyView {
                                        id: shot
                                        anchors.fill: parent
                                        captureSource: win.modelData.wayland
                                        live: false
                                        Component.onCompleted: captureFrame()
                                    }
                                    IconImage {
                                        visible: !shot.hasContent
                                        anchors.centerIn: parent
                                        implicitSize: Math.min(32, parent.height * 0.5)
                                        source: Quickshell.iconPath((DesktopEntries.heuristicLookup(win.ipc.class || "") || {}).icon || "", "application-x-executable")
                                    }
                                }
                                // the app's icon in the corner, so a window is recognisable at a glance
                                IconImage {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.margins: -6
                                    visible: shot.hasContent && parent.width > 40
                                    implicitSize: 22
                                    source: Quickshell.iconPath((DesktopEntries.heuristicLookup(win.ipc.class || "") || {}).icon || "", "application-x-executable")
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
                            color: Theme.alpha("#ffffff", 0.6)
                        }
                    }

                    // the big number, and the name if it has one
                    Row {
                        spacing: 10
                        Txt {
                            text: (frame.modelData.id < 10 ? "0" : "") + frame.modelData.id
                            font.family: Theme.display
                            font.pixelSize: 26
                            font.weight: Font.Black
                            color: frame.active ? Theme.primary : "#ffffff"
                            renderType: Text.QtRendering
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Txt {
                                visible: frame.modelData.name !== String(frame.modelData.id)
                                text: frame.modelData.name
                                font.weight: Font.DemiBold
                                color: "#ffffff"
                            }
                            Txt {
                                text: {
                                    const n = frame.modelData.toplevels.values.length;
                                    return n === 0 ? "nothing open" : n === 1 ? "1 window" : n + " windows";
                                }
                                font.family: Theme.mono
                                font.pixelSize: Theme.xs + 1
                                color: Theme.alpha("#ffffff", 0.55)
                            }
                        }
                    }
                }
            }

            // a new workspace: click it, or drop a window on it
            Column {
                spacing: 12
                Rectangle {
                    width: root.cardW
                    height: root.cardH
                    radius: 16
                    readonly property bool hot: newDrop.containsDrag || plusArea.containsMouse || root.sel === root.list.length
                    color: newDrop.containsDrag ? Theme.alpha(Theme.primary, 0.25) : hot ? Theme.alpha("#ffffff", 0.1) : Theme.alpha("#ffffff", 0.04)
                    border.width: 2
                    border.color: hot ? Theme.primary : Theme.alpha("#ffffff", 0.18)
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 52; height: 52; radius: 26
                            color: Theme.primary
                            Icon { anchors.centerIn: parent; name: "plus"; size: 24; color: Theme.primaryText }
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: newDrop.containsDrag ? "Drop to give it its own workspace" : "New workspace"
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                        }
                    }
                    MouseArea {
                        id: plusArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.sel = root.list.length
                        onClicked: root.fresh()
                    }
                    DropArea {
                        id: newDrop
                        anchors.fill: parent
                        keys: ["kk-window"]
                        onDropped: d => {
                            if (d.source && d.source.address)
                                Hypr.moveWindowTo(Hypr.firstFreeId(), d.source.address, false);
                        }
                    }
                }
            }
        }
    }
}
