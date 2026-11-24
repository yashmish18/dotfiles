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
        if (adapter.configVersion >= 9) return;
        // 9: wallpapers switch quickly (the ink took 4.2 s); how rounded the bars are is an amount, not on or off
        if (!adapter.visualizerRound) adapter.visualizerRoundness = 0;
        if (adapter.configVersion === 8) {
            if (adapter.transitionMs === 4200) adapter.transitionMs = 1600;
            adapter.configVersion = 9;
            return;
        }
        // 8: nautilus is the file manager again (7 had swapped it for thunar)
        if (adapter.configVersion === 7) {
            adapter.dockPinned = (adapter.dockPinned || []).map(x => x === "thunar" ? "org.gnome.Nautilus" : x);
            if (adapter.transitionMs === 4200) adapter.transitionMs = 1600;
            adapter.configVersion = 9;
            return;
        }
        // 7: kde connect and nm-applet no longer run in the background
        if (adapter.configVersion === 6) {
            adapter.backgroundAllowed = (adapter.backgroundAllowed || []).filter(x => !/kdeconnect|nm-applet/.test(x));
            if (adapter.transitionMs === 4200) adapter.transitionMs = 1600;
            adapter.configVersion = 9;
            return;
        }
        // 6: every running app is one tap away (apps), and the phone when kde connect is set up
        if (adapter.configVersion === 5) {
            const m = Object.assign({ left: [], center: [], right: [] }, adapter.barModules || {});
            const all = [].concat(m.left || [], m.center || [], m.right || []);
            const add = ["apps", "phone"].filter(x => all.indexOf(x) === -1);
            if (add.length) adapter.barModules = { left: m.left || [], center: m.center || [], right: add.concat(m.right || []) };
            adapter.transitionMs = 1600;
            adapter.configVersion = 9;
            return;
        }
        // 5: the clock decides for itself, per wallpaper: face, spot and colour
        adapter.clockStyle = "auto";
        adapter.clockColor = "auto";
        // 4: preserve battery life by keeping expensive wallpaper AI off on battery.
        adapter.aiOnBattery = false;
        adapter.clockDepth = true;
        adapter.parallax = true;
        adapter.transition = "ink";
        adapter.transitionMs = 1600;
        const l = Object.assign({}, adapter.layout || {});
        l.clock = Object.assign({}, l.clock || {}, { auto: true });
        adapter.layout = l;
        adapter.barModules = Object.assign({}, adapter.barModules || {}, { right: ["apps", "phone"].concat(((adapter.barModules || {}).right || []).filter(x => x !== "apps" && x !== "phone")) });
        adapter.configVersion = 9;
    }

    // 10: the ink spread is back at its full length, the clock decides for itself again (it goes
    // behind the wallpaper's subject), and the music bars are a little lower by default
    function migrate10() {
        if (adapter.configVersion >= 11) return;
        // 11: the music bars are low by default (8% of the screen)
        if (adapter.visualizerHeight > 0.09) adapter.visualizerHeight = 0.08;
        if (adapter.configVersion >= 10) { adapter.configVersion = 11; return; }
        if (adapter.transitionMs === 1600) adapter.transitionMs = 4200;
        adapter.clockDepth = true;
        const l = Object.assign({}, adapter.layout || {});
        l.clock = Object.assign({}, l.clock || {}, { auto: true });
        adapter.layout = l;
        adapter.configVersion = 11;
    }
    Timer { id: saveSoon; interval: 250; onTriggered: file.writeAdapter() }

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
        const was = l[name] || (name === "clock" ? { x: 0.5, y: 0.15, auto: true } : pos(name, null));
        l[name] = Object.assign({}, was, { s: Math.round(s * 100) / 100 });
        adapter.layout = l;
    }
    // back to where the look put it (or the widget's own default), at its normal size
    function resetWidget(name: string) {
        const l = Object.assign({}, adapter.layout || {});
        const look = Looks.presets[adapter.look];
        if (look && look.layout && look.layout[name]) l[name] = Object.assign({}, look.layout[name]);
        else delete l[name];
        // the clock goes back to deciding for itself: right behind the wallpaper's subject
        if (name === "clock") l.clock = Object.assign({}, l.clock || {}, { auto: true });
        adapter.layout = l;
    }
    function resetLayout() {
        const look = Looks.presets[adapter.look];
        adapter.layout = look && look.layout ? Object.assign({}, look.layout) : ({});
        adapter.layout = Object.assign({}, adapter.layout, { clock: Object.assign({}, adapter.layout.clock || {}, { auto: true }) });
        adapter.clockScale = look && look.clockScale ? look.clockScale : 1.0;
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/kajukatli/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        blockLoading: true
        // one write for a burst of changes (applying a look sets a dozen settings at once:
        // a file write, a file-watch reload and another write for each was what made switching stutter)
        onAdapterUpdated: if (root.loaded) saveSoon.restart()
        onLoaded: { root.loaded = true; root.migrate(); root.migrate10(); }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            root.loaded = true;
        }

        JsonAdapter {
            id: adapter

            property int configVersion: 11           // settings written by older versions get updated once

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
                right: ["apps", "phone", "tray", "control"]
            })

            // ---------------------------------------------------- desktop
            property string clockStyle: "auto"      // stack | hero | serif | line | day | date | off
            property bool clockDepth: true          // tuck the clock behind the wallpaper's subject
            property string clockFont: "Syne"       // any installed family; each look sets its own
            property string clockColor: "auto"     // auto: light or dark ink, whichever reads on the picture under it · theme
            property bool clockPulse: false         // unused: the clocks don't react to music (kept so old settings files load)
            property real clockScale: 0.8
            property string visualizer: "off"      // off | wave | bars | mirror
            property bool visualizerBehind: true
            property int visualizerBars: 48
            property string visualizerSpan: "auto"     // auto (wave across the screen, bars in a box) | full | widget
            property string visualizerEdge: "bottom"   // full width: bottom | top | middle
            property real visualizerHeight: 0.08      // full width: how tall, as a part of the screen
            property string visualizerColor: "wallpaper" // wallpaper | accent | album | rainbow
            property real visualizerOpacity: 0.6
            property int visualizerGap: 2             // pixels between bars
            property bool visualizerRound: true       // (old) rounded bar ends: read once into visualizerRoundness
            property real visualizerRoundness: 0.5    // 0 square bars … 1 fully rounded ends
            property int visualizerSmooth: 60         // ms each bar takes to follow the music
            // ------------------------------------------- what's kept, and for how long (kk-storage tidy)
            property int clipboardKeep: 30            // clipboard history: this many entries at most
            property bool clipboardClearAtLogin: true  // and none from the last session
            property int screenshotsDays: 0           // delete screenshots older than this (0 = keep)
            property int recordingsDays: 0            // same for screen recordings
            property int trashDays: 30                // empty what's been in the recycle bin this long
            property bool musicPulse: false           // the clock bounces on the bass
            property bool musicSparks: false          // sparks fly off the visualizer on every beat
            property bool musicGlow: false            // the screen edges glow in the album's colour on the beat
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
            property bool networkWeather: false      // opt in: wttr.in receives a location or IP
            property bool networkLyrics: false       // opt in: lrclib.net receives track metadata
            property string localLyricsDir: "~/Music/Lyrics"
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
            property bool aiOnBattery: false        // expensive wallpaper ai waits for ac on battery
            property string subjectModel: "isnet-anime"   // birefnet-general-lite for photos
            property bool videoOnBattery: false     // live wallpapers freeze to a still on battery

            // ---------------------------------------------------- system
            property bool autoPowerProfile: true    // power-saver on battery, balanced on ac
            // what the battery saver does while unplugged: each one can be turned off on its own
            property bool saverParallax: true       // no pointer parallax on the wallpaper
            property bool saverAnimations: true     // no window animations
            property bool saverFun: true            // no beat glow or bouncing clock
            property int idleBatDim: 60             // seconds idle on battery before the screen dims (0 = never)
            property int idleBatOff: 120            // … before it turns off (0 = never)
            property int idleBatSuspend: 7          // minutes idle on battery before the machine sleeps (0 = never)
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
            property var monitorProfiles: ({})       // { "eDP-1": { scale, refresh, position } }
            property bool largeText: false
            property bool reducedMotion: false
            property bool highContrast: false
            property bool keyboardNavigation: true
            property int nightLightTemp: 4200
            property bool nightLightAuto: false     // warm from nightLightFrom to nightLightTo
            property string nightLightFrom: "19:30"
            property string nightLightTo: "06:30"
            property bool lockPoetry: true
            property int notificationTimeout: 5000

            // ---------------------------------------------------- behaviour
            property bool tileTapToggles: true      // unused: the icon always switches, the tile opens its page (kept so old settings load)
            property bool btAutoReconnect: true     // bluetooth on again: reconnect the devices that were connected before
            property bool compactWorkspaces: true   // close workspace 3 of 1·2·3·4 and 4 becomes 3: no gaps, nothing empty on the left
            property bool followLogins: true        // a sign-in page opens in a browser on another workspace: go there
            property bool trayTapMenu: true         // one tap on a tray icon opens everything that app offers
            property bool noBackgroundApps: false   // an app whose last window closes is asked to quit (unless allowed below)
            property var backgroundAllowed: ["blueman-applet", "easyeffects", "syncthing"]
            property var gpuApps: ["blender", "steam", "lutris", "heroic", "godot", "unity", "unityhub", "davinci-resolve", "resolve", "obs", "kdenlive", "krita", "minecraft-launcher", "prismlauncher", "bottles", "gamescope", "rpcs3", "pcsx2", "dolphin-emu", "yuzu", "ryujinx"]
            property string soundMode: "off"        // off | music | movie | voice | speakers | atmos (kk-sound)
            property string soundModeLast: "music"
            property bool gpuHint: true             // a heavy app (a game, blender…) started on the integrated gpu: offer to restart it on nvidia
        }
    }
}
