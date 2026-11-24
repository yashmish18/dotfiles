import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// every screen, every setting (super + d → "Arrange & tune", or settings → display):
//   drag the screens to arrange them (they snap edge to edge), and for the one picked:
//   on/off, resolution, refresh rate, scale, rotation, flip, mirroring, adaptive sync, 10-bit.
// changes apply at once and are remembered. a new resolution, refresh or rotation asks
// "keep this?" and goes back by itself after 15 seconds if the screen went black.
Item {
    id: root
    focus: true
    Keys.onEscapePressed: Ui.overlay = ""

    property var screens: []            // hyprctl monitors all -j
    property string picked: ""
    readonly property var sel: screens.find(s => s.name === picked) || screens[0] || null
    readonly property var enabledScreens: screens.filter(s => !s.disabled)

    Process {
        id: read
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.screens = JSON.parse(text);
                    if (!root.screens.find(s => s.name === root.picked)) {
                        const f = root.screens.find(s => s.focused) || root.screens[0];
                        root.picked = f ? f.name : "";
                    }
                } catch (e) {}
            }
        }
        Component.onCompleted: running = true
    }
    Timer { id: reread; interval: 900; onTriggered: read.running = true }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (/^monitor(added|removed)/.test(ev.name || "")) reread.restart(); }
    }

    // ------------------------------------------------------------ applying, with a way back
    property var undo: null             // { name, profile } to go back to
    property int countdown: 0
    function change(values, risky) {
        if (!sel) return;
        if (risky) {
            undo = { name: sel.name, profile: Object.assign({}, System.monitorProfile(sel.name)) };
            countdown = 15;
            tick.restart();
        }
        System.setMonitor(sel.name, values);
        reread.restart();
    }
    function keep() { undo = null; countdown = 0; tick.stop(); }
    function revert() {
        if (!undo) return;
        const profiles = Object.assign({}, Config.s.monitorProfiles || {});
        profiles[undo.name] = undo.profile;
        Config.s.monitorProfiles = profiles;
        System.applyMonitor(undo.name);
        keep();
        reread.restart();
    }
    Timer { id: tick; interval: 1000; repeat: true; onTriggered: { root.countdown--; if (root.countdown <= 0) root.revert(); } }

    // ------------------------------------------------------------ helpers
    function logical(s) {
        const rot = s.transform % 2 === 1;
        const w = (rot ? s.height : s.width) / (s.scale || 1), h = (rot ? s.width : s.height) / (s.scale || 1);
        return { w: w, h: h };
    }
    function modesOf(s) {
        const out = {};
        for (const m of (s ? s.availableModes || [] : [])) {
            const r = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(m);
            if (!r) continue;
            const res = r[1] + "x" + r[2];
            (out[res] = out[res] || []).push(parseFloat(r[3]));
        }
        return out;
    }
    readonly property var modes: modesOf(sel)
    readonly property var resolutions: Object.keys(modes).sort((a, b) => {
        const [aw, ah] = a.split("x").map(Number), [bw, bh] = b.split("x").map(Number);
        return bw * bh - aw * ah;
    })
    readonly property string curRes: sel ? sel.width + "x" + sel.height : ""
    readonly property var rates: (modes[curRes] || []).slice().sort((a, b) => b - a)

    // ------------------------------------------------------------ identify: the name on each screen
    property bool identifying: false
    Timer { id: idTimer; interval: 2500; onTriggered: root.identifying = false }
    Variants {
        model: root.identifying ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "kajukatli-identify"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; bottom: true }
            margins { left: 40; bottom: 40 }
            implicitWidth: idTxt.implicitWidth + 60
            implicitHeight: 110
            color: "transparent"
            Rectangle {
                anchors.fill: parent
                radius: 28
                color: Theme.primary
                Txt { id: idTxt; anchors.centerIn: parent; text: modelData.name; font.pixelSize: 54; font.weight: Font.Black; color: Theme.primaryText }
            }
        }
    }

    // ------------------------------------------------------------ the window
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, 980)
        height: Math.min(parent.height, 760)
        radius: 24
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outlineVariant
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt { text: "Displays"; font.pixelSize: Theme.xl; font.weight: Font.Bold; Layout.fillWidth: true }
                Btn { text: "Identify"; icon: "monitor"; onClicked: { root.identifying = true; idTimer.restart(); } }
                Btn { text: "Quick modes"; icon: "extend"; onClicked: Ui.overlay = "projection" }
                Btn { icon: "close"; onClicked: Ui.overlay = "" }
            }

            // keep it? (after a resolution / refresh / rotation change)
            Rectangle {
                visible: root.undo !== null
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 14
                color: Theme.alpha(Theme.primary, 0.18)
                Txt { x: 16; anchors.verticalCenter: parent.verticalCenter; text: "Keep this? Going back in " + root.countdown + " s."; font.weight: Font.DemiBold }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Btn { text: "Keep"; primary: true; onClicked: root.keep() }
                    Btn { text: "Go back"; onClicked: root.revert() }
                }
            }

            // ---------------------------------------------------- arrangement
            Rectangle {
                id: board
                Layout.fillWidth: true
                Layout.preferredHeight: 230
                radius: 16
                color: Theme.surfaceLow
                clip: true
                // the scale that fits every enabled screen in the board
                readonly property var bounds: {
                    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
                    for (const s of root.enabledScreens) {
                        const l = root.logical(s);
                        x0 = Math.min(x0, s.x); y0 = Math.min(y0, s.y);
                        x1 = Math.max(x1, s.x + l.w); y1 = Math.max(y1, s.y + l.h);
                    }
                    if (x0 > x1) return { x0: 0, y0: 0, w: 1920, h: 1080 };
                    return { x0: x0, y0: y0, w: x1 - x0, h: y1 - y0 };
                }
                readonly property real k: Math.min((width - 60) / Math.max(1, bounds.w * 1.6), (height - 50) / Math.max(1, bounds.h * 1.3))
                readonly property real ox: (width - bounds.w * k) / 2
                readonly property real oy: (height - bounds.h * k) / 2

                Txt {
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
                    text: root.enabledScreens.length > 1 ? "drag to arrange · they snap edge to edge" : "one screen"
                    font.pixelSize: Theme.xs + 1; color: Theme.outline
                }

                Repeater {
                    model: root.enabledScreens
                    delegate: Rectangle {
                        id: mon
                        required property var modelData
                        readonly property var l: root.logical(modelData)
                        readonly property bool on: root.picked === modelData.name
                        property bool held: false
                        // where hyprland has it; a drag moves it freely, a release puts the binding back
                        function home() {
                            x = Qt.binding(() => board.ox + (mon.modelData.x - board.bounds.x0) * board.k);
                            y = Qt.binding(() => board.oy + (mon.modelData.y - board.bounds.y0) * board.k);
                        }
                        Component.onCompleted: home()
                        width: l.w * board.k
                        height: l.h * board.k
                        radius: 8
                        color: on ? Theme.primaryContainer : Theme.surfaceHighest
                        border.width: on ? 2 : 1
                        border.color: on ? Theme.primary : Theme.outlineVariant
                        z: held ? 5 : 1
                        Column {
                            anchors.centerIn: parent
                            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: mon.modelData.name; font.weight: Font.Bold; color: mon.on ? Theme.primaryContainerText : Theme.surfaceText }
                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: mon.modelData.width + "×" + mon.modelData.height + (mon.modelData.mirrorOf && mon.modelData.mirrorOf !== "none" ? " · mirror" : "")
                                font.family: Theme.mono; font.pixelSize: Theme.xs
                                color: mon.on ? Theme.primaryContainerText : Theme.surfaceTextDim
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            drag.target: root.enabledScreens.length > 1 ? mon : null
                            onPressed: { root.picked = mon.modelData.name; mon.held = true; }
                            onReleased: {
                                if (!mon.held) return;
                                mon.held = false;
                                const moved = Math.abs(mon.x - (board.ox + (mon.modelData.x - board.bounds.x0) * board.k)) + Math.abs(mon.y - (board.oy + (mon.modelData.y - board.bounds.y0) * board.k));
                                if (moved < 3) { mon.home(); return; }
                                // back to real coordinates, then snap to the nearest edge of another screen
                                let X = (mon.x - board.ox) / board.k + board.bounds.x0, Y = (mon.y - board.oy) / board.k + board.bounds.y0;
                                let best = null, bestD = 1e12;
                                for (const o of root.enabledScreens) {
                                    if (o.name === mon.modelData.name) continue;
                                    const ol = root.logical(o);
                                    const spots = [
                                        { x: o.x + ol.w, y: o.y }, { x: o.x - mon.l.w, y: o.y },        // right, left
                                        { x: o.x, y: o.y - mon.l.h }, { x: o.x, y: o.y + ol.h },        // above, below
                                        { x: o.x + ol.w, y: o.y + ol.h - mon.l.h }, { x: o.x - mon.l.w, y: o.y + ol.h - mon.l.h } // bottoms aligned
                                    ];
                                    for (const s of spots) {
                                        const d = (s.x - X) * (s.x - X) + (s.y - Y) * (s.y - Y);
                                        if (d < bestD) { bestD = d; best = s; }
                                    }
                                }
                                if (best) { X = best.x; Y = best.y; }
                                System.setMonitor(mon.modelData.name, { position: Math.round(X) + "x" + Math.round(Y), mirror: null });
                                mon.home();
                                reread.restart();
                            }
                        }
                    }
                }
            }

            // the screens that are off, to pick them too
            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: root.screens.length > 1
                Repeater {
                    model: root.screens
                    delegate: Btn {
                        required property var modelData
                        text: modelData.name + (modelData.disabled ? " (off)" : "")
                        active: root.picked === modelData.name
                        mono: true
                        onClicked: root.picked = modelData.name
                    }
                }
            }

            // ---------------------------------------------------- the picked screen
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: opts.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                GridLayout {
                    id: opts
                    width: parent.width
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 12
                    visible: root.sel !== null

                    component Label: Txt { Layout.alignment: Qt.AlignTop; Layout.topMargin: 4; Layout.preferredWidth: 150; font.weight: Font.Medium }

                    Label { text: root.sel ? root.sel.name : "" ; font.pixelSize: Theme.lg; font.weight: Font.Bold }
                    Txt {
                        Layout.fillWidth: true
                        text: root.sel ? [root.sel.make, root.sel.model].filter(x => x).join(" ") + (root.sel.description ? "" : "") : ""
                        color: Theme.surfaceTextDim; elide: Text.ElideRight
                    }

                    Label { text: "On" }
                    Switch {
                        on: root.sel ? !root.sel.disabled : false
                        // never the last screen that's on
                        enabled: root.sel !== null && (root.sel.disabled || root.enabledScreens.length > 1)
                        onToggled: root.change({ disabled: root.sel.disabled ? null : true }, false)
                    }

                    Label { text: "Resolution" }
                    Choice {
                        options: root.resolutions.slice(0, 10)
                        value: root.curRes
                        onPicked: v => {
                            const r = (root.modes[v] || []).slice().sort((a, b) => b - a);
                            const hz = r.find(x => Math.abs(x - root.sel.refreshRate) < 1) || r[0];
                            root.change({ mode: v + "@" + hz.toFixed(2), refresh: null }, true);
                        }
                    }

                    Label { text: "Refresh rate" }
                    Choice {
                        options: root.rates.map(r => ({ value: r, label: Math.round(r) + " Hz" }))
                        value: root.rates.find(r => root.sel && Math.abs(r - root.sel.refreshRate) < 0.5)
                        onPicked: v => root.change({ mode: root.curRes + "@" + v.toFixed(2), refresh: null }, true)
                    }

                    Label { text: "Scale" }
                    Choice {
                        options: [1, 1.25, 1.333333, 1.5, 1.6, 1.75, 2, 2.5, 3].map(v => ({ value: v, label: Math.round(v * 100) + "%" }))
                        value: root.sel ? [1, 1.25, 1.333333, 1.5, 1.6, 1.75, 2, 2.5, 3].find(v => Math.abs(v - root.sel.scale) < 0.01) : 1
                        onPicked: v => root.change({ scale: v }, false)
                    }

                    Label { text: "Rotation" }
                    RowLayout {
                        spacing: 10
                        Choice {
                            options: [{ value: 0, label: "normal" }, { value: 1, label: "90°" }, { value: 2, label: "180°" }, { value: 3, label: "270°" }]
                            value: root.sel ? root.sel.transform % 4 : 0
                            onPicked: v => root.change({ transform: v + (root.sel.transform >= 4 ? 4 : 0) }, true)
                        }
                        Txt { text: "flip"; color: Theme.surfaceTextDim }
                        Switch { on: root.sel ? root.sel.transform >= 4 : false; onToggled: root.change({ transform: (root.sel.transform % 4) + (root.sel.transform >= 4 ? 0 : 4) }, true) }
                    }

                    Label { text: "Mirror"; visible: root.screens.length > 1 }
                    Choice {
                        visible: root.screens.length > 1
                        options: [{ value: "", label: "its own desktop" }].concat(root.screens.filter(s => root.sel && s.name !== root.sel.name).map(s => ({ value: s.name, label: "show " + s.name })))
                        value: root.sel && root.sel.mirrorOf && root.sel.mirrorOf !== "none" ? root.sel.mirrorOf : ""
                        onPicked: v => root.change({ mirror: v === "" ? null : v }, false)
                    }

                    Label { text: "Adaptive sync" }
                    Choice {
                        options: [{ value: 0, label: "off" }, { value: 1, label: "always" }, { value: 2, label: "fullscreen only (games, video)" }]
                        value: (root.sel ? (Config.s.monitorProfiles || {})[root.sel.name] || {} : {}).vrr !== undefined
                            ? (Config.s.monitorProfiles || {})[root.sel.name].vrr : (root.sel && root.sel.vrr ? 1 : 0)
                        onPicked: v => root.change({ vrr: v }, false)
                    }

                    Label { text: "10-bit colour" }
                    RowLayout {
                        Switch {
                            on: root.sel ? ((Config.s.monitorProfiles || {})[root.sel.name] || {}).bitdepth === 10 : false
                            onToggled: root.change({ bitdepth: ((Config.s.monitorProfiles || {})[root.sel.name] || {}).bitdepth === 10 ? null : 10 }, true)
                        }
                        Txt { text: "smoother gradients on screens that support it (HDR-ready panels)"; color: Theme.surfaceTextDim; font.pixelSize: Theme.sm }
                    }

                    Label { text: "Position" }
                    Txt {
                        text: root.sel ? root.sel.x + ", " + root.sel.y + "  (drag it above)" : ""
                        font.family: Theme.mono; color: Theme.surfaceTextDim
                    }

                    Item { width: 1; height: 1 }
                    Btn {
                        text: "Back to automatic"
                        onClicked: {
                            const profiles = Object.assign({}, Config.s.monitorProfiles || {});
                            delete profiles[root.sel.name];
                            Config.s.monitorProfiles = profiles;
                            System.setMonitor(root.sel.name, { mode: "preferred", position: "auto", scale: 1 });
                            reread.restart();
                        }
                    }
                }
            }
        }
    }
}
