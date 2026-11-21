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

    function lockNow() {
        if (lock.locked) return;
        Store.s.frame = Store.s.frame + 1;
        password = "";
        phase = "idle";
        attempts = 0;
        note = "";
        Ui.closeAll();
        lock.locked = true;
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
                release.start();
            } else {
                root.fail(result === PamResult.MaxTries ? "too many tries. wait a little." : "");
            }
        }
        onError: root.fail("something went wrong checking that.")
    }

    // let the fade-out play before the lock lifts
    Timer {
        id: release
        interval: 520
        onTriggered: {
            lock.locked = false;
            root.password = "";
            root.phase = "idle";
        }
    }

    WlSessionLock {
        id: lock

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
    }
}
