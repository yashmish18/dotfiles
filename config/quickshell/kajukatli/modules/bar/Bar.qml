import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components
import qs.modules.panels

// the bar, in four shapes (settings → looks, or barStyle in settings.json):
//
//   pill      one compact floating capsule, centred                        (top or bottom)
//   bar       a long floating bar: left · centre · right                   (top or bottom)
//   islands   three separate capsules: left, centre, right                 (top or bottom)
//   rail      a thin full-height strip down the left edge
//   none      no bar; panels still open from their shortcuts
//
// what goes in it is barModules.left / center / right (see BarModule.qml for the names).
// panels (control centre, calendar, media…) pop out as a card next to the thing you clicked.
//
// the window covers the whole screen but only takes input where something is drawn.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar
        required property var modelData
        screen: modelData

        readonly property string style: Config.s.barStyle
        readonly property bool vertical: style === "rail"
        readonly property bool atBottom: !vertical && Config.s.barPosition === "bottom"
        readonly property bool shownBar: style !== "none" && Ui.barVisible && !Ui.focusMode
        readonly property int thick: vertical ? 42 : Theme.barHeight
        readonly property int edge: vertical ? 0 : 6
        readonly property int menuEdge: vertical ? Edges.Right : atBottom ? Edges.Top : Edges.Bottom
        readonly property var mods: {
            const m = Config.s.barModules || {};
            return { left: m.left || [], center: m.center || [], right: m.right || [] };
        }

        readonly property var monitor: Hyprland.monitorFor(modelData)
        readonly property bool focusedScreen: Quickshell.screens.length === 1 || Hyprland.focusedMonitor === null || Hyprland.focusedMonitor === monitor
        readonly property bool open: Ui.panel !== "" && focusedScreen
        readonly property bool typing: ["launcher", "clipboard", "rename", "session", "capture"].indexOf(Ui.panel) !== -1

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "kajukatli-bar"
        WlrLayershell.keyboardFocus: !open ? WlrKeyboardFocus.None : typing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
        anchors {
            top: !bar.atBottom
            bottom: bar.atBottom || bar.vertical
            left: true
            right: !bar.vertical
        }
        implicitWidth: vertical ? modelData.width : 0
        implicitHeight: vertical ? 0 : modelData.height
        exclusiveZone: shownBar ? thick + edge : 0
        color: "transparent"

        mask: Region {
            regions: [
                Region { item: bar.shownBar ? shapeA : null },
                Region { item: bar.shownBar ? shapeB : null },
                Region { item: bar.shownBar ? shapeC : null },
                Region { item: bar.shown !== "" ? card : null }
            ]
        }

        HyprlandFocusGrab {
            windows: [bar]
            active: bar.open && grabArmed.armed
            onCleared: Ui.panel = ""
        }

        // the panel that's drawn lags behind Ui.panel on close, so it can fade out first
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
        Timer {
            id: grabArmed
            property bool armed: false
            interval: 250
            onTriggered: armed = true
        }
        onShownChanged: { grabArmed.armed = false; if (shown !== "") grabArmed.restart(); }

        // ------------------------------------------------------------ pieces
        // (inline components can't see the window's ids, so it's all passed in)
        component Group: Grid {
            id: grp
            property var names: []
            property bool vertical: false
            property var monitor: null
            property int menuEdge: Edges.Bottom
            columns: vertical ? 1 : Math.max(1, names.length)
            rowSpacing: 6
            columnSpacing: 3
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            Repeater {
                model: grp.names
                BarModule {
                    required property string modelData
                    name: modelData
                    vertical: grp.vertical
                    monitor: grp.monitor
                    menuEdge: grp.menuEdge
                }
            }
        }

        component Shell: Rectangle {
            property bool flat: false
            color: flat ? Theme.surfaceLowest : Theme.alpha(Theme.surfaceLowest, 0.84)
            radius: flat ? 0 : height / 2
            border.width: flat ? 0 : 1
            border.color: Theme.alpha(Theme.surfaceText, 0.08)
        }

        // a thin upright line between groups
        component Dot: Rectangle {
            width: 1; height: 14
            color: Theme.alpha(Theme.surfaceText, 0.14)
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        }

        // slides the whole bar off its edge when hidden
        property real off: shownBar ? 0 : -(thick + edge + 20)
        Behavior on off { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

        Item {
            id: shapes
            anchors.fill: parent
            transform: Translate {
                x: bar.vertical ? bar.off : 0
                y: bar.vertical ? 0 : bar.atBottom ? -bar.off : bar.off
            }
            readonly property real barY: bar.atBottom ? bar.height - bar.edge - pillH : bar.edge
            readonly property real pillH: bar.thick - 6

            // ---------------- A: the pill, the long bar, the rail, or the left island
            Shell {
                id: shapeA
                flat: bar.vertical
                visible: bar.style !== "none"
                x: bar.vertical ? 0
                 : bar.style === "pill" ? (bar.width - width) / 2
                 : bar.style === "bar" ? (bar.width - width) / 2
                 : 10
                y: bar.vertical ? 0 : shapes.barY
                width: bar.vertical ? bar.thick
                     : bar.style === "pill" ? pillRow.implicitWidth + 14
                     : bar.style === "bar" ? Math.min(bar.width - 20, Math.max(barL.implicitWidth + barC.implicitWidth + barR.implicitWidth + 90, bar.width * 0.66))
                     : islandL.implicitWidth + 26
                height: bar.vertical ? bar.height : shapes.pillH

                // pill: everything in one row, groups separated by dots
                Row {
                    id: pillRow
                    visible: bar.style === "pill"
                    anchors.centerIn: parent
                    spacing: 8
                    Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; names: bar.style === "pill" ? bar.mods.left : []; anchors.verticalCenter: parent.verticalCenter }
                    Dot { visible: bar.mods.left.length > 0 && bar.mods.center.length > 0 }
                    Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; names: bar.style === "pill" ? bar.mods.center : []; anchors.verticalCenter: parent.verticalCenter }
                    Dot { visible: bar.mods.right.length > 0 }
                    Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; names: bar.style === "pill" ? bar.mods.right : []; anchors.verticalCenter: parent.verticalCenter }
                    Txt {
                        visible: Ui.status !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: Ui.status
                        font.family: Theme.mono
                        font.pixelSize: Theme.xs
                        color: Theme.primary
                    }
                }

                // bar: three groups pinned left, centre, right
                Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; id: barL; visible: bar.style === "bar"; names: bar.style === "bar" ? bar.mods.left : []; anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter }
                Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; id: barC; visible: bar.style === "bar"; names: bar.style === "bar" ? bar.mods.center : []; anchors.centerIn: parent }
                Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; id: barR; visible: bar.style === "bar"; names: bar.style === "bar" ? bar.mods.right : []; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter }

                // islands: the left one lives here
                Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; id: islandL; visible: bar.style === "islands"; names: bar.style === "islands" ? bar.mods.left : []; anchors.centerIn: parent }

                // rail: top · middle · bottom
                Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; visible: bar.vertical; names: bar.vertical ? bar.mods.left : []; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 16 }
                Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; visible: bar.vertical; names: bar.vertical ? bar.mods.center : []; anchors.centerIn: parent }
                Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; visible: bar.vertical; names: bar.vertical ? bar.mods.right : []; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 16 }

                Txt {
                    visible: Ui.status !== "" && bar.style === "bar"
                    anchors.right: barR.left
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: Ui.status
                    font.family: Theme.mono
                    font.pixelSize: Theme.xs
                    color: Theme.primary
                }

                WheelHandler {
                    target: null
                    onWheel: e => Hypr.step(e.angleDelta.y < 0 ? 1 : -1)
                }
            }

            // ---------------- B, C: the centre and right islands
            Shell {
                id: shapeB
                visible: bar.style === "islands" && bar.mods.center.length > 0
                width: visible ? islandC.implicitWidth + 26 : 0
                height: visible ? shapes.pillH : 0
                x: (bar.width - width) / 2
                y: shapes.barY
                Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; id: islandC; names: bar.style === "islands" ? bar.mods.center : []; anchors.centerIn: parent }
            }
            Shell {
                id: shapeC
                visible: bar.style === "islands" && bar.mods.right.length > 0
                width: visible ? islandR.implicitWidth + 26 : 0
                height: visible ? shapes.pillH : 0
                x: bar.width - width - 10
                y: shapes.barY
                Group { vertical: bar.vertical; monitor: bar.monitor; menuEdge: bar.menuEdge; id: islandR; names: bar.style === "islands" ? bar.mods.right : []; anchors.centerIn: parent }
            }
        }

        // ------------------------------------------------------------ the panel card
        Rectangle {
            id: card
            readonly property Item content: loader.item
            readonly property real cw: content && bar.shown !== "" ? content.implicitWidth + 36 : 0
            readonly property real ch: content && bar.shown !== "" ? content.implicitHeight + 36 : 0
            readonly property real along: Ui.panelX >= 0 ? Ui.panelX : (bar.vertical ? bar.height / 2 : bar.width / 2)
            width: cw
            height: ch
            x: bar.vertical ? bar.thick + 10 : Math.max(10, Math.min(bar.width - cw - 10, along - cw / 2))
            y: bar.vertical ? Math.max(10, Math.min(bar.height - ch - 10, along - ch / 2))
             : bar.atBottom ? bar.height - bar.thick - bar.edge - 10 - ch
             : bar.thick + bar.edge + 10
            visible: bar.shown !== ""
            radius: Theme.radius + 8
            color: Theme.glassStrong
            border.width: 1
            border.color: Theme.alpha(Theme.surfaceText, 0.08)
            opacity: bar.open && loader.status === Loader.Ready ? 1 : 0
            scale: bar.open ? 1 : 0.92
            transformOrigin: bar.vertical ? Item.Left : bar.atBottom ? Item.Bottom : Item.Top
            Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: Theme.normal + 60; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            Behavior on height { enabled: bar.open; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            clip: true

            Loader {
                id: loader
                x: 18
                y: 18
                active: bar.shown !== ""
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
                    case "capture": return captureC;
                    case "running": return runningC;
                    case "phone": return phoneC;
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
            Component { id: captureC; CapturePanel {} }
            Component { id: runningC; RunningPanel {} }
            Component { id: phoneC; PhonePanel {} }
        }
    }
}
