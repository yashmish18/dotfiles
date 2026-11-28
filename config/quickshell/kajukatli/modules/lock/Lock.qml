import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services

// the lock. one shared state, one surface per screen (LockSurface.qml draws it).
// uses the wayland session-lock protocol, so if the shell ever crashes while locked,
// the compositor keeps the screen locked rather than showing your desktop.
Scope {
    id: root

    property string password: ""
    property string phase: "idle"     // idle · checking · wrong · ok
    property int attempts: 0
    property string note: ""
    readonly property bool locked: lock.locked
    signal woke()       // back from sleep: every surface takes the keyboard again

    // "is it locked" lives on disk, per hyprland session, so it survives the shell restarting.
    //   .on     exists while locked: a restarted or reloaded shell takes the lock back
    //   .booted the "start in the lock screen" lock (KK_LOCK_AT_START) has been used. that
    //           variable stays set all session, so without this every shell restart re-locked
    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/kk-lock-" + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "x")
    Process {
        running: true
        command: ["sh", "-c", 'if [ -e "$1.on" ] || { [ "$KK_LOCK_AT_START" = 1 ] && [ ! -e "$1.booted" ]; }; then echo lock; fi; : > "$1.booted"', "sh", root.marker]
        stdout: StdioCollector { onStreamFinished: if (text.trim() === "lock") root.lockNow() }
    }

    function lockNow() {
        if (!lock.locked) Sounds.play("lock", 500);
        if (lock.locked) return;
        Store.s.frame = Store.s.frame + 1;
        password = "";
        phase = "idle";
        attempts = 0;
        note = "";
        Ui.closeAll();
        lock.locked = true;
        Quickshell.execDetached(["touch", marker + ".on"]);
    }

    function type(s: string) {
        if (phase === "checking" || phase === "ok") return;
        if (phase === "wrong") phase = "idle";
        password += s;
    }
    function erase(all: bool) {
        if (phase === "checking" || phase === "ok") return;
        password = all ? "" : password.slice(0, -1);
    }
    function submit() {
        if (password === "" || pam.active || phase === "ok") return;
        phase = "checking";
        if (!pam.start()) fail("couldn't ask pam. is the shell's pam file there?");
    }
    function fail(msg: string) {
        Sounds.play("error", 300);
        attempts++;
        phase = "wrong";
        password = "";
        note = msg !== "" ? msg : attempts >= 3 ? "take a breath. try again." : "not quite.";
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellDir + "/pam"
        config: "password.conf"
        onPamMessage: {
            if (responseRequired) respond(root.password);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.phase = "ok";
                root.note = "";
                Sounds.play("unlock", 500);
                release.start();
            } else {
                root.fail(result === PamResult.MaxTries ? "too many tries. wait a little." : "");
            }
        }
        // (this used to be a binding that called fail() the moment the shell started)
    }

    // let the fade-out play before the lock lifts
    Timer {
        id: release
        interval: 520
        onTriggered: {
            lock.locked = false;
            Quickshell.execDetached(["rm", "-f", root.marker + ".on"]);
            root.password = "";
            root.phase = "idle";
        }
    }

    WlSessionLock {
        id: lock
        // a marker for kk-shell: "the screen is locked by me". if the shell dies while it exists,
        // the restarted shell takes the lock back (so it can be unlocked), and only then
        onLockedChanged: Quickshell.execDetached(["sh", "-c", locked
            ? 'touch "${XDG_RUNTIME_DIR:-/tmp}/kk-locked"'
            : 'rm -f "${XDG_RUNTIME_DIR:-/tmp}/kk-locked"'])

        WlSessionLockSurface {
            color: Theme.ink
            LockSurface {
                anchors.fill: parent
                ctx: root
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lockNow(); }
        function isLocked(): bool { return root.locked; }
        function wake(): void { root.woke(); }
    }
}
