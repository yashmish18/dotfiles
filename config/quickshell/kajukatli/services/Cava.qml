pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// the audio visualiser. one cava process feeds every visualiser on every screen.
// it only runs while something is playing and something is showing it; on battery it
// drops to a lower frame rate.
Singleton {
    id: root

    property int consumers: 0           // visualisers on screen register themselves
    // unplugged: at most 32 bars at 24 fps (about a third of the work), never off
    readonly property int bars: Math.max(8, Math.min(Power.onBattery ? 32 : 96, Config.s.visualizerBars))
    readonly property int fps: Power.onBattery ? 24 : 30
    readonly property bool wanted: consumers > 0 && Media.playing && !Power.saving   // unplugged with the battery saver: no audio analysis at all
    property var values: []             // 0..1, `bars` long
    property real level: 0              // overall loudness, 0..1
    property real bass: 0               // the low end (first eighth of the bars), 0..1
    property real bassAvg: 0            // its recent average: a hit is bass well above it
    property double lastFrame: 0
    property double lastSignal: Date.now()   // the last frame with any sound in it
    property double lastRestart: 0
    signal beat(real strength)          // a kick / bass hit (sparks, the pulsing clock)
    property double lastBeat: 0

    readonly property string conf: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/kajukatli/cava.conf"
    readonly property string confText: [
        "[general]",
        "bars = " + bars,
        "framerate = " + fps,
        "autosens = 1",
        "sleep_timer = 3",
        "[input]",
        "method = pipewire",
        "source = auto",
        "[output]",
        "method = raw",
        "raw_target = /dev/stdout",
        "data_format = ascii",
        "ascii_max_range = 1000",
        "bar_delimiter = 59",
        "frame_delimiter = 10",
        "channels = mono",
        "[smoothing]",
        "noise_reduction = 60",
        ""
    ].join("\n")

    function zero() {
        const z = [];
        for (let i = 0; i < bars; i++) z.push(0);
        values = z;
        level = 0;
    }
    Component.onCompleted: zero()
    onBarsChanged: { zero(); restart(); }
    onFpsChanged: restart()
    onWantedChanged: {
        if (wanted) restart();
        else { proc.running = false; decay.start(); }
    }

    function restart() {
        lastRestart = Date.now();
        lastSignal = Date.now();
        proc.running = false;
        if (!wanted) return;
        writer.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "sh", conf, confText];
        writer.running = true;
    }

    Process {
        id: writer
        onExited: if (root.wanted) proc.running = true
    }

    Process {
        id: proc
        command: ["cava", "-p", root.conf]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                const n = root.bars;
                const v = new Array(n);
                let sum = 0;
                for (let i = 0; i < n; i++) {
                    const x = (parseInt(parts[i]) || 0) / 1000;
                    v[i] = x;
                    sum += x;
                }
                root.values = v;
                root.level = sum / n;
                if (sum > 0.02) root.lastSignal = Date.now();
                // the beat: bass jumping well above its recent average, at most ~4 a second
                const k = Math.max(1, Math.floor(n / 8));
                let b = 0;
                for (let i = 0; i < k; i++) b += v[i];
                b /= k;
                root.bass = b;
                root.bassAvg = root.bassAvg * 0.92 + b * 0.08;
                const now = Date.now();
                root.lastFrame = now;
                if (b > 0.25 && b > root.bassAvg * 1.35 && now - root.lastBeat > 240) {
                    root.lastBeat = now;
                    root.beat(Math.min(1, b));
                }
            }
        }
        // cava stopped by itself (the audio device changed: a sound mode, headphones, a new
        // wallpaper's video): start it again instead of leaving the bars frozen
        onExited: if (root.wanted) again.restart()
    }
    Timer { id: again; interval: 800; onTriggered: root.restart() }
    // and if it's running but silent while music plays, it lost its input: restart
    Timer {
        interval: 4000
        repeat: true
        running: root.wanted
        onTriggered: {
            if (!root.wanted) return;
            const now = Date.now();
            if (!proc.running && !writer.running && !again.running) root.restart();
            // alive but deaf (frames of zeros while music plays): it lost its input, e.g. after a
            // new wallpaper's video grabbed the audio device. don't retry more than every 15 s
            else if (proc.running && now - root.lastRestart > 15000
                     && (now - root.lastFrame > 6000 || now - root.lastSignal > 8000)) root.restart();
        }
    }
    // a new wallpaper rebuilds the desktop layers; make sure the feed survives it
    Connections {
        target: Wall
        function onCurrentChanged() { if (root.wanted && !proc.running) again.restart(); }
    }

    // ease back to silence when playback stops, instead of freezing mid-shout
    Timer {
        id: decay
        interval: 33
        repeat: true
        onTriggered: {
            let any = false;
            const v = root.values.map(x => { const y = x * 0.82; if (y > 0.01) any = true; return y > 0.01 ? y : 0; });
            root.values = v;
            root.level *= 0.82;
            if (!any) stop();
        }
    }
}
