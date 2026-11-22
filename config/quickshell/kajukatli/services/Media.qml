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
    property var _last: null
    property var pinned: null           // chosen in the media panel; else whatever's playing
    function pick(p) { pinned = p; }
    readonly property var player: {
        if (pinned && players.indexOf(pinned) !== -1) return pinned;
        const playing = players.find(p => p.isPlaying);
        if (playing) return playing;
        if (_last && players.indexOf(_last) !== -1) return _last;
        return players.length ? players[0] : null;
    }
    onPlayerChanged: if (player && player.isPlaying) _last = player

    readonly property bool active: player !== null
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string album: player ? (player.trackAlbum || "") : ""
    readonly property string art: player ? (player.trackArtUrl || "") : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    property real position: 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying(); }
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
            root.player.positionChanged();
            root.position = root.player.position;
        }
    }
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged() { root.position = 0; }
        function onPositionChanged() { root.position = root.player.position; }
    }

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
    Component.onCompleted: {
        try {
            _quant = Qt.createQmlObject('import Quickshell; ColorQuantizer { depth: 3; rescaleSize: 48 }', root, "artcolour");
            _quant.colorsChanged.connect(pickArtColor);
            if (art !== "") _quant.source = art;
        } catch (e) {
            _quant = null;
        }
    }
    onArtChanged: {
        artReady = false;
        if (_quant && art !== "") _quant.source = art;
        else if (art === "") { artColor = Theme.primary; artText = Theme.primaryText; }
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
    readonly property string trackKey: artist + "\u0001" + title
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

    onTrackKeyChanged: lyricsTimer.restart()
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

    function useResult(r) {
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
        let t = title || "", a = artist || "";
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
        if (!Config.s.lyrics || lyricsUsers <= 0 || title === "") {
            lines = [];
            lyricsState = "";
            return;
        }
        const key = trackKey;
        if (_cache[key] !== undefined) { useResult(_cache[key]); return; }
        lyricsState = "loading";
        lines = [];
        localLyrics.key = key;
        const dir = (Config.s.localLyricsDir || "").replace(/^~/, Config.home);
        const artist = song.artist.replace(/'/g, "'\\''");
        const track = song.title.replace(/'/g, "'\\''");
        localLyrics.command = ["sh", "-c",
            "d=\"$1\"; a=\"$2\"; t=\"$3\"; "
            + "for f in \"$d/$a - $t.lrc\" \"$d/$t.lrc\" \"$d/$a - $t.txt\" \"$d/$t.txt\"; do "
            + "[ -f \"$f\" ] && { cat \"$f\"; exit 0; }; done",
            "sh", dir, artist, track];
        localLyrics.running = true;
        if (!Config.s.networkLyrics) return;
        if (lyricsProc.running) lyricsProc.running = false;
        lyricsProc.key = key;
        const args = ["curl", "-sfL", "--max-time", "8", "-G", "https://lrclib.net/api/get",
                      "-H", "User-Agent: desktop-shell/1.0",
                      "--data-urlencode", "track_name=" + song.title,
                      "--data-urlencode", "artist_name=" + song.artist];
        // a video's length includes intros and outros: only trust it from music players
        if (!fromBrowser && album !== "") args.push("--data-urlencode", "album_name=" + album);
        if (!fromBrowser && length > 0) args.push("--data-urlencode", "duration=" + Math.round(length));
        lyricsProc.command = args;
        lyricsProc.searched = false;
        lyricsProc.running = true;
    }

    Process {
        id: localLyrics
        property string key: ""
        stdout: StdioCollector {
            id: localLyricsOut
            onStreamFinished: {
                const text = localLyricsOut.text.trim();
                if (text === "") {
                    if (!Config.s.networkLyrics) root._cache[localLyrics.key] = null;
                    if (!Config.s.networkLyrics && localLyrics.key === root.trackKey) root.useResult(null);
                    return;
                }
                const r = text.indexOf("[") === 0 ? { syncedLyrics: text } : { plainLyrics: text };
                root._cache[localLyrics.key] = r;
                if (localLyrics.key === root.trackKey) {
                    if (lyricsProc.running) lyricsProc.running = false;
                    root.useResult(r);
                }
            }
        }
    }

    Process {
        id: lyricsProc
        property string key: ""
        property bool searched: false
        stdout: StdioCollector { id: lyricsOut }
        onExited: code => {
            let r = null;
            try { r = code === 0 ? JSON.parse(lyricsOut.text) : null; } catch (e) { r = null; }
            if (Array.isArray(r)) r = r.find(x => x.syncedLyrics) || r[0] || null;
            if (!r && !searched) {
                // the exact lookup wants matching album / duration. a loose search often finds it
                searched = true;
                command = ["curl", "-sfL", "--max-time", "8", "-G", "https://lrclib.net/api/search",
                           "-H", "User-Agent: desktop-shell/1.0",
                           "--data-urlencode", "q=" + root.song.artist + " " + root.song.title];
                Qt.callLater(() => lyricsProc.running = true);
                return;
            }
            root._cache[key] = r;
            if (key === root.trackKey) root.useResult(r);
        }
    }
}
