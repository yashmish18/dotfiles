pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// the nvidia card on a hybrid laptop (kk-gpu does the work):
//   · which card draws the desktop (igpu · both · nvidia), at the next login
//   · the card itself on or off (off: taken off the bus until you turn it back on)
//   · heavy apps (Config.s.gpuApps: blender, steam, games…) start on it from the launcher,
//     and one started on the integrated card anyway gets a "restart it on nvidia" offer
Singleton {
    id: root

    property var info: ({})               // kk-gpu status
    readonly property bool hybrid: info.hybrid === true
    readonly property bool present: info.dgpu === true
    readonly property bool powered: info.power !== "removed"
    readonly property string mode: info.mode || ""
    readonly property string running: info.running || ""
    readonly property string runtime: info.runtime || ""     // active | suspended | removed
    readonly property string name: info.name || "NVIDIA"
    readonly property var users: info.users || []           // apps on the card right now

    function refresh() { if (!statusProc.running) statusProc.running = true; }
    Component.onCompleted: refresh()

    Process {
        id: statusProc
        command: [Config.bin + "kk-gpu", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.info = JSON.parse(text.trim()); } catch (e) {} } }
    }
    Process {
        id: setProc
        stdout: StdioCollector { id: setOut }
        stderr: StdioCollector { id: setErr }
        onExited: code => {
            root.message = code === 0 ? setOut.text.trim() : (setErr.text.trim() || "that didn't work");
            root.refresh();
        }
    }
    property string message: ""

    // igpu | both | nvidia
    function setMode(m: string) {
        if (setProc.running) return;
        setProc.command = [Config.bin + "kk-gpu", "set", m];
        setProc.running = true;
    }
    // the card on or off (asks for your password). off moves the apps on it to the integrated
    // graphics first: each is closed and started again there
    function setPower(on: bool) {
        if (setProc.running) return;
        setProc.command = [Config.bin + "kk-gpu", on ? "on" : "off"];
        setProc.running = true;
    }

    // close everything of yours that is using the card (nothing reopens): so it can go off,
    // or a new mode applied at the next login with nothing holding on to it
    function freeCard() {
        if (setProc.running) return;
        setProc.command = [Config.bin + "kk-gpu", "free"];
        setProc.running = true;
    }

    // should this desktop entry / window class run on the nvidia card?
    function wants(app: var): bool {
        if (!hybrid || !powered) return false;
        const keys = [];
        if (typeof app === "string") keys.push(app);
        else if (app) {
            keys.push(app.id || "", app.name || "");
            if (app.command && app.command.length) keys.push(String(app.command[0]).split("/").pop());
        }
        const list = (Config.s.gpuApps || []).map(x => String(x).toLowerCase());
        for (const k of keys) {
            const s = String(k).toLowerCase();
            if (s === "") continue;
            if (/^steam_app_/.test(s)) return true;
            // whole names only ("obs" must not catch obsidian): "blender-4.2", "net.lutris.lutris"
            for (const g of list) if (g !== "" && (s === g || s.startsWith(g + "-") || s.split(".").indexOf(g) !== -1)) return true;
        }
        return false;
    }
    // the command, wrapped to run on the nvidia card when it should (or when forced)
    function wrap(cmd: var, app: var, force: bool): var {
        if (!(force && hybrid) && !wants(app)) return cmd;
        return [Config.bin + "kk-gpu", "run"].concat(cmd);
    }

    // a heavy app opened on the integrated card: offer to start it again on nvidia
    function checkWindow(address: string, cls: string) {
        if (!Config.s.gpuHint || !hybrid || !powered || !wants(cls)) return;
        Quickshell.execDetached([Config.bin + "kk-gpu", "hint", address, cls]);
    }
}
