pragma Singleton
import QtQuick
import Quickshell

// looks: whole-desktop presets. each one is only a bundle of settings, so after applying
// one you can still change any single thing (settings → looks, or settings.json).
//
//   studio    three pills up top (workspaces · time · control center), a quiet clock
//   tide      floating top pill, a huge stacked clock behind the subject, a sea of a waveform
//   ronin     a thin rail on the left, a big date in the corner, a small player card
//   komorebi  top pill, a heavy clock tucked behind the subject, a calendar, the dock
//   currents  bottom bar, weather + day + time stacked top-left, calendar and a lyrics card
//   dreamer   three islands up top, a long time-and-date line, system stats, a tall player
//   grove     no bar at all, just a serif clock behind the subject and the dock
//   print     the original kajukatli: black & white, one muted accent, a single full bar
Singleton {
    id: root

    readonly property var names: ["studio", "tide", "ronin", "komorebi", "currents", "dreamer", "grove", "print"]

    readonly property var blurbs: ({
        studio: "three pills · a quiet clock top-left · dock",
        tide: "top pill · stacked clock behind the subject · wave",
        ronin: "left rail · big date · player card",
        komorebi: "top pill · heavy clock · calendar · dock",
        currents: "bottom bar · weather & day · calendar · lyrics",
        dreamer: "islands · time line · stats · tall player",
        grove: "no bar · serif clock · dock",
        print: "the original: black & white, one accent"
    })

    readonly property var presets: ({
        studio: {
            themeScheme: "vibrant", radius: 14,
            barStyle: "islands", barPosition: "top", workspaceStyle: "dots",
            barModules: { left: ["workspaces"], center: ["clock", "notifs"], right: ["apps", "phone", "tray", "control"] },
            clockStyle: "hero", clockDepth: true, clockFont: "Syne", clockScale: 0.8,
            visualizer: "off", visualizerBehind: false, visualizerBars: 48,
            showCalendar: false, mediaWidget: "card", showStats: false,
            dock: true, dockAutoHide: true, dockMedia: true,
            layout: { clock: { x: 0.05, y: 0.1 }, media: { x: 0.5, y: 0.97 } }
        },
        tide: {
            themeScheme: "vibrant", radius: 14,
            barStyle: "pill", barPosition: "top", workspaceStyle: "dots",
            barModules: { left: ["logo", "workspaces"], center: ["media", "visualizer", "clock", "weather"], right: ["apps", "phone", "tray", "brightness", "volume", "network", "battery", "power"] },
            clockStyle: "stack", clockDepth: true, clockFont: "Unbounded", clockScale: 1.0,
            visualizer: "wave", visualizerBehind: true, visualizerBars: 56,
            showCalendar: false, mediaWidget: "card", showStats: false,
            dock: true, dockAutoHide: true, dockMedia: true,
            layout: { clock: { x: 0.5, y: 0.16 } }
        },
        ronin: {
            themeScheme: "tonal", radius: 10,
            barStyle: "rail", barPosition: "top", workspaceStyle: "dots",
            barModules: { left: ["logo", "workspaces"], center: ["media"], right: ["apps", "phone", "tray", "volume", "bluetooth", "network", "clock", "battery", "power"] },
            clockStyle: "date", clockDepth: false, clockFont: "Anton", clockScale: 1.0,
            visualizer: "bars", visualizerBehind: false, visualizerBars: 64,
            showCalendar: false, mediaWidget: "card", showStats: false,
            dock: false, dockAutoHide: true, dockMedia: true,
            layout: { clock: { x: 0.94, y: 0.16 }, bars: { x: 0.92, y: 0.03 }, media: { x: 0.47, y: 0.97 } }
        },
        komorebi: {
            themeScheme: "vibrant", radius: 16,
            barStyle: "pill", barPosition: "top", workspaceStyle: "numbers",
            barModules: { left: ["logo", "temp", "notifs", "workspaces"], center: ["volume", "clock", "weather"], right: ["apps", "phone", "brightness", "battery", "network", "power"] },
            clockStyle: "hero", clockDepth: true, clockFont: "Syne", clockScale: 1.0,
            visualizer: "off", visualizerBehind: false, visualizerBars: 48,
            showCalendar: true, mediaWidget: "card", showStats: false,
            dock: true, dockAutoHide: true, dockMedia: true,
            layout: { clock: { x: 0.6, y: 0.08 }, calendar: { x: 0.3, y: 0.62 } }
        },
        currents: {
            themeScheme: "vibrant", radius: 12,
            barStyle: "bar", barPosition: "bottom", workspaceStyle: "diamonds",
            barModules: { left: ["logo", "workspaces", "notifs", "cpu", "mem", "volume"], center: ["clock", "weather", "media", "visualizer"], right: ["apps", "phone", "brightness", "network", "bluetooth", "temp", "battery", "power"] },
            clockStyle: "day", clockDepth: false, clockFont: "Bricolage Grotesque", clockScale: 1.0,
            visualizer: "off", visualizerBehind: false, visualizerBars: 48,
            showCalendar: true, mediaWidget: "lyrics", showStats: false,
            dock: false, dockAutoHide: true, dockMedia: true,
            layout: { clock: { x: 0.03, y: 0.05 }, calendar: { x: 0.015, y: 0.93 }, media: { x: 0.97, y: 0.04 } }
        },
        dreamer: {
            themeScheme: "tonal", radius: 12,
            barStyle: "islands", barPosition: "top", workspaceStyle: "numbers",
            barModules: { left: ["logo", "temp", "notifs", "workspaces"], center: ["clock", "weather", "volume", "battery"], right: ["apps", "phone", "brightness", "network", "mem", "power"] },
            clockStyle: "line", clockDepth: true, clockFont: "Bricolage Grotesque", clockScale: 1.0,
            visualizer: "off", visualizerBehind: false, visualizerBars: 48,
            showCalendar: false, mediaWidget: "portrait", showStats: true,
            dock: true, dockAutoHide: true, dockMedia: true,
            layout: { clock: { x: 0.03, y: 0.08 }, stats: { x: 0.02, y: 0.78 }, media: { x: 0.53, y: 0.9 } }
        },
        grove: {
            themeScheme: "vibrant", radius: 14,
            barStyle: "none", barPosition: "top", workspaceStyle: "dots",
            barModules: { left: ["logo", "workspaces"], center: ["clock"], right: ["apps", "phone", "volume", "network", "battery", "power"] },
            clockStyle: "serif", clockDepth: true, clockFont: "Fraunces", clockScale: 1.0,
            visualizer: "off", visualizerBehind: false, visualizerBars: 48,
            showCalendar: false, mediaWidget: "card", showStats: false,
            dock: true, dockAutoHide: false, dockMedia: true,
            layout: { clock: { x: 0.04, y: 0.06 } }
        },
        print: {
            themeScheme: "mono", radius: 6,
            barStyle: "bar", barPosition: "top", workspaceStyle: "numbers",
            barModules: { left: ["workspaces", "media"], center: ["clock"], right: ["apps", "phone", "tray", "volume", "network", "battery", "notifs"] },
            clockStyle: "line", clockDepth: false, clockFont: "Instrument Serif", clockScale: 0.6,
            visualizer: "off", visualizerBehind: false, visualizerBars: 32,
            showCalendar: false, mediaWidget: "card", showStats: false,
            dock: false, dockAutoHide: true, dockMedia: false,
            layout: { clock: { x: 0.03, y: 0.94 } }
        }
    })

    function apply(name: string) {
        const p = presets[name];
        if (!p) return false;
        const schemeBefore = Config.s.themeScheme;
        for (const k in p) {
            if (k === "layout") Config.s.layout = Object.assign({}, p.layout);
            else Config.s[k] = p[k];
        }
        Config.s.look = name;
        Ui.barVisible = p.barStyle !== "none";
        // kk-theme reads the scheme from settings.json; give the file a moment to land
        if (p.themeScheme !== schemeBefore) rethemeTimer.restart();
        return true;
    }

    function retheme() { rethemeTimer.restart(); }

    Timer {
        id: rethemeTimer
        interval: 400
        onTriggered: Quickshell.execDetached([Config.bin + "kk-theme", "--reapply"])
    }
}
