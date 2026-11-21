pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// the wallpaper engine's brain. the pictures themselves are drawn by modules/wallpaper.
//
//   set(file) → kk-prep makes/reuses the bundle → every screen runs the ink transition
//             → kk-theme recolours the desktop → (video) mpvpaper takes over once it settles
Singleton {
    id: root

    property var current: null          // meta.json of what's on screen
    property int generation: 0          // +1 per new wallpaper; screens react to this
    property bool preparing: false
    property string error: ""
    property var library: []            // picker contents, from `kk-prep --list`
    property bool listing: false

    readonly property bool isVideo: current !== null && current.kind === "video" && current.video !== ""
    readonly property bool videoAllowed: !Power.onBattery || Config.s.videoOnBattery
    property bool videoReady: false     // mpvpaper is up: our own layer can step aside

    property string _queued: ""
    property bool _queuedForce: false
    property string _queuedModel: ""

    function set(file: string) { prep(file, false, ""); }
    function redetect(model: string) {
        if (current) prep(current.source, true, model);
    }

    function prep(file: string, force: bool, model: string) {
        if (!file) return;
        const ext = file.toLowerCase();
        const previewKind = ext.endsWith(".gif") || ext.endsWith(".mp4") || ext.endsWith(".webm") || ext.endsWith(".mkv") || ext.endsWith(".mov") || ext.endsWith(".avi") || ext.endsWith(".m4v") ? "video" : "image";
        root.apply({
            source: file,
            name: file.split("/").pop().replace(/\.[^.]+$/, ""),
            kind: previewKind,
            display: file,
            thumb: file,
            dir: "",
            depth: "",
            ink: "",
            video: previewKind === "video" ? file : "",
            width: 0,
            height: 0
        });
        if (prepProc.running) {          // last request wins
            _queued = file;
            _queuedForce = force;
            _queuedModel = model;
            return;
        }
        error = "";
        preparing = true;
        Ui.status = "developing…";
        const cmd = ["nice", "-n", "10", "kk-prep", file, "--model", model || Config.s.subjectModel];
        if (force) cmd.push("--force");
        prepProc.command = cmd;
        prepProc.running = true;
    }

    function apply(meta) {
        stopVideo();
        current = meta;
        generation++;
        Store.s.wallpaper = meta.source;
        themeProc.command = ["kk-theme", meta.dir];
        themeProc.running = true;
        if (isVideo) videoStart.restart();
    }

    property int _pendingStep: 0   // 1 next, -1 prev, 2 random, once the library is listed

    function step(dir: int) {
        const lib = library;
        if (!lib.length) { _pendingStep = dir; refreshLibrary(); return; }
        const i = current ? lib.findIndex(w => w.path === current.source) : -1;
        set(lib[(i + dir + lib.length) % lib.length].path);
    }
    function random() {
        if (!library.length) { _pendingStep = 2; refreshLibrary(); return; }
        let pick = library[Math.floor(Math.random() * library.length)];
        if (library.length > 1 && current && pick.path === current.source)
            pick = library[(library.indexOf(pick) + 1) % library.length];
        set(pick.path);
    }
    function refreshLibrary() {
        if (listProc.running) return;
        listing = true;
        listProc.command = ["kk-prep", "--list", Config.wallpaperDir];
        listProc.running = true;
    }

    function startVideo() {
        if (!isVideo || !videoAllowed || mpv.running) return;
        mpv.command = ["mpvpaper", "-p", "-o", "no-audio loop hwdec=auto-safe panscan=1.0", "ALL", current.video];
        mpv.running = true;
    }
    function stopVideo() {
        videoStart.stop();
        videoReady = false;      // our still frame comes back first…
        if (mpv.running) mpv.running = false;   // …then the video goes
    }

    onVideoAllowedChanged: videoAllowed ? startVideo() : stopVideo()

    // restore the last wallpaper on login (the bundle is cached, so this is quick)
    Connections {
        target: Store
        function onReadyChanged() {
            if (Store.ready && Store.s.wallpaper !== "" && root.current === null)
                root.set(Store.s.wallpaper);
        }
    }
    Component.onCompleted: {
        if (Store.ready && Store.s.wallpaper !== "") set(Store.s.wallpaper);
    }

    Process {
        id: prepProc
        stdout: StdioCollector { id: prepOut }
        stderr: StdioCollector { id: prepErr }
        onExited: code => {
            root.preparing = false;
            Ui.status = "";
            if (code === 0) {
                const lines = prepOut.text.trim().split("\n");
                try {
                    root.apply(JSON.parse(lines[lines.length - 1]));
                } catch (e) {
                    root.error = "kk-prep gave nothing usable";
                }
            } else {
                const lines = prepErr.text.trim().split("\n");
                root.error = (lines[lines.length - 1] || "kk-prep failed").replace(/^kk-prep:\s*/, "");
                Quickshell.execDetached(["notify-send", "-a", "wallpaper", "couldn't develop that one", root.error]);
            }
            if (root._queued !== "") {
                const f = root._queued, force = root._queuedForce, model = root._queuedModel;
                root._queued = "";
                Qt.callLater(() => root.prep(f, force, model));
            }
        }
    }

    Process {
        id: themeProc
        onExited: Theme.reload()
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                try {
                    root.library = JSON.parse(text.trim().split("\n").pop() || "[]");
                } catch (e) {
                    root.library = [];
                }
            }
        }
        onExited: {
            root.listing = false;
            const p = root._pendingStep;
            root._pendingStep = 0;
            if (p !== 0 && root.library.length) Qt.callLater(() => p === 2 ? root.random() : root.step(p));
        }
    }

    // let the ink finish before the video replaces it
    Timer {
        id: videoStart
        interval: 0
        onTriggered: root.startVideo()
    }

    Process {
        id: mpv
        onRunningChanged: {
            if (running) settle.restart();
            else root.videoReady = false;
        }
    }
    Timer {
        id: settle
        interval: 1200
        onTriggered: root.videoReady = mpv.running
    }

    IpcHandler {
        target: "wall"
        function set(path: string): void { root.set(path); }
        function next(): void { root.step(1); }
        function prev(): void { root.step(-1); }
        function random(): void { root.random(); }
        function redetect(model: string): void { root.redetect(model); }
        function current(): string { return root.current ? root.current.source : ""; }
    }
}
