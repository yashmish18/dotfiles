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

    function go(ws: var) { Hypr.focusWorkspace(ws.id); Ui.overlay = ""; }
    function fresh() { Hypr.newWorkspace(false); Ui.overlay = ""; }
    function accept() { sel < list.length ? go(list[sel]) : fresh(); }
    // ← → (or ↑ ↓) move the highlight, enter goes there. super + tab again while it's open
    // steps along too, and letting go of super goes to the highlighted one (like alt + tab).
    property bool cycling: false
    function stepSel(d: var) { sel = (sel + d + count) % count; }
    Keys.onLeftPressed: sel = Math.max(0, sel - 1)
    Keys.onRightPressed: sel = Math.min(list.length, sel + 1)
    Keys.onUpPressed: sel = Math.max(0, sel - 1)
    Keys.onDownPressed: sel = Math.min(list.length, sel + 1)
    Keys.onReturnPressed: accept()
    Keys.onEnterPressed: accept()
    Keys.onSpacePressed: accept()
    Keys.onPressed: e => {
        if (e.text === "n") { fresh(); e.accepted = true; }
        else if (e.key === Qt.Key_Tab) { stepSel(1); e.accepted = true; }
        else if (e.key === Qt.Key_Backtab) { stepSel(-1); e.accepted = true; }
        else if (e.key === Qt.Key_Home) { sel = 0; e.accepted = true; }
        else if (e.key === Qt.Key_End) { sel = list.length; e.accepted = true; }
    }
    Keys.onReleased: e => {
        if (root.cycling && (e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R || e.key === Qt.Key_Meta)) {
            e.accepted = true;
            root.accept();
        }
    }
    Connections {
        target: Ui
        function onOverviewCycle(d) { root.cycling = true; root.stepSel(d); }
    }

    // live placement: hyprland says nothing when a window is only resized or dragged about,
    // so ask while this is open. never mid-drag, so the window in your hand stays put
    function refresh() { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); }
    Timer { interval: 400; repeat: true; running: root.dragging === 0; onTriggered: root.refresh() }

    // keep the highlighted workspace in view
    onSelChanged: Qt.callLater(showSel)
    function showSel() {
        const left = row.x + sel * (cardW + gap) - 30, right = left + cardW + 60;
        const maxX = Math.max(0, strip.contentWidth - strip.width);
        if (left < strip.contentX) strip.contentX = Math.max(0, left);
        else if (right > strip.contentX + strip.width) strip.contentX = Math.min(maxX, right - strip.width);
    }

    // dragging a window to the strip's edge scrolls it, so a workspace far off to the side can
    // still be reached. the window being dragged is moved back by the same amount so it stays
    // under the pointer.
    property Item dragItem: null
    property real dragX: -1
    Timer {
        interval: 16
        repeat: true
        running: root.dragging > 0 && root.dragItem !== null
        onTriggered: {
            const edge = 110, maxX = Math.max(0, strip.contentWidth - strip.width);
            let d = 0;
            if (root.dragX >= 0 && root.dragX < edge) d = -Math.ceil((edge - root.dragX) / 6);
            else if (root.dragX > strip.width - edge) d = Math.ceil((root.dragX - (strip.width - edge)) / 6);
            if (d === 0) return;
            const was = strip.contentX;
            strip.contentX = Math.max(0, Math.min(maxX, was + d));
            if (root.dragItem) root.dragItem.x += strip.contentX - was;
        }
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

    // ------------------------------------------------------------ other screens
    // drop a window on one to send it to that screen (onto the workspace it's showing)
    readonly property var otherMonitors: Hyprland.monitors.values.filter(m => m !== root.monitor && m.name !== (root.monitor ? root.monitor.name : ""))
    Row {
        id: screensRow
        visible: root.otherMonitors.length > 0
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14
        z: 5
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dragging > 0 ? "Drop on a screen:" : "Other screens"
            font.family: Theme.mono
            font.pixelSize: Theme.sm
            color: Theme.alpha("#ffffff", 0.6)
        }
        Repeater {
            model: root.otherMonitors
            delegate: Rectangle {
                id: scr
                required property var modelData
                width: 210
                height: 64
                radius: 16
                color: scrDrop.containsDrag ? Theme.alpha(Theme.primary, 0.3) : Theme.alpha("#ffffff", root.dragging > 0 ? 0.1 : 0.05)
                border.width: scrDrop.containsDrag ? 2 : 1
                border.color: scrDrop.containsDrag ? Theme.primary : Theme.alpha("#ffffff", 0.2)
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "monitor"; size: 22; color: "#ffffff" }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Txt { text: scr.modelData.name; font.weight: Font.DemiBold; color: "#ffffff" }
                        Txt {
                            text: scr.modelData.activeWorkspace ? "showing workspace " + scr.modelData.activeWorkspace.id : ""
                            font.family: Theme.mono; font.pixelSize: Theme.xs + 1
                            color: Theme.alpha("#ffffff", 0.55)
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // a click: go to that screen
                    onClicked: { if (scr.modelData.activeWorkspace) Hypr.focusWorkspace(scr.modelData.activeWorkspace.id); Ui.overlay = ""; }
                }
                DropArea {
                    id: scrDrop
                    anchors.fill: parent
                    keys: ["kk-window"]
                    onDropped: d => { if (d.source && d.source.address) Hypr.moveWindowToMonitor(d.source.address, scr.modelData.name); }
                }
            }
        }
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
                // keeps the cards that stay: a plain array rebuilt them all (blank previews)
                model: ScriptModel { values: root.list }

                delegate: Column {
                    id: frame
                    required property var modelData
                    required property int index
                    property int drags: 0
                    readonly property bool active: modelData.active
                    readonly property bool hot: drop.containsDrag || root.sel === index
                    // a window from another workspace is over this one
                    readonly property bool target: drop.containsDrag && drop.drag.source !== null && drop.drag.source.wsId !== modelData.id
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
                            // the one you're on: the accent. the one you're pointing at (or picked with
                            // the arrows): a white ring, so it's clear where a click or enter goes
                            border.width: frame.active ? 3 : (drop.containsDrag || root.sel === frame.index) ? 2.5 : 0
                            border.color: frame.active ? Theme.primary : Theme.alpha("#ffffff", 0.85)
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

                        // where a dropped window will go, drawn over the windows so it can't be missed
                        Rectangle {
                            anchors.fill: parent
                            z: 15
                            visible: frame.target
                            radius: 16
                            color: Theme.alpha(Theme.primary, 0.35)
                            border.width: 4
                            border.color: Theme.primary
                            Rectangle {
                                anchors.centerIn: parent
                                width: dropText.implicitWidth + 32
                                height: 40
                                radius: 20
                                color: Theme.primary
                                Txt { id: dropText; anchors.centerIn: parent; text: "Move to workspace " + frame.modelData.id; font.weight: Font.Bold; color: Theme.primaryText }
                            }
                        }

                        // windows, positioned like they are on screen
                        Repeater {
                            model: frame.modelData.toplevels
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
                                property bool counted: false
                                function count(on: bool) {
                                    if (on === counted) return;
                                    counted = on;
                                    frame.drags += on ? 1 : -1;
                                    root.dragging += on ? 1 : -1;
                                }
                                onMovingChanged: count(moving)
                                Component.onDestruction: if (counted) root.dragging -= 1   // closed in your hand
                                property point grab: Qt.point(0, 0)    // where you took hold of it
                                // in your hand it shrinks around the pointer, so the card under it stays readable
                                property real held: moving ? Math.min(1, root.cardW * 0.4 / Math.max(1, width)) : 1
                                Behavior on held { NumberAnimation { duration: Theme.fast } }
                                transform: Scale { origin.x: win.grab.x; origin.y: win.grab.y; xScale: win.held; yScale: win.held }
                                opacity: moving ? 0.92 : 1
                                scale: !moving && dragArea.containsMouse ? 1.03 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.fast } }

                                Drag.active: dragArea.drag.active
                                Drag.keys: ["kk-window"]
                                Drag.source: win
                                // the drop goes where the pointer is. it used to be judged by the window's
                                // middle, which could already be over the next card or "new workspace"
                                Drag.hotSpot.x: grab.x
                                Drag.hotSpot.y: grab.y

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: 7
                                    color: Theme.surfaceHigh
                                    border.width: win.moving ? 5 : dragArea.containsMouse ? 2 : 1
                                    border.color: dragArea.containsMouse || win.moving ? Theme.primary : Theme.alpha("#ffffff", 0.12)
                                    ScreencopyView {
                                        id: shot
                                        anchors.fill: parent
                                        captureSource: win.modelData.wayland
                                        live: true          // only while the overview is open
                                    }
                                    // a moved or resized window ends its capture, and quickshell doesn't
                                    // start it again by itself: without this the preview stayed blank
                                    Timer {
                                        interval: 300
                                        repeat: true
                                        running: !shot.hasContent
                                        onTriggered: {
                                            shot.captureSource = null;
                                            shot.captureSource = Qt.binding(() => win.modelData.wayland);
                                        }
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
                                    onPressed: m => { start = Qt.point(win.x, win.y); win.grab = Qt.point(m.x, m.y); root.dragItem = win; }
                                    onPositionChanged: m => { if (drag.active) root.dragX = mapToItem(strip, m.x, m.y).x; }
                                    onReleased: {
                                        if (drag.active) {
                                            win.Drag.drop();
                                            // back onto the live position (a plain value would freeze it there)
                                            win.x = Qt.binding(() => win.visible ? (win.ipc.at[0] - win.ox) * root.scaleF : 0);
                                            win.y = Qt.binding(() => win.visible ? (win.ipc.at[1] - win.oy) * root.scaleF : 0);
                                        }
                                        root.dragItem = null;
                                        root.dragX = -1;
                                    }
                                    onClicked: e => {
                                        if (e.button === Qt.MiddleButton) Hypr.closeWindow(win.address);
                                        else { Hypr.focusWindow(win.address); Ui.overlay = ""; }
                                    }
                                }
                            }
                        }

                        Txt {
                            visible: frame.modelData.toplevels.values.length === 0 && !frame.target
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
                                Hypr.moveWindowTo(Hypr.takeFreeId(), d.source.address, false);
                        }
                    }
                }
            }
        }
    }
}
