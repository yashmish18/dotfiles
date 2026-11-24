import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components
import qs.modules.desktop

// one background layer per screen. two picture slots (A/B) so the old one stays on screen
// while the new one loads; then the shader inks from one to the other.
//
// depth: widgets that go *behind* the subject (the clock, the visualiser) are drawn here,
// off-screen, and the shader lays them between the picture and the subject's soft mask.
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
        property bool inkRun: false       // this transition draws the ink outline (else: a crossfade)

        readonly property var toMeta: toSlot === 0 ? metaA : metaB
        readonly property var fromMeta: fromSlot === 0 ? metaA : metaB
        readonly property real dpr: modelData.devicePixelRatio || 1

        function fileUrl(p): string { return p ? "file://" + p : ""; }

        // every picture is decoded at screen size (plus the parallax margin), never at full
        // resolution: a 6000 px photo costs what a screen-sized one does, and decodes in a blink
        readonly property size decode: Qt.size(Math.ceil(win.width * dpr * (Config.s.parallax ? 1.07 : 1)),
                                               Math.ceil(win.height * dpr * (Config.s.parallax ? 1.07 : 1)))
        function cover(img): vector2d {
            if (!img || img.implicitWidth <= 0 || win.height === 0) return Qt.vector2d(1, 1);
            const S = win.width / win.height, I = img.implicitWidth / img.implicitHeight;
            const zoom = Config.s.parallax ? 0.94 : 1.0;     // room for the camera to move
            return S > I ? Qt.vector2d(zoom, zoom * I / S) : Qt.vector2d(zoom * S / I, zoom);
        }

        function finishNow() {
            if (!anim.running) return;
            anim.stop();
            progress = 1;
            if (fromSlot === 0) metaA = null; else metaB = null;
        }

        function begin() {
            const m = Wall.current;
            if (!m) return;
            finishNow();    // a new picture mid-transition: land the current one first
            if (!waiting && toMeta !== null && toMeta.source === m.source) { refine(); return; }
            const target = toMeta === null ? toSlot : (toSlot === 0 ? 1 : 0);
            if (target === 0) metaA = m; else metaB = m;
            pendingSlot = target;
            waitedMs = 0;
            waiting = true;      // start the moment the picture is decoded: no black frame
        }
        // the same wallpaper learned more (cut-out, depth): swap those in, keep the picture
        function refine() {
            const m = Wall.current;
            if (!m) return;
            const pend = pendingSlot === 0 ? metaA : metaB;
            const slot = waiting && pend && pend.source === m.source ? pendingSlot
                       : toMeta && toMeta.source === m.source ? toSlot : -1;
            if (slot < 0) return;
            const cur = slot === 0 ? metaA : metaB;
            const merged = Object.assign({}, m, { display: cur.display });
            if (slot === 0) metaA = merged; else metaB = merged;
        }
        function settled(st): bool { return st === Image.Ready || st === Image.Error || st === Image.Null; }
        function tryStart() {
            const img = pendingSlot === 0 ? imgA : imgB;
            waitedMs += 30;
            if (img.status === Image.Error || waitedMs > 15000) {
                waiting = false;
                return;
            }
            if (img.status !== Image.Ready) return;
            const m = pendingSlot === 0 ? metaA : metaB;
            // a brand-new picture shows up before kk-prep has made its ink map: give the fast
            // stage a moment (it's usually ~0.2 s) so the switch can still ink in
            if (!m.ink && (m.stage || 0) === 0 && waitedMs < 4000) return;
            const wantInk = !!m.ink && !Config.s.reducedMotion;   // reduced motion: a short fade
            if (wantInk && !settled(inkImg.status)) return;
            inkRun = wantInk;
            waiting = false;
            fromSlot = toMeta === null || pendingSlot === toSlot ? (pendingSlot === 0 ? 1 : 0) : toSlot;
            toSlot = pendingSlot;
            seed = Math.random() * 100;
            if (fromMeta === null) {
                progress = 1;
                if (fromSlot === 0) metaA = null; else metaB = null;
                return;
            }
            progress = 0;
            anim.duration = inkRun ? Config.s.transitionMs : Config.s.reducedMotion ? 350 : 700;
            anim.restart();
        }

        Connections {
            target: Wall
            function onGenerationChanged() { win.begin(); }
            function onRefined() { win.refine(); }
        }
        Component.onCompleted: if (Wall.current) begin()

        Timer {
            interval: 30
            repeat: true
            running: win.waiting
            onTriggered: win.tryStart()
        }

        NumberAnimation {
            id: anim
            target: win
            property: "progress"
            from: 0
            to: 1
            duration: 420
            easing.type: Easing.InOutQuad
            onFinished: {
                // free the old picture's video memory
                if (win.fromSlot === 0) win.metaA = null; else win.metaB = null;
                gc();       // the old picture's textures can go now
            }
        }

        Image { id: imgA; visible: false; asynchronous: true; cache: false; fillMode: Image.PreserveAspectCrop; sourceSize: win.decode; source: win.fileUrl(win.metaA ? win.metaA.display : "") }
        Image { id: imgB; visible: false; asynchronous: true; cache: false; fillMode: Image.PreserveAspectCrop; sourceSize: win.decode; source: win.fileUrl(win.metaB ? win.metaB.display : "") }
        // depth/mask/ink are sampled at screen size too — without sourceSize Qt decodes the
        // full-resolution PNGs (tens of MB each, per screen) and that is most of the shell's RSS.
        Image { id: depA; visible: false; asynchronous: true; cache: false; sourceSize: win.decode; source: win.fileUrl(win.metaA && Config.s.parallax ? win.metaA.depth : "") }
        Image { id: depB; visible: false; asynchronous: true; cache: false; sourceSize: win.decode; source: win.fileUrl(win.metaB && Config.s.parallax ? win.metaB.depth : "") }
        Image { id: maskA; visible: false; asynchronous: true; cache: false; sourceSize: win.decode; source: win.fileUrl(win.metaA ? (win.metaA.mask || "") : "") }
        Image { id: maskB; visible: false; asynchronous: true; cache: false; sourceSize: win.decode; source: win.fileUrl(win.metaB ? (win.metaB.mask || "") : "") }

        // ---------------------------------------------------------------- behind the subject
        // the shader samples this as a texture. it sits under the (opaque) wallpaper effect, so
        // it never shows on its own; live only while something is actually behind.
        DesktopLayer {
            id: depthLayer
            width: win.width
            height: win.height
            behind: true
            monitor: win.monitor
        }
        ShaderEffectSource {
            id: depthTex
            width: win.width
            height: win.height
            sourceItem: depthLayer
            hideSource: true
            live: depthLayer.anyHere
            recursive: false
        }

        Image {
            id: inkImg
            visible: false
            asynchronous: true
            cache: false
            sourceSize: win.decode
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
        // (it only redraws while the pointer moves over the bare desktop, so battery is fine)
        readonly property bool cursorOn: Config.s.parallax && Config.s.cursorParallax
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
            // a depth map that arrives late fades the 3d in instead of snapping to it
            readonly property real toDepthReady: (win.toSlot === 0 ? depA : depB).status === Image.Ready ? 1 : 0
            property real hasToDepth: toDepthReady
            Behavior on hasToDepth { enabled: fx.toDepthReady > 0.5; NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
            property real seed: win.seed
            property real aspect: win.height > 0 ? win.width / win.height : 1.6
            // never more than the picture's spare margin (it's drawn at 94%), or the edges smear
            readonly property real room: 0.026
            property vector2d offset: Config.s.parallax && !Config.s.reducedMotion
                ? Qt.vector2d(Math.max(-room, Math.min(room, (win.camX * 0.8 + win.tiltX * 0.9) * win.strength)),
                              Math.max(-room, Math.min(room, win.tiltY * 0.65 * win.strength)))
                : Qt.vector2d(0, 0)
            property vector2d coverFrom: win.cover(win.fromSlot === 0 ? imgA : imgB)
            property vector2d coverTo: win.cover(win.toSlot === 0 ? imgA : imgB)
            property real useInk: win.inkRun ? 1 : 0
            property color inkDark: "#0e0d0c"
            property color inkLight: "#ece6da"
            property color baseColor: Theme.ink

            property var fromTex: win.fromSlot === 0 ? imgA : imgB
            property var fromDepth: win.fromSlot === 0 ? depA : depB
            property var toTex: win.toSlot === 0 ? imgA : imgB
            property var toDepth: win.toSlot === 0 ? depA : depB
            property var inkTex: inkImg

            property real hasOverlay: depthLayer.anyHere ? 1 : 0
            property var overlayTex: depthTex
            readonly property var toMaskImg: win.toSlot === 0 ? maskA : maskB
            property real hasMask: toMaskImg.status === Image.Ready ? 1 : 0
            property var toMask: toMaskImg
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: win.cursorOn
            acceptedButtons: Qt.NoButton
            onPositionChanged: e => {
                win.mx = (e.x / width) * 2 - 1;
                win.my = (e.y / height) * 2 - 1;
            }
            // (no snapping back to the middle when the pointer slips onto a window or the bar:
            // the picture stays where it was and carries on from there)
        }

        // nothing chosen yet
        Column {
            visible: win.toMeta === null && !win.waiting
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 64
            spacing: 6
            Txt {
                text: ""
                font.pixelSize: 34
                font.weight: Font.Light
                color: Theme.muted
            }
            Txt {
                text: Config.s.wallpaperDir
                font.family: Theme.mono
                font.pixelSize: Theme.sm
                color: Theme.faint
            }
        }
    }
}
