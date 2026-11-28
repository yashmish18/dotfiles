pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// the equalizer: ten bands in front of whatever output you're using (bin/kk-eq, pipewire's own
// filters). nothing runs while it's off.
Singleton {
    id: root

    readonly property var freqs: ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property var presets: [
        { key: "flat", label: "Flat", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
        { key: "bass", label: "Bass", gains: [5, 4.5, 3.5, 2, 0.5, 0, 0, 0, 0, 0] },
        { key: "deepbass", label: "Deep bass", gains: [9, 7, 4, 1, -1, -1, 0, 0, 0, 0] },
        { key: "studio", label: "Studio", gains: [1, 0.5, 0, -1, -1, 0, 0.5, 1, 1.5, 1] },
        { key: "vocal", label: "Vocal", gains: [-4, -3, -1.5, 0, 2, 4, 4, 2.5, 0.5, -0.5] },
        { key: "treble", label: "Treble", gains: [0, 0, 0, 0, 0, 1, 2.5, 4, 5, 5.5] },
        { key: "warm", label: "Warm", gains: [2, 3, 3, 2, 1, 0, -1, -2, -2.5, -3] },
        { key: "pop", label: "Pop", gains: [-1, 0, 1.5, 3, 3.5, 2.5, 1, 0.5, 1, 1] },
        { key: "rock", label: "Rock", gains: [4.5, 3.5, 2, 0, -1.5, -1, 1, 2.5, 3.5, 3.5] },
        { key: "hiphop", label: "Hip-hop", gains: [6, 5, 2.5, 2, -1, -1, 1, 0, 2, 3] },
        { key: "electronic", label: "Electronic", gains: [5.5, 4.5, 1.5, 0, -2, 1, 0.5, 1.5, 4, 4.5] },
        { key: "acoustic", label: "Acoustic", gains: [3, 3, 2, 0.5, 1.5, 1.5, 2.5, 3, 2.5, 1.5] },
        { key: "jazz", label: "Jazz", gains: [3, 2, 1, 2, -1.5, -1.5, 0, 1, 2.5, 3] },
        { key: "classical", label: "Classical", gains: [3.5, 2.5, 1.5, 1, -0.5, -0.5, 0, 1.5, 2.5, 3] },
        { key: "movie", label: "Movie", gains: [5, 4, 2, 0, -1, 1.5, 3, 2.5, 2, 1] },
        { key: "podcast", label: "Podcast", gains: [-8, -5, -1, 1, 3, 4, 3, 1.5, -1, -3] },
        { key: "gaming", label: "Gaming", gains: [3, 2.5, 0, -1.5, -1, 1, 3, 4, 3, 1.5] },
        { key: "latenight", label: "Late night", gains: [-4, -3, -1, 0.5, 1.5, 2, 2, 1, -1, -2] }
    ]

    readonly property bool on: Config.s.eqOn
    // always ten numbers within range, whatever the settings file holds
    readonly property var gains: {
        const g = Config.s.eqGains || [];
        const out = [];
        for (let i = 0; i < 10; i++) out.push(Math.max(-12, Math.min(12, Number(g[i]) || 0)));
        return out;
    }
    readonly property string csv: gains.join(",")
    readonly property string presetLabel: {
        const hit = presets.find(p => p.gains.join(",") === csv);
        return hit ? hit.label : "Custom";
    }
    readonly property string label: error !== "" ? "error" : on ? presetLabel : "off"
    property string error: ""
    property int fails: 0

    function toggle() { Config.s.eqOn = !Config.s.eqOn; }
    function usePreset(p: var) { Config.s.eqGains = p.gains.slice(); Config.s.eqOn = true; }
    function setBand(i: int, db: real) {
        const g = gains.slice();
        g[i] = Math.round(Math.max(-12, Math.min(12, db)) * 2) / 2;
        if (g[i] !== gains[i]) Config.s.eqGains = g;
    }

    // ---------------------------------------------------------------- the process
    readonly property bool shouldRun: on && Config.loaded
    onShouldRunChanged: {
        fails = 0;
        error = "";
        restart.stop();
        if (filter.running) { if (!shouldRun) filter.running = false; }   // back on while stopping: onExited starts it
        else if (shouldRun) start();
    }
    Component.onCompleted: if (shouldRun) start()
    function start() {
        if (!shouldRun || filter.running) return;
        filter.sent = csv;
        filter.command = ["setpriv", "--pdeathsig", "TERM", "--", Config.bin + "kk-eq", "run", csv];
        filter.running = true;
    }
    Process {
        id: filter
        property string sent: ""
        stderr: StdioCollector { id: err }
        onRunningChanged: if (running) settle.restart()
        onExited: code => {
            settle.stop();
            if (!root.shouldRun) return;
            if (code === 75 || code === 0) { restart.interval = 600; restart.restart(); return; }   // another output: move over
            root.fails++;
            if (root.fails >= 3) root.error = err.text.trim().split("\n").pop() || "the equalizer stopped";
            else { restart.interval = 2000; restart.restart(); }
        }
    }
    Timer { id: restart; onTriggered: root.start() }
    // up and steady: forget earlier failures, and send anything changed while it was starting
    Timer {
        id: settle
        interval: 2500
        onTriggered: {
            root.fails = 0;
            root.error = "";
            if (root.csv !== filter.sent) root.push();
        }
    }
    onCsvChanged: if (filter.running && !settle.running) soon.restart()
    Timer { id: soon; interval: 60; onTriggered: root.push() }
    function push() {
        if (!filter.running || applier.running) return;   // applier looks again when it finishes
        applier.sent = csv;
        applier.command = [Config.bin + "kk-eq", "apply", csv];
        applier.running = true;
    }
    Process {
        id: applier
        property string sent: ""
        property int misses: 0
        onExited: code => {
            if (code !== 0) { if (++misses <= 3) soon.restart(); return; }   // not applied: try again, a few times
            misses = 0;
            filter.sent = sent;
            if (root.csv !== sent) Qt.callLater(root.push);
        }
    }

    // qs -c kajukatli ipc call eq status
    IpcHandler {
        target: "eq"
        function status(): string { return JSON.stringify({ on: root.on, running: filter.running, gains: root.csv, preset: root.presetLabel, error: root.error }); }
        function toggle(): void { root.toggle(); }
        function preset(key: string): void { const p = root.presets.find(x => x.key === key); if (p) root.usePreset(p); }
    }
}
