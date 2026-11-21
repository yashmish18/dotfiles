pragma Singleton
import QtQuick
import Quickshell

// what's open right now. one pill panel and one full-screen overlay at most.
Singleton {
    id: root

    property string panel: ""      // "", control, notifications, calendar, media, launcher, clipboard, session, rename
    property string overlay: ""    // "", overview, wallpapers, cheatsheet
    property bool barVisible: true
    property string status: ""     // short message shown in the pill ("developing…")
    property bool recording: false // kk-record tells us over ipc

    readonly property bool anyOpen: panel !== "" || overlay !== ""

    function toggle(name: string) {
        overlay = "";
        panel = panel === name ? "" : name;
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
    }
}
