pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// your phone, through kde connect's daemon (the "phone" extra installs it; the KDE Connect app
// on the phone pairs with it). the shell reads it with kdeconnect-cli and d-bus:
// battery, ring it, send files / the clipboard / a link, browse its storage, texts, pairing.
// its notifications arrive as ordinary desktop notifications.
Singleton {
    id: root

    property int consumers: 0
    property bool available: false        // kdeconnect-cli is installed
    property var devices: []              // [{ id, name, paired, reachable, battery, charging }]
    property string selected: ""
    property string message: ""
    readonly property var current: devices.find(d => d.id === selected) || devices.find(d => d.paired && d.reachable) || devices[0] || null

    function refresh() { if (!listProc.running) listProc.running = true; }
    Component.onCompleted: refresh()
    Timer {
        // quietly in the background (the bar shows the battery), often while a panel shows it
        interval: root.consumers > 0 ? 5000 : 60000
        repeat: true
        running: root.available || root.consumers > 0
        onTriggered: root.refresh()
    }

    Process {
        id: listProc
        // every known device, and its battery over d-bus
        command: ["sh", "-c", 'command -v kdeconnect-cli >/dev/null || { echo NOKDC; exit 0; }; '
            + 'kdeconnect-cli -l 2>/dev/null | while IFS= read -r l; do '
            + '  case "$l" in "- "*) ;; *) continue ;; esac; '
            + '  id="$(printf %s "$l" | sed -E "s/^- .*: ([A-Za-z0-9_-]+) \\(.*$/\\1/")"; '
            + '  b="$(busctl --user get-property org.kde.kdeconnect /modules/kdeconnect/devices/$id/battery org.kde.kdeconnect.device.battery charge 2>/dev/null | cut -d" " -f2)"; '
            + '  c="$(busctl --user get-property org.kde.kdeconnect /modules/kdeconnect/devices/$id/battery org.kde.kdeconnect.device.battery isCharging 2>/dev/null | cut -d" " -f2)"; '
            + '  printf "%s\\t%s\\t%s\\n" "$l" "${b:--1}" "${c:-false}"; '
            + 'done']
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("NOKDC") === 0) { root.available = false; root.devices = []; return; }
                root.available = true;
                const out = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    // - Pixel 8: 1a2b3c4d5e (paired and reachable)
                    const m = /^- (.+): ([A-Za-z0-9_-]+) \((.+)\)$/.exec(f[0] || "");
                    if (!m) continue;
                    const st = m[3].toLowerCase();
                    out.push({
                        name: m[1], id: m[2],
                        paired: st.indexOf("paired") !== -1 && st.indexOf("not paired") === -1 && st.indexOf("unpaired") === -1,
                        reachable: st.indexOf("reachable") !== -1 && st.indexOf("unreachable") === -1 && st.indexOf("not reachable") === -1,
                        battery: parseInt(f[1]) >= 0 ? parseInt(f[1]) : -1,
                        charging: (f[2] || "") === "true"
                    });
                }
                out.sort((a, b) => (b.reachable - a.reachable) || (b.paired - a.paired) || a.name.localeCompare(b.name));
                root.devices = out;
            }
        }
    }

    Process {
        id: act
        stderr: StdioCollector { id: actErr }
        onExited: code => { root.message = code === 0 ? root.okText : (actErr.text.trim().split("\n")[0] || "the phone didn't answer"); root.refresh(); clearMsg.restart(); }
    }
    property string okText: ""
    Timer { id: clearMsg; interval: 4000; onTriggered: root.message = "" }
    function run(args, ok: string) {
        okText = ok;
        act.command = args;
        act.running = true;
    }
    function cli(d, args, ok: string) { if (d) run(["kdeconnect-cli", "-d", d.id].concat(args), ok); }

    function ring(d) { cli(d, ["--ring"], "ringing"); }
    function ping(d) { cli(d, ["--ping"], "pinged"); }
    function pair(d) { cli(d, ["--pair"], "accept on the phone"); }
    function unpair(d) { cli(d, ["--unpair"], "unpaired"); }
    function sendClipboard(d) {
        if (d) run(["sh", "-c", 't="$(wl-paste --no-newline 2>/dev/null)"; [ -n "$t" ] || exit 1; exec kdeconnect-cli -d "$1" --share-text "$t"', "sh", d.id], "clipboard sent");
    }
    // pick files in a dialog, send each one
    function sendFiles(d) {
        if (!d) return;
        run(["sh", "-c", 'f="$( (command -v zenity >/dev/null && zenity --file-selection --multiple --separator="\n" --title="Send to $2") '
            + '|| (command -v kdialog >/dev/null && kdialog --getopenfilename "$HOME" --multiple --separate-output) )" || exit 0; '
            + 'printf "%s\n" "$f" | while IFS= read -r x; do [ -f "$x" ] && kdeconnect-cli -d "$1" --share "$x"; done', "sh", d.id, d.name], "sent");
    }
    // the phone's storage in the file manager (kde connect's sftp)
    function browse(d) {
        if (!d) return;
        run(["busctl", "--user", "call", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + d.id + "/sftp", "org.kde.kdeconnect.device.sftp", "startBrowsing"], "opening its files");
    }
    function texts(d) { Quickshell.execDetached(["sh", "-c", 'command -v kdeconnect-sms >/dev/null && exec kdeconnect-sms --device "$1" || exec kdeconnect-app', "sh", d ? d.id : ""]); }
    function openApp() { Quickshell.execDetached(["sh", "-c", "command -v kdeconnect-app >/dev/null && exec kdeconnect-app || exec kdeconnect-settings"]); }
    function rescan() { run(["kdeconnect-cli", "--refresh"], "looking for phones"); }
}
