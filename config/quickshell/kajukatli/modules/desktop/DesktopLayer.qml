import QtQuick
import qs.services
import qs.components

// every desktop widget, laid out on one screen-sized item. it is used twice per screen:
//
//   behind: false   in the desktop window (above the wallpaper, below your windows)
//   behind: true    inside the wallpaper itself, rendered off-screen and composited by the
//                   wallpaper shader *under* the subject's cut-out — the depth effect
//
// a widget appears in exactly one of the two. the clock and the visualiser can go behind;
// everything you click (calendar, player) is always in front. edit mode brings all of them
// to the front so they can be dragged.
Item {
    id: layer
    property bool behind: false
    property var monitor: null
    // windows over the desktop? then nobody can see the moving parts: pause them (power)
    readonly property bool covered: !Ui.editing && monitor !== null && monitor.activeWorkspace !== null
                                   && monitor.activeWorkspace.toplevels.values.length > 0

    // while you drag or arrange, everything comes to the front so you can see where it goes
    readonly property bool depthOk: Wall.depthReady && !Ui.editing && !Ui.dragging
    readonly property bool clockBehind: Config.s.clockDepth && depthOk
    readonly property bool visBehind: Config.s.visualizerBehind && depthOk
    readonly property string vis: Config.s.visualizer

    readonly property bool hasBars: vis === "bars" || vis === "mirror" || vis === "both"
    readonly property bool hasWave: vis === "wave" || vis === "both"
    // the copy in front is always there to be grabbed; it's only invisible while the one
    // behind the subject is the one you see
    readonly property bool clockHere: Config.s.clockStyle !== "off" && (behind ? clockBehind : true)
    readonly property bool barsHere: hasBars && (behind ? visBehind : true)
    readonly property bool waveHere: hasWave && visBehind === behind
    // anything to draw at all? (the wallpaper skips the composite when not)
    readonly property bool anyHere: clockHere || barsHere || waveHere

    // focus mode: everything here steps away
    opacity: Ui.focusMode ? 0 : 1
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

    property alias timerItem: timerM
    property alias calendarItem: calendar
    property alias mediaItem: media
    property alias noteItem: note
    property alias clockItem: clockM

    // how the picture is fitted to the screen (the same cover maths as the wallpaper shader)
    function coverOf(m) {
        const S = layer.width / Math.max(1, layer.height), I = m.width / Math.max(1, m.height);
        const zoom = Config.s.parallax ? 0.94 : 1.0;
        return { x: S > I ? zoom : zoom * S / I, y: S > I ? zoom * I / S : zoom };
    }

    // the clock's ink: light or dark, whichever reads on the picture right under the clock
    readonly property var clockTone: {
        const m = Wall.current;
        if (Config.s.clockColor !== "auto" || !m || !m.grid || m.grid.length < 144 || !m.width || !clockM.width) return null;
        const c = coverOf(m);
        const toU = sx => (sx / layer.width - 0.5) * c.x + 0.5;
        const toV = sy => (sy / layer.height - 0.5) * c.y + 0.5;
        const u0 = toU(area.x + clockM.x), u1 = toU(area.x + clockM.x + clockM.width);
        const v0 = toV(area.y + clockM.y), v1 = toV(area.y + clockM.y + clockM.height);
        let r = 0, g = 0, bl = 0, n = 0;
        for (let j = 0; j < 9; j++) {
            for (let i = 0; i < 16; i++) {
                const u = (i + 0.5) / 16, v = (j + 0.5) / 9;
                if (u < u0 - 1 / 32 || u > u1 + 1 / 32 || v < v0 - 1 / 18 || v > v1 + 1 / 18) continue;
                const px = m.grid[j * 16 + i];
                r += px[0]; g += px[1]; bl += px[2]; n++;
            }
        }
        if (n === 0) return null;
        r /= n * 255; g /= n * 255; bl /= n * 255;
        const luma = 0.2126 * r + 0.7152 * g + 0.0722 * bl;
        // a touch of the theme's colour so it still belongs, but never the picture's own hue
        const p = Theme.primary;
        const mix = (a, b, t) => a * (1 - t) + b * t;
        if (luma > 0.55)
            return { ink: Qt.rgba(mix(0.07, p.r, 0.12), mix(0.06, p.g, 0.12), mix(0.08, p.b, 0.12), 1),
                     dim: Qt.rgba(0.08, 0.07, 0.09, 0.72), shadow: Qt.rgba(1, 1, 1, 0.35) };
        return { ink: Qt.rgba(mix(0.97, p.r, 0.08), mix(0.96, p.g, 0.08), mix(0.95, p.b, 0.08), 1),
                 dim: Qt.rgba(0.97, 0.96, 0.95, 0.78), shadow: Qt.rgba(0, 0, 0, 0.5) };
    }
    Binding { when: !layer.behind && layer.clockTone !== null; target: Theme; property: "clockInk"; value: layer.clockTone ? layer.clockTone.ink : Theme.wallText }
    Binding { when: !layer.behind && layer.clockTone !== null; target: Theme; property: "clockInkDim"; value: layer.clockTone ? layer.clockTone.dim : Theme.wallTextDim }
    Binding { when: !layer.behind && layer.clockTone !== null; target: Theme; property: "clockShadow"; value: layer.clockTone ? layer.clockTone.shadow : Theme.wallShadow }

    // the clock's "auto" spot: centred on the wallpaper's subject, its lower part tucked behind
    // the subject's top, so the person stands in front of the numbers
    function autoClock(w, h, W, H) {
        const m = Wall.current;
        if (!m || !m.width || !m.height || W <= w || H <= h) return null;
        if (!(m.clock_auto && m.clock_auto.mode === "free") && (!m.subject_box || m.subject_box.length < 4)) return null;
        const c = coverOf(m);
        const toX = u => ((u - 0.5) / c.x + 0.5) * layer.width - area.x;
        const toY = v => ((v - 0.5) / c.y + 0.5) * layer.height - area.y;
        // no subject: the calm part of the picture kk-prep found, centred on it
        const ca = m.clock_auto;
        if (ca && ca.mode === "free") {
            const fx = toX(ca.x) - w / 2, fy = toY(ca.y) - h / 2;
            return { x: Math.max(0, Math.min(1, fx / (W - w))), y: Math.max(0, Math.min(1, fy / (H - h))) };
        }
        // the subject's solid top (kk-prep's clock_anchor); the box's top edge as a fallback
        const a = ca && ca.mode === "behind" ? [ca.x, ca.y] : m.clock_anchor && m.clock_anchor.length >= 2 ? m.clock_anchor : null;
        const b = m.subject_box;
        const midX = toX(a ? a[0] : (b[0] + b[2]) / 2), top = toY(a ? a[1] : b[1]);
        const x = midX - w / 2;
        // the lower half of the numbers behind the subject
        const y = Math.max(0, top - h * 0.5);
        return { x: Math.max(0, Math.min(1, x / (W - w))), y: Math.max(0, Math.min(1, y / (H - h))) };
    }
    property alias barsItem: barsM
    property alias statsItem: statsM
    property alias weatherItem: weatherM
    property alias batteryItem: batteryM
    property alias analogItem: analogM

    // widgets keep clear of the bar (both instances must agree, or the clock would jump
    // when it moves behind the subject)
    readonly property bool barShown: Ui.barVisible && Config.s.barStyle !== "none"
    readonly property int padTop: barShown && Config.s.barStyle !== "rail" && Config.s.barPosition === "top" ? Theme.barHeight + 10 : 0
    readonly property int padBottom: barShown && Config.s.barStyle !== "rail" && Config.s.barPosition === "bottom" ? Theme.barHeight + 10 : 0
    readonly property int padLeft: barShown && Config.s.barStyle === "rail" ? 46 : 0

    // the long wave along the bottom edge
    Visualizer {
        visible: layer.waveHere
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.round(parent.height * 0.24)
        style: "wave"
        active: visible && !layer.covered
        count: Cava.bars
        color: Theme.wallText
        fillOpacity: 0.5
    }

    // rain or snow, when it's falling outside
    WeatherFx {
        anchors.fill: parent
        visible: !layer.behind && Config.s.weatherFx
        active: visible && !layer.covered && !Power.onBattery
    }

    Item {
        id: area
        anchors.fill: parent
        anchors.topMargin: layer.padTop
        anchors.bottomMargin: layer.padBottom
        anchors.leftMargin: layer.padLeft

        Movable {
            id: barsM
            name: "bars"
            ghost: !layer.behind && layer.visBehind
            fallback: ({ x: 0.92, y: 0.04 })
            editable: !layer.behind
            shown: layer.barsHere
            Visualizer {
                implicitWidth: layer.vis === "mirror" ? 620 : 320
                implicitHeight: layer.vis === "mirror" ? 160 : 60
                style: layer.vis === "mirror" ? "mirror" : "bars"
            active: visible && !layer.covered
                count: layer.vis === "mirror" ? 96 : 64
                gap: 1
                color: layer.vis === "mirror" ? Theme.primary : Theme.wallText
                fillOpacity: 0.7
            }
        }

        Movable {
            id: clockM
            name: "clock"
            autoPlace: layer.autoClock
            ghost: !layer.behind && layer.clockBehind
            fallback: ({ x: 0.5, y: 0.15 })
            editable: !layer.behind
            shown: layer.clockHere
            DesktopClock { screenHeight: layer.height; live: !layer.covered }
        }

        Movable {
            id: calendar
            name: "calendar"
            fallback: ({ x: 0.02, y: 0.93 })
            shown: !layer.behind && Config.s.showCalendar
            CalendarWidget {}
        }

        Movable {
            id: media
            name: "media"
            fallback: ({ x: 0.5, y: 0.93 })
            shown: !layer.behind && Config.s.mediaWidget !== "off" && Media.active
            MediaWidget { style: Config.s.mediaWidget }
        }

        Movable {
            id: statsM
            name: "stats"
            fallback: ({ x: 0.02, y: 0.7 })
            shown: !layer.behind && Config.s.showStats
            StatsWidget { live: !layer.covered }
        }

        Movable {
            id: weatherM
            name: "weather"
            fallback: ({ x: 0.96, y: 0.1 })
            shown: !layer.behind && Config.s.showWeather
            WeatherWidget {}
        }

        Movable {
            id: batteryM
            name: "battery"
            fallback: ({ x: 0.96, y: 0.4 })
            shown: !layer.behind && Config.s.showBattery && Power.hasBattery
            BatteryWidget {}
        }

        Movable {
            id: analogM
            name: "analog"
            fallback: ({ x: 0.85, y: 0.6 })
            shown: !layer.behind && Config.s.showAnalog
            AnalogClock {}
        }

        Movable {
            id: timerM
            name: "timer"
            fallback: ({ x: 0.92, y: 0.5 })
            shown: !layer.behind && Config.s.showTimer
            TimerWidget {}
        }

        Movable {
            id: note
            name: "note"
            fallback: ({ x: 0.96, y: 0.85 })
            shown: !layer.behind && Config.s.showNote
            NoteWidget {}
        }
    }
}
