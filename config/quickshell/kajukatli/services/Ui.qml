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
    property string status: ""     // short message shown in the bar ("developing…")
    property bool recording: false // kk-record tells us over ipc

    readonly property bool anyOpen: panel !== "" || overlay !== ""
    // room the bar takes at the top edge, for toasts and the osd to sit under it
    readonly property int topInset: barVisible && Config.s.barStyle !== "none" && Config.s.barStyle !== "rail" && Config.s.barPosition === "top" ? Theme.barHeight + 6 : 0

    function toggle(name: string) {
        overlay = "";
        if (panel !== name) panelX = -1;
        panel = panel === name ? "" : name;
    }
    // open a panel hanging under (or beside) the thing that was clicked
    function toggleAt(name: string, x: real) {
        overlay = "";
        if (panel === name) { panel = ""; return; }
        panelX = x;
        panel = name;
    }
    function open(name: string) {
        overlay = "";
        panel = name;
    }
    function toggleOverlay(name: string) {
        panel = "";
        overlay = overlay === name ? "" : name;
    }
    function closeAll() {
        panel = "";
        overlay = "";
        editing = false;
    }
}
