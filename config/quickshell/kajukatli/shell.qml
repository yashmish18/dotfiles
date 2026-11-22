//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// kajukatli — a desktop shell for hyprland.
// run:      qs -c kajukatli
// reload:   it reloads itself when you save a file here
// talk to:  qs -c kajukatli ipc show     (lists every command)

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.components
import qs.modules.wallpaper
import qs.modules.desktop
import qs.modules.bar
import qs.modules.settings
import qs.modules.notifications
import qs.modules.osd
import qs.modules.overlays
import qs.modules.lock

ShellRoot {
    id: shell

    // (loading parts by file path skipped quickshell's module setup, so every part with a
    // sibling file failed. they're plain types again; every file is checked before release.)
    Wallpaper {}
    Desktop {}
    Bar {}
    SettingsWindow {}
    Popups {}
    Osd {}
    Overlay {}
    Lock { id: lock }
    // apply touchpad / keyboard / scale settings at login
    readonly property var systemService: System

    // make sure the folders the shell writes to exist
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/kajukatli" "${XDG_STATE_HOME:-$HOME/.local/state}/kajukatli" "${XDG_CACHE_HOME:-$HOME/.cache}/kajukatli"']
    }

    // battery saver: when unplugged, drop the expensive bits; restore them on ac
    Connections {
        target: Power
        function onOnBatteryChanged() {
            // shadows and blur are the expensive bits of the compositor
            if (Power.onBattery)
                Hypr.hyprEval('hl.config({ decoration = { shadow = { enabled = false }, blur = { enabled = false } } })');
            else
                Hypr.hyprEval('hl.config({ decoration = { shadow = { enabled = true }, blur = { enabled = true } } })');
        }
    }

    // ------------------------------------------------------------- shortcuts
    // bound in hyprland as hl.dsp.global("kajukatli:<name>")
    // every shell action, by name. hyprland's binds reach these through `qs ipc call shell
    // run <name>` (see hypr/modules/vars.lua), which works however hyprland was set up;
    // the global shortcuts below are the same actions for anything that prefers those.
    function run(name: string) {
        switch (name) {
        case "launcher": Ui.toggle("launcher"); break;
        case "control": Ui.toggle("control"); break;
        case "settings": Ui.toggle("settings"); break;
        case "notifications": Ui.toggle("notifications"); break;
        case "clipboard": Ui.toggle("clipboard"); break;
        case "session": Ui.toggle("session"); break;
        case "wallpapers": Ui.toggleOverlay("wallpapers"); break;
        case "overview": Ui.toggleOverlay("overview"); break;
        case "cheatsheet": Ui.toggleOverlay("cheatsheet"); break;
        case "bar": Ui.barVisible = !Ui.barVisible; break;
        case "ws_next": Hypr.step(1); break;
        case "ws_prev": Hypr.step(-1); break;
        case "ws_new": Hypr.newWorkspace(false); break;
        case "ws_new_move": Hypr.newWorkspace(true); break;
        case "ws_rename": Ui.open("rename"); break;
        case "brightness_up": Bright.up(); break;
        case "brightness_down": Bright.down(); break;
        case "close": Ui.closeAll(); break;
        case "edit": Ui.panel = ""; Ui.editing = !Ui.editing; break;
        case "look_next": {
            const n = Looks.names;
            Looks.apply(n[(n.indexOf(Config.s.look) + 1) % n.length]);
            break;
        }
        }
    }

    Variants {
        model: ["launcher", "control", "settings", "notifications", "clipboard", "session", "wallpapers",
                "overview", "cheatsheet", "bar", "ws_next", "ws_prev", "ws_new", "ws_new_move", "ws_rename",
                "brightness_up", "brightness_down", "close", "edit", "look_next"]
        GlobalShortcut {
            required property var modelData
            appid: "kajukatli"
            name: modelData
            onPressed: shell.run(modelData)
        }
    }

    // ------------------------------------------------------------- ipc
    IpcHandler {
        target: "shell"
        function toggle(panel: string): void { Ui.toggle(panel); }
        function run(name: string): void { shell.run(name); }
        function settings(page: string): void { Ui.settings(page); }
        function overlay(name: string): void { Ui.toggleOverlay(name); }
        function close(): void { Ui.closeAll(); }
        function recording(on: bool): void { Ui.recording = on; }
        function status(text: string): void { Ui.status = text; }
        function dnd(on: bool): void { Notifs.dnd = on; }
        function look(name: string): string { return Looks.apply(name) ? "ok" : "no such look. try: " + Looks.names.join(" "); }
        function looks(): string { return Looks.names.join(" "); }
        function edit(): void { Ui.panel = ""; Ui.editing = !Ui.editing; }
    }
}
