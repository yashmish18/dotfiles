pragma Singleton
import QtQuick
import Quickshell

// little sounds for little moments: volume, notifications, lock / unlock, a wrong password,
// the charger, a new wallpaper. made by sounds/make.py, played with pipewire's pw-play.
// settings → sound turns them off or down.
Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir + "/sounds/"
    property var last: ({})

    // `gap` keeps a held key or a dragged slider from turning into a buzz
    function play(name: string, gap: int) {
        if (!Config.s.sounds) return;
        const now = Date.now();
        if (now - (last[name] || 0) < (gap || 60)) return;
        last[name] = now;
        Quickshell.execDetached(["pw-play", "--volume", String(Math.max(0, Math.min(1, Config.s.soundVolume))), dir + name + ".wav"]);
    }
}
