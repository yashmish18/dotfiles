pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// sound modes (kk-sound): music, movie, voice, laptop speakers, and atmos from your own
// laptop's dolby impulse file. a small pipewire filter that every app plays through; it
// becomes the output while it runs and gives the old one back when it stops.
Singleton {
    id: root

    readonly property string mode: Config.s.soundMode
    readonly property bool active: mode !== "off"
    readonly property var modes: [
        { key: "music", label: "Music", about: "Warmer bass, air on top, a little wider" },
        { key: "movie", label: "Movie", about: "Deep bass, clear voices, a wide stage" },
        { key: "voice", label: "Voice", about: "Calls and podcasts: speech forward" },
        { key: "speakers", label: "Laptop speakers", about: "Louder and cleaner on small speakers" },
        { key: "atmos", label: "Dolby Atmos", about: "Your laptop's own Atmos tuning, from its Windows driver file" }
    ]
    readonly property string label: active ? (modes.find(m => m.key === mode) || { label: mode }).label : "off"
    property bool haveAtmos: false
    property string error: ""

    function set(m: string) {
        if (m !== "off") Config.s.soundModeLast = m;
        Config.s.soundMode = m;
    }
    function toggle() { set(active ? "off" : (Config.s.soundModeLast || "music")); }

    Process {
        id: filter
        running: root.active && Config.loaded
        command: [Config.bin + "kk-sound", "run", root.mode]
        stderr: StdioCollector { id: err }
        onExited: code => {
            // it stopped on its own (a bad impulse file, pipewire restarted): say so, try once more later
            if (root.active && code !== 0) { root.error = err.text.trim().split("\n").pop() || "the sound mode stopped"; retry.restart(); }
        }
        onRunningChanged: if (running) root.error = ""
    }
    Timer { id: retry; interval: 5000; onTriggered: if (root.active && !filter.running) filter.running = true }

    Process {
        id: listProc
        running: true
        command: [Config.bin + "kk-sound", "list"]
        stdout: StdioCollector { onStreamFinished: root.haveAtmos = /^atmos$/m.test(text) }
    }
    function recheck() { listProc.running = true; }
    function openFolder() {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/kajukatli/sound" && xdg-open "${XDG_CONFIG_HOME:-$HOME/.config}/kajukatli/sound"']);
    }
}
