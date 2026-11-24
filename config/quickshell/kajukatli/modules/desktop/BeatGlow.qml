import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// music: the edges of every screen glow in the album's colour on the beat. drawn above
// everything but takes no clicks. settings → desktop → music fun → glow.
Variants {
    model: Config.s.musicGlow ? Quickshell.screens : []

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "kajukatli-glow"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        mask: Region {}
        visible: Media.playing && !Hypr.fullscreen

        Uses { service: Cava; active: win.visible }
        property real glow: 0
        Connections {
            target: Cava
            function onBeat(strength) { win.glow = 0.35 + 0.65 * strength; fade.restart(); }
        }
        NumberAnimation { id: fade; target: win; property: "glow"; to: 0; duration: 520; easing.type: Easing.OutQuad }
        readonly property color c: Media.artReady ? Media.artTint : Theme.primary

        // four soft edges
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                readonly property bool vertical: index >= 2
                x: index === 3 ? win.width - width : 0
                y: index === 1 ? win.height - height : 0
                width: vertical ? 70 : win.width
                height: vertical ? win.height : 70
                opacity: win.glow
                gradient: Gradient {
                    orientation: vertical ? Gradient.Horizontal : Gradient.Vertical
                    GradientStop { position: 0; color: (index === 1 || index === 3) ? "transparent" : Theme.alpha(win.c, 0.55) }
                    GradientStop { position: 1; color: (index === 1 || index === 3) ? Theme.alpha(win.c, 0.55) : "transparent" }
                }
            }
        }
    }
}
