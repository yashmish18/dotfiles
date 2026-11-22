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

    function lua(v) { return typeof v === "string" ? '"' + v.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"' : String(v); }

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
    function applyMonitor(name: string) {
        Hypr.hyprEval("hl.monitor({ output = " + lua(name) + ", mode = \"" + modeFor(name) + "\", position = \"auto\", scale = \""
                      + scaleOf(name) + "\" })");
    }
    function applyAll() {
        applyInput();
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
