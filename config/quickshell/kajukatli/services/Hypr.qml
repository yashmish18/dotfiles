pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// thin helpers over hyprland ipc. works with the lua config and the old hyprlang one.
Singleton {
    id: root

    // some changes (a touchpad swipe, a workspace made on the fly) don't always reach quickshell's
    // own model: re-read it after any workspace event, debounced
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            const n = ev.name || "";
            if (n === "monitoradded" || n === "monitoraddedv2")
                monitorHotplug.restart();
            else if (n === "monitorremoved" || n === "monitorremovedv2")
                monitorRescue.restart();
            const data = ev.data || "";
            // a window closed or moved away: close the gap it may have left (1 2 _ 4 → 1 2 3)
            if (n === "closewindow" || n === "destroyworkspace" || n === "destroyworkspacev2" || n === "movewindowv2")
                compactSoon.restart();
            // a sign-in page (or a link another app opened) in a browser somewhere else
            if (n === "openwindow") {
                const f = data.split(",");
                const addr = "0x" + f[0].replace(/^0x/, "");
                root.consider(addr, f[2] || "", f.slice(3).join(","), false);
                Gpu.checkWindow(addr, f[2] || "");
            } else if (n === "windowtitlev2") {
                const i = data.indexOf(",");
                root.consider("0x" + data.slice(0, i).replace(/^0x/, ""), "", data.slice(i + 1), false);
            } else if (n === "urgent") {
                root.consider("0x" + data.trim().replace(/^0x/, ""), "", "", true);
            }
            // ask, don't guess: coming back to a fullscreen video must count as fullscreen
            if (n === "fullscreen" || n === "workspace" || n === "workspacev2" || n === "focusedmon" || n === "closewindow")
                fsSoon.restart();
            if (n.startsWith("workspace") || n.startsWith("createworkspace") || n.startsWith("destroyworkspace")
                || n.startsWith("focusedmon") || n.startsWith("moveworkspace") || n.startsWith("openwindow")
                || n.startsWith("closewindow") || n.startsWith("movewindow"))
                again.restart();
        }
    }
    Timer { id: fsSoon; interval: 80; onTriggered: if (fsProc.running) restart(); else fsProc.running = true }
    Process {
        id: fsProc
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.fullscreen = JSON.parse(text).hasfullscreen === true; } catch (e) {} } }
    }
    Timer {
        id: again
        interval: 120          // one refresh for a burst of events (opening an app sends several)
        onTriggered: Hyprland.refreshWorkspaces()
    }
    Timer {
        id: monitorHotplug
        interval: 900
        // kk-display ignores the burst of "monitor added" events its own mode changes cause
        // (a reload re-adds every screen), so "External only" isn't undone a second later
        onTriggered: Quickshell.execDetached(["sh", "-c", "sleep 0.2; exec " + Config.bin + "kk-display hotplug"])
    }
    // an unplugged screen must never leave you with every screen off
    Timer {
        id: monitorRescue
        interval: 700
        onTriggered: Quickshell.execDetached([Config.bin + "kk-display", "rescue"])
    }

    // the screen shell windows (overlays, toasts, osd) belong on: the focused one, or, when
    // hyprland's idea of "focused" is a screen that was just switched off or unplugged, one
    // that is really on
    readonly property var liveScreen: {
        const live = Quickshell.screens;
        const mon = Hyprland.focusedMonitor;
        const hit = live.find(s => mon && s.name === mon.name);
        if (hit) return hit;
        const on = Hyprland.monitors.values.find(m => !(m.lastIpcObject && m.lastIpcObject.disabled) && live.some(s => s.name === m.name));
        return (on && live.find(s => s.name === on.name)) || live[0];
    }

    // ...but a shell window that is already showing never changes screen: moving a live
    // layer-shell window to another output makes Qt tear down and rebuild its surface, which
    // is a crash waiting to happen (and it would jump away from under your hands anyway).
    // so this follows liveScreen only while no overlay, emoji picker or toast is up.
    property var activeScreen: null
    Binding {
        target: root
        property: "activeScreen"
        value: root.liveScreen
        when: Ui.overlay === "" && !Ui.overlayLinger && !Ui.emojiOpen && !Ui.emojiLinger && Notifs.popups.length === 0
    }

    // something is fullscreen (a video, a game): notifications wait until it isn't
    property bool fullscreen: false

    readonly property var focusedWs: Hyprland.focusedWorkspace
    readonly property int focusedId: Number(focusedWs && focusedWs.id) || 1

    // normal (positive id) workspaces on a monitor, sorted
    function workspacesOn(monitor: var): var {
        const out = [];
        const all = Hyprland.workspaces.values;
        for (let i = 0; i < all.length; i++) {
            const w = all[i];
            if (w.id > 0 && (!monitor || w.monitor === monitor))
                out.push(w);
        }
        out.sort((a, b) => a.id - b.id);
        return out;
    }

    // an id just handed out isn't in hyprland's list for a moment: nobody else may take it
    property var reserved: ({})      // id → when
    function isReserved(id: int): bool { return Date.now() - (reserved[id] || 0) < 1500; }
    function takeFreeId(): int {
        const used = {};
        const all = Hyprland.workspaces.values;
        for (let i = 0; i < all.length; i++)
            used[all[i].id] = true;
        let id = 1;
        while (used[id] || isReserved(id))
            id++;
        reserved[id] = Date.now();
        return id;
    }

    function luaStr(s: var): string {
        return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }

    function focusWorkspace(id: var) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + luaStr(id) + " })");
        else
            Hyprland.dispatch("workspace " + id);
    }

    function moveWindowTo(id: var, address: var, follow: var) {
        if (Hyprland.usingLua) {
            let args = "workspace = " + luaStr(id) + ", follow = " + (follow ? "true" : "false");
            if (address)
                args += ", window = " + luaStr("address:" + address);
            Hyprland.dispatch("hl.dsp.window.move({ " + args + " })");
        } else {
            const d = follow ? "movetoworkspace" : "movetoworkspacesilent";
            Hyprland.dispatch(d + " " + id + (address ? ",address:" + address : ""));
        }
    }

    function focusWindow(address: var) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ window = " + luaStr("address:" + address) + " })");
        else
            Hyprland.dispatch("focuswindow address:" + address);
    }

    function closeWindow(address: var) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.window.close({ window = " + luaStr("address:" + address) + " })");
        else
            Hyprland.dispatch("closewindow address:" + address);
    }

    function renameWorkspace(id: var, name: var) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.workspace.rename({ workspace = " + luaStr(id) + ", name = " + luaStr(name) + " })");
        else
            Hyprland.dispatch("renameworkspace " + id + " " + name);
    }

    // go one step along existing workspaces; stepping past the last one opens a fresh one,
    // unless you're already standing in an empty one.
    function step(dir: int) {
        const mon = Hyprland.focusedMonitor;
        const list = workspacesOn(mon);
        const cur = root.focusedWs;
        const idx = list.findIndex(w => cur && w.id === cur.id);
        if (dir > 0) {
            if (idx >= 0 && idx < list.length - 1)
                focusWorkspace(list[idx + 1].id);
            else if (cur && cur.toplevels.values.length > 0)
                focusWorkspace(takeFreeId());
        } else if (idx > 0) {
            focusWorkspace(list[idx - 1].id);
        }
    }

    function newWorkspace(moveWindow: bool) {
        const id = takeFreeId();
        if (moveWindow && Hyprland.activeToplevel)
            moveWindowTo(id, "", true);
        else
            focusWorkspace(id);
    }

    // which workspaces move up so a new one can take id `at`: { old: new }. only the run that
    // is in the way moves (a free number absorbs the shift); ids another screen uses are skipped
    function insertPlan(mine: var, others: var, at: int): var {
        const plan = {};
        let last = at;
        for (const id of mine.filter(i => i >= at).sort((a, b) => a - b)) {
            if (id > last) break;
            let to = last + 1;
            while (others.indexOf(to) !== -1) to++;
            plan[id] = to;
            last = to;
        }
        return plan;
    }
    // a new workspace holding this window, where workspace `at` is now: it and those after move up
    function insertWorkspace(at: int, address: string, monitor: var) {
        const here = workspacesOn(monitor);
        const others = workspacesOn(null).filter(w => here.indexOf(w) === -1).map(w => w.id);
        const plan = insertPlan(here.map(w => w.id), others, at);
        const active = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1;
        // read everything first: the lists change under us as windows move
        const steps = Object.keys(plan).map(Number).sort((a, b) => b - a).map(id => {
            const w = here.find(x => x.id === id);
            return { to: plan[id], name: w.name !== String(id) ? w.name : "",
                     windows: w.toplevels.values.map(t => (t.lastIpcObject || {}).address).filter(a => a && a !== address) };
        });
        for (const s of steps) {       // highest first, so two workspaces never mix
            for (const a of s.windows) moveWindowTo(s.to, a, false);
            if (s.name !== "") renameWorkspace(s.to, s.name);
        }
        moveWindowTo(at, address, false);
        if (plan[active] !== undefined) focusWorkspace(plan[active]);   // stay with your windows
    }

    function hyprEval(lua: string) {
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    // ------------------------------------------------------------- no gaps
    // close workspace 3 of 1 2 3 4 and 4 becomes 3. only on the screen you're on (ids are shared
    // between screens, and a window sent to a new id lands on the focused screen), only into ids
    // nobody uses, and never a workspace you gave a name. settings: compactWorkspaces.
    Timer {
        id: compactSoon
        interval: 450
        // not while you're arranging in the overview: renumbering under your hands looked like
        // a drop had made a new workspace. it happens when the overview closes
        onTriggered: if (Config.s.compactWorkspaces && Ui.overlay !== "overview" && !snapProc.running) snapProc.running = true
    }
    Connections {
        target: Ui
        function onOverlayChanged() { if (Ui.overlay !== "overview") compactSoon.restart(); }
    }
    Process {
        id: snapProc
        command: ["sh", "-c", 'jq -nc --argjson c "$(hyprctl clients -j)" --argjson w "$(hyprctl workspaces -j)" --argjson m "$(hyprctl monitors -j)" \'{c: $c, w: $w, m: $m}\'']
        stdout: StdioCollector {
            onStreamFinished: {
                let j;
                try { j = JSON.parse(text); } catch (e) { return; }
                root.compact(j.c || [], j.w || [], j.m || []);
            }
        }
    }
    function compact(clients: var, workspaces: var, monitors: var) {
        const mon = monitors.find(m => m.focused);
        if (!mon) return;
        const active = mon.activeWorkspace ? mon.activeWorkspace.id : -1;
        const used = {};
        for (const w of workspaces) used[w.id] = true;
        const mine = workspaces.filter(w => w.id > 0 && w.monitor === mon.name && w.name === String(w.id)).sort((a, b) => a.id - b.id);
        for (const w of mine) {
            let free = 1;
            while (used[free] || isReserved(free)) free++;
            if (free >= w.id) continue;
            const wins = clients.filter(c => c.workspace && c.workspace.id === w.id && c.address);
            if (wins.length === 0 && w.id !== active) continue;
            for (const c of wins) moveWindowTo(free, c.address, false);
            if (w.id === active) focusWorkspace(free);
            delete used[w.id];
            used[free] = true;
        }
    }

    // ------------------------------------------------------------- sign-ins
    // "log in with your browser" from a terminal, an app's oauth page, a link opened from chat:
    // when it shows up in a browser on another workspace, go there (once per page).
    // settings: followLogins.
    readonly property var loginWords: /\b(sign[\s-]?in|log[\s-]?in|login|sign[\s-]?up|authenticat\w*|authori[sz]\w*|verify|verification|two[\s-]factor|2fa|one[\s-]time|oauth|sso|single sign[\s-]on|device (code|activation)|choose an account|connect (your )?account)\b/i
    readonly property var browsers: /firefox|librewolf|zen|floorp|waterfox|chrom|brave|vivaldi|opera|edge|epiphany|qutebrowser|falkon|thorium|mullvad|torbrowser/i
    property var followed: ({})
    function consider(address: string, cls: string, title: string, urgent: bool) {
        if (!Config.s.followLogins) return;
        if (!urgent && !loginWords.test(title)) return;
        const key = address + "|" + (urgent ? "urgent" : title);
        if (followed[key] && Date.now() - followed[key] < 15000) return;
        followed[key] = Date.now();
        loginProc.address = address;
        loginProc.cls = cls;
        if (!loginProc.running) loginProc.running = true;
    }
    Process {
        id: loginProc
        property string address: ""
        property string cls: ""
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list;
                try { list = JSON.parse(text); } catch (e) { return; }
                const c = list.find(x => x.address === loginProc.address);
                if (!c || !root.browsers.test(c.class || loginProc.cls)) return;
                const here = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
                if (c.workspace && c.workspace.id !== here && c.workspace.id > 0) root.focusWindow(c.address);
            }
        }
    }

    // ------------------------------------------------------------- windows to other screens
    function moveWindowToMonitor(address: string, monitorName: string) {
        const m = Hyprland.monitors.values.find(x => x.name === monitorName);
        if (!m || !m.activeWorkspace) return;
        moveWindowTo(m.activeWorkspace.id, address, false);
    }
}
