pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// networkmanager through nmcli. event driven: `nmcli monitor` tells us when to look again,
// so nothing polls while you're not touching the network.
Singleton {
    id: root

    property bool wifiEnabled: true
    property bool ethernet: false
    property string ssid: ""          // connected wifi, "" if none
    property int signal: 0
    property bool scanning: false
    property var networks: []         // [{ ssid, signal, secure, active, known }]
    property var known: ({})          // saved connection names
    property string busySsid: ""      // currently connecting to
    property string error: ""
    property string needsPassword: "" // ssid the ui should ask a password for

    readonly property bool connected: ssid !== "" || ethernet
    readonly property string label: ethernet ? "wired" : (ssid !== "" ? ssid : (wifiEnabled ? "offline" : "wi-fi off"))

    // nmcli -t escapes ':' inside fields as '\:'
    function splitTerse(line: string): var {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    function refresh() {
        if (!devProc.running) devProc.running = true;
        if (!radioProc.running) radioProc.running = true;
        if (!knownProc.running) knownProc.running = true;
        if (!listProc.running) listProc.running = true;
    }
    function rescan() {
        if (scanProc.running) return;
        scanning = true;
        scanProc.running = true;
    }
    function setWifi(on: bool) {
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        wifiEnabled = on;
    }
    function connectTo(name: string, password: string) {
        error = "";
        busySsid = name;
        needsPassword = "";
        if (password !== "")
            connectProc.command = ["nmcli", "--wait", "25", "device", "wifi", "connect", name, "password", password];
        else if (known[name])
            connectProc.command = ["nmcli", "--wait", "25", "connection", "up", "id", name];
        else
            connectProc.command = ["nmcli", "--wait", "25", "device", "wifi", "connect", name];
        connectProc.target = name;
        connectProc.running = true;
    }
    function disconnect() {
        if (ssid !== "")
            Quickshell.execDetached(["nmcli", "connection", "down", "id", ssid]);
    }
    function forget(name: string) {
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", name]);
    }
    function openEditor() {
        Quickshell.execDetached(["nm-connection-editor"]);
    }

    Component.onCompleted: refresh()

    Timer {
        id: debounce
        interval: 500
        onTriggered: root.refresh()
    }

    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
        // networkmanager restarted or missing: try again later instead of spinning
        onExited: restartMonitor.start()
    }
    Timer {
        id: restartMonitor
        interval: 5000
        onTriggered: monitor.running = true
    }

    Process {
        id: devProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let eth = false, wifi = "";
                for (const line of text.trim().split("\n")) {
                    const f = root.splitTerse(line);
                    if (f.length < 3) continue;
                    if (f[0] === "ethernet" && f[1] === "connected") eth = true;
                    if (f[0] === "wifi" && f[1] === "connected") wifi = f[2];
                }
                root.ethernet = eth;
                root.ssid = wifi;
            }
        }
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
        }
    }

    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const k = {};
                for (const line of text.trim().split("\n")) {
                    const f = root.splitTerse(line);
                    if (f.length >= 2 && f[1].indexOf("wireless") !== -1) k[f[0]] = true;
                }
                root.known = k;
            }
        }
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                for (const line of text.trim().split("\n")) {
                    const f = root.splitTerse(line);
                    if (f.length < 4 || f[1] === "") continue;
                    const n = { ssid: f[1], signal: parseInt(f[2]) || 0, secure: f[3] !== "" && f[3] !== "--", active: f[0] === "*" };
                    const prev = seen[n.ssid];
                    if (!prev || n.active || (!prev.active && n.signal > prev.signal)) seen[n.ssid] = n;
                }
                const list = Object.values(seen);
                for (const n of list) n.known = !!root.known[n.ssid];
                list.sort((a, b) => (b.active - a.active) || (b.known - a.known) || (b.signal - a.signal));
                root.networks = list;
                const act = list.find(n => n.active);
                root.signal = act ? act.signal : 0;
            }
        }
    }

    Process {
        id: scanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: {
            root.scanning = false;
            listProc.running = true;
        }
    }

    Process {
        id: connectProc
        property string target: ""
        stderr: StdioCollector { id: connectErr }
        onExited: code => {
            root.busySsid = "";
            if (code === 0) {
                root.error = "";
            } else {
                const msg = connectErr.text.toLowerCase();
                if (msg.indexOf("secrets were required") !== -1 || msg.indexOf("password") !== -1 || msg.indexOf("802-11-wireless-security") !== -1) {
                    root.needsPassword = target;
                    root.error = msg.indexOf("secrets were required") !== -1 && root.known[target] ? "wrong password" : "";
                } else {
                    root.error = "couldn't connect";
                }
            }
            root.refresh();
        }
    }
}
