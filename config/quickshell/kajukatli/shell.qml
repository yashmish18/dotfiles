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
import qs.modules.wallpaper
import qs.modules.bar
import qs.modules.notifications
import qs.modules.osd
import qs.modules.overlays
import qs.modules.lock
import qs.modules.widgets

ShellRoot {
    id: shell

    Wallpaper {}
    Bar {}
    Popups {}
    Osd {}
    Overlay {}
    Lock { id: lock }
    DesktopWidget {}

    // make sure the folders the shell writes to exist
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/kajukatli" "${XDG_STATE_HOME:-$HOME/.local/state}/kajukatli" "${XDG_CACHE_HOME:-$HOME/.cache}/kajukatli"']
    }

    // battery saver: when unplugged, drop the expensive bits; restore them on ac
    Connections {
        target: Power
        function onOnBatteryChanged() {
            if (Power.onBattery)
                Hypr.hyprEval('hl.config({ decoration = { shadow = { enabled = false } } })');
            else
                Hypr.hyprEval('hl.config({ decoration = { shadow = { enabled = true } } })');
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

    // ------------------------------------------------------------- ipc
    IpcHandler {
        target: "shell"
        function toggle(panel: string): void { Ui.toggle(panel); }
        function overlay(name: string): void { Ui.toggleOverlay(name); }
        function close(): void { Ui.closeAll(); }
        function recording(on: bool): void { Ui.recording = on; }
        function status(text: string): void { Ui.status = text; }
        function dnd(on: bool): void { Notifs.dnd = on; }
    }
}
