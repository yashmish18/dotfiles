pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

// every app running for you, whatever shape it's in: windows, tray icons, and apps with no
// window at all (anything of yours that has a desktop entry). the bar's apps pill and the
// running panel show this, so nothing hides in the background.
//
// an app is asked to quit a few seconds after its last
// window closes, unless it's in Config.s.backgroundAllowed.
Singleton {
    id: root

    property int consumers: 0
    property var procs: []                 // [{ pid, ppid, cpu, rss (kb), comm }]

    // processes that are part of the desktop itself, never listed as "apps"
    readonly property var system: /^(quickshell|qs|Hyprland|hypridle|hyprsunset|hyprpolkitagent|xdg-desktop-portal.*|pipewire.*|wireplumber|dbus.*|systemd|\(sd-pam\)|at-spi.*|gvfs.*|dconf-service|cliphist|wl-paste|kk-.*|sh|bash|zsh|fish|sleep|cava|mpvpaper|ps|gnome-keyring-daemon|xwayland|Xwayland|kdeconnectd?)$/

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: root.consumers > 0
        onTriggered: if (!psProc.running) psProc.running = true
    }
    Process {
        id: psProc
        command: ["ps", "-u", Quickshell.env("USER") || "", "-o", "pid=,ppid=,pcpu=,rss=,comm="]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const m = /^\s*(\d+)\s+(\d+)\s+([\d.]+)\s+(\d+)\s+(.+)$/.exec(line);
                    if (m) out.push({ pid: +m[1], ppid: +m[2], cpu: +m[3], rss: +m[4], comm: m[5].trim() });
                }
                root.procs = out;
            }
        }
    }

    function entryFor(name: string): var {
        if (!name) return null;
        return DesktopEntries.heuristicLookup(name) || null;
    }
    function iconFor(entry: var, name: string): string {
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : (name || "").toLowerCase(), "application-x-executable");
    }

    // [{ key, name, icon, windows: [{address, title, ws}], pids: [], tray, cpu, mem, kind }]
    readonly property var list: {
        const groups = {};
        const byPid = {};
        const get = (key, name, entry) => {
            if (!groups[key]) groups[key] = { key: key, name: name, icon: iconFor(entry, key), windows: [], pids: [], tray: null, cpu: 0, mem: 0, kind: "background", entry: entry };
            return groups[key];
        };
        // windows
        for (const t of Hyprland.toplevels.values) {
            const ipc = t.lastIpcObject || {};
            const cls = ipc.class || ipc.initialClass || "";
            if (!cls) continue;
            const entry = entryFor(cls);
            const key = entry ? entry.id : cls;
            const g = get(key, entry ? entry.name : cls, entry);
            g.kind = "window";
            g.windows.push({ address: ipc.address || "", title: ipc.title || t.title || "", ws: ipc.workspace ? ipc.workspace.id : 0 });
            if (ipc.pid > 0 && g.pids.indexOf(ipc.pid) === -1) { g.pids.push(ipc.pid); byPid[ipc.pid] = g; }
        }
        // tray icons
        for (const it of SystemTray.items.values) {
            const entry = entryFor(it.id) || entryFor(it.title);
            const key = entry ? entry.id : (it.id || it.title);
            const g = get(key, entry ? entry.name : (it.title || it.id), entry);
            g.tray = it;
            if (g.kind !== "window") g.kind = "tray";
            if (it.icon) g.icon = it.icon;
        }
        // everything else of yours that is an app (has a desktop entry)
        for (const p of root.procs) {
            if (byPid[p.pid]) { byPid[p.pid].cpu += p.cpu; byPid[p.pid].mem += p.rss; continue; }
            // a child of an app we already have (browser tabs, electron helpers): count it there
            if (byPid[p.ppid]) { byPid[p.pid] = byPid[p.ppid]; byPid[p.pid].cpu += p.cpu; byPid[p.pid].mem += p.rss; continue; }
            if (root.system.test(p.comm)) continue;
            const entry = entryFor(p.comm);
            const known = groups[p.comm] || (entry && groups[entry.id]);
            if (!entry && !known) continue;
            const g = known || get(entry.id, entry.name, entry);
            if (g.pids.indexOf(p.pid) === -1) g.pids.push(p.pid);
            g.cpu += p.cpu;
            g.mem += p.rss;
            byPid[p.pid] = g;
        }
        const out = Object.values(groups);
        const rank = { window: 0, tray: 1, background: 2 };
        out.sort((a, b) => (rank[a.kind] - rank[b.kind]) || a.name.localeCompare(b.name));
        return out;
    }
    readonly property int count: list.length
    readonly property int hiddenCount: list.filter(g => g.kind !== "window").length

    function focus(g: var) {
        if (g.windows.length) Hypr.focusWindow(g.windows[0].address);
        else if (g.tray) g.tray.activate();
        else if (g.entry) g.entry.execute();
    }
    function closeWindows(g: var) { for (const w of g.windows) Hypr.closeWindow(w.address); }
    function quit(g: var) { signal_(g, "TERM"); }
    function forceQuit(g: var) { signal_(g, "KILL"); }
    function signal_(g: var, sig: string) {
        if (!g.pids.length) return;
        Quickshell.execDetached(["kill", "-" + sig].concat(g.pids.map(String)));
    }
    function allowed(g: var): bool {
        const a = (Config.s.backgroundAllowed || []).map(x => String(x).toLowerCase());
        return a.indexOf(String(g.key).toLowerCase()) !== -1 || a.indexOf(String(g.name).toLowerCase()) !== -1;
    }
    function setAllowed(g: var, on: bool) {
        const a = (Config.s.backgroundAllowed || []).filter(x => String(x).toLowerCase() !== String(g.key).toLowerCase());
        if (on) a.push(g.key);
        Config.s.backgroundAllowed = a;
    }

    // ------------------------------------------------------------ no background apps
    // remember which process each window belongs to, so a closed window can be traced back
    property var owners: ({})              // address → { pid, cls }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            const n = ev.name || "";
            if (n === "openwindow") ownerProc.running = true;
            else if (n === "closewindow") {
                const addr = "0x" + (ev.data || "").trim().replace(/^0x/, "");
                const o = root.owners[addr];
                if (o) { reapProc.target = o; reapTimer.restart(); }
            }
        }
    }
    Process {
        id: ownerProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = {};
                    for (const c of JSON.parse(text)) o[c.address] = { pid: c.pid, cls: c.class };
                    root.owners = o;
                } catch (e) {}
            }
        }
    }
    Component.onCompleted: ownerProc.running = true
    Timer {
        id: reapTimer
        interval: 3000
        onTriggered: reapProc.running = true
    }
    Process {
        id: reapProc
        property var target: null
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = reapProc.target;
                if (!t || !(t.pid > 0)) return;
                let list = [];
                try { list = JSON.parse(text); } catch (e) { return; }
                if (list.some(c => c.pid === t.pid)) return;           // it still has a window
                const a = (Config.s.backgroundAllowed || []).map(x => String(x).toLowerCase());
                const entry = root.entryFor(t.cls);
                if (a.indexOf(String(t.cls).toLowerCase()) !== -1 || (entry && a.indexOf(String(entry.id).toLowerCase()) !== -1)) return;
                Quickshell.execDetached(["kill", "-TERM", String(t.pid)]);
                ownerProc.running = true;
            }
        }
    }
}
