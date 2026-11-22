import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.components

// a small dock along the bottom: pinned apps, then whatever else is open, then the player.
// it tucks itself away while a window shares the workspace (dockAutoHide), and comes back
// when the pointer touches the bottom edge.
//
//   click         focus the app (again: cycle its windows) · or launch it
//   middle click  open a new window
//   right click   pin / unpin
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: dock
        required property var modelData
        screen: modelData

        readonly property var monitor: Hyprland.monitorFor(modelData)
        readonly property var ws: monitor ? monitor.activeWorkspace : null
        readonly property bool busy: ws !== null && ws.toplevels.values.length > 0
        readonly property bool bottomBar: Config.s.barStyle !== "none" && Config.s.barStyle !== "rail" && Config.s.barPosition === "bottom" && Ui.barVisible
        property bool hovered: false
        readonly property bool tucked: Config.s.dockAutoHide && busy && !hovered && !Ui.editing

        visible: Config.s.dock
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "kajukatli-dock"
        exclusionMode: ExclusionMode.Ignore
        anchors.bottom: true
        margins.bottom: bottomBar ? Theme.barHeight + 8 : 0
        implicitWidth: body.width + 24
        implicitHeight: body.height + 18
        color: "transparent"
        // tucked: only the edge strip listens. shown: the dock and the strip under it, so the
        // pointer resting at the very bottom doesn't count as leaving
        mask: Region {
            regions: [
                Region { item: dock.tucked ? null : body },
                Region { item: trigger }
            ]
        }

        // ------------------------------------------------------------ apps
        function lookup(id) {
            if (!id) return null;
            const e = DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(id) : DesktopEntries.byId(id);
            return e || DesktopEntries.byId(id) || DesktopEntries.byId(id.toLowerCase());
        }
        function sameApp(a, b) {
            return (a || "").toLowerCase() === (b || "").toLowerCase();
        }
        readonly property var toplevels: ToplevelManager.toplevels.values
        readonly property var apps: {
            const pinned = Config.s.dockPinned || [];
            const out = pinned.map(id => ({ id: id, pinned: true }));
            for (const t of toplevels) {
                if (!t.appId) continue;
                if (!out.some(a => sameApp(a.id, t.appId) || sameApp(a.id, lookup(t.appId) ? lookup(t.appId).id : "")))
                    out.push({ id: t.appId, pinned: false });
            }
            return out;
        }
        function windowsOf(id) {
            const e = lookup(id);
            return toplevels.filter(t => sameApp(t.appId, id) || (e && sameApp(t.appId, e.id)) || (e && e.startupClass && sameApp(t.appId, e.startupClass)));
        }
        function togglePin(id) {
            const p = (Config.s.dockPinned || []).slice();
            const i = p.findIndex(x => sameApp(x, id));
            if (i >= 0) p.splice(i, 1); else p.push(id);
            Config.s.dockPinned = p;
        }
        property var cycle: ({})

        // a 4px strip at the bottom edge that brings it back
        Item {
            id: trigger
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: body.width
            height: dock.tucked ? 4 : 12
        }
        HoverHandler {
            id: dockHover
            onHoveredChanged: {
                if (hovered) { hideDelay.stop(); dock.hovered = true; }
                else hideDelay.restart();
            }
        }
        Timer {
            id: hideDelay
            interval: 450
            onTriggered: dock.hovered = dockHover.hovered
        }

        Rectangle {
            id: body
            anchors.horizontalCenter: parent.horizontalCenter
            y: dock.tucked ? dock.height + 4 : dock.height - height - 9
            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            width: row.implicitWidth + 16
            height: 50
            radius: Theme.radius
            color: Theme.alpha(Theme.ink, 0.86)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.5)

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: dock.apps
                    delegate: Item {
                        id: app
                        required property var modelData
                        required property int index
                        readonly property var entry: dock.lookup(modelData.id)
                        readonly property var wins: dock.windowsOf(modelData.id)
                        readonly property bool running: wins.length > 0
                        readonly property bool focused: wins.some(w => w.activated)
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: app.focused ? Theme.alpha(Theme.primary, 0.18) : area.containsMouse ? Theme.alpha(Theme.surfaceText, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                        }
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 28
                            source: Quickshell.iconPath(app.entry ? app.entry.icon : app.modelData.id, "application-x-executable")
                            scale: area.pressed ? 0.88 : area.containsMouse ? 1.08 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutBack } }
                        }
                        Rectangle {
                            visible: app.running
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: -3
                            width: app.focused ? 12 : 4
                            height: 3
                            radius: 1.5
                            color: app.focused ? Theme.primary : Theme.surfaceTextDim
                            Behavior on width { NumberAnimation { duration: Theme.normal } }
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: e => {
                                if (e.button === Qt.RightButton) { dock.togglePin(app.modelData.id); return; }
                                if (e.button === Qt.MiddleButton || !app.running) {
                                    if (app.entry) app.entry.execute();
                                    else Quickshell.execDetached([app.modelData.id]);
                                    return;
                                }
                                // focus, or cycle through its windows if one is already focused
                                const n = app.wins.length;
                                let i = app.wins.findIndex(w => w.activated);
                                i = i < 0 ? 0 : (i + 1) % n;
                                app.wins[i].activate();
                            }
                        }
                    }
                }

                // ---------------- the player
                Rectangle {
                    visible: Config.s.dockMedia && Media.active
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 26
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    color: Theme.alpha(Theme.outlineVariant, 0.8)
                }
                Rectangle {
                    visible: Config.s.dockMedia && Media.active
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: mediaRow.implicitWidth + 14
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.surfaceText, 0.06)
                    RowLayout {
                        id: mediaRow
                        anchors.centerIn: parent
                        spacing: 8
                        ClippingRectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 6
                            color: Theme.surfaceHigh
                            Image {
                                anchors.fill: parent
                                source: Media.art
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(64, 64)
                                asynchronous: true
                            }
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.preferredWidth: 104
                            Txt { Layout.fillWidth: true; text: Media.title; font.family: Theme.mono; font.pixelSize: 9; color: Theme.surfaceText }
                            Txt { Layout.fillWidth: true; text: Media.artist; font.family: Theme.mono; font.pixelSize: 8; color: Theme.outline }
                            MouseArea { Layout.fillWidth: true; Layout.fillHeight: true }
                        }
                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            radius: 11
                            color: Media.artColor
                            Icon {
                                anchors.centerIn: parent
                                name: Media.playing ? "pause" : "play"
                                size: 11
                                color: Media.artText
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Media.toggle() }
                        }
                        Icon {
                            name: "next"
                            size: 12
                            color: Theme.surfaceTextDim
                            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Media.next() }
                        }
                    }
                }
            }
        }
    }
}
