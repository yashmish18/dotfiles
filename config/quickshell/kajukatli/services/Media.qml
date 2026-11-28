pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// the player everything else shows: the one playing, else the last one that played.
// also keeps the position ticking and fetches synced lyrics from lrclib.net.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var _last: null            // the last real music player that played
    property var pinned: null           // chosen in the media panel; else whatever's playing
    function pick(p: var) { pinned = p; }
    function isBrowser(p: var): bool {
        return p !== null && /firefox|chrom|brave|vivaldi|edge|opera|zen|youtube/i.test((p.identity || "") + " " + (p.desktopEntry || "") + " " + (p.dbusName || ""))
    }
    // a music player beats a browser (which reports "playing" for any tab with sound, often
    // without artist or cover), and the one already chosen stays while it keeps playing
    readonly property var player: {
        if (pinned && players.indexOf(pinned) !== -1) return pinned;
        const playing = players.filter(p => p.isPlaying);
        const music = playing.filter(p => !isBrowser(p));
        if (music.length) return music.indexOf(_last) !== -1 ? _last : music[0];
        if (playing.length) return playing[0];
        if (_last && players.indexOf(_last) !== -1) return _last;
        return players.find(p => !isBrowser(p)) || players[0] || null;
    }
    // later, not inside the change: `player` reads _last, so writing it here at once is a binding loop
    onPlayerChanged: Qt.callLater(() => { if (root.player && root.player.isPlaying && !root.isBrowser(root.player)) root._last = root.player; })

    readonly property bool active: player !== null
    readonly property bool playing: player !== null && player.isPlaying
    // after the shell reloads itself quickshell can leave trackTitle & co. empty although the
    // player's metadata is all there: read that too
    function meta(key: string): string {
        const v = player && player.metadata ? player.metadata[key] : undefined;
        return v === undefined || v === null ? "" : String(Array.isArray(v) ? v.join(", ") : v);
    }
    readonly property string trackName: player ? (player.trackTitle || meta("xesam:title")) : ""   // "" = unknown
    readonly property string title: player ? (trackName || player.identity || "") : ""
    readonly property string artist: player ? (player.trackArtist || meta("xesam:artist")) : ""
    readonly property string album: player ? (player.trackAlbum || meta("xesam:album")) : ""
    readonly property string art: player ? (player.trackArtUrl || meta("mpris:artUrl")) : ""
    readonly property real length: player && player.lengthSupported && player.length > 0 ? player.length : Number(meta("mpris:length") || 0) / 1e6
    property real position: 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    function toggle() {
        if (!player) return;
        if (player.canTogglePlaying) player.togglePlaying();
        else if (player.isPlaying && player.canPause) player.pause();
        else if (player.canPlay) player.play();
    }
    function next() { if (player && player.canGoNext) player.next(); }
    function prev() { if (player && player.canGoPrevious) player.previous(); }
    function seek(frac: real) {
        if (player && player.canSeek && length > 0) player.position = frac * length;
    }
    function fmt(sec: real): string {
        if (!(sec >= 0)) return "0:00";
        const m = Math.floor(sec / 60), s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // mpris doesn't push position updates; ask for them while something plays and something
    // on screen shows the position (consumers), twice a second
    Timer {
        interval: 500
        repeat: true
        running: root.playing && root.consumers > 0
        triggeredOnStart: true
        onTriggered: {
            const p = root.player;
            if (!p) return;
            p.positionChanged();
            root.position = p.position;
        }
    }
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged() { root.position = 0; }
        function onPositionChanged() { if (root.player) root.position = root.player.position; }
    }

    // a fresh process per request, destroyed when done. reusing one Process meant a new request
    // could be swallowed while the old one was still dying, or receive its leftover output.
    Component {
        id: jobC
        Process {
            id: job
            property var done
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    job.done(text);
                    job.destroy();
                }
            }
        }
    }
    function run(cmd: var, done: var) { jobC.createObject(root, { command: cmd, done: done }); }

    // ---------------------------------------------------------------- the cover's colour
    // the player ui takes its accent from the album art. ColorQuantizer is made at runtime, so an
    // older quickshell without it just keeps the theme's colour instead of failing to load.
    property color artColor: Theme.primary
    property color artText: Theme.primaryText
    // the cover's colour, once worked out (Theme tints the accent with it while music plays)
    property bool artReady: false
    property color artTint: "#888888"
    property color artTintText: "#000000"
    property var _quant: null
    // ColorQuantizer only reads local files. mpris gives remote URLs for streaming players
    // (spotify's i.scdn.co among them), which made it log a failed image load on every track.
    // fetch those once into a small cache file instead of pointing it at the URL.
    // one file per url, so a late download can't overwrite the current track's cover
    readonly property string coverDir: Config.home + "/.cache/kajukatli/covers"
    // what every cover image shows: a local file once downloaded (qt doesn't retry a remote
    // image that failed once), the plain url only if the download failed
    property string coverFor: ""
    property string coverPath: ""
    readonly property string cover: {
        if (art === "" || art.charAt(0) === "/" || art.indexOf("file://") === 0) return art;
        return coverFor === art ? coverPath : "";
    }
    function fetchCover(url: string) {
        const file = coverDir + "/" + Qt.md5(url);
        // download to a private temp file and rename; keep only the newest 12 covers
        run(["sh", "-c", 'mkdir -p "$3" && { [ -s "$2" ] || { curl -sfL --max-time 8 -o "$2.$$" "$1" && mv -f "$2.$$" "$2"; } || { rm -f "$2.$$"; exit 1; }; } '
             + '&& touch "$2" && echo ok; ls -t "$3" | tail -n +13 | while read -r f; do rm -f "$3/$f"; done',
             "sh", url, file, coverDir], out => {
            if (url !== root.art) return;
            const ok = out.trim() === "ok";
            root.coverPath = ok ? "file://" + file : url;
            root.coverFor = url;
            if (ok && root._quant) root._quant.source = "file://" + file;
        });
    }
    function setArtSource(u: string): void {
        const local = u.indexOf("file://") === 0 ? u : u.charAt(0) === "/" ? "file://" + u : "";
        if (u !== "" && local === "") fetchCover(u);
        else if (_quant) _quant.source = local;
    }
    Component.onCompleted: {
        try {
            _quant = Qt.createQmlObject('import Quickshell; ColorQuantizer { depth: 3; rescaleSize: 48 }', root, "artcolour");
            _quant.colorsChanged.connect(pickArtColor);
            if (art !== "") setArtSource(art);
        } catch (e) {
            _quant = null;
        }
    }
    onArtChanged: {
        artReady = false;
        setArtSource("");
        if (art === "") { artColor = Theme.primary; artText = Theme.primaryText; }
        setArtSource(art);
    }
    function pickArtColor() {
        const cs = _quant ? _quant.colors : [];
        let best = null, score = 0.1;
        for (let i = 0; i < cs.length; i++) {
            const c = cs[i];
            const sc = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.5);
            if (sc > score) { best = c; score = sc; }
        }
        if (!best) { artColor = Theme.primary; artText = Theme.primaryText; return; }
        const dark = Theme.dark;
        artColor = Qt.hsla(best.hslHue, Math.max(0.45, Math.min(0.85, best.hslSaturation)), dark ? 0.72 : 0.42, 1);
        artText = Qt.hsla(best.hslHue, 0.5, dark ? 0.14 : 0.97, 1);
        artTint = artColor;
        artTintText = artText;
        artReady = true;
    }

    // ---------------------------------------------------------------- lyrics
    property var lines: []            // [{ t: seconds, text }]
    property bool synced: false
    property string lyricsState: ""   // "", loading, none, ready
    property var _cache: ({})
    readonly property string trackKey: artist + "\u0001" + title + "\u0001" + album
    property int lyricsReq: 0         // only the newest request may write
    property var _cacheOrder: []
    function remember(key: string, r: var) {
        if (_cache[key] === undefined) _cacheOrder.push(key);
        _cache[key] = r;
        while (_cacheOrder.length > 40) delete _cache[_cacheOrder.shift()];
    }
    readonly property int lineIndex: {
        if (!synced || lines.length === 0) return -1;
        const p = position + 0.25;
        let lo = 0, hi = lines.length - 1, ans = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (lines[mid].t <= p) { ans = mid; lo = mid + 1; } else hi = mid - 1;
        }
        return ans;
    }
    property int consumers: 0         // widgets showing the position (ticks it)
    property int lyricsUsers: 0       // widgets showing lyrics; nothing is fetched without one

    onTrackKeyChanged: {
        lyricsReq++;
        lines = [];
        synced = false;
        lyricsState = "";
        lyricsTimer.restart();
    }
    // switching lyrics or online lyrics on takes effect at once
    Connections {
        target: Config.s
        function onNetworkLyricsChanged() { lyricsTimer.restart(); }
        function onLyricsChanged() { lyricsTimer.restart(); }
    }
    // qs -c kajukatli ipc call media status
    IpcHandler {
        target: "media"
        function status(): string {
            return JSON.stringify({ player: root.player ? root.player.identity : null, playing: root.playing, title: root.title, artist: root.artist,
                                    art: root.art, cover: root.cover, lyrics: root.lyricsState, lines: root.lines.length, lyricsUsers: root.lyricsUsers,
                                    online: Config.s.networkLyrics,
                                    position: root.position, length: root.length, live: root.player ? root.player.position : 0, synced: root.synced, line: root.lineIndex, ticking: root.consumers,
                                    lineAt: root.lineIndex >= 0 ? root.lines[root.lineIndex].t : -1,
                                    raw: root.player ? { title: root.player.trackTitle, keys: Object.keys(root.player.metadata || {}), dbus: root.player.dbusName } : null,
                                    all: root.players.map(p => ({ id: p.dbusName, playing: p.isPlaying, title: p.trackTitle })) });
        }
        function toggle(): void { root.toggle(); }
    }
    onLyricsUsersChanged: if (lyricsUsers > 0) lyricsTimer.restart()

    Timer {
        id: lyricsTimer
        interval: 600       // let the metadata settle (players send it in pieces)
        onTriggered: root.fetchLyrics()
    }

    function parseLrc(text: string): var {
        const out = [];
        const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        for (const raw of text.split("\n")) {
            const stamps = [];
            let m;
            re.lastIndex = 0;
            while ((m = re.exec(raw)) !== null) stamps.push(parseInt(m[1]) * 60 + parseFloat(m[2]));
            const t = raw.replace(re, "").trim();
            for (const s of stamps) out.push({ t: s, text: t });
        }
        out.sort((a, b) => a.t - b.t);
        return out;
    }

    function useResult(r: var) {
        if (r && r.syncedLyrics) {
            lines = parseLrc(r.syncedLyrics);
            synced = true;
            lyricsState = "ready";
        } else if (r && r.plainLyrics) {
            lines = r.plainLyrics.split("\n").map(t => ({ t: 0, text: t }));
            synced = false;
            lyricsState = "ready";
        } else {
            lines = [];
            synced = false;
            lyricsState = "none";
        }
    }

    // youtube & co. in a browser report the video's title ("Artist - Song (Official Video)")
    // and the channel ("ArtistVEVO") instead of song and artist. clean that up for the search.
    readonly property bool fromBrowser: player !== null && /firefox|chrom|brave|vivaldi|edge|opera|zen|youtube/i.test((player.identity || "") + " " + (player.desktopEntry || ""))
    readonly property var song: {
        let t = trackName, a = artist || "";
        const junk = /\s*[\(\[][^\)\]]*(official|lyric|audio|video|visuali[sz]er|music|mv|m\/v|hd|hq|4k|remaster|live|explicit|clean|full|version|edit)[^\)\]]*[\)\]]/gi;
        t = t.replace(junk, "").replace(/\s*\|.*$/, "").replace(/\s+(ft\.?|feat\.?|featuring)\s.*$/i, "");
        a = a.replace(/vevo$/i, "").replace(/\s*-\s*topic$/i, "").replace(/\s*official$/i, "").trim();
        const m = /^(.+?)\s+[-–—]\s+(.+)$/.exec(t);
        if (m && (fromBrowser || a === "" || m[1].toLowerCase().indexOf(a.toLowerCase()) !== -1 || a.toLowerCase().indexOf(m[1].toLowerCase()) !== -1)) {
            a = m[1].replace(/\s+(ft\.?|feat\.?|&|x)\s.*$/i, "");
            t = m[2];
        }
        return { title: t.replace(/["“”]/g, "").trim(), artist: a.trim() };
    }

    function fetchLyrics() {
        // (`title` falls back to the app's name: searching for that returned some other song's lyrics)
        if (!Config.s.lyrics || lyricsUsers <= 0 || trackName === "") {
            lines = [];
            lyricsState = "";
            return;
        }
        const req = ++lyricsReq, key = trackKey;
        if (_cache[key] !== undefined) { useResult(_cache[key]); return; }
        lyricsState = "loading";
        lines = [];
        // snapshot the track now: later steps must not search for whatever is playing by then
        const q = { title: song.title, artist: song.artist, album: album, length: length, browser: fromBrowser };
        const dir = (Config.s.localLyricsDir || "").replace(/^~/, Config.home);
        // passed as separate arguments, so no quoting is needed (escaping here broke "Don't")
        run(["sh", "-c",
             "d=\"$1\"; a=\"$2\"; t=\"$3\"; "
             + "for f in \"$d/$a - $t.lrc\" \"$d/$t.lrc\" \"$d/$a - $t.txt\" \"$d/$t.txt\"; do "
             + "[ -f \"$f\" ] && { cat \"$f\"; exit 0; }; done",
             "sh", dir, q.artist.replace(/\//g, "-"), q.title.replace(/\//g, "-")], out => {
            if (req !== root.lyricsReq) return;
            const text = out.trim();
            if (text !== "") root.finish(key, /^\[\d+:/m.test(text) ? { syncedLyrics: text } : { plainLyrics: text });
            else if (Config.s.networkLyrics) root.lookup(req, key, q, false);
            else root.useResult(null);
        });
    }

    function finish(key: string, r: var) {
        if (r) remember(key, r);     // misses aren't cached: being offline once must not stick
        useResult(r);
    }

    // the search returns every version of a song (edits, remixes, sped up): timed lyrics are
    // only right for a recording of about the same length. taking the first one put another
    // version's timing on the track. no match: show the words without timing
    function best(list: var, length: real, browser: bool): var {
        const off = x => length > 0 && x.duration > 0 ? Math.abs(x.duration - length) : 1e6;
        const sorted = list.filter(x => x && (x.syncedLyrics || x.plainLyrics)).sort((a, b) => off(a) - off(b));
        const timed = sorted.find(x => x.syncedLyrics && (length <= 0 || off(x) <= (browser ? 6 : 3)));
        if (timed) return timed;
        const any = sorted[0];
        return any ? { plainLyrics: any.plainLyrics || any.syncedLyrics.replace(/\[[0-9:.]+\] ?/g, "") } : null;
    }

    function lookup(req: int, key: string, q: var, search: bool) {
        const args = ["curl", "-sfL", "--max-time", "8", "-G", "https://lrclib.net/api/" + (search ? "search" : "get"),
                      "-H", "User-Agent: desktop-shell/1.0"];
        if (search) args.push("--data-urlencode", "q=" + q.artist + " " + q.title);
        else {
            args.push("--data-urlencode", "track_name=" + q.title, "--data-urlencode", "artist_name=" + q.artist);
            // a video's length includes intros and outros: only trust it from music players
            if (!q.browser && q.album !== "") args.push("--data-urlencode", "album_name=" + q.album);
            if (!q.browser && q.length > 0) args.push("--data-urlencode", "duration=" + Math.round(q.length));
        }
        run(args, out => {
            if (req !== root.lyricsReq) return;
            let r = null;
            try { r = JSON.parse(out); } catch (e) {}
            if (Array.isArray(r)) r = root.best(r, q.length, q.browser);
            else if (r && !r.syncedLyrics && !r.plainLyrics) r = null;
            if (!r && !search) root.lookup(req, key, q, true);
            else root.finish(key, r);
        });
    }
}
