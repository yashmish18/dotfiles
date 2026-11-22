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
    readonly property int bars: Math.max(8, Math.min(128, Config.s.visualizerBars))
    readonly property int fps: Power.onBattery ? 24 : 45
    readonly property bool wanted: consumers > 0 && Media.playing
    property var values: []             // 0..1, `bars` long
    property real level: 0              // overall loudness, 0..1

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
            }
        }
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
