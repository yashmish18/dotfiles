//@ pragma UseQApplication
// kk-photobooth: the camera, as a photobooth. its own little quickshell app (qs -c kk-photobooth),
// so the camera libraries are only loaded while it's open, and the desktop never depends on them.
//
//   space     take it (3, 2, 1, flash)
//   tab       one photo · a strip of four
//   1–6       the look: clean, film, mono, ink, warm, dream
//   esc       close
// photos land in ~/Pictures/photobooth, mirrored like a mirror, with the look baked in.
import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io

ShellRoot {
    id: app

    // ---------------------------------------------------------------- colours from the wallpaper
    property var t: ({})
    readonly property color bg: t.surfaceContainerLowest || "#111013"
    readonly property color card: t.surfaceContainer || "#1d1b20"
    readonly property color fg: t.surfaceText || "#ece6f0"
    readonly property color dim: t.surfaceTextDim || "#a9a2ad"
    readonly property color accent: t.primary || "#e9a86b"
    readonly property color accentText: t.primaryText || "#1b1208"
    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/kajukatli/theme.json"
        printErrors: false
        onLoaded: { try { app.t = JSON.parse(text()); } catch (e) {} }
    }

    readonly property string out: (Quickshell.env("XDG_PICTURES_DIR") || Quickshell.env("HOME") + "/Pictures") + "/photobooth"
    readonly property string sounds: Quickshell.env("HOME") + "/.config/quickshell/kajukatli/sounds"
    property var recent: []          // newest first
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$1"; ls -t "$1"/*.png 2>/dev/null | head -n 8', "sh", app.out]
        stdout: StdioCollector { onStreamFinished: app.recent = text.split("\n").filter(x => x !== "") }
    }

    readonly property var looks: [
        { name: "clean", sat: 0, con: 0, bri: 0, tint: 0, col: "#ffffff", blur: 0 },
        { name: "film", sat: -0.25, con: 0.18, bri: 0.02, tint: 0.18, col: "#ffb070", blur: 0 },
        { name: "mono", sat: -1, con: 0.3, bri: 0, tint: 0, col: "#ffffff", blur: 0 },
        { name: "ink", sat: -1, con: 0.85, bri: 0.12, tint: 0.25, col: "#2a3a6a", blur: 0 },
        { name: "warm", sat: 0.2, con: 0.05, bri: 0.04, tint: 0.22, col: "#ff8a5c", blur: 0 },
        { name: "dream", sat: 0.1, con: -0.1, bri: 0.08, tint: 0.2, col: "#d9a6ff", blur: 0.35 }
    ]
    property int look: 0
    property string camError: ""
    property bool strip: false
    property int count: 0            // the countdown on screen (0 = none)
    property int shotsLeft: 0
    property var stripShots: []

    function shoot() {
        if (count > 0 || shotsLeft > 0) return;
        shotsLeft = strip ? 4 : 1;
        stripShots = [];
        countdown();
    }
    function countdown() { count = 3; tick.restart(); }
    function play(name) { Quickshell.execDetached(["pw-play", "--volume", "0.6", app.sounds + "/" + name + ".wav"]); }

    function stamp() {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "_" + p(d.getHours()) + "-" + p(d.getMinutes()) + "-" + p(d.getSeconds()) + "-" + d.getMilliseconds();
    }

    FloatingWindow {
        id: win
        title: "Photobooth"
        implicitWidth: 1080
        implicitHeight: 780
        color: app.bg
        visible: true
        // closing the window ends the app, so the camera is let go (and its light goes off)
        onVisibleChanged: if (!visible) { cam.active = false; Qt.quit(); }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onSpacePressed: app.shoot()
            Keys.onReturnPressed: app.shoot()
            Keys.onTabPressed: app.strip = !app.strip
            Keys.onEscapePressed: { cam.active = false; Qt.quit(); }
            Keys.onPressed: e => {
                const n = parseInt(e.text);
                if (n >= 1 && n <= app.looks.length) app.look = n - 1;
            }

            MediaDevices { id: devices }
            CaptureSession {
                camera: Camera {
                    id: cam
                    cameraDevice: devices.defaultVideoInput
                    active: true
                    onErrorOccurred: (error, message) => app.camError = message || "the camera didn't start"
                }
                videoOutput: video
            }

            // ------------------------------------------------ the mirror
            Rectangle {
                id: frame
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 24
                width: Math.min(parent.width - 48, (parent.height - 210) * 4 / 3)
                height: width * 3 / 4
                radius: 26
                color: "#000000"
                clip: true

                Item {
                    id: shot          // what gets saved: the picture with its look
                    anchors.fill: parent
                    VideoOutput {
                        id: video
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectCrop
                        visible: false
                        transform: Scale { origin.x: video.width / 2; xScale: -1 }   // a mirror, not a security camera
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: video
                        readonly property var l: app.looks[app.look]
                        saturation: l.sat
                        contrast: l.con
                        brightness: l.bri
                        colorization: l.tint
                        colorizationColor: l.col
                        blurEnabled: l.blur > 0
                        blur: l.blur
                        blurMax: 24
                        Behavior on saturation { NumberAnimation { duration: 260 } }
                        Behavior on contrast { NumberAnimation { duration: 260 } }
                        Behavior on colorization { NumberAnimation { duration: 260 } }
                    }
                    // film gets its corners darkened
                    Rectangle {
                        anchors.fill: parent
                        visible: app.looks[app.look].name === "film" || app.looks[app.look].name === "ink"
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.25) }
                            GradientStop { position: 0.3; color: "transparent" }
                            GradientStop { position: 0.7; color: "transparent" }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.35) }
                        }
                    }
                }

                // no camera?
                Text {
                    anchors.centerIn: parent
                    visible: devices.videoInputs.length === 0 || app.camError !== ""
                    width: parent.width - 80
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: devices.videoInputs.length === 0 ? "No camera found" : "Camera: " + app.camError
                    font.family: "Bricolage Grotesque"
                    font.pixelSize: 22
                    color: app.dim
                }

                // 3, 2, 1
                Text {
                    id: big
                    anchors.centerIn: parent
                    visible: app.count > 0
                    text: app.count
                    font.family: "Bricolage Grotesque"
                    font.pixelSize: 220
                    font.weight: Font.Black
                    color: "#ffffff"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.4)
                    onTextChanged: { pop.restart(); }
                    NumberAnimation on scale { id: pop; from: 1.5; to: 1; duration: 420; easing.type: Easing.OutBack }
                }
                // the strip's progress
                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 18
                    spacing: 8
                    visible: app.strip
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: 10; height: 10; radius: 5
                            color: index < app.stripShots.length ? app.accent : Qt.rgba(1, 1, 1, 0.35)
                        }
                    }
                }
                // flash
                Rectangle {
                    id: flash
                    anchors.fill: parent
                    color: "#ffffff"
                    opacity: 0
                    NumberAnimation on opacity { id: flashAnim; running: false; from: 1; to: 0; duration: 520; easing.type: Easing.OutQuad }
                }
            }

            Timer {
                id: tick
                interval: 800
                repeat: true
                onTriggered: {
                    if (app.count > 1) { app.count--; app.play("tick"); return; }
                    stop();
                    app.count = 0;
                    // wait for the number to leave the frame before taking it
                    Qt.callLater(capture);
                }
                function capture() {
                    shot.grabToImage(r => {
                        const f = app.out + "/" + app.stamp() + ".png";
                        r.saveToFile(f);
                        app.play("shutter");
                        flashAnim.restart();
                        app.shotsLeft--;
                        if (app.strip) {
                            app.stripShots = app.stripShots.concat([f]);
                            if (app.shotsLeft > 0) { gap.restart(); return; }
                            makeStrip.restart();
                        } else {
                            app.recent = [f].concat(app.recent).slice(0, 8);
                        }
                    });
                }
            }
            Timer { id: gap; interval: 900; onTriggered: app.countdown() }

            // the strip: four frames, one under the other, on paper
            Rectangle {
                id: paper
                visible: false
                width: 420
                height: col.implicitHeight + 40
                color: "#f4efe6"
                Column {
                    id: col
                    x: 20; y: 20
                    spacing: 14
                    Repeater {
                        model: app.stripShots
                        Image {
                            required property string modelData
                            width: 380; height: 285
                            fillMode: Image.PreserveAspectCrop
                            source: "file://" + modelData
                            cache: false
                        }
                    }
                }
            }
            Timer {
                id: makeStrip
                interval: 400        // the four images load
                onTriggered: {
                    paper.visible = true;
                    paper.grabToImage(r => {
                        const f = app.out + "/strip_" + app.stamp() + ".png";
                        r.saveToFile(f);
                        paper.visible = false;
                        app.recent = [f].concat(app.recent).slice(0, 8);
                    });
                }
            }

            // ------------------------------------------------ the controls
            Row {
                id: lookRow
                anchors.top: frame.bottom
                anchors.topMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Repeater {
                    model: app.looks
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: app.look === index
                        width: lbl.implicitWidth + 26
                        height: 34
                        radius: 17
                        color: on ? app.accent : ma.containsMouse ? app.card : "transparent"
                        border.width: on ? 0 : 1
                        border.color: Qt.rgba(app.fg.r, app.fg.g, app.fg.b, 0.15)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Text {
                            id: lbl
                            anchors.centerIn: parent
                            text: parent.modelData.name
                            font.family: "Bricolage Grotesque"
                            font.pixelSize: 14
                            color: parent.on ? app.accentText : app.fg
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.look = parent.index }
                    }
                }
            }

            Item {
                anchors.top: lookRow.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                // photo / strip
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: ["photo", "strip"]
                        Rectangle {
                            required property string modelData
                            readonly property bool on: (modelData === "strip") === app.strip
                            width: 72; height: 30; radius: 15
                            color: on ? app.card : "transparent"
                            Text { anchors.centerIn: parent; text: parent.modelData; font.family: "Bricolage Grotesque"; font.pixelSize: 14; color: parent.on ? app.fg : app.dim }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.strip = parent.modelData === "strip" }
                        }
                    }
                }

                // the shutter
                Rectangle {
                    anchors.centerIn: parent
                    width: 74; height: 74; radius: 37
                    color: "transparent"
                    border.width: 3
                    border.color: app.fg
                    Rectangle {
                        anchors.centerIn: parent
                        width: shutter.pressed ? 50 : 60
                        height: width
                        radius: width / 2
                        color: app.count > 0 || app.shotsLeft > 0 ? "#ff5a5a" : app.accent
                        Behavior on width { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    MouseArea { id: shutter; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: app.shoot() }
                }

                // the last few
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Repeater {
                        model: app.recent.slice(0, 4)
                        Rectangle {
                            required property string modelData
                            width: 64; height: 64; radius: 12
                            clip: true
                            color: app.card
                            Image {
                                anchors.fill: parent
                                source: "file://" + parent.modelData
                                sourceSize: Qt.size(128, 128)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", parent.modelData]) }
                        }
                    }
                }
            }
        }
    }
}
