pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// your phone, through kk-phone: kajukatli's own service that speaks the KDE Connect protocol,
// so the KDE Connect app on the phone pairs with it. nothing from KDE or GNOME is installed.
// kk-phone keeps ~/.local/state/kajukatli/phone.json current; the shell just watches it.
Singleton {
    id: root

    property int consumers: 0
    property bool available: false        // kk-phone is running
    property var devices: []              // [{ id, name, paired, reachable, battery, charging, requested, waiting, mounted }]
    property string selfName: ""
    property string selected: ""
    property string message: ""
    readonly property var current: devices.find(d => d.id === selected) || devices.find(d => d.paired && d.reachable) || devices.find(d => d.paired) || devices[0] || null
    readonly property var requests: devices.filter(d => d.requested)

    FileView {
        id: state
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/kajukatli/phone.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root.selfName = j.self ? j.self.name : "";
                const list = j.devices || [];
                list.sort((a, b) => (b.reachable - a.reachable) || (b.paired - a.paired) || String(a.name).localeCompare(String(b.name)));
                root.devices = list;
                root.available = true;
            } catch (e) {}
        }
        onLoadFailed: root.available = false
    }

    Process {
        id: act
        stdout: StdioCollector { id: actOut }
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            const out = (actOut.text.trim() || actErr.text.trim()).split("\n")[0];
            root.message = code === 0 ? (out === "ok" ? root.okText : out) : (out || "the phone didn't answer");
            clearMsg.restart();
        }
    }
    property string okText: ""
    Timer { id: clearMsg; interval: 4000; onTriggered: root.message = "" }
    function run(args: var, ok: string) {
        okText = ok;
        act.command = [Config.bin + "kk-phone"].concat(args);
        act.running = true;
    }

    function refresh() { run(["refresh"], "looking for phones"); }
    function rescan() { refresh(); }
    function ring(d: var) { if (d) run(["ring", d.id], "ringing"); }
    function ping(d: var) { if (d) run(["ping", d.id], "pinged"); }
    function pair(d: var) { if (d) run(["pair", d.id], "accept on the phone"); }
    function unpair(d: var) { if (d) run(["unpair", d.id], "unpaired"); }
    function accept(d: var) { if (d) run(["accept", d.id], "paired"); }
    function reject(d: var) { if (d) run(["reject", d.id], "said no"); }
    function sendClipboard(d: var) { if (d) run(["clip", d.id], "clipboard sent"); }
    function sendPaths(d: var, paths: var) { if (d && paths.length) run(["send", d.id].concat(paths), paths.length === 1 ? "sent" : paths.length + " sent"); }
    function browse(d: var) { if (d) run(["browse", d.id], "opening its files"); }
    function battery(d: var) { if (d) run(["battery", d.id], ""); }
    // the daemon wasn't running (first login after an update): start it
    function start() { Quickshell.execDetached([Config.bin + "kk-phone", "daemon"]); }
}
