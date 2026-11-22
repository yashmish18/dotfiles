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
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    // the shell calls its helpers by full path: a session started before ~/.local/bin was
    // on PATH must not break wallpapers, the lock or stats
    readonly property string bin: home + "/.local/bin/"
    readonly property string wallpaperDir: adapter.wallpaperDir.replace(/^~/, home)
    property bool loaded: false

    // a settings file from an older version keeps the old defaults it saved. bring those
    // forward once (only things whose meaning changed, never your own choices)
    function migrate() {
        if (adapter.configVersion >= 5) return;
        // 5: the clock decides for itself, per wallpaper: face, spot and colour
        adapter.clockStyle = "auto";
        adapter.clockColor = "auto";
        // 4: the wallpaper ai runs on battery too (the clock behind the subject, the 3d
        //    parallax and the auto clock all need it, and laptops are mostly unplugged)
        adapter.aiOnBattery = true;
        adapter.clockDepth = true;
        adapter.parallax = true;
        adapter.transition = "ink";
        adapter.transitionMs = 4200;
        const l = Object.assign({}, adapter.layout || {});
        l.clock = Object.assign({}, l.clock || {}, { auto: true });
        adapter.layout = l;
        adapter.configVersion = 5;
    }

    // where a desktop widget sits, as a fraction of the room it has to move in (0..1 each way)
    function pos(name: string, fallback: var): var {
        const l = adapter.layout || {};
        return l[name] || fallback || ({ x: 0.5, y: 0.5 });
    }
    function setPos(name: string, x: real, y: real) {
        const l = Object.assign({}, adapter.layout || {});
        const was = l[name] || {};
        l[name] = Object.assign({}, was, { x: Math.round(x * 1000) / 1000, y: Math.round(y * 1000) / 1000 });
        delete l[name].auto;      // you put it somewhere yourself: that's where it stays
        adapter.layout = l;
    }
    // let the shell pick the spot (the clock: right behind the wallpaper's subject)
    function setAuto(name: string) {
        const l = Object.assign({}, adapter.layout || {});
        l[name] = Object.assign({}, l[name] || pos(name, null), { auto: true });
        adapter.layout = l;
    }
    function setScale(name: string, s: real) {
        const l = Object.assign({}, adapter.layout || {});
        const was = l[name] || pos(name, null);
        l[name] = Object.assign({}, was, { s: Math.round(s * 100) / 100 });
        adapter.layout = l;
    }
    // back to where the look put it (or the widget's own default), at its normal size
    function resetWidget(name: string) {
        const l = Object.assign({}, adapter.layout || {});
        const look = Looks.presets[adapter.look];
        if (look && look.layout && look.layout[name]) l[name] = Object.assign({}, look.layout[name]);
        else delete l[name];
        adapter.layout = l;
    }
    function resetLayout() {
        const look = Looks.presets[adapter.look];
        adapter.layout = look && look.layout ? Object.assign({}, look.layout) : ({});
        adapter.clockScale = look && look.clockScale ? look.clockScale : 1.0;
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/kajukatli/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        blockLoading: true
        onAdapterUpdated: if (root.loaded) writeAdapter()
        onLoaded: { root.loaded = true; root.migrate(); }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            root.loaded = true;
        }

        JsonAdapter {
            id: adapter

            property int configVersion: 5           // settings written by older versions get updated once

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
            property string clockStyle: "auto"      // stack | hero | serif | line | day | date | off
            property bool clockDepth: true          // tuck the clock behind the wallpaper's subject
            property string clockFont: "Syne"       // any installed family; each look sets its own
            property string clockColor: "auto"     // auto: light or dark ink, whichever reads on the picture under it · theme
            property bool clockPulse: true          // the clock swells a little on the beat while music plays
            property real clockScale: 0.8
            property string visualizer: "off"      // off | wave | bars | mirror
            property bool visualizerBehind: true
            property int visualizerBars: 48
            property bool showCalendar: false
            property string mediaWidget: "card"     // off | card | lyrics | portrait (shown while music plays)
            property bool showStats: false
            property bool showWeather: false
            property bool showBattery: false
            property bool showAnalog: false
            property bool showNote: false
            property bool showTimer: false
            property int timerMinutes: 25
            property int timerBreak: 5
            property bool weatherFx: true           // rain / snow over the wallpaper when it's raining / snowing outside
            property bool musicTint: true           // while music plays, the accent takes the album art's colour
            property bool hotCorners: true          // top left: overview · bottom right: the desktop
            property string wallRotate: "off"       // off | hourly | daily: a new wallpaper by itself
            property string noteText: ""
            property var layout: ({ clock: { x: 0.05, y: 0.1, auto: true }, media: { x: 0.5, y: 0.97 } })   // where widgets sit: drag them, ctrl + scroll to resize

            // ---------------------------------------------------- dock
            property bool dock: true
            property bool dockAutoHide: true
            property bool dockMedia: true
            property var dockPinned: ["kitty", "firefox", "org.gnome.Nautilus"]

            // ---------------------------------------------------- data
            property string weatherLocation: ""     // a city name. "" = guess from your ip (wttr.in)
            property string tempUnit: "c"           // c | f
            property bool sounds: true              // little sounds for volume, notifications, lock…
            property real soundVolume: 0.6
            property bool lyrics: true              // fetch synced lyrics from lrclib.net

            // ---------------------------------------------------- wallpaper
            property string wallpaperDir: "~/Pictures/wallpapers"
            property bool parallax: true            // depth parallax on workspace switch
            property bool cursorParallax: true      // also follow the cursor over the bare desktop
            property real parallaxStrength: 1.0     // 0.2 … 2.0
            property string transition: "ink"      // ink (bleeds in; draws the subject's outline when known) · fade · none
            property int transitionMs: 4200         // length of the ink transition (trace, then ink)
            property bool aiOnBattery: true         // run the wallpaper ai unplugged too (else it waits for ac)
            property string subjectModel: "isnet-anime"   // birefnet-general-lite for photos
            property bool videoOnBattery: false     // live wallpapers freeze to a still on battery

            // ---------------------------------------------------- system
            property bool autoPowerProfile: true    // power-saver on battery, balanced on ac
            property bool batterySaver: true        // unplugged: 60 hz, lighter blur, no shadows, no visualizer
            property int chargeLimit: 100           // stop charging here (80 keeps the battery young); 100 = off
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
            property bool nightLightAuto: false     // warm from nightLightFrom to nightLightTo
            property string nightLightFrom: "19:30"
            property string nightLightTo: "06:30"
            property bool lockPoetry: true
            property int notificationTimeout: 5000
        }
    }
}
