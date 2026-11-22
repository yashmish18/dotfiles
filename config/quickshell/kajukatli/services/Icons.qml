pragma Singleton
import QtQuick
import Quickshell

// the shell's icons: drawn line by line on a 24-unit grid with round ends, one stroke weight
// for all of them, so they sit together like one hand drew them. components/Icon.qml draws them.
//
// each entry: d (stroked), dim (stroked at 30%: the unlit part of a meter), solid (filled).
Singleton {
    id: root

    readonly property string cloudPath: "M7 15.5a4 4 0 0 1-.4-8 5.5 5.5 0 0 1 10.6 1.3 3.3 3.3 0 0 1 0 6.7z"
    readonly property var wifiArcs: ["M8.6 15.4a4.8 4.8 0 0 1 6.8 0", "M5.6 12.4a9 9 0 0 1 12.8 0", "M2.6 9.3a13.3 13.3 0 0 1 18.8 0"]
    readonly property string speakerPath: "M4 9.5h3.2l4.6-4v13l-4.6-4H4z"

    readonly property var table: ({
        // status
        "wifi-off": { d: "M12 19.2v.4 M8.6 15.4a4.8 4.8 0 0 1 3.9-1.4 M5.6 12.4a9 9 0 0 1 4-2.3 M2.6 9.3a13.3 13.3 0 0 1 4.2-2.8 M3.5 3.5l17 17" },
        "ethernet": { d: "M4.5 6h15v9.5h-15z M9 15.5v3.5h6v-3.5 M8 9v3 M11 9v3 M14 9v3 M17 9v3" },
        "bluetooth": { d: "M7 7.5l10 9-5 4.5V3l5 4.5-10 9" },
        "bluetooth-on": { d: "M7 7.5l10 9-5 4.5V3l5 4.5-10 9 M3.5 12h.01 M20.5 12h.01" },
        "bluetooth-off": { d: "M7 7.5l10 9-5 4.5V3l5 4.5-10 9 M3.5 3.5l17 17" },
        "bell": { d: "M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 1.5h-15z M10 20.5a2 2 0 0 0 4 0" },
        "bell-off": { d: "M6 16.5V11a6 6 0 0 1 9.3-5 M18 11v5.5l1.5 1.5H8 M10 20.5a2 2 0 0 0 4 0 M3.5 3.5l17 17" },
        "volume-mute": { d: speakerPath + " M16 9.5l5 5 M21 9.5l-5 5" },
        "mic": { d: "M9 5.5a3 3 0 0 1 6 0v5a3 3 0 0 1-6 0z M5.5 10.5a6.5 6.5 0 0 0 13 0 M12 17v3.5" },
        "mic-off": { d: "M9 5.5a3 3 0 0 1 6 0v5a3 3 0 0 1-6 0z M5.5 10.5a6.5 6.5 0 0 0 13 0 M12 17v3.5 M3.5 3.5l17 17" },
        "sun": { d: "M12 8.5a3.5 3.5 0 1 0 0 7a3.5 3.5 0 1 0 0-7 M12 2.5v2 M12 19.5v2 M4.6 4.6l1.4 1.4 M18 18l1.4 1.4 M2.5 12h2 M19.5 12h2 M4.6 19.4l1.4-1.4 M18 6l1.4-1.4" },
        "moon": { d: "M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z" },
        "night-light": { d: "M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5z M17 3v3.5 M15.25 4.75h3.5" },
        "bolt": { d: "M13 2.5L5 13.5h6l-1 8 8-11h-6z" },
        "power": { d: "M12 3v8 M6.4 6.6a8 8 0 1 0 11.2 0" },
        "lock": { d: "M6 11h12v9H6z M8.5 11V8a3.5 3.5 0 0 1 7 0v3" },
        "logout": { d: "M14 4.5h4.5v15H14 M10 8l-4 4 4 4 M6 12h9" },
        "restart": { d: "M19.5 12a7.5 7.5 0 1 1-2.2-5.3 M19.5 4.5v4h-4" },
        "coffee": { d: "M5 9h11v5a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5z M16 10.5h1.5a2.5 2.5 0 0 1 0 5H16 M9 3.5v2.5 M12.5 3.5v2.5" },
        "leaf": { d: "M5 19c0-8 5-13 14-14 0 9-5 14-13 14z M5 19l7-7" },
        "gauge": { d: "M4.5 16.5a7.5 7.5 0 1 1 15 0 M12 16.5l3.5-5 M4.5 16.5h1.5 M18 16.5h1.5" },
        "balance": { d: "M12 4v16 M8 20h8 M5 8h14 M5 8l-2.5 6a2.5 2.5 0 0 0 5 0z M19 8l-2.5 6a2.5 2.5 0 0 0 5 0z" },
        "dnd": { d: "M12 4a8 8 0 1 0 0 16a8 8 0 1 0 0-16 M8.5 12h7" },
        // media
        "play": { solid: "M8 5.5v13l10.5-6.5z" },
        "pause": { solid: "M7 5h3.5v14H7z M13.5 5H17v14h-3.5z" },
        "next": { solid: "M6 6l8.5 6L6 18z", d: "M17.5 6v12" },
        "prev": { solid: "M18 6l-8.5 6L18 18z", d: "M6.5 6v12" },
        "music": { d: "M9 17.5V6l10-2v11.5 M9 17.5a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0 M19 15.5a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0" },
        "shuffle": { d: "M4 7h3.5l9 10H20 M4 17h3.5l2.2-2.5 M14.3 9.5L16.5 7H20 M17.5 4.5L20 7l-2.5 2.5 M17.5 14.5L20 17l-2.5 2.5" },
        // things
        "calendar": { d: "M4.5 6.5h15v13h-15z M4.5 10.5h15 M8.5 4v4 M15.5 4v4" },
        "cpu": { d: "M7 7h10v10H7z M10 10h4v4h-4z M9.5 3v4 M14.5 3v4 M9.5 17v4 M14.5 17v4 M3 9.5h4 M3 14.5h4 M17 9.5h4 M17 14.5h4" },
        "memory": { d: "M3.5 7.5h17v8h-17z M7 15.5v3 M11 15.5v3 M15 15.5v3 M7 10.5v2 M11 10.5v2 M15 10.5v2" },
        "temp": { d: "M10 14.5V5a2 2 0 0 1 4 0v9.5a4 4 0 1 1-4 0z M12 10v7" },
        "fan": { d: "M10.5 12a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0-3 0 M12 10.5c0-4 1-7 4-7 2 0 2.5 3-1 5.5 M13.5 12c4 0 7 1 7 4 0 2-3 2.5-5.5-1 M12 13.5c0 4-1 7-4 7-2 0-2.5-3 1-5.5 M10.5 12c-4 0-7-1-7-4 0-2 3-2.5 5.5 1" },
        "disk": { d: "M4 15h16 M4 15l2.5-9h11l2.5 9v4H4z M16.5 17h.5" },
        "download": { d: "M12 4v11 M7.5 10.5L12 15l4.5-4.5 M5 19.5h14" },
        "upload": { d: "M12 15V4 M7.5 8.5L12 4l4.5 4.5 M5 19.5h14" },
        "search": { d: "M10.5 4a6.5 6.5 0 1 0 0 13a6.5 6.5 0 1 0 0-13 M15.5 15.5L20 20" },
        "image": { d: "M4 5.5h16v13H4z M4 15.5l4.5-4.5 4 4 2.5-2.5 5 5 M15 8.5a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0-2.4 0" },
        "sliders": { d: "M4 7h9 M17 7h3 M4 17h3 M11 17h9 M15 5v4 M9 15v4" },
        "palette": { d: "M12 3.5a8.5 8.5 0 1 0 0 17c1.2 0 1.8-.8 1.8-1.8 0-1.4-1.2-1.8-1.2-3.2 0-1 .8-1.7 1.8-1.7H17a3.5 3.5 0 0 0 3.5-3.5c0-3.8-3.8-6.8-8.5-6.8z M7.2 11.5a1 1 0 1 0 2 0a1 1 0 1 0-2 0 M10.2 7.8a1 1 0 1 0 2 0a1 1 0 1 0-2 0 M14.6 8.6a1 1 0 1 0 2 0a1 1 0 1 0-2 0" },
        "grid": { d: "M5 5h5v5H5z M14 5h5v5h-5z M5 14h5v5H5z M14 14h5v5h-5z" },
        "clipboard": { d: "M8 5H6.5v15h11V5H16 M9 3.5h6v3H9z" },
        "screenshot": { d: "M4 8V5.5A1.5 1.5 0 0 1 5.5 4H8 M16 4h2.5A1.5 1.5 0 0 1 20 5.5V8 M20 16v2.5a1.5 1.5 0 0 1-1.5 1.5H16 M8 20H5.5A1.5 1.5 0 0 1 4 18.5V16" },
        "record": { d: "M12 4a8 8 0 1 0 0 16a8 8 0 1 0 0-16", solid: "M12 8.5a3.5 3.5 0 1 0 0 7a3.5 3.5 0 1 0 0-7" },
        "move": { d: "M12 3v18 M3 12h18 M9 6l3-3 3 3 M9 18l3 3 3-3 M6 9l-3 3 3 3 M18 9l3 3-3 3" },
        "trash": { d: "M5 7h14 M9 7V4.5h6V7 M7 7l1 12.5h8L17 7" },
        "external": { d: "M14 4h6v6 M20 4l-9 9 M18 14v5H5V6h5" },
        "spark": { solid: "M12 2.5c.9 4.9 4.6 8.6 9.5 9.5-4.9.9-8.6 4.6-9.5 9.5-.9-4.9-4.6-8.6-9.5-9.5 4.9-.9 8.6-4.6 9.5-9.5z" },
        // arrows & marks
        "left": { d: "M14.5 6l-6 6 6 6" },
        "right": { d: "M9.5 6l6 6-6 6" },
        "down": { d: "M6 9.5l6 6 6-6" },
        "up": { d: "M6 14.5l6-6 6 6" },
        "back": { d: "M19 12H5 M11 6l-6 6 6 6" },
        "close": { d: "M6 6l12 12 M18 6L6 18" },
        "check": { d: "M5 12.5l4.5 4.5L19 7.5" },
        "plus": { d: "M12 5v14 M5 12h14" },
        // weather
        "clear": { d: "M12 7.5a4.5 4.5 0 1 0 0 9a4.5 4.5 0 1 0 0-9 M12 2.5v2 M12 19.5v2 M4.6 4.6l1.4 1.4 M18 18l1.4 1.4 M2.5 12h2 M19.5 12h2 M4.6 19.4l1.4-1.4 M18 6l1.4-1.4" },
        "clear-night": { d: "M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10z" },
        "partly": { d: "M7.5 6.5V5 M3.5 10.5H5 M4.7 6.7l1 1 M11 9.5a3.5 3.5 0 0 0-6 2.5 M9 19.5a3.5 3.5 0 0 1-.4-7 5 5 0 0 1 9.6 1.2 3 3 0 0 1 0 5.8z" },
        "partly-night": { d: "M10.5 8.5A4 4 0 0 1 6 4a4 4 0 1 0 4.5 4.5z M9 19.5a3.5 3.5 0 0 1-.4-7 5 5 0 0 1 9.6 1.2 3 3 0 0 1 0 5.8z" },
        "cloud": { d: "M7 18.5a4.5 4.5 0 0 1-.5-9 6 6 0 0 1 11.5 1.5 3.75 3.75 0 0 1 0 7.5z" },
        "rain": { d: cloudPath + " M9 18.5l-1 2.5 M13 18.5l-1 2.5 M17 18.5l-1 2.5" },
        "snow": { d: cloudPath + " M8.5 19v.5 M12 20.5v.5 M15.5 19v.5" },
        "storm": { d: cloudPath + " M12.5 15.5l-2 3.5h3l-2 3.5" },
        "fog": { d: "M4 9h16 M6 13h14 M4 17h12" }
    })

    // the shape to draw for an icon. some icons are meters: level 0..1 (or 0..4 for wi-fi bars)
    function path(name: string, level: real): var {
        if (name === "wifi") {
            const n = Math.max(0, Math.min(3, Math.round(level < 0 ? 3 : level * 3 / 4)));
            return { d: "M12 19.2v.4 " + wifiArcs.slice(0, n).join(" "), dim: wifiArcs.slice(n).join(" ") };
        }
        if (name === "volume") {
            const w = ["M15.2 9.8a3.2 3.2 0 0 1 0 4.4", "M17.8 7.3a6.8 6.8 0 0 1 0 9.4"];
            const n = level < 0 ? 2 : level <= 0 ? 0 : level < 0.5 ? 1 : 2;
            return { d: speakerPath + " " + w.slice(0, n).join(" "), dim: w.slice(n).join(" ") };
        }
        if (name === "battery") {
            const l = Math.max(0, Math.min(1, level < 0 ? 1 : level));
            const w = Math.max(0.6, 11.5 * l);
            return { d: "M3.5 8.5a1.5 1.5 0 0 1 1.5-1.5h12a1.5 1.5 0 0 1 1.5 1.5v7a1.5 1.5 0 0 1-1.5 1.5H5a1.5 1.5 0 0 1-1.5-1.5z M21 10.5v3",
                     solid: "M5.6 9.1h" + w.toFixed(2) + "v5.8h-" + w.toFixed(2) + "z" };
        }
        if (name === "battery-charging") {
            return { d: "M3.5 8.5a1.5 1.5 0 0 1 1.5-1.5h12a1.5 1.5 0 0 1 1.5 1.5v7a1.5 1.5 0 0 1-1.5 1.5H5a1.5 1.5 0 0 1-1.5-1.5z M21 10.5v3",
                     solid: "M11.8 8.3L8 12.6h3l-.6 3.1 3.8-4.3h-3z" };
        }
        return table[name] || table["spark"];
    }

    // names for the moods of the hardware
    function volume(v: real, muted: bool): string { return muted || v <= 0 ? "volume-mute" : "volume"; }
    function net(ethernet: bool, on: bool, ssid: string): string { return ethernet ? "ethernet" : !on || ssid === "" ? "wifi-off" : "wifi"; }
    function battery(charging: bool): string { return charging ? "battery-charging" : "battery"; }
    function weather(code: int, night: bool): string {
        if (code === 113) return night ? "clear-night" : "clear";
        if (code === 116) return night ? "partly-night" : "partly";
        if (code === 119 || code === 122) return "cloud";
        if ([143, 248, 260].indexOf(code) !== -1) return "fog";
        if ([200, 386, 389, 392, 395].indexOf(code) !== -1) return "storm";
        if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].indexOf(code) !== -1) return "snow";
        if ([263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 353, 356, 359].indexOf(code) !== -1) return "rain";
        return "cloud";
    }
}
