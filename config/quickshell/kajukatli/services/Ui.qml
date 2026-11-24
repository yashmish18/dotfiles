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
    property string overlayQuery: ""
    property var projectionMode: ""
    // a privileged action is waiting for your password: the full-screen overlays step aside so
    // the password prompt (an ordinary window, under them) can be seen and typed into
    property bool authWaiting: false
    // right-click on a desktop widget: which one, where, and on which screen's layer
    property string widgetMenu: ""
    property real widgetMenuX: 0
    property real widgetMenuY: 0
    property var widgetMenuOwner: null
    // right-click on the bar: ask the bar on the focused screen to open its menu at x
    signal barMenu(real x)
    // focus: the bar and the widgets step away, notifications wait, the wallpaper dims
    property bool focusMode: false
    function toggleFocus() {
        focusMode = !focusMode;
        Sounds.play(focusMode ? "focus" : "unfocus", 0);
    }

    // Closing a window that still has a text field focused makes Qt's wayland text-input code
    // trip over the dead surface ("Trying to disable X but Y is focused", the last line of the
    // shell's logs before it died). So a closed overlay / emoji picker keeps its (empty,
    // unfocused) window alive for a moment and is destroyed only after the focus has moved on.
    property bool overlayLinger: false
    property bool emojiLinger: false
    onOverlayChanged: { overlayLinger = overlay === "" ; if (overlay === "") lingerTimer.restart(); }
    onEmojiOpenChanged: { emojiLinger = !emojiOpen; if (!emojiOpen) lingerTimer.restart(); }
    Timer { id: lingerTimer; interval: 350; onTriggered: { root.overlayLinger = false; root.emojiLinger = false; } }

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
    // super + tab while the overview is open: step along instead of closing it
    signal overviewCycle(int dir)
    function overview(dir: int) {
        if (overlay === "overview") overviewCycle(dir);
        else { panel = ""; overlay = "overview"; }
    }
    function toggleOverlay(name: string) {
        panel = "";
        overlay = overlay === name ? "" : name;
    }
    // the emoji picker is its own small window in the bottom-left corner (EmojiPicker.qml)
    property bool emojiOpen: false
    function openEmoji() {
        panel = "";
        overlay = "";
        emojiOpen = !emojiOpen;
    }
    function openProjection() {
        panel = "";
        overlay = "projection";
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
        emojiOpen = false;
        editing = false;
    }
}
