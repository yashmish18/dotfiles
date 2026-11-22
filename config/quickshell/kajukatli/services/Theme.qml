pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// one place for every colour, font and size in the shell.
// colours come from the wallpaper: kk-theme writes ~/.cache/kajukatli/theme.json
// (material-you style roles in oklch) and every colour eases into the new one.
//
// the older names (ink, paper, muted, faint, accent…) are kept so every panel keeps working;
// new code should prefer the role names (primary, surfaceContainer, surfaceText…).
Singleton {
    id: root

    // ---------------------------------------------------------------- roles
    // while music plays, the accent borrows the album cover's colour (settings → look)
    readonly property bool tinted: Config.s.musicTint && Media.playing && Media.artReady
    property color primary: tinted ? Media.artTint : a.primary
    property color primaryText: tinted ? Media.artTintText : a.primaryText
    property color primaryContainer: a.primaryContainer
    property color primaryContainerText: a.primaryContainerText
    property color secondary: a.secondary
    property color secondaryContainer: a.secondaryContainer
    property color secondaryContainerText: a.secondaryContainerText
    property color tertiary: a.tertiary
    property color tertiaryContainer: a.tertiaryContainer
    property color tertiaryContainerText: a.tertiaryContainerText
    property color error: a.error
    property color errorText: a.errorText
    property color success: a.success
    property color background: a.background
    property color surfaceLowest: a.surfaceContainerLowest
    property color surfaceLow: a.surfaceContainerLow
    property color surfaceContainer: a.surfaceContainer
    property color surfaceHigh: a.surfaceContainerHigh
    property color surfaceHighest: a.surfaceContainerHighest
    property color surfaceText: a.surfaceText
    property color surfaceTextDim: a.surfaceTextDim
    property color outline: a.outline
    property color outlineVariant: a.outlineVariant
    property color wallText: a.wallText
    property color wallTextDim: a.wallTextDim
    property color wallShadow: a.wallShadow
    // the desktop clock's colours: set from the picture right under it (DesktopLayer),
    // so it reads on a red dress as well as on a white sky
    property color clockInk: wallText
    property color clockInkDim: wallTextDim
    property color clockShadow: wallShadow
    Behavior on clockInk { ColorAnimation { duration: 900; easing.type: Easing.InOutQuad } }
    Behavior on clockInkDim { ColorAnimation { duration: 900; easing.type: Easing.InOutQuad } }
    readonly property bool dark: a.dark
    readonly property string scheme: a.scheme

    // ---------------------------------------------------------------- the old names
    property color ink: a.ink
    property color surface: a.card
    property color raised: a.raised
    property color line: a.line
    property color paper: a.paper
    property color muted: a.muted
    property color faint: a.faint
    property color danger: a.danger
    property color ok: a.ok
    property color accent: tinted ? Media.artTint : a.accent
    property color accentDim: a.accentDim
    property color accentFaint: a.accentFaint

    // a translucent card for things floating over the wallpaper
    readonly property color glass: alpha(surfaceContainer, 0.86)
    readonly property color glassStrong: alpha(surfaceLow, 0.94)

    function alpha(c: color, a: real): color { return Qt.rgba(c.r, c.g, c.b, a); }

    Behavior on primary { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on primaryText { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on primaryContainer { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on tertiary { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on accent { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on accentDim { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on ink { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on surface { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on surfaceContainer { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on surfaceLow { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on wallText { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    Behavior on wallTextDim { ColorAnimation { duration: 1400; easing.type: Easing.InOutQuad } }

    // ---------------------------------------------------------------- type
    // chosen, not defaulted: a grotesque with some wobble for the interface, a mono with soft
    // curves for numbers, and loud display faces for the desktop clocks (install.sh fetches them).
    // there are no italics anywhere in the interface.
    readonly property string sans: "Bricolage Grotesque"
    readonly property string mono: "DM Mono"
    readonly property string serif: "Fraunces"            // clocks only
    readonly property string glyph: "Symbols Nerd Font"   // tray fallbacks only; the shell draws its own icons
    readonly property string display: Config.s.clockFont !== "" ? Config.s.clockFont : "Syne"

    readonly property int xs: 10
    readonly property int sm: 11
    readonly property int md: 13
    readonly property int lg: 16
    readonly property int xl: 24

    // motion
    readonly property int fast: 160
    readonly property int normal: 280
    readonly property int slow: 460

    // shape
    readonly property int barHeight: 36
    readonly property int gap: 10
    readonly property int radius: Config.s.radius
    readonly property int radiusSmall: Math.max(4, Math.round(Config.s.radius * 0.55))

    function reload() { file.reload() }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/kajukatli/theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        // defaults = a warm dark scheme, until the first wallpaper decides
        JsonAdapter {
            id: a
            property string primary: "#e9c08b"
            property string primaryText: "#432c05"
            property string primaryContainer: "#5c4219"
            property string primaryContainerText: "#ffddb2"
            property string secondary: "#d9c4a8"
            property string secondaryContainer: "#524533"
            property string secondaryContainerText: "#f6e0c3"
            property string tertiary: "#b7cea1"
            property string tertiaryContainer: "#3a4c2c"
            property string tertiaryContainerText: "#d3eabc"
            property string error: "#ffb4ab"
            property string errorText: "#690005"
            property string success: "#a8d39a"
            property string background: "#17130e"
            property string surfaceContainerLowest: "#110d09"
            property string surfaceContainerLow: "#1f1b16"
            property string surfaceContainer: "#231f1a"
            property string surfaceContainerHigh: "#2e2924"
            property string surfaceContainerHighest: "#39342e"
            property string surfaceText: "#ebe1d8"
            property string surfaceTextDim: "#d3c4b4"
            property string outline: "#9c8f80"
            property string outlineVariant: "#4f4539"
            property string wallText: "#ffddb2"
            property string wallTextDim: "#d0a76f"
            property string wallShadow: "#000000"
            property bool dark: true
            property string scheme: "vibrant"

            property string ink: "#17130e"
            property string card: "#1f1b16"
            property string raised: "#2e2924"
            property string line: "#4f4539"
            property string paper: "#ebe1d8"
            property string muted: "#d3c4b4"
            property string faint: "#9c8f80"
            property string danger: "#ffb4ab"
            property string ok: "#a8d39a"
            property string accent: "#e9c08b"
            property string accentDim: "#5c4219"
            property string accentFaint: "#2f281f"
            property string inkColor: "#ece8e0"
            property real luma: 0.3
        }
    }
}
