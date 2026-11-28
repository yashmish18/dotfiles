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

    // at login only what you changed in settings is sent: a value still at its default (the
    // same one input.lua sets) must not overwrite what you put in user.lua
    function applyInput(onlyChanged: var) {
        const s = Config.s;
        const set = (key, value, dflt) => onlyChanged === true && value === dflt ? [] : [key + " = " + (typeof value === "string" ? lua(value) : value)];
        const pad = [].concat(set("natural_scroll", s.naturalScroll, true), set("tap_to_click", s.tapToClick, true),
            set("disable_while_typing", s.disableWhileTyping, true), set("clickfinger_behavior", s.clickFinger, true),
            set("scroll_factor", Number(s.scrollFactor.toFixed(2)), 0.6));
        const all = [].concat(set("kb_layout", s.kbLayout, "us"), set("repeat_rate", s.repeatRate, 35),
            set("repeat_delay", s.repeatDelay, 280), set("sensitivity", Number(s.pointerSpeed.toFixed(2)), 0),
            pad.length ? ["touchpad = { " + pad.join(", ") + " }"] : []);
        if (all.length) Hypr.hyprEval("hl.config({ input = { " + all.join(", ") + " } })");
    }

    function scaleOf(name: string): real {
        const m = Config.s.monitorScales || {};
        return m[name] !== undefined ? m[name] : 1.0;
    }
    // one place saves a screen's settings (setMonitor), so no control can shadow another
    function setScale(name: string, scale: real) { setMonitor(name, { scale: scale }); }
    function monitorProfile(name: string): var {
        return (Config.s.monitorProfiles || {})[name] || ({});
    }
    function setMonitorProfile(name: string, key: string, value: var) {
        // picking a refresh rate replaces a full mode saved from the arrange page ("" / 0: preferred)
        setMonitor(name, key === "refresh" ? { refresh: value || null, mode: null } : { [key]: value });
    }
    // forget everything saved for a screen: hyprland's automatic choice, and the saver works again
    function resetMonitor(name: string) {
        const profiles = Object.assign({}, Config.s.monitorProfiles || {});
        const scales = Object.assign({}, Config.s.monitorScales || {});
        delete profiles[name];
        delete scales[name];
        Config.s.monitorProfiles = profiles;
        Config.s.monitorScales = scales;
        Hypr.hyprEval("hl.monitor({ output = " + lua(name) + ", mode = \"preferred\", position = \"auto\", scale = \"1\" })");
    }
    property var slowed: ({})      // screens the battery saver took down, to bring back
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
    // `once`: values for this call only (going back after "keep this?"); it also forces the apply
    function applyMonitor(name: string, once: var) {
        const p = Object.assign({}, once || {}, monitorProfile(name));
        // nothing saved and nothing for the battery saver to do: the screen is hyprland's
        // (and user.lua's) business. leave it alone
        // shortcut: `slowed` is forgotten on a shell restart; `hyprctl reload` restores 60 hz then
        const saved = Object.keys(monitorProfile(name)).length > 0 || (Config.s.monitorScales || {})[name] !== undefined;
        if (!once && !saved && !Power.saving && !slowed[name]) return;
        const m = monitors.find(x => x.name === name);
        const ipc = m ? (m.lastIpcObject || {}) : {};
        if (p.disabled) {
            Hypr.hyprEval("hl.monitor({ output = " + lua(name) + ", disabled = true })");
            return;
        }
        let mode = p.mode || (p.refresh ? nameModeAt(name, p.refresh) : modeFor(name));
        const position = p.position || "auto";
        const scale = p.scale !== undefined ? p.scale : (Config.s.monitorScales || {})[name] !== undefined ? scaleOf(name) : (ipc.scale || 1.0);
        slowed[name] = Power.saving && mode !== "preferred" && !p.mode && !p.refresh;
        // nothing would change? then don't touch it
        if (!once && ipc.width && !p.mirror) {
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
        if (p.bitdepth) f += ", bitdepth = " + p.bitdepth;
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
        // always send it: the "nothing changed" check can't see bit depth, and "back to
        // preferred" leaves nothing saved to compare with
        applyMonitor(name, "bitdepth" in values ? { bitdepth: values.bitdepth === 10 ? 10 : 8 } : {});
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
        // one place decides: "reduced motion", or the battery saver's "no window animations"
        Hypr.hyprEval("hl.config({ animations = { enabled = " + (Config.s.reducedMotion || Power.saveAnimations ? "false" : "true") + " } })");
    }
    Connections {
        target: Config.s
        function onReducedMotionChanged() { root.applyMotion(); }
    }
    function applyAll() {
        applyInput(true);
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
