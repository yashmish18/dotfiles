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

    // full width across the screen, or in a box you can move: any style can be either
    // (settings → desktop → visualiser). "auto": the wave across, bars in a box. "both": a wave
    // across and bars in a box.
    readonly property string span: Config.s.visualizerSpan
    readonly property bool hasWave: vis !== "off" && (vis === "both" || span === "full" || (span === "auto" && vis === "wave"))
    readonly property bool hasBars: vis !== "off" && (vis === "both" || span === "widget" || (span === "auto" && vis !== "wave"))
    readonly property string fullStyle: vis === "both" ? "wave" : vis
    readonly property string boxStyle: vis === "both" ? "bars" : vis
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
    function coverOf(m): var {
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
        return layer.colourFor(Qt.rgba(r, g, bl, 1));
    }
    // a colour from the wallpaper's own palette that stands out on the ground under the clock:
    //  · the hue: the theme's primary, tertiary or secondary — whichever is furthest from the
    //    ground's own hue (no red clock on a red dress; if all of them are, a pale tint of it)
    //  · the lightness: pushed away from the ground until the contrast is at least 4.5 : 1
    function lin(c): real { return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    function lum(c): real { return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b); }
    function contrast(a, b): real { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
    function colourFor(ground): var {
        const gh = ground.hslHue, gs = ground.hslSaturation;
        const hueGap = h => { if (h < 0 || gh < 0 || gs < 0.18) return 1; const d = Math.abs(h - gh); return Math.min(d, 1 - d); };
        let best = Theme.basePrimary, gap = -1;
        for (const c of [Theme.basePrimary, Theme.tertiary, Theme.secondary]) {
            const d = hueGap(c.hslHue) + c.hslSaturation * 0.15;     // apart, and properly coloured
            if (d > gap) { gap = d; best = c; }
        }
        let h = best.hslHue < 0 ? Theme.basePrimary.hslHue : best.hslHue;
        if (h < 0) h = 0.08;
        // still the ground's own hue (a red theme on a red picture): keep the hue, soften it, and
        // let lightness carry the contrast — pale rose on deep red rather than a foreign colour
        const sameHue = gs >= 0.18 && hueGap(h) < 0.1;
        const sat = sameHue ? 0.38 : Math.max(0.55, Math.min(0.85, best.hslSaturation));
        // try lighter and darker, keep whichever reaches 4.5 : 1 first (or gets closest)
        const walk = (l, step) => {
            let ink = Qt.hsla(h, sat, l, 1);
            for (let i = 0; i < 14 && contrast(ink, ground) < 4.5; i++) {
                l = Math.max(0.06, Math.min(0.95, l + step));
                ink = Qt.hsla(h, sat, l, 1);
            }
            return { ink: ink, l: l, c: contrast(ink, ground) };
        };
        const up = walk(0.68, 0.03), down = walk(0.36, -0.03);
        const pick = (up.c >= 4.5) !== (down.c >= 4.5) ? (up.c >= 4.5 ? up : down)
                   : (up.c >= 4.5 ? (Math.abs(up.l - 0.68) <= Math.abs(down.l - 0.36) ? up : down) : (up.c > down.c ? up : down));
        const ink = pick.ink, l = pick.l;
        const darkGround = pick === up;
        return {
            ink: ink,
            dim: Qt.hsla(h, sat * 0.85, l, 0.8),
            shadow: darkGround ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.35)
        };
    }
    Binding { when: !layer.behind && layer.clockTone !== null; target: Theme; property: "clockInk"; value: layer.clockTone ? layer.clockTone.ink : Theme.wallText }
    Binding { when: !layer.behind && layer.clockTone !== null; target: Theme; property: "clockInkDim"; value: layer.clockTone ? layer.clockTone.dim : Theme.wallTextDim }
    Binding { when: !layer.behind && layer.clockTone !== null; target: Theme; property: "clockShadow"; value: layer.clockTone ? layer.clockTone.shadow : Theme.wallShadow }

    // the clock's "auto" spot: centred on the wallpaper's subject, its lower part tucked behind
    // the subject's top, so the person stands in front of the numbers
    function autoClock(w, h, W, H): var {
        const m = Wall.current;
        if (!m || !m.width || !m.height || W <= w || H <= h) return null;
        // without the cut-out (no wallpaper ai, or the clock kept in front) the numbers can't
        // tuck behind anyone: find the calmest open part of the picture instead
        const depth = Config.s.clockDepth && Wall.depthReady;
        if (!(m.clock_auto && m.clock_auto.mode === "free") && (!depth || !m.subject_box || m.subject_box.length < 4))
            return calmSpot(m, w, h, W, H);
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
    // the emptiest place on screen for a w × h clock: low detail in the 16 × 9 colour grid,
    // away from the subject, a little nearer the top than the bottom. always fully on screen.
    function calmSpot(m, w, h, W, H): var {
        const g = m.grid;
        if (!g || g.length < 144) return { x: 0.5, y: 0.18 };
        const c = coverOf(m);
        const toU = x => ((area.x + x) / layer.width - 0.5) * c.x + 0.5;
        const toV = y => ((area.y + y) / layer.height - 0.5) * c.y + 0.5;
        const box = m.subject_box && m.subject_box.length >= 4 ? m.subject_box : null;
        let best = null, bestCost = 1e12;
        for (let fy = 0; fy <= 1.0001; fy += 0.1) {
            for (let fx = 0; fx <= 1.0001; fx += 0.1) {
                const x = fx * (W - w), y = fy * (H - h);
                const u0 = toU(x), u1 = toU(x + w), v0 = toV(y), v1 = toV(y + h);
                let n = 0, sr = 0, sg = 0, sb = 0, qr = 0, qg = 0, qb = 0;
                for (let j = 0; j < 9; j++) {
                    const v = (j + 0.5) / 9;
                    if (v < v0 || v > v1) continue;
                    for (let i = 0; i < 16; i++) {
                        const u = (i + 0.5) / 16;
                        if (u < u0 || u > u1) continue;
                        const px = g[j * 16 + i];
                        sr += px[0]; sg += px[1]; sb += px[2];
                        qr += px[0] * px[0]; qg += px[1] * px[1]; qb += px[2] * px[2];
                        n++;
                    }
                }
                if (n === 0) continue;
                // how busy the picture is under it: the spread of colours in those cells
                let cost = (qr / n - (sr / n) * (sr / n)) + (qg / n - (sg / n) * (sg / n)) + (qb / n - (sb / n) * (sb / n));
                if (box) {
                    const ox = Math.max(0, Math.min(u1, box[2]) - Math.max(u0, box[0]));
                    const oy = Math.max(0, Math.min(v1, box[3]) - Math.max(v0, box[1]));
                    cost += 9000 * (ox * oy) / Math.max(1e-6, (u1 - u0) * (v1 - v0));
                }
                cost += 900 * Math.abs(fy - 0.2);
                if (cost < bestCost) { bestCost = cost; best = { x: fx, y: fy }; }
            }
        }
        return best || { x: 0.5, y: 0.18 };
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

    // the full-width one: along the bottom, hanging from the top, or through the middle
    Visualizer {
        readonly property string edge: Config.s.visualizerEdge
        visible: layer.waveHere
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round(parent.height * Math.max(0.05, Math.min(0.6, Config.s.visualizerHeight)))
        y: edge === "top" ? 0 : edge === "middle" ? (parent.height - height) / 2 : parent.height - height
        flip: edge === "top"
        style: edge === "middle" && layer.fullStyle === "bars" ? "mirror" : layer.fullStyle
        active: visible && !layer.covered
        count: layer.fullStyle === "wave" ? Cava.bars : Math.max(16, Config.s.visualizerBars)
        color: Theme.wallText
        colorMode: Config.s.visualizerColor
        fillOpacity: Config.s.visualizerOpacity
        gap: Config.s.visualizerGap
        round: Config.s.visualizerRound
        smooth: Config.s.visualizerSmooth
        sparks: Config.s.musicSparks && !layer.behind
    }

    // rain or snow, when it's falling outside
    WeatherFx {
        anchors.fill: parent
        visible: !layer.behind && Config.s.weatherFx
        active: visible && !layer.covered && !Power.onBattery && !Config.s.reducedMotion
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
                implicitWidth: layer.boxStyle === "mirror" ? 620 : layer.boxStyle === "wave" ? 520 : 320
                implicitHeight: layer.boxStyle === "mirror" ? 160 : layer.boxStyle === "wave" ? 120 : 60
                style: layer.boxStyle
                active: visible && !layer.covered
                count: layer.boxStyle === "mirror" ? 96 : Math.max(16, Math.min(96, Config.s.visualizerBars))
                gap: Math.min(Config.s.visualizerGap, 3)
                color: Theme.wallText
                colorMode: Config.s.visualizerColor
                fillOpacity: Config.s.visualizerOpacity
                round: Config.s.visualizerRound
                smooth: Config.s.visualizerSmooth
                sparks: Config.s.musicSparks && !layer.behind
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
