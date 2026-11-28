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
    property string backend: ""

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

    // ---------------------------------------------------------------- captive portals
    // hotel / campus wi-fi that wants you to sign in first: networkmanager reports "portal"
    // (install.sh turns its connectivity check on). the sign-in page opens once per network.
    property string connectivity: ""
    property string portalShownFor: ""
    function checkPortal() {
        if (!portalProc.running) portalProc.running = true;
    }
    Process {
        id: portalProc
        command: ["nmcli", "networking", "connectivity", "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.connectivity = text.trim();
                const here = root.ssid || (root.ethernet ? "wired" : "");
                if (root.connectivity === "portal" && here !== "" && root.portalShownFor !== here) {
                    root.portalShownFor = here;
                    // any plain-http page gets redirected to the network's sign-in page
                    Quickshell.execDetached(["xdg-open", "http://neverssl.com"]);
                } else if (root.connectivity === "full") {
                    root.portalShownFor = "";
                }
            }
        }
    }
    // look again shortly after every change, and now and then while connected
    Timer {
        id: portalSoon
        interval: 2500
        onTriggered: root.checkPortal()
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.connected && root.connectivity !== "full"
        onTriggered: root.checkPortal()
    }
    onSsidChanged: portalSoon.restart()
    onEthernetChanged: portalSoon.restart()

    function refresh() {
        backendProc.running = true;
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
        if (wifiProc.running) return;
        wifiEnabled = on;
        wifiProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        wifiProc.running = true;
    }
    function connectTo(name: string, password: string) {
        if (connectProc.running) return;    // one at a time, so the result is shown for the right one
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
        // networkmanager's own editor, in the terminal (no gtk applet needed)
        Quickshell.execDetached(["kitty", "--class", "kk-float", "-e", "nmtui"]);
    }

    Process {
        id: wifiProc
        stderr: StdioCollector { id: wifiErr }
        onExited: code => {
            if (code !== 0) root.error = wifiErr.text.trim() || "couldn't change wi-fi";
            root.refresh();
            if (root.wifiEnabled) root.rescan();
        }
    }

    Component.onCompleted: refresh()

    Timer {
        id: debounce
        interval: 500
        onTriggered: root.refresh()
    }

    Process {
        id: backendProc
        command: ["sh", "-c", "nmcli -t -f STATE general 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: root.backend = text.trim() === "" ? "NetworkManager unavailable" : text.trim()
        }
    }

    Process {
        id: monitor
        running: true
        // pdeathsig: without it every shell restart left another one running
        command: ["setpriv", "--pdeathsig", "TERM", "--", "nmcli", "monitor"]
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
        command: ["sh", "-c", "[ \"$(nmcli radio wifi)\" = enabled ] || exit 0; nmcli device wifi rescan >/dev/null 2>&1 || true; sleep 1; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list"]
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
            }
        }
        stderr: StdioCollector { id: scanErr }
        onExited: {
            root.scanning = false;
            if (scanErr.text.trim() !== "") root.error = "wi-fi scan failed: " + scanErr.text.trim();
            else root.error = "";
            root.refresh();
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
