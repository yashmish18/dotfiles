pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// cpu, memory, network, disk, temperatures. read by `kk-sys` every two seconds, and only
// while something on screen shows them (the stats widget, or cpu/mem/temp in the bar).
Singleton {
    id: root

    property int consumers: 0
    readonly property bool running: consumers > 0

    property real cpu: 0          // 0..1
    property real gpu: -1         // 0..1, -1 = unknown
    property real memUsed: 0      // bytes
    property real memTotal: 1
    readonly property real mem: memTotal > 0 ? memUsed / memTotal : 0
    property real rx: 0           // bytes / s
    property real tx: 0
    property var netHistory: []   // last 40 rx+tx samples
    property var cpuHistory: []
    property real diskUsed: 0
    property real diskTotal: 1
    readonly property real disk: diskTotal > 0 ? diskUsed / diskTotal : 0
    property real cpuTemp: -1     // °C
    property real gpuTemp: -1
    property int fan: -1          // rpm
    property real power: -1       // watts in/out of the battery

    property var _prev: null

    function bytes(b: real): string {
        const u = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (i === 0 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }

    Process {
        id: proc
        running: root.running
        command: ["setpriv", "--pdeathsig", "TERM", "--", Config.bin + "kk-sys", Power.saving ? "5" : "2"]   // slower sampling on battery
        stdout: SplitParser {
            onRead: line => {
                let j;
                try { j = JSON.parse(line); } catch (e) { return; }
                const p = root._prev;
                if (p) {
                    const dt = Math.max(0.5, (j.t - p.t) / 1000);
                    const busy = j.cpu_busy - p.cpu_busy, total = j.cpu_total - p.cpu_total;
                    root.cpu = total > 0 ? Math.max(0, Math.min(1, busy / total)) : 0;
                    root.rx = Math.max(0, (j.rx - p.rx) / dt);
                    root.tx = Math.max(0, (j.tx - p.tx) / dt);
                    const nh = root.netHistory.slice(-39); nh.push(root.rx + root.tx); root.netHistory = nh;
                    const ch = root.cpuHistory.slice(-39); ch.push(root.cpu); root.cpuHistory = ch;
                }
                root._prev = j;
                root.memTotal = j.mem_total;
                root.memUsed = j.mem_total - j.mem_avail;
                root.diskUsed = j.disk_used;
                root.diskTotal = j.disk_total || 1;
                root.cpuTemp = j.cpu_temp;
                root.gpuTemp = j.gpu_temp;
                root.gpu = j.gpu_busy >= 0 ? j.gpu_busy / 100 : -1;
                root.fan = j.fan;
                root.power = j.power;
            }
        }
    }
    onRunningChanged: if (!running) _prev = null
}
