pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// the battery beyond its percentage: a charge limit (stop at 80% to make it last longer),
// its health (what it holds now against what it held new), cycles, and a day of history.
Singleton {
    id: root

    property bool limitSupported: false
    property int limitNow: 100           // what the battery is set to right now
    property real health: -1             // 0..1, -1 = unknown
    property int cycles: -1
    property var history: Store.s.batteryLog || []   // [{ t: ms, p: percent, c: charging }]

    readonly property string probeCmd: 'b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); [ -n "$b" ] || exit 0; '
        + 'cat "$b/charge_control_end_threshold" 2>/dev/null || echo none; '
        + 'f=$(cat "$b/energy_full" 2>/dev/null || cat "$b/charge_full" 2>/dev/null); '
        + 'd=$(cat "$b/energy_full_design" 2>/dev/null || cat "$b/charge_full_design" 2>/dev/null); '
        + 'echo "${f:-0} ${d:-0}"; cat "$b/cycle_count" 2>/dev/null || echo -1'

    function refresh() { if (!probe.running) probe.running = true; }

    // 100 = no limit
    function setLimit(pct: int) {
        Config.s.chargeLimit = pct;
        apply();
    }
    function apply() {
        if (!limitSupported) return;
        const pct = Math.max(50, Math.min(100, Config.s.chargeLimit));
        // writable for "wheel" thanks to install.sh's udev rule; else ask once with pkexec
        const set = "for b in /sys/class/power_supply/BAT*; do echo " + pct + " > \"$b/charge_control_end_threshold\"; done";
        setter.command = ["sh", "-c", set + " 2>/dev/null || pkexec sh -c '" + set + "'"];
        setter.running = true;
    }

    Process {
        id: probe
        command: ["sh", "-c", root.probeCmd]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (l.length < 3) return;
                root.limitSupported = l[0] !== "none";
                root.limitNow = root.limitSupported ? parseInt(l[0]) || 100 : 100;
                const fd = l[1].split(" ").map(x => parseFloat(x) || 0);
                root.health = fd[1] > 0 ? Math.min(1, fd[0] / fd[1]) : -1;
                root.cycles = parseInt(l[2]);
                // put the saved limit back after a reboot (some laptops forget it)
                if (root.limitSupported && Config.s.chargeLimit < 100 && root.limitNow !== Config.s.chargeLimit && !root.applied) {
                    root.applied = true;
                    root.apply();
                }
            }
        }
    }
    property bool applied: false
    Process {
        id: setter
        onExited: root.refresh()
    }

    // a day of charge, one point every ten minutes
    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: Power.hasBattery && Store.ready
        triggeredOnStart: true
        onTriggered: {
            const now = Date.now();
            const h = (Store.s.batteryLog || []).filter(x => now - x.t < 24 * 3600 * 1000);
            h.push({ t: now, p: Power.percent, c: Power.charging });
            Store.s.batteryLog = h;
        }
    }

    Component.onCompleted: refresh()
    Connections {
        target: Config
        function onLoadedChanged() { if (Config.loaded) root.refresh(); }
    }
}
