pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// the wallpaper engine's brain. the pictures themselves are drawn by modules/wallpaper.
//
// a switch never waits for anything slow:
//   0 ms     the picture itself is on screen (decoded by qt at screen size)
//   ~200 ms  kk-prep --fast: colours → kk-theme recolours the desktop
//   later    kk-prep --ai at idle priority: subject cut-out + depth slide in quietly
//            (no second transition). on battery this waits for the charger unless
//            aiOnBattery is set.
Singleton {
    id: root

    property var current: null          // meta.json of what's on screen
    property int generation: 0          // +1 per new wallpaper: screens play a transition
    signal refined()                    // same wallpaper, more detail (cut-out, depth)
    property bool preparing: false      // the ai stage is working
    property bool aiMissing: false      // kk-prep said the ai isn't installed
    property string aiError: ""         // the last thing that went wrong in the ai stage
    // one line for settings: what the subject detection is doing for this wallpaper
    readonly property string subjectStatus:
        aiMissing ? "not installed"
        : preparing ? "looking…"
        : current === null ? ""
        : current.mask ? "found"
        : (current.stage || 0) >= 2 ? "none in this picture"
        : aiPending !== "" ? "waiting for the charger"
        : aiError !== "" ? aiError
        : "not yet"
    property string error: ""
    property var library: []            // picker contents, from `kk-prep --list`
    property bool listing: false

    readonly property bool isVideo: current !== null && current.kind === "video" && current.video !== ""
    readonly property bool videoAllowed: !Power.onBattery || Config.s.videoOnBattery
    property bool videoReady: false     // mpvpaper is up: our own layer can step aside
    // the subject's cut-out is ready, so desktop widgets can be tucked behind it.
    // (not for live wallpapers once they play: the subject moves, the mask doesn't)
    readonly property bool depthReady: current !== null && !!current.mask && !videoReady

    // the biggest screen's long edge, so nothing is decoded or stored bigger than it needs
    readonly property int maxEdge: {
        let m = 1920;
        for (const s of Quickshell.screens)
            m = Math.max(m, Math.round(Math.max(s.width, s.height) * (s.devicePixelRatio || 1)));
        return Math.min(m, 3840);
    }

    function isVideoPath(f: string): bool {
        return /\.(gif|mp4|webm|mkv|mov|avi|m4v)$/i.test(f);
    }

    // ---------------------------------------------------------------- switching
    function set(file: string) {
        if (!file) return;
        error = "";
        const known = cachedMeta(file);
        if (known) {
            show(known);
        } else if (!isVideoPath(file)) {
            show({ source: file, name: file.split("/").pop().replace(/\.[^.]+$/, ""), kind: "image",
                   display: file, thumb: file, dir: "", depth: "", ink: "", mask: "", video: "",
                   width: 0, height: 0, stage: 0 });
        }
        fast.want = file;
        if (!fast.running) fast.go(file);
    }

    function cachedMeta(file: string): var {
        const last = Store.s.wallMeta;
        if (last && last.source === file && last.display) return last;
        const e = library.find(w => w.path === file);
        return e && e.meta && e.meta.display ? e.meta : null;
    }

    function show(meta: var) {
        if (current !== null) Sounds.play("swoosh", 800);   // not at login, only on a real switch
        stopVideo();
        current = meta;
        generation++;
        Store.s.wallpaper = meta.source;
        if (meta.dir) Store.s.wallMeta = meta;
        if (isVideo) videoStart.restart();
        pointAt(meta);
    }
    // same picture, more known about it: no transition, just the new parts
    function refine(meta: var) {
        current = meta;
        if (meta.dir) Store.s.wallMeta = meta;
        refined();
        pointAt(meta);
    }
    // ~/.cache/kajukatli/current → this wallpaper's bundle. the terminal greeting shows its
    // subject (cut.png) as fastfetch's logo; an older bundle gets its cut-out made here
    function pointAt(meta: var) {
        if (!meta || !meta.dir) return;
        Quickshell.execDetached(["sh", "-c",
            'c="${XDG_CACHE_HOME:-$HOME/.cache}/kajukatli"; ln -sfn "$1" "$c/current"; '
            + '[ -f "$1/mask.png" ] && [ ! -f "$1/cut.png" ] && exec nice -n 19 "$2" --cut "$1"; true',
            "sh", meta.dir, Config.bin + "kk-prep"]);
    }
    function sameSource(meta: var): bool {
        return current !== null && meta && current.source === meta.source;
    }

    function redetect(model: string) {
        if (current) runAi(current.source, model, true);
    }

    function theme(dir: string) {
        if (!dir) return;
        themeProc.want = dir;
        if (!themeProc.running) { themeProc.command = [Config.bin + "kk-theme", dir]; themeProc.running = true; }
    }

    // ---------------------------------------------------------------- the ai stage
    property string aiPending: ""
    function runAi(file: string, model: string, force: bool) {
        if (aiMissing && !force) return;
        if (Power.onBattery && !Config.s.aiOnBattery && !force) { aiPending = file; return; }
        aiPending = "";
        const cmd = ["nice", "-n", "19", "ionice", "-c", "3", Config.bin + "kk-prep", file, "--ai"];
        if (model) cmd.push("--model", model);
        if (force) cmd.push("--force");
        ai.want = cmd;
        if (!ai.running) ai.go();
    }
    Connections {
        target: Power
        function onOnBatteryChanged() {
            if (!Power.onBattery && root.aiPending !== "") root.runAi(root.aiPending, "", false);
        }
    }

    // ---------------------------------------------------------------- a new one by itself
    Timer {
        interval: 60 * 1000
        repeat: true
        running: Config.s.wallRotate !== "off"
        onTriggered: {
            const period = Config.s.wallRotate === "hourly" ? 3600e3 : 86400e3;
            const now = Date.now();
            if (Store.s.rotatedAt === 0) { Store.s.rotatedAt = now; return; }
            // daily: at the first minute of a new day you're here for
            const due = Config.s.wallRotate === "daily" ? new Date(Store.s.rotatedAt).toDateString() !== new Date(now).toDateString()
                                                         : now - Store.s.rotatedAt >= period;
            if (!due) return;
            Store.s.rotatedAt = now;
            root.random();
        }
    }

    // ---------------------------------------------------------------- library
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
    // ---------------------------------------------------------------- the rest of the library
    // on the charger, one wallpaper at a time at idle priority: so every switch has its ink
    // map, cut-out and depth ready, instead of working them out while you watch
    property var backlog: []
    function queueBacklog() {
        backlog = library.filter(w => w.kind === "image" && !(w.meta && (w.meta.stage || 0) >= 2)).map(w => w.path);
        backlogTimer.restart();
    }
    Timer {
        id: backlogTimer
        interval: 20000
        repeat: true
        running: root.backlog.length > 0 && !Power.onBattery && !root.aiMissing
        onTriggered: {
            if (ai.running || fast.running || root.backlog.length === 0) return;
            const next = root.backlog[0];
            root.backlog = root.backlog.slice(1);
            bg.command = ["nice", "-n", "19", "ionice", "-c", "3", Config.bin + "kk-prep", next];
            bg.running = true;
        }
    }
    Process {
        id: bg
        onExited: if (root.backlog.length === 0) root.refreshLibrary()
    }

    // kk-getwalls: fresh anime wallpapers from wallhaven, from settings
    property bool fetching: false
    property string fetchNote: ""
    function fetchAnime() {
        if (getter.running) return;
        fetching = true;
        fetchNote = "downloading…";
        getter.running = true;
    }
    Process {
        id: getter
        command: [Config.bin + "kk-getwalls", "16"]
        stdout: StdioCollector { id: getOut }
        onExited: code => {
            root.fetching = false;
            const l = getOut.text.trim().split("\n");
            root.fetchNote = code === 0 ? l[l.length - 1] : "couldn't reach wallhaven";
            root.refreshLibrary();
        }
    }

    function refreshLibrary() {
        if (listProc.running) return;
        listing = true;
        listProc.command = [Config.bin + "kk-prep", "--list", Config.wallpaperDir];
        listProc.running = true;
    }

    // ---------------------------------------------------------------- live wallpapers
    function startVideo() {
        if (!isVideo || !videoAllowed || mpv.running) return;
        mpv.command = ["mpvpaper", "-p", "-o", "no-audio loop hwdec=auto-safe panscan=1.0 vf=fps=30", "ALL", current.video];
        mpv.running = true;
    }
    function stopVideo() {
        videoStart.stop();
        settle.stop();
        videoReady = false;      // our still frame comes back first…
        // …then the video goes, once our layer has had time to put the picture back on screen:
        // killing it at once leaves a black gap, which is the screen "turning off" on a switch
        if (mpv.running) mpvStop.restart();
    }
    onVideoAllowedChanged: videoAllowed ? startVideo() : stopVideo()

    // restore the last wallpaper on login (cached, so this is instant)
    Connections {
        target: Store
        function onReadyChanged() { root.restore(); }
    }
    Component.onCompleted: restore()
    // the last one; if that's gone (or nothing was saved), any from the folder: never a blank screen
    function restore() {
        if (!Store.ready || root.current !== null) return;
        refreshLibrary();
        if (Store.s.wallpaper !== "") set(Store.s.wallpaper);
        else random();
    }

    function lastJson(text: string): var {
        const lines = text.trim().split("\n");
        try { return JSON.parse(lines[lines.length - 1]); } catch (e) { return null; }
    }

    // ---------------------------------------------------------------- processes
    Process {
        id: fast
        property string want: ""
        property string file: ""
        function go(f: string) {
            file = f;
            command = [Config.bin + "kk-prep", f, "--fast", "--max-edge", String(root.maxEdge)];
            running = true;
        }
        stdout: StdioCollector { id: fastOut }
        stderr: StdioCollector { id: fastErr }
        onExited: code => {
            const meta = code === 0 ? root.lastJson(fastOut.text) : null;
            if (file === want) {
                if (meta) {
                    if (root.sameSource(meta) && meta.kind !== "video") root.refine(meta);
                    else root.show(meta);
                    root.theme(meta.dir);
                    if ((meta.stage || 1) < 2) root.runAi(meta.source, "", false);
                } else {
                    const lines = fastErr.text.trim().split("\n");
                    root.error = (lines[lines.length - 1] || "kk-prep failed").replace(/^kk-prep:\s*/, "");
                    Quickshell.execDetached(["notify-send", "-a", "wallpaper", "couldn't open that one", root.error]);
                }
            }
            if (want !== file) Qt.callLater(() => fast.go(fast.want));   // the newest request wins
        }
    }

    Process {
        id: ai
        property var want: null
        function go() {
            command = want;
            want = null;
            root.preparing = true;
            running = true;
        }
        stdout: StdioCollector { id: aiOut }
        stderr: StdioCollector { id: aiErr }
        onExited: code => {
            root.preparing = false;
            const lines = aiErr.text.trim().split("\n");
            root.aiError = code !== 0 && code !== 3 ? (lines[lines.length - 1] || "failed").replace(/^kk-prep:\s*(failed:\s*)?/, "") : "";
            if (code === 3) root.aiMissing = true;
            else if (code === 0) {
                const meta = root.lastJson(aiOut.text);
                if (meta && root.sameSource(meta)) root.refine(Object.assign({}, meta, { display: root.current.display }));
            }
            if (ai.want) Qt.callLater(() => ai.go());
        }
    }

    Process {
        id: themeProc
        property string want: ""
        onExited: {
            Theme.reload();
            if (want !== command[1]) Qt.callLater(() => { themeProc.command = [Config.bin + "kk-theme", themeProc.want]; themeProc.running = true; });
        }
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
                root.queueBacklog();
            }
        }
        onExited: {
            root.listing = false;
            const p = root._pendingStep;
            root._pendingStep = 0;
            if (p !== 0 && root.library.length) Qt.callLater(() => p === 2 ? root.random() : root.step(p));
        }
    }

    // let the fade finish before the video replaces it
    Timer {
        id: videoStart
        interval: 600
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
        id: mpvStop
        interval: 450
        onTriggered: if (!root.videoReady) mpv.running = false
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
        function refresh(): void { root.refreshLibrary(); }
    }
}
