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

ShellRoot {
    id: shell

    // each part loads on its own: if one file has a mistake, only that part is missing and
    // the error goes to the log (qs log -c kajukatli). the rest of the desktop still runs.
    component Part: LazyLoader { active: true }
    Part { source: Qt.resolvedUrl("modules/wallpaper/Wallpaper.qml") }
    Part { source: Qt.resolvedUrl("modules/desktop/Desktop.qml") }
    Part { source: Qt.resolvedUrl("modules/bar/Bar.qml") }
    Part { source: Qt.resolvedUrl("modules/dock/Dock.qml") }
    Part { source: Qt.resolvedUrl("modules/settings/SettingsWindow.qml") }
    Part { source: Qt.resolvedUrl("modules/notifications/Popups.qml") }
    Part { source: Qt.resolvedUrl("modules/osd/Osd.qml") }
    Part { source: Qt.resolvedUrl("modules/overlays/Overlay.qml") }
    Part { source: Qt.resolvedUrl("modules/lock/Lock.qml") }
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
    component Shortcut: GlobalShortcut { appid: "kajukatli" }

    Shortcut { name: "launcher";      description: "open the launcher";        onPressed: Ui.toggle("launcher") }
    Shortcut { name: "control";       description: "control center";           onPressed: Ui.toggle("control") }
    Shortcut { name: "settings";      description: "desktop settings";         onPressed: Ui.toggle("settings") }
    Shortcut { name: "notifications"; description: "notifications";            onPressed: Ui.toggle("notifications") }
    Shortcut { name: "clipboard";     description: "clipboard history";        onPressed: Ui.toggle("clipboard") }
    Shortcut { name: "session";       description: "power menu";               onPressed: Ui.toggle("session") }
    Shortcut { name: "wallpapers";    description: "wallpaper picker";         onPressed: Ui.toggleOverlay("wallpapers") }
    Shortcut { name: "overview";      description: "workspace overview";       onPressed: Ui.toggleOverlay("overview") }
    Shortcut { name: "cheatsheet";    description: "keybind cheatsheet";       onPressed: Ui.toggleOverlay("cheatsheet") }
    Shortcut { name: "bar";           description: "hide or show the bar";     onPressed: Ui.barVisible = !Ui.barVisible }
    Shortcut { name: "ws_next";       description: "next workspace";           onPressed: Hypr.step(1) }
    Shortcut { name: "ws_prev";       description: "previous workspace";       onPressed: Hypr.step(-1) }
    Shortcut { name: "ws_new";        description: "new workspace";            onPressed: Hypr.newWorkspace(false) }
    Shortcut { name: "ws_new_move";   description: "window to new workspace";  onPressed: Hypr.newWorkspace(true) }
    Shortcut { name: "ws_rename";     description: "rename workspace";         onPressed: Ui.open("rename") }
    Shortcut { name: "brightness_up";   description: "brighter";               onPressed: Bright.up() }
    Shortcut { name: "brightness_down"; description: "dimmer";                 onPressed: Bright.down() }
    Shortcut { name: "close";         description: "close panels and overlays"; onPressed: Ui.closeAll() }
    Shortcut { name: "edit";          description: "arrange desktop widgets";  onPressed: { Ui.panel = ""; Ui.editing = !Ui.editing; } }
    Shortcut {
        name: "look_next"
        description: "next look"
        onPressed: {
            const n = Looks.names;
            Looks.apply(n[(n.indexOf(Config.s.look) + 1) % n.length]);
            Quickshell.execDetached(["notify-send", "-a", "looks", "-t", "1800", Config.s.look, Looks.blurbs[Config.s.look] || ""]);
        }
    }

    // ------------------------------------------------------------- ipc
    IpcHandler {
        target: "shell"
        function toggle(panel: string): void { Ui.toggle(panel); }
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
