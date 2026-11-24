pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// the parts of settings that belong to hyprland: touchpad, keyboard, pointer, screen scale.
// applied live when you change them, and again at every login (hyprland's own files only
// hold the defaults).
Singleton {
    id: root

    readonly property var monitors: Hyprland.monitors.values

    function lua(v: var): string { return typeof v === "string" ? '"' + v.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"' : String(v); }

    function applyInput() {
        const s = Config.s;
        Hypr.hyprEval("hl.config({ input = {"
            + " kb_layout = " + lua(s.kbLayout)
            + ", repeat_rate = " + s.repeatRate
            + ", repeat_delay = " + s.repeatDelay
            + ", sensitivity = " + s.pointerSpeed.toFixed(2)
            + ", touchpad = { natural_scroll = " + s.naturalScroll
            + ", tap_to_click = " + s.tapToClick
            + ", disable_while_typing = " + s.disableWhileTyping
            + ", clickfinger_behavior = " + s.clickFinger
            + ", scroll_factor = " + s.scrollFactor.toFixed(2)
            + " } } })");
    }

    function scaleOf(name: string): real {
        const m = Config.s.monitorScales || {};
        return m[name] !== undefined ? m[name] : 1.0;
    }
    function setScale(name: string, scale: real) {
        const m = Object.assign({}, Config.s.monitorScales || {});
        m[name] = scale;
        Config.s.monitorScales = m;
        applyMonitor(name);
    }
    function monitorProfile(name: string): var {
        return (Config.s.monitorProfiles || {})[name] || ({});
    }
    function setMonitorProfile(name: string, key: string, value: var) {
        const profiles = Object.assign({}, Config.s.monitorProfiles || {});
        profiles[name] = Object.assign({}, profiles[name] || {}, { [key]: value });
        Config.s.monitorProfiles = profiles;
        applyMonitor(name);
    }
    // the mode for a screen: its preferred one, or the same size at ~60 hz while the battery
    // saver is on (a 120/144/165 hz panel draws noticeably more power)
    function modeFor(name: string): string {
        const m = monitors.find(x => x.name === name);
        const ipc = m ? m.lastIpcObject : null;
        if (!Power.saving || !ipc || !ipc.refreshRate || ipc.refreshRate < 65) return "preferred";
        const size = ipc.width + "x" + ipc.height + "@";
        let best = null;
        for (const mode of (ipc.availableModes || [])) {
            if (!mode.startsWith(size)) continue;
            const hz = parseFloat(mode.slice(size.length));
            if (hz >= 47 && hz <= 65 && (best === null || Math.abs(hz - 60) < Math.abs(best - 60))) best = hz;
        }
        return best === null ? "preferred" : size + best.toFixed(2);
    }
    function nameModeAt(name: string, refresh: real): string {
        const m = monitors.find(x => x.name === name);
        const ipc = m ? m.lastIpcObject : null;
        if (!ipc || !ipc.width || !ipc.height) return "preferred";
        const size = ipc.width + "x" + ipc.height + "@";
        let best = null;
        for (const mode of (ipc.availableModes || [])) {
            if (!mode.startsWith(size)) continue;
            const hz = parseFloat(mode.slice(size.length));
            if (best === null || Math.abs(hz - refresh) < Math.abs(parseFloat(best.slice(size.length)) - refresh)) best = mode;
        }
        return best || "preferred";
    }
    // one screen, from its saved profile (settings → display):
    //   mode "1920x1080@60.00" (or resolution + refresh), position "1920x0", scale, transform 0-7,
    //   vrr 0/1/2, bitdepth 8/10, mirror "eDP-1", disabled
    // a screen whose profile matches what it already shows is left alone: re-sending the same
    // monitor rule makes the screen go dark for a moment (a modeset), for nothing.
    function applyMonitor(name: string) {
        const p = monitorProfile(name);
        const m = monitors.find(x => x.name === name);
        const ipc = m ? (m.lastIpcObject || {}) : {};
        if (p.disabled) {
            Hypr.hyprEval("hl.monitor({ output = " + lua(name) + ", disabled = true })");
            return;
        }
        let mode = p.mode || (p.refresh ? nameModeAt(name, p.refresh) : modeFor(name));
        const position = p.position || "auto";
        const scale = p.scale !== undefined ? p.scale : scaleOf(name);
        // nothing would change? then don't touch it
        if (ipc.width && !p.mirror) {
            const want = /^(\d+)x(\d+)@([\d.]+)/.exec(mode);
            // "preferred" is already showing unless the battery saver took the refresh down
            const atBest = !(ipc.availableModes || []).some(md => md.startsWith(ipc.width + "x" + ipc.height + "@") && parseFloat(md.split("@")[1]) > ipc.refreshRate + 1);
            const same = (mode === "preferred" ? atBest
                          : want && +want[1] === ipc.width && +want[2] === ipc.height && Math.abs(+want[3] - ipc.refreshRate) < 0.5)
                && (position === "auto" || position === ipc.x + "x" + ipc.y)
                && Math.abs(scale - ipc.scale) < 0.01
                && (p.transform === undefined || p.transform === ipc.transform)
                && (p.vrr === undefined || !!p.vrr === !!ipc.vrr)
                && (ipc.mirrorOf === undefined || ipc.mirrorOf === "none")
                && !ipc.disabled;
            if (same) return;
        }
        let f = "output = " + lua(name) + ", mode = " + lua(mode) + ", position = " + lua(position) + ", scale = " + lua(String(scale));
        if (p.transform !== undefined) f += ", transform = " + p.transform;
        if (p.vrr !== undefined) f += ", vrr = " + p.vrr;
        if (p.bitdepth === 10) f += ", bitdepth = 10";
        if (p.mirror) f += ", mirror = " + lua(p.mirror);
        Hypr.hyprEval("hl.monitor({ " + f + " })");
    }
    // several settings of one screen at once (the display page), then applied
    function setMonitor(name: string, values: var) {
        const profiles = Object.assign({}, Config.s.monitorProfiles || {});
        const p = Object.assign({}, profiles[name] || {}, values);
        for (const k in values) if (values[k] === null) delete p[k];
        profiles[name] = p;
        Config.s.monitorProfiles = profiles;
        if (values.scale !== undefined && values.scale !== null) {
            const sc = Object.assign({}, Config.s.monitorScales || {});
            sc[name] = values.scale;
            Config.s.monitorScales = sc;
        }
        applyMonitor(name);
    }
    // the quick projection modes (super + d) arrange the screens themselves: forget the saved
    // arrangement so it doesn't come back on the next battery change
    function forgetLayout() {
        const profiles = Object.assign({}, Config.s.monitorProfiles || {});
        for (const k in profiles) {
            const p = Object.assign({}, profiles[k]);
            delete p.position; delete p.mirror; delete p.disabled;
            profiles[k] = p;
        }
        Config.s.monitorProfiles = profiles;
    }
    function applyMotion() {
        Hypr.hyprEval("hl.config({ animations = { enabled = " + (Config.s.reducedMotion ? "false" : "true") + " } })");
    }
    Connections {
        target: Config.s
        function onReducedMotionChanged() { root.applyMotion(); }
    }
    function applyAll() {
        applyInput();
        applyMotion();
        for (const m of monitors) applyMonitor(m.name);
    }

    // at login, once settings.json is read
    Connections {
        target: Config
        function onLoadedChanged() { if (Config.loaded) applyTimer.restart(); }
    }
    Timer { id: applyTimer; interval: 800; onTriggered: root.applyAll() }
    Component.onCompleted: if (Config.loaded) applyTimer.restart()
}
