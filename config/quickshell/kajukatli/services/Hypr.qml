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
            if (n === "fullscreen") root.fullscreen = data.trim() === "1";
            else if (n === "workspace" || n === "workspacev2") root.fullscreen = false;
            if (n.startsWith("workspace") || n.startsWith("createworkspace") || n.startsWith("destroyworkspace")
                || n.startsWith("focusedmon") || n.startsWith("moveworkspace") || n.startsWith("openwindow")
                || n.startsWith("closewindow") || n.startsWith("movewindow"))
                again.restart();
        }
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

    function firstFreeId(): int {
        const used = {};
        const all = Hyprland.workspaces.values;
        for (let i = 0; i < all.length; i++)
            used[all[i].id] = true;
        let id = 1;
        while (used[id])
            id++;
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
                focusWorkspace(firstFreeId());
        } else if (idx > 0) {
            focusWorkspace(list[idx - 1].id);
        }
    }

    function newWorkspace(moveWindow: bool) {
        const id = firstFreeId();
        if (moveWindow && Hyprland.activeToplevel)
            moveWindowTo(id, "", true);
        else
            focusWorkspace(id);
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
        onTriggered: if (Config.s.compactWorkspaces && !snapProc.running) snapProc.running = true
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
            while (used[free]) free++;
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
