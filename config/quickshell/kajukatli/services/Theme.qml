pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// one place for every colour, font and size in the shell.
// the base never changes; only `accent` follows the wallpaper (kk-theme writes theme.json).
Singleton {
    id: root

    // ink & paper
    readonly property color ink: "#0c0c0c"
    readonly property color surface: "#141414"
    readonly property color raised: "#1c1c1c"
    readonly property color line: "#2a2a2a"
    readonly property color paper: "#e8e4dc"
    readonly property color muted: "#8f8a80"
    readonly property color faint: "#5a5650"
    readonly property color danger: "#b5655a"
    readonly property color ok: "#8a9a7b"

    // follows the wallpaper, eased so it changes with the ink, not before it
    property color accent: file.loaded ? adapter.accent : "#c9b79c"
    property color accentDim: file.loaded ? adapter.accentDim : "#5f574b"
    property color accentFaint: file.loaded ? adapter.accentFaint : "#24221f"
    Behavior on accent { ColorAnimation { duration: 1600; easing.type: Easing.InOutQuad } }
    Behavior on accentDim { ColorAnimation { duration: 1600; easing.type: Easing.InOutQuad } }
    Behavior on accentFaint { ColorAnimation { duration: 1600; easing.type: Easing.InOutQuad } }

    // type: a serif for voice, a mono for facts, a sans for everything else
    readonly property string serif: "Noto Serif"
    readonly property string sans: "Inter"
    readonly property string mono: "IBM Plex Mono"
    readonly property string glyph: "Symbols Nerd Font"

    readonly property int xs: 10
    readonly property int sm: 11
    readonly property int md: 13
    readonly property int lg: 16
    readonly property int xl: 24

    // motion
    readonly property int fast: 160
    readonly property int normal: 280
    readonly property int slow: 460

    readonly property int barHeight: 34
    readonly property int gap: 10

    function reload() { file.reload() }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/kajukatli/theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string accent: "#c9b79c"
            property string accentDim: "#5f574b"
            property string accentFaint: "#24221f"
            property string inkColor: "#ece8e0"
            property real luma: 0.3
        }
    }
}
