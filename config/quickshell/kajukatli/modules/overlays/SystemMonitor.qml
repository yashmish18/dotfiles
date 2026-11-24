import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// ctrl + shift + esc: what the computer is doing, and room to breathe.
//   Processes   everything running, by cpu or memory; end, pause or kill any of it
//   Memory      ram, swap, and who's holding it
//   Storage     every disk, what fills your home, and one-tap clean-ups
//   Recycle bin restore or delete what you threw away
//   Drives      usb sticks and sd cards: mount, eject, format
Item {
    id: root
    focus: true
    property string tab: "processes"
    Keys.onEscapePressed: Ui.overlay = ""

    readonly property var tabs: [
        { key: "processes", label: "Processes", icon: "cpu" },
        { key: "memory", label: "Memory", icon: "memory" },
        { key: "storage", label: "Storage", icon: "disk" },
        { key: "trash", label: "Recycle bin", icon: "trash" },
        { key: "drives", label: "Drives", icon: "usb" }
    ]

    function human(b: var): string {
        b = Number(b) || 0;
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (i >= 3 ? b.toFixed(1) : Math.round(b)) + " " + u[i];
    }

    // ------------------------------------------------------------ data
    property var procs: []
    property string sortBy: "cpu"
    property string filter: ""
    property int selectedPid: -1
    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.tab === "processes" || root.tab === "memory"
        onTriggered: { if (!psProc.running) psProc.running = true; if (!memProc.running) memProc.running = true; }
    }
    Process {
        id: psProc
        command: ["ps", "-eo", "pid=,user=,pcpu=,pmem=,rss=,stat=,comm=", "--sort=-pcpu"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const m = /^\s*(\d+)\s+(\S+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+(\S+)\s+(.+)$/.exec(line);
                    if (m) out.push({ pid: +m[1], user: m[2], cpu: +m[3], mem: +m[4], rss: +m[5] * 1024, stat: m[6], name: m[7].trim() });
                }
                root.procs = out;
            }
        }
    }
    readonly property var shownProcs: {
        const q = filter.trim().toLowerCase();
        let l = q ? procs.filter(p => p.name.toLowerCase().indexOf(q) !== -1 || String(p.pid) === q || p.user.toLowerCase() === q) : procs.slice();
        if (sortBy === "mem") l.sort((a, b) => b.rss - a.rss);
        else if (sortBy === "name") l.sort((a, b) => a.name.localeCompare(b.name));
        else l.sort((a, b) => b.cpu - a.cpu);
        return l.slice(0, 150);
    }
    property var mem: ({})
    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const line of text.split("\n")) {
                    const m = /^(\w+):\s+(\d+)/.exec(line);
                    if (m) o[m[1]] = +m[2] * 1024;
                }
                root.mem = o;
            }
        }
    }
    function signal_(pid: var, sig: var) {
        actProc.command = ["sh", "-c", 'kill -' + sig + ' "$1" 2>/dev/null || pkexec kill -' + sig + ' "$1"', "sh", String(pid)];
        actProc.running = true;
    }

    property var report: null
    property bool reporting: false
    function loadReport() { if (!repProc.running) { reporting = true; repProc.running = true; } }
    Process {
        id: repProc
        command: [Config.bin + "kk-storage", "report"]
        stdout: StdioCollector { onStreamFinished: { try { root.report = JSON.parse(text.trim()); } catch (e) {} root.reporting = false; } }
    }
    property var trash: []
    function loadTrash() { if (!trashProc.running) trashProc.running = true; }
    Process {
        id: trashProc
        command: [Config.bin + "kk-storage", "trash", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.split("\n")) { try { if (l.trim()) out.push(JSON.parse(l)); } catch (e) {} }
                out.sort((a, b) => String(b.when).localeCompare(String(a.when)));
                root.trash = out;
            }
        }
    }
    property var drives: []
    // the format dialog (drives tab): which partition, as what, called what
    property string formatting: ""
    property string formatFs: "exfat"
    property string formatLabel: ""
    function loadDrives() { if (!drvProc.running) drvProc.running = true; }
    Process {
        id: drvProc
        command: [Config.bin + "kk-storage", "drives"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const out = [];
                    // a disk holding /, /boot or /home: none of it can be formatted from here
                    const sysMounts = ["/", "/boot", "/boot/efi", "/efi", "/home", "[SWAP]"];
                    const holdsSystem = d => sysMounts.indexOf(d.mountpoint || "") !== -1 || (d.children || []).some(holdsSystem);
                    const walk = (d, disk) => {
                        if (d.type === "disk") disk = d;
                        if (d.type === "part" || (d.type === "disk" && !(d.children && d.children.length)))
                            out.push(Object.assign({}, d, { sysdisk: disk ? holdsSystem(disk) : false, disk: disk ? (disk.model || disk.name) : "", removable: disk ? (disk.rm || disk.hotplug) : false, tran: disk ? disk.tran : "" }));
                        for (const c of (d.children || [])) walk(c, disk);
                    };
                    for (const d of JSON.parse(text).blockdevices || []) if (!/^(loop|zram|sr)/.test(d.name)) walk(d, null);
                    root.drives = out;
                } catch (e) {}
            }
        }
    }
    onTabChanged: {
        if (tab === "storage") loadReport();
        else if (tab === "trash") loadTrash();
        else if (tab === "drives") loadDrives();
    }

    // one place every action goes through, with a word about how it went
    property string note: ""
    Process {
        id: actProc
        property string after: ""
        stdout: StdioCollector { id: actOut }
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            Ui.authWaiting = false;
            const said = actOut.text.trim().split("\n").pop();
            root.note = code === 0 ? (said && said.length < 60 ? said : "done")
                      : code === 126 || code === 127 ? "needs your password: is the polkit agent running?"
                      : (actErr.text.trim().split("\n").pop() || "that didn't work");
            noteClear.restart();
            if (actProc.after === "report") root.loadReport();
            else if (actProc.after === "trash") root.loadTrash();
            else if (actProc.after === "drives") root.loadDrives();
            actProc.after = "";
        }
    }
    Timer { id: noteClear; interval: 4000; onTriggered: root.note = "" }
    function storage(args: var, after: var) {
        if (actProc.running) { note = "one moment, still working on the last one…"; noteClear.restart(); return; }
        const root_ = ["pacman", "journal", "orphans", "format"].some(k => args.indexOf(k) !== -1) || args[0] === "format";
        note = root_ ? "waiting for your password…" : "working…";
        noteClear.stop();
        if (root_) {
            Ui.authWaiting = true;     // the password prompt sits under this overlay: step aside
            Quickshell.execDetached(["notify-send", "-a", "System", "Waiting for your password", "Type it in the prompt; the window comes back when it's done."]);
        }
        actProc.after = after || "";
        actProc.command = [Config.bin + "kk-storage"].concat(args);
        actProc.running = true;
    }

    // ------------------------------------------------------------ the window
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, 1060)
        height: Math.min(parent.height, 720)
        radius: 24
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outlineVariant
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Txt { text: "System"; font.pixelSize: Theme.xl; font.weight: Font.Bold; Layout.rightMargin: 14 }
                Repeater {
                    model: root.tabs
                    delegate: Btn {
                        required property var modelData
                        text: modelData.label
                        icon: modelData.icon
                        active: root.tab === modelData.key
                        onClicked: root.tab = modelData.key
                    }
                }
                Item { Layout.fillWidth: true }
                Icon {
                    visible: actProc.running
                    name: "restart"
                    size: 16
                    color: Theme.primary
                    RotationAnimation on rotation { running: actProc.running; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                }
                Txt { text: root.note; color: Theme.primary; font.pixelSize: Theme.sm }
                Btn { icon: "close"; onClicked: Ui.overlay = "" }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.tabs.findIndex(t => t.key === root.tab)

                // ==================================================== processes
                ColumnLayout {
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Field { Layout.preferredWidth: 260; size: Theme.md; placeholder: "Find a process, pid or user"; onTextChanged: root.filter = text }
                        Txt { text: "sort:"; color: Theme.surfaceTextDim; font.pixelSize: Theme.sm }
                        Btn { text: "CPU"; active: root.sortBy === "cpu"; onClicked: root.sortBy = "cpu" }
                        Btn { text: "Memory"; active: root.sortBy === "mem"; onClicked: root.sortBy = "mem" }
                        Btn { text: "Name"; active: root.sortBy === "name"; onClicked: root.sortBy = "name" }
                        Item { Layout.fillWidth: true }
                        Txt {
                            text: root.procs.length + " processes · " + Math.round(root.procs.reduce((s, p) => s + p.cpu, 0)) + "% cpu"
                            font.family: Theme.mono; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim
                        }
                    }
                    // the selected one: what to do with it
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.selectedPid > 0
                        spacing: 6
                        readonly property var p: root.procs.find(x => x.pid === root.selectedPid) || null
                        Txt { text: parent.p ? parent.p.name + "  (" + parent.p.pid + ", " + parent.p.user + ")" : ""; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Btn { text: "End"; onClicked: root.signal_(root.selectedPid, "TERM") }
                        Btn { text: parent.p && parent.p.stat.indexOf("T") === 0 ? "Resume" : "Pause"; onClicked: root.signal_(root.selectedPid, parent.p && parent.p.stat.indexOf("T") === 0 ? "CONT" : "STOP") }
                        Btn { text: "Kill"; danger: true; onClicked: { root.signal_(root.selectedPid, "KILL"); root.selectedPid = -1; } }
                    }
                    ListView {
                        id: plist
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.shownProcs
                        header: RowLayout {
                            width: plist.width
                            spacing: 0
                            Txt { Layout.preferredWidth: 70; text: "PID"; font.pixelSize: Theme.xs; color: Theme.outline }
                            Txt { Layout.fillWidth: true; text: "NAME"; font.pixelSize: Theme.xs; color: Theme.outline }
                            Txt { Layout.preferredWidth: 110; text: "USER"; font.pixelSize: Theme.xs; color: Theme.outline }
                            Txt { Layout.preferredWidth: 70; text: "CPU"; font.pixelSize: Theme.xs; color: Theme.outline; horizontalAlignment: Text.AlignRight }
                            Txt { Layout.preferredWidth: 100; text: "MEMORY"; font.pixelSize: Theme.xs; color: Theme.outline; horizontalAlignment: Text.AlignRight }
                        }
                        delegate: Rectangle {
                            id: pr
                            required property var modelData
                            width: plist.width
                            height: 28
                            radius: 6
                            color: root.selectedPid === modelData.pid ? Theme.alpha(Theme.primary, 0.18) : prArea.containsMouse ? Theme.surfaceHigh : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                Txt { Layout.preferredWidth: 70; text: pr.modelData.pid; font.family: Theme.mono; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                                Txt { Layout.fillWidth: true; text: pr.modelData.name + (pr.modelData.stat.indexOf("T") === 0 ? "  (paused)" : ""); elide: Text.ElideRight; font.pixelSize: Theme.sm }
                                Txt { Layout.preferredWidth: 110; text: pr.modelData.user; elide: Text.ElideRight; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                                Txt { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight; text: pr.modelData.cpu.toFixed(1) + "%"; font.family: Theme.mono; font.pixelSize: Theme.sm; color: pr.modelData.cpu > 50 ? Theme.error : Theme.surfaceText }
                                Txt { Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight; text: root.human(pr.modelData.rss); font.family: Theme.mono; font.pixelSize: Theme.sm }
                            }
                            MouseArea { id: prArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.selectedPid = pr.modelData.pid }
                        }
                    }
                }

                // ==================================================== memory
                ColumnLayout {
                    spacing: 14
                    readonly property real total: root.mem.MemTotal || 1
                    readonly property real avail: root.mem.MemAvailable || 0
                    readonly property real used: total - avail
                    readonly property real cached: (root.mem.Cached || 0) + (root.mem.Buffers || 0)
                    readonly property real swapT: root.mem.SwapTotal || 0
                    readonly property real swapU: swapT - (root.mem.SwapFree || 0)
                    component Meter: ColumnLayout {
                        id: meter
                        property string title: ""
                        property string detail: ""
                        property real frac: 0
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Txt { text: meter.title; font.weight: Font.DemiBold; Layout.fillWidth: true }
                            Txt { text: meter.detail; font.family: Theme.mono; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 14
                            radius: 7
                            color: Theme.surfaceHigh
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, meter.frac))
                                height: parent.height
                                radius: 7
                                color: meter.frac > 0.9 ? Theme.error : Theme.primary
                                Behavior on width { NumberAnimation { duration: Theme.normal } }
                            }
                        }
                    }
                    Meter { title: "Memory in use"; frac: parent.used / parent.total; detail: root.human(parent.used) + " of " + root.human(parent.total) }
                    Meter { title: "Cache (given back when needed)"; frac: parent.cached / parent.total; detail: root.human(parent.cached) }
                    Meter { visible: parent.swapT > 0; title: "Swap" + ((root.mem.Zswapped || 0) > 0 ? " (compressed)" : ""); frac: parent.swapT > 0 ? parent.swapU / parent.swapT : 0; detail: root.human(parent.swapU) + " of " + root.human(parent.swapT) }
                    Txt { text: "HOLDING THE MOST"; font.pixelSize: Theme.xs + 1; font.letterSpacing: 1.2; font.weight: Font.DemiBold; color: Theme.outline }
                    Repeater {
                        model: root.procs.slice().sort((a, b) => b.rss - a.rss).slice(0, 8)
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Txt { text: modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                            Txt { text: root.human(modelData.rss); font.family: Theme.mono; font.pixelSize: Theme.sm }
                            Btn { text: "End"; flat: true; onClicked: root.signal_(modelData.pid, "TERM") }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }

                // ==================================================== storage
                Flickable {
                    clip: true
                    contentHeight: stCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ColumnLayout {
                        id: stCol
                        width: parent.width
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            Txt { text: root.reporting ? "Measuring…" : "Disks"; font.weight: Font.DemiBold; Layout.fillWidth: true }
                            Btn { icon: "restart"; onClicked: root.loadReport() }
                            Btn { text: "Partitions (GParted)"; icon: "external"; onClicked: { Ui.overlay = ""; Quickshell.execDetached(["sh", "-c", "xhost +SI:localuser:root >/dev/null 2>&1; exec gparted"]); } }
                        }
                        Repeater {
                            model: root.report ? root.report.disks : []
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    Txt { text: modelData.mount + "  "; font.weight: Font.DemiBold }
                                    Txt { text: modelData.dev + " · " + modelData.fs; color: Theme.surfaceTextDim; font.pixelSize: Theme.sm; Layout.fillWidth: true }
                                    Txt { text: root.human(modelData.free) + " free of " + root.human(modelData.size); font.family: Theme.mono; font.pixelSize: Theme.sm }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 12
                                    radius: 6
                                    color: Theme.surfaceHigh
                                    Rectangle {
                                        readonly property real f: modelData.size > 0 ? modelData.used / modelData.size : 0
                                        width: parent.width * f
                                        height: parent.height
                                        radius: 6
                                        color: f > 0.9 ? Theme.error : Theme.primary
                                    }
                                }
                            }
                        }
                        Txt { text: "YOUR FOLDERS"; visible: root.report !== null; font.pixelSize: Theme.xs + 1; font.letterSpacing: 1.2; font.weight: Font.DemiBold; color: Theme.outline; Layout.topMargin: 8 }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: root.report ? root.report.home : []
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 150; height: 58
                                    radius: Theme.radiusSmall + 4
                                    color: fArea.containsMouse ? Theme.surfaceHighest : Theme.surfaceHigh
                                    Column {
                                        anchors.left: parent.left; anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        Txt { text: modelData.name; font.weight: Font.DemiBold }
                                        Txt { text: root.human(modelData.size); font.family: Theme.mono; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                                    }
                                    MouseArea { id: fArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Ui.overlay = ""; Quickshell.execDetached(["xdg-open", modelData.path]); } }
                                }
                            }
                        }
                        Txt { text: "FREE UP SPACE"; visible: root.report !== null; font.pixelSize: Theme.xs + 1; font.letterSpacing: 1.2; font.weight: Font.DemiBold; color: Theme.outline; Layout.topMargin: 8 }
                        Repeater {
                            model: root.report ? [
                                { k: "trash", t: "Recycle bin", d: "Everything you deleted", v: root.report.clean.trash },
                                { k: "thumbnails", t: "Thumbnails", d: "Little previews; they come back as you browse", v: root.report.clean.thumbnails },
                                { k: "cache", t: "App caches", d: "Shader, font and build caches apps rebuild by themselves (of " + root.human(root.report.clean.cache) + " in ~/.cache)", v: -1 },
                                { k: "walls", t: "Wallpaper workspace", d: "Cut-outs and depth for every wallpaper but the current one (rebuilt when you pick it again)", v: root.report.clean.walls },
                                { k: "pacman", t: "Old packages", d: "Downloaded package files, keeping the newest of each", v: root.report.clean.pacman },
                                { k: "journal", t: "System logs", d: "Trimmed to the last 100 MB", v: root.report.clean.journal },
                                { k: "aur", t: "AUR build files", d: "Sources left over from building AUR packages", v: root.report.clean.aur },
                                { k: "orphans", t: "Unneeded packages", d: root.report.clean.orphans + " packages nothing depends on any more", v: -2 }
                            ] : []
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 12
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Txt { text: modelData.t; font.weight: Font.Medium }
                                    Txt { text: modelData.d; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                }
                                Txt { visible: modelData.v >= 0; text: root.human(modelData.v); font.family: Theme.mono; font.pixelSize: Theme.sm }
                                Btn {
                                    text: modelData.k === "trash" ? "Empty" : modelData.k === "orphans" ? "Remove" : "Clean"
                                    danger: modelData.k === "trash" || modelData.k === "orphans"
                                    enabled: modelData.v !== 0 && !(modelData.k === "orphans" && root.report.clean.orphans === 0)
                                    onClicked: root.storage(["clean", modelData.k], "report")
                                }
                            }
                        }
                    }
                }

                // ==================================================== recycle bin
                ColumnLayout {
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Txt { text: root.trash.length + (root.trash.length === 1 ? " item" : " items") + " · " + root.human(root.trash.reduce((s, t) => s + (t.size || 0), 0)); Layout.fillWidth: true; font.weight: Font.DemiBold }
                        Btn { icon: "restart"; onClicked: root.loadTrash() }
                        Btn { text: "Open in Files"; icon: "external"; onClicked: { Ui.overlay = ""; Quickshell.execDetached(["sh", "-c", "thunar trash:/// || xdg-open trash:///"]); } }
                        Btn { text: "Empty"; danger: true; enabled: root.trash.length > 0; onClicked: root.storage(["trash", "empty"], "trash") }
                    }
                    ListView {
                        id: tlist
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.trash
                        delegate: Rectangle {
                            id: ti
                            required property var modelData
                            width: tlist.width
                            height: 44
                            radius: 8
                            color: tiArea.containsMouse ? Theme.surfaceHigh : "transparent"
                            MouseArea { id: tiArea; anchors.fill: parent; hoverEnabled: true }
                            Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: ti.modelData.dir ? "folder" : "image"; size: 18; color: Theme.surfaceTextDim }
                            Column {
                                x: 40
                                width: parent.width - 300
                                anchors.verticalCenter: parent.verticalCenter
                                Txt { width: parent.width; text: ti.modelData.name; elide: Text.ElideMiddle }
                                Txt { width: parent.width; text: ti.modelData.orig + " · " + String(ti.modelData.when).replace("T", " "); elide: Text.ElideMiddle; font.pixelSize: Theme.xs + 1; color: Theme.surfaceTextDim }
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Txt { anchors.verticalCenter: parent.verticalCenter; text: root.human(ti.modelData.size); font.family: Theme.mono; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                                Btn { text: "Restore"; onClicked: root.storage(["trash", "restore", ti.modelData.uri], "trash") }
                                Btn { text: "Delete"; danger: true; onClicked: root.storage(["trash", "delete", ti.modelData.uri], "trash") }
                            }
                        }
                    }
                    Txt { visible: root.trash.length === 0; text: "The recycle bin is empty."; color: Theme.surfaceTextDim }
                }

                // ==================================================== drives
                ColumnLayout {
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Txt { text: "Drives and partitions"; Layout.fillWidth: true; font.weight: Font.DemiBold }
                        Btn { text: "Partitions (GParted)"; icon: "external"; onClicked: { Ui.overlay = ""; Quickshell.execDetached(["sh", "-c", "xhost +SI:localuser:root >/dev/null 2>&1; exec gparted"]); } }
                        Btn { icon: "restart"; onClicked: root.loadDrives() }
                    }
                    // format: pick a filesystem and a name; everything on it is erased
                    Rectangle {
                        visible: root.formatting !== ""
                        Layout.fillWidth: true
                        implicitHeight: fmt.implicitHeight + 24
                        radius: 14
                        color: Theme.alpha(Theme.error, 0.12)
                        border.width: 1
                        border.color: Theme.alpha(Theme.error, 0.5)
                        ColumnLayout {
                            id: fmt
                            x: 12; y: 12
                            width: parent.width - 24
                            spacing: 8
                            Txt { text: "Format " + root.formatting + ": everything on it is erased"; font.weight: Font.Bold; color: Theme.error }
                            RowLayout {
                                spacing: 6
                                Txt { text: "as"; color: Theme.surfaceTextDim }
                                Repeater {
                                    model: [{ v: "exfat", l: "exFAT (any computer, big files)" }, { v: "fat32", l: "FAT32 (old devices)" }, { v: "ntfs", l: "NTFS (Windows)" }, { v: "ext4", l: "ext4 (Linux)" }, { v: "btrfs", l: "Btrfs" }]
                                    delegate: Btn { required property var modelData; text: modelData.l; active: root.formatFs === modelData.v; onClicked: root.formatFs = modelData.v }
                                }
                            }
                            RowLayout {
                                spacing: 8
                                Field { Layout.preferredWidth: 220; size: Theme.md; placeholder: "Name (optional)"; text: root.formatLabel; onTextChanged: root.formatLabel = text }
                                Item { Layout.fillWidth: true }
                                Btn { text: "Cancel"; onClicked: root.formatting = "" }
                                Btn { text: "Erase and format"; danger: true; active: true; onClicked: { root.storage(["format", root.formatting, root.formatFs, root.formatLabel], "drives"); root.formatting = ""; } }
                            }
                        }
                    }
                    ListView {
                        id: dlist
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.drives
                        delegate: Rectangle {
                            id: dv
                            required property var modelData
                            readonly property bool system: modelData.sysdisk || ["/", "/boot", "/boot/efi", "/efi", "/home", "[SWAP]"].indexOf(modelData.mountpoint || "") !== -1
                            width: dlist.width
                            height: 54
                            radius: 10
                            color: Theme.surfaceHigh
                            Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: dv.modelData.removable ? "usb" : "disk"; size: 20; color: dv.modelData.removable ? Theme.primary : Theme.surfaceTextDim }
                            Column {
                                x: 44
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 420
                                Txt { width: parent.width; elide: Text.ElideRight; font.weight: Font.DemiBold
                                      text: (dv.modelData.label || dv.modelData.disk || dv.modelData.name) + "  ·  " + root.human(dv.modelData.size) }
                                Txt { width: parent.width; elide: Text.ElideRight; font.family: Theme.mono; font.pixelSize: Theme.xs + 1; color: Theme.surfaceTextDim
                                      text: dv.modelData.path + "  " + (dv.modelData.fstype || "no filesystem") + (dv.modelData.mountpoint ? "  at " + dv.modelData.mountpoint : "  not mounted") + (dv.modelData.tran ? "  · " + dv.modelData.tran : "") }
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Btn { text: "Open"; visible: !!dv.modelData.mountpoint && dv.modelData.mountpoint !== "[SWAP]"; onClicked: { Ui.overlay = ""; Quickshell.execDetached(["xdg-open", dv.modelData.mountpoint]); } }
                                Btn { text: "Mount"; visible: !dv.modelData.mountpoint && !!dv.modelData.fstype && dv.modelData.fstype !== "swap"; onClicked: root.storage(["mount", dv.modelData.path], "drives") }
                                Btn { text: "Unmount"; visible: !!dv.modelData.mountpoint && !dv.system; onClicked: root.storage(["unmount", dv.modelData.path], "drives") }
                                Btn { text: "Eject"; visible: dv.modelData.removable && !dv.system; onClicked: root.storage(["eject", dv.modelData.path], "drives") }
                                // never the disk the system runs from
                                Btn { text: "Format…"; danger: true; visible: !dv.system; onClicked: { root.formatting = dv.modelData.path; root.formatFs = "exfat"; root.formatLabel = dv.modelData.label || ""; } }
                            }
                        }
                    }
                }
            }
        }
    }
}
