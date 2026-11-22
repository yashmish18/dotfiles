pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// user settings: ~/.config/kajukatli/settings.json (created with defaults on first run).
// edit the file by hand or from the shell; both stay in sync.
// a "look" (Looks.qml) is just a bundle of these values applied at once.
Singleton {
    id: root

    readonly property alias s: adapter
    readonly property string home: Quickshell.env("HOME")
    // the shell calls its helpers by full path: a session started before ~/.local/bin was
    // on PATH must not break wallpapers, the lock or stats
    readonly property string bin: home + "/.local/bin/"
    readonly property string wallpaperDir: adapter.wallpaperDir.replace(/^~/, home)
    property bool loaded: false

    // where a desktop widget sits, as a fraction of the room it has to move in (0..1 each way)
    function pos(name: string, fallback: var): var {
        const l = adapter.layout || {};
        return l[name] || fallback || ({ x: 0.5, y: 0.5 });
    }
    function setPos(name: string, x: real, y: real) {
        const l = Object.assign({}, adapter.layout || {});
        l[name] = { x: Math.round(x * 1000) / 1000, y: Math.round(y * 1000) / 1000 };
        adapter.layout = l;
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/kajukatli/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.loaded = true
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            root.loaded = true;
        }

        JsonAdapter {
            id: adapter

            // ---------------------------------------------------- look
            property string look: "studio"          // the preset last applied (see Looks.qml)
            property string themeScheme: "vibrant"  // vibrant | tonal | mono
            property string themeMode: "dark"       // dark | light | auto
            property int radius: 14

            // ---------------------------------------------------- bar
            property string barStyle: "islands"     // islands | pill | bar | rail | none
            property string barPosition: "top"      // top | bottom (pill, bar, islands)
            property string workspaceStyle: "dots"  // dots | diamonds | numbers
            property string barLogo: ""             // "" = the shell's mark. any text works (力 needs cjk fonts)
            property var barModules: ({
                left: ["workspaces"],
                center: ["clock", "notifs"],
                right: ["tray", "control"]
            })

            // ---------------------------------------------------- desktop
            property string clockStyle: "hero"      // stack | hero | serif | line | day | date | off
            property bool clockDepth: true          // tuck the clock behind the wallpaper's subject
            property string clockFont: "Syne"       // any installed family; each look sets its own
            property real clockScale: 0.8
            property string visualizer: "off"      // off | wave | bars | mirror
            property bool visualizerBehind: true
            property int visualizerBars: 48
            property bool showCalendar: false
            property string mediaWidget: "off"      // off | lyrics | card | portrait
            property bool showStats: false
            property var layout: ({ clock: { x: 0.05, y: 0.1 } })   // widget positions (settings → desktop, or drag them)

            // ---------------------------------------------------- dock
            property bool dock: true
            property bool dockAutoHide: true
            property bool dockMedia: true
            property var dockPinned: ["kitty", "firefox", "org.gnome.Nautilus"]

            // ---------------------------------------------------- data
            property string weatherLocation: ""     // a city name. "" = guess from your ip (wttr.in)
            property string tempUnit: "c"           // c | f
            property bool lyrics: true              // fetch synced lyrics from lrclib.net

            // ---------------------------------------------------- wallpaper
            property string wallpaperDir: "~/Pictures/wallpapers"
            property bool parallax: true            // depth parallax on workspace switch
            property bool cursorParallax: true      // also follow the cursor over the bare desktop
            property real parallaxStrength: 1.0     // 0.2 … 2.0
            property string transition: "fade"     // fade (0.4 s) · ink (the drawn outline, needs the ai) · none
            property int transitionMs: 2200         // length of the ink transition
            property bool aiOnBattery: false        // run the wallpaper ai unplugged too (else it waits for ac)
            property string subjectModel: "isnet-anime"   // birefnet-general-lite for photos
            property bool videoOnBattery: false     // live wallpapers freeze to a still on battery

            // ---------------------------------------------------- system
            property bool autoPowerProfile: true    // power-saver on battery, balanced on ac
            property bool clock24h: true
            property bool naturalScroll: true
            property bool tapToClick: true
            property bool disableWhileTyping: true
            property bool clickFinger: true          // two-finger click = right click
            property real scrollFactor: 0.6
            property real pointerSpeed: 0.0          // -1 … 1
            property string kbLayout: "us"
            property int repeatRate: 35
            property int repeatDelay: 280
            property var monitorScales: ({})         // { "eDP-1": 1.0 } — everything is 100% unless you say
            property int nightLightTemp: 4200
            property bool lockPoetry: true
            property int notificationTimeout: 5000
        }
    }
}
