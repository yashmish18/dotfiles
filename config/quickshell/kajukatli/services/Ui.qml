pragma Singleton
import QtQuick
import Quickshell

// what's open right now. one bar panel and one full-screen overlay at most.
Singleton {
    id: root

    property string panel: ""      // "", control, settings, notifications, calendar, media, launcher, clipboard, session, rename
    property string overlay: ""    // "", overview, wallpapers, cheatsheet
    property real panelX: -1       // screen x the panel should hang from (-1 = centre)
    property bool barVisible: true
    property bool editing: false   // desktop widgets can be dragged around
    property bool dragging: false  // a widget is being dragged right now
    property string controlPage: "" // open the control center straight on a page: wifi, bluetooth, sound
    property bool settingsOpen: false   // the settings window
    property string settingsPage: ""    // which page it opens on
    property string status: ""     // short message shown in the bar ("developing…")
    property bool recording: false // kk-record tells us over ipc
    // focus: the bar and the widgets step away, notifications wait, the wallpaper dims
    property bool focusMode: false
    function toggleFocus() {
        focusMode = !focusMode;
        Sounds.play(focusMode ? "focus" : "unfocus", 0);
    }

    readonly property bool anyOpen: panel !== "" || overlay !== ""
    // room the bar takes at the top edge, for toasts and the osd to sit under it
    readonly property int topInset: barVisible && Config.s.barStyle !== "none" && Config.s.barStyle !== "rail" && Config.s.barPosition === "top" ? Theme.barHeight + 6 : 0

    function toggle(name: string) {
        if (name === "settings") { panel = ""; settingsPage = ""; settingsOpen = !settingsOpen; return; }
        overlay = "";
        if (panel !== name) panelX = -1;
        panel = panel === name ? "" : name;
    }
    // open a panel hanging under (or beside) the thing that was clicked
    function toggleAt(name: string, x: real) {
        if (name === "settings") { toggle(name); return; }
        overlay = "";
        if (panel === name) { panel = ""; return; }
        panelX = x;
        panel = name;
    }
    function open(name: string) {
        if (name === "settings") { panel = ""; settingsOpen = true; return; }
        overlay = "";
        panel = name;
    }
    function toggleOverlay(name: string) {
        panel = "";
        overlay = overlay === name ? "" : name;
    }
    // open the settings window on a page: "wallpaper", "display", "input"…
    function settings(page: string) {
        panel = "";
        settingsPage = page;
        settingsOpen = true;
    }
    function closeAll() {
        panel = "";
        overlay = "";
        editing = false;
    }
}
