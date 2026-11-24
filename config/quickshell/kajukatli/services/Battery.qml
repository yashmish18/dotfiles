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
    // what the laptop draws right now, in watts (read only while something shows it)
    property int consumers: 0
    property real watts: 0
    Timer {
        interval: 4000
        repeat: true
        triggeredOnStart: true
        running: root.consumers > 0 && Power.hasBattery
        onTriggered: if (!wattProc.running) wattProc.running = true
    }
    Process {
        id: wattProc
        command: ["sh", "-c", 'b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); '
            + 'if [ -r "$b/power_now" ]; then cat "$b/power_now"; '
            + 'else echo $(( $(cat "$b/current_now" 2>/dev/null || echo 0) / 1000 * $(cat "$b/voltage_now" 2>/dev/null || echo 0) / 1000 )); fi']
        stdout: StdioCollector { onStreamFinished: root.watts = Math.abs(parseInt(text.trim()) || 0) / 1e6 }
    }
    property var history: Store.s.batteryLog || []   // [{ t: ms, p: percent, c: charging }]

    // everything the battery says about itself (the control center's battery page).
    // read while something shows it, along with the watts.
    property var info: ({})
    readonly property real energyNow: info.energy_now ? info.energy_now / 1e6
                                     : info.charge_now && info.voltage_min_design ? info.charge_now * info.voltage_min_design / 1e12 : -1
    readonly property real energyFull: info.energy_full ? info.energy_full / 1e6
                                      : info.charge_full && info.voltage_min_design ? info.charge_full * info.voltage_min_design / 1e12 : -1
    readonly property real energyDesign: info.energy_full_design ? info.energy_full_design / 1e6
                                        : info.charge_full_design && info.voltage_min_design ? info.charge_full_design * info.voltage_min_design / 1e12 : -1
    readonly property real volts: info.voltage_now ? info.voltage_now / 1e6 : -1
    readonly property real tempC: info.temp ? info.temp / 10 : -1
    Timer {
        interval: 8000
        repeat: true
        triggeredOnStart: true
        running: root.consumers > 0 && Power.hasBattery
        onTriggered: { if (!detailProc.running) detailProc.running = true; root.refresh(); }
    }
    Process {
        id: detailProc
        command: ["sh", "-c", 'b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); [ -n "$b" ] || exit 0; '
            + 'for f in status technology manufacturer model_name voltage_now voltage_min_design energy_now energy_full energy_full_design '
            + 'charge_now charge_full charge_full_design capacity capacity_level cycle_count temp; do '
            + '[ -r "$b/$f" ] && printf "%s=%s\\n" "$f" "$(cat "$b/$f" 2>/dev/null)"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i <= 0) continue;
                    const k = line.slice(0, i), v = line.slice(i + 1).trim();
                    o[k] = /^-?\d+$/.test(v) ? parseInt(v) : v;
                }
                root.info = o;
            }
        }
    }

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
