pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// screen brightness via brightnessctl (works without root thanks to logind).
Singleton {
    id: root

    property real value: 1.0       // 0..1
    property bool available: false
    signal changedByUser()

    function set(v: real) {
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        run(["brightnessctl", "-m", "set", pct + "%"], false);
    }
    function up() {
        run(["brightnessctl", "-m", "-e4", "-n2", "set", "5%+"], true);
    }
    function down() {
        run(["brightnessctl", "-m", "-e4", "-n2", "set", "5%-"], true);
    }
    function run(cmd: var, fromKey: var) {
        if (proc.running) { // slider or key repeat faster than brightnessctl: keep only the latest
            proc.pending = cmd;
            proc.pendingUser = fromKey;
            return;
        }
        proc.command = cmd;
        proc.user = fromKey;
        proc.running = true;
    }

    Component.onCompleted: run(["brightnessctl", "-m", "-c", "backlight", "info"], false)

    Process {
        id: proc
        property bool user: false
        property var pending: null
        property bool pendingUser: false
        // -m output: device,class,current,percent,max
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",");
                if (f.length >= 5) {
                    const cur = parseInt(f[2]), max = parseInt(f[4]);
                    if (max > 0) {
                        root.value = cur / max;
                        root.available = true;
                    }
                }
            }
        }
        onExited: {
            if (user && root.available) root.changedByUser();
            if (pending) {
                const next = pending;
                pending = null;
                Qt.callLater(() => root.run(next, pendingUser));
            }
        }
    }
}
