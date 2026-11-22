pragma Singleton
import QtQuick
import Quickshell
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
            if (n === "monitoradded" || n === "monitoraddedv2") {
                monitorHotplug.restart();
            }
            if (n === "fullscreen") root.fullscreen = (ev.data || "").trim() === "1";
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
        onTriggered: Quickshell.execDetached(["sh", "-c", "sleep 0.2; exec " + Config.bin + "kk-display extend"])
    }

    // something is fullscreen (a video, a game): notifications wait until it isn't
    property bool fullscreen: false

    readonly property var focusedWs: Hyprland.focusedWorkspace
    readonly property int focusedId: focusedWs ? focusedWs.id : 1

    // normal (positive id) workspaces on a monitor, sorted
    function workspacesOn(monitor): var {
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

    function luaStr(s): string {
        return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }

    function focusWorkspace(id) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + luaStr(id) + " })");
        else
            Hyprland.dispatch("workspace " + id);
    }

    function moveWindowTo(id, address, follow) {
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

    function focusWindow(address) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({ window = " + luaStr("address:" + address) + " })");
        else
            Hyprland.dispatch("focuswindow address:" + address);
    }

    function closeWindow(address) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.window.close({ window = " + luaStr("address:" + address) + " })");
        else
            Hyprland.dispatch("closewindow address:" + address);
    }

    function renameWorkspace(id, name) {
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
}
