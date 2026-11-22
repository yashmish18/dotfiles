pragma Singleton
import QtQuick
import Quickshell

// the desktop timer: 25 minutes of work, a chime, 5 minutes off. or any length you scroll to.
Singleton {
    id: root

    property int minutes: Config.s.timerMinutes
    property bool running: false
    property bool onBreak: false
    property real endsAt: 0          // ms since epoch while running
    property real leftMs: minutes * 60000   // what's left while paused
    property real now: Date.now()

    readonly property real remaining: running ? Math.max(0, endsAt - now) : leftMs
    readonly property real total: (onBreak ? Config.s.timerBreak : minutes) * 60000
    readonly property real progress: total > 0 ? 1 - remaining / total : 0
    readonly property string text: {
        const s = Math.ceil(remaining / 1000);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    function toggle() {
        if (running) { leftMs = Math.max(0, endsAt - Date.now()); running = false; }
        else { endsAt = Date.now() + leftMs; now = Date.now(); running = true; }
    }
    function reset() {
        running = false;
        onBreak = false;
        leftMs = minutes * 60000;
    }
    function nudge(deltaMin: int) {
        if (running) return;
        Config.s.timerMinutes = Math.max(1, Math.min(180, Config.s.timerMinutes + deltaMin));
        if (!onBreak) leftMs = Config.s.timerMinutes * 60000;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            root.now = Date.now();
            if (root.remaining > 0) return;
            Sounds.play("chime", 0);
            const wasBreak = root.onBreak;
            Quickshell.execDetached(["notify-send", "-a", "Timer", wasBreak ? "Break's over" : "Time's up",
                                     wasBreak ? root.minutes + " minutes on the clock" : Config.s.timerBreak + " minutes off"]);
            root.onBreak = !wasBreak;
            root.leftMs = (root.onBreak ? Config.s.timerBreak : root.minutes) * 60000;
            root.endsAt = Date.now() + root.leftMs;
            root.running = root.onBreak;   // the break starts by itself; work waits for you
        }
    }
}
