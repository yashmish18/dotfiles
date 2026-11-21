import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// one background layer per screen. two picture slots (A/B) so the old one stays on screen
// while the new one loads; then the shader inks from one to the other.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "kajukatli-wallpaper"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: Theme.ink
        // a live wallpaper (mpvpaper) sits underneath; step aside once it's playing
        visible: !Wall.videoReady

        // ---------------------------------------------------------------- slots
        property var metaA: null
        property var metaB: null
        property int toSlot: 0
        property int fromSlot: 1
        property int pendingSlot: -1
        property real progress: 1
        property bool waiting: false
        property int waitedMs: 0
        property real seed: 0

        readonly property var toMeta: toSlot === 0 ? metaA : metaB
        readonly property var fromMeta: fromSlot === 0 ? metaA : metaB
        readonly property real dpr: modelData.devicePixelRatio || 1

        function fileUrl(p) { return p ? "file://" + p : ""; }

        // decode only as many pixels as the screen needs, plus the parallax margin
        function decodeSize(m) {
            if (!m || !m.width) return undefined;   // undefined = decode at full size
            const W = win.width * dpr * 1.08, H = win.height * dpr * 1.08;
            const s = Math.max(W / m.width, H / m.height);
            return s >= 1 ? undefined : Qt.size(Math.ceil(m.width * s), Math.ceil(m.height * s));
        }
        function cover(m) {
            if (!m || !m.width || win.height === 0) return Qt.vector2d(1, 1);
            const S = win.width / win.height, I = m.width / m.height;
            const zoom = Config.s.parallax ? 0.94 : 1.0;     // room for the camera to move
            return S > I ? Qt.vector2d(zoom, zoom * I / S) : Qt.vector2d(zoom * S / I, zoom);
        }

        function finishNow() {
            if (!inkAnim.running) return;
            inkAnim.stop();
            progress = 1;
            if (fromSlot === 0) metaA = null; else metaB = null;
        }

        function begin() {
            const m = Wall.current;
            if (!m) return;
            finishNow();    // a new picture mid-transition: land the current one first
            if (toMeta === null) progress = 0;
            const target = toMeta === null ? toSlot : (toSlot === 0 ? 1 : 0);
            if (target === 0) metaA = m; else metaB = m;
            pendingSlot = target;
            waitedMs = 0;
            if (!m.ink) {
                // source preview: make the wallpaper visible as soon as Image decodes it.
                waiting = false;
                progress = 1;
                fromSlot = pendingSlot === 0 ? 1 : 0;
                toSlot = pendingSlot;
                return;
            }
            waiting = true;
        }
        function settled(st) { return st === Image.Ready || st === Image.Error || st === Image.Null; }
        function tryStart() {
            const img = pendingSlot === 0 ? imgA : imgB;
            const dep = pendingSlot === 0 ? depA : depB;
            waitedMs += 40;
            if (img.status === Image.Error || waitedMs > 15000) {
                waiting = false;
                return;
            }
            if (img.status !== Image.Ready || !settled(dep.status) || !settled(inkImg.status)) return;
            waiting = false;
            fromSlot = toMeta === null || pendingSlot === toSlot ? (pendingSlot === 0 ? 1 : 0) : toSlot;
            toSlot = pendingSlot;
            seed = Math.random() * 100;
            progress = 0;
            inkAnim.restart();
        }

        Connections {
            target: Wall
            function onGenerationChanged() { win.begin(); }
        }
        Component.onCompleted: if (Wall.current) begin()

        Timer {
            interval: 40
            repeat: true
            running: win.waiting
            onTriggered: win.tryStart()
        }

        NumberAnimation {
            id: inkAnim
            target: win
            property: "progress"
            from: 0
            to: 1
            duration: Config.s.transitionMs
            easing.type: Easing.InOutSine
            onFinished: {
                // free the old picture's video memory
                if (win.fromSlot === 0) win.metaA = null; else win.metaB = null;
            }
        }

        Image { id: imgA; visible: false; asynchronous: true; cache: false; source: win.fileUrl(win.metaA ? win.metaA.display : ""); sourceSize: win.decodeSize(win.metaA) }
        Image { id: imgB; visible: false; asynchronous: true; cache: false; source: win.fileUrl(win.metaB ? win.metaB.display : ""); sourceSize: win.decodeSize(win.metaB) }
        Image { id: depA; visible: false; asynchronous: true; cache: false; source: win.fileUrl(win.metaA && Config.s.parallax ? win.metaA.depth : "") }
        Image { id: depB; visible: false; asynchronous: true; cache: false; source: win.fileUrl(win.metaB && Config.s.parallax ? win.metaB.depth : "") }
        Image {
            id: inkImg
            visible: false
            asynchronous: true
            cache: false
            readonly property var m: win.pendingSlot === 0 ? win.metaA : win.pendingSlot === 1 ? win.metaB : null
            source: win.fileUrl(m ? m.ink : "")
        }

        // ---------------------------------------------------------------- camera
        // workspace position pans the camera; the cursor over the bare desktop tilts it
        readonly property var monitor: Hyprland.monitorFor(modelData)
        readonly property real wsCam: {
            const list = Hypr.workspacesOn(monitor);
            const i = list.findIndex(w => w.active);
            return list.length > 1 && i >= 0 ? (i / (list.length - 1)) * 2 - 1 : 0;
        }
        readonly property bool cursorOn: Config.s.parallax && Config.s.cursorParallax && !Power.onBattery
        property real mx: 0
        property real my: 0
        property real camX: -wsCam
        Behavior on camX { NumberAnimation { duration: 1400; easing.type: Easing.OutCubic } }
        property real tiltX: cursorOn ? mx : 0
        property real tiltY: cursorOn ? my : 0
        Behavior on tiltX { SmoothedAnimation { velocity: 1.2 } }
        Behavior on tiltY { SmoothedAnimation { velocity: 1.2 } }
        readonly property real strength: 0.024 * Math.max(0.2, Math.min(2.0, Config.s.parallaxStrength))

        ShaderEffect {
            id: fx
            anchors.fill: parent
            visible: win.toMeta !== null
            fragmentShader: Qt.resolvedUrl("../../shaders/wallpaper.frag.qsb")

            property real progress: win.progress
            property real hasFrom: win.fromMeta !== null && (win.fromSlot === 0 ? imgA : imgB).status === Image.Ready ? 1 : 0
            property real hasFromDepth: win.fromMeta !== null && (win.fromSlot === 0 ? depA : depB).status === Image.Ready ? 1 : 0
            property real hasToDepth: (win.toSlot === 0 ? depA : depB).status === Image.Ready ? 1 : 0
            property real seed: win.seed
            property real aspect: win.height > 0 ? win.width / win.height : 1.6
            property vector2d offset: Config.s.parallax
                ? Qt.vector2d((win.camX * 0.8 + win.tiltX * 0.5) * win.strength, win.tiltY * 0.35 * win.strength)
                : Qt.vector2d(0, 0)
            property vector2d coverFrom: win.cover(win.fromMeta)
            property vector2d coverTo: win.cover(win.toMeta)
            property color inkDark: "#0e0d0c"
            property color inkLight: "#ece6da"
            property color baseColor: Theme.ink

            property var fromTex: win.fromSlot === 0 ? imgA : imgB
            property var fromDepth: win.fromSlot === 0 ? depA : depB
            property var toTex: win.toSlot === 0 ? imgA : imgB
            property var toDepth: win.toSlot === 0 ? depA : depB
            property var inkTex: inkImg
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: win.cursorOn
            acceptedButtons: Qt.NoButton
            onPositionChanged: e => {
                win.mx = (e.x / width) * 2 - 1;
                win.my = (e.y / height) * 2 - 1;
            }
            onExited: { win.mx = 0; win.my = 0; }
        }

        // nothing chosen yet
        Column {
            visible: win.toMeta === null && !win.waiting
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 64
            spacing: 6
            Txt {
                text: Wall.preparing ? "developing…" : "no wallpaper yet."
                font.family: Theme.serif
                font.italic: true
                font.pixelSize: 34
                font.weight: Font.Light
                color: Theme.muted
            }
            Txt {
                text: "put pictures or videos in " + Config.s.wallpaperDir + ", then super + w"
                font.family: Theme.mono
                font.pixelSize: Theme.sm
                color: Theme.faint
            }
        }
    }
}
