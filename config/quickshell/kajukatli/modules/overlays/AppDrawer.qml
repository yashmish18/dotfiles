import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.services
import qs.components

// the apps: super + space, or tap super. type to find one, arrows to move, enter to open.
//   = 12*7   maths (enter copies it)     > htop   run it in a terminal     ? words   search the web
//   :fire    emoji (enter inserts it directly)
// with nothing typed, the ones you open most come first.
Item {
    id: root
    focus: true

    readonly property string q: input.text.trim()
    readonly property string mode: q.startsWith("=") ? "calc" : q.startsWith(">") ? "run" : q.startsWith("?") ? "web" : q.startsWith(":") ? "emoji" : "apps"

    // ---------------------------------------------------------------- emoji
    property var emojiAll: []        // [[char, name]]
    FileView {
        id: emojiFile
        path: Config.home + "/.cache/kajukatli/emoji.tsv"
        printErrors: false
        onLoaded: root.emojiAll = text().split("\n").filter(l => l).map(l => l.split("\t"))
        onLoadFailed: emojiMake.running = true
    }
    Process { id: emojiMake; command: [Config.bin + "kk-emoji-list"]; onExited: emojiFile.reload() }
    readonly property var emojis: {
        if (mode !== "emoji") return [];
        const t = q.slice(1).trim().toLowerCase();
        const words = t.split(/\s+/).filter(w => w);
        const out = [];
        for (const e of emojiAll) {
            if (words.every(w => e[1].indexOf(w) !== -1)) out.push(e);
            if (out.length >= 80) break;
        }
        return out;
    }
    readonly property var launches: Store.s.launches || ({})
    property int index: 0

    function score(app, s) {
        const name = (app.name || "").toLowerCase();
        if (name.startsWith(s)) return 100 - name.length * 0.1;
        if (name.split(/[\s\-_]/).some(w => w.startsWith(s))) return 60;
        if (name.indexOf(s) !== -1) return 40;
        const extra = [app.genericName, app.comment, (app.keywords || []).join(" ")].join(" ").toLowerCase();
        if (extra.indexOf(s) !== -1) return 20;
        let i = 0;
        for (const c of name) if (c === s[i]) i++;
        return i === s.length ? 10 : 0;
    }
    readonly property var apps: {
        if (mode !== "apps") return [];
        const s = q.toLowerCase();
        const out = [];
        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay) continue;
            const v = s ? score(a, s) : 1;
            if (v > 0) out.push({ app: a, v: v + Math.min(30, (launches[a.id] || 0) * 2) });
        }
        out.sort((x, y) => y.v - x.v || x.app.name.localeCompare(y.app.name));
        return out.map(x => x.app);
    }
    readonly property string calc: {
        if (mode !== "calc") return "";
        const expr = q.slice(1).replace(/\^/g, "**").replace(/×/g, "*").replace(/÷/g, "/");
        if (!/^[\d\s+\-*/().%e]*$/.test(expr) || expr.trim() === "") return "";
        try {
            const v = Function('"use strict"; return (' + expr + ")")();
            return typeof v === "number" && isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) {
            return "";
        }
    }

    // onGpu: right-click starts it on the nvidia card; heavy apps (settings → display) always do
    function launch(app, onGpu) {
        if (!app) return;
        const l = Object.assign({}, Store.s.launches || {});
        l[app.id] = (l[app.id] || 0) + 1;
        Store.s.launches = l;
        Ui.overlay = "";
        const cmd = app.runInTerminal ? ["kitty", "--"].concat(app.command) : Gpu.wrap(app.command, app, onGpu === true);
        Quickshell.execDetached({ command: cmd, workingDirectory: app.workingDirectory || Config.home });
    }
    function accept() {
        const rest = q.slice(1).trim();
        if (mode === "apps") launch(apps[index]);
        else if (mode === "emoji" && emojis.length) {
            const emoji = emojis[Math.min(index, emojis.length - 1)][0];
            Ui.overlay = "";
            Quickshell.execDetached(["sh", "-c", 'sleep 0.08; exec wtype -- "$1"', "sh", emoji]);
        }
        else if (mode === "calc" && calc !== "") { Quickshell.execDetached(["wl-copy", calc]); Ui.overlay = ""; }
        else if (mode === "run" && rest) { Ui.overlay = ""; Quickshell.execDetached(["kitty", "--hold", "sh", "-c", rest]); }
        else if (mode === "web" && rest) { Ui.overlay = ""; Qt.openUrlExternally("https://duckduckgo.com/?q=" + encodeURIComponent(rest)); }
    }
    function move(d) {
        const n = mode === "emoji" ? emojis.length : apps.length;
        if (n === 0) return;
        index = Math.max(0, Math.min(n - 1, index + d));
        (mode === "emoji" ? emojiGrid : grid).positionViewAtIndex(index, GridView.Contain);
    }

    // ------------------------------------------------------------ the search line
    Item {
        id: head
        anchors.top: parent.top
        anchors.topMargin: Math.max(20, parent.height * 0.06)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, 720)
        height: 74

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: TextInput.AlignHCenter
            font.family: Theme.sans
            font.pixelSize: 40
            font.weight: Font.Medium
            color: "#ffffff"
            selectionColor: Theme.primary
            selectedTextColor: Theme.primaryText
            cursorDelegate: Rectangle {
                width: 3
                color: Theme.primary
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 520; easing.type: Easing.InQuad }
                    NumberAnimation { to: 1; duration: 520; easing.type: Easing.OutQuad }
                }
            }
            Component.onCompleted: {
                if (Ui.overlayQuery !== "") text = Ui.overlayQuery;
                forceActiveFocus();
            }
            onTextChanged: { root.index = 0; grid.positionViewAtBeginning(); }
            Keys.onReturnPressed: root.accept()
            Keys.onEnterPressed: root.accept()
            Keys.onEscapePressed: Ui.overlay = ""
            Keys.onLeftPressed: root.move(-1)
            Keys.onRightPressed: root.move(1)
            Keys.onUpPressed: root.move(-grid.cols)
            Keys.onDownPressed: root.move(grid.cols)
            Keys.onTabPressed: root.move(1)
            Keys.onBacktabPressed: root.move(-1)
        }
        Txt {
            anchors.centerIn: parent
            visible: input.text === ""
            text: "Search"
            font.pixelSize: 40
            font.weight: Font.Medium
            color: Theme.alpha("#ffffff", 0.28)
        }
        // the line under it grows with what you type
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            height: 2
            radius: 1
            width: Math.max(48, Math.min(parent.width, input.contentWidth + 40))
            color: Theme.primary
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
    }

    // ------------------------------------------------------------ maths / run / web
    Txt {
        anchors.top: head.bottom
        anchors.topMargin: 36
        anchors.horizontalCenter: parent.horizontalCenter
        visible: (root.mode !== "apps" && root.mode !== "emoji") || (root.mode === "apps" && root.apps.length === 0) || (root.mode === "emoji" && root.emojis.length === 0)
        text: root.mode === "calc" ? (root.calc !== "" ? root.calc : "…")
            : root.mode === "run" ? "enter runs it in a terminal"
            : root.mode === "web" ? "enter searches the web"
            : root.mode === "emoji" ? (root.q.length < 2 ? "an emoji's name: fire, heart, cat…" : "no emoji by that name")
            : "nothing called that.   > runs it,   ? searches for it"
        font.family: root.mode === "calc" ? Theme.mono : Theme.sans
        font.pixelSize: root.mode === "calc" ? 64 : Theme.md
        color: root.mode === "calc" ? Theme.primary : Theme.alpha("#ffffff", 0.6)
    }

    // ------------------------------------------------------------ the grid
    GridView {
        id: grid
        readonly property int cell: 136
        readonly property int cols: Math.max(1, Math.floor(width / cell))
        anchors.top: head.bottom
        anchors.topMargin: 40
        anchors.bottom: hints.top
        anchors.bottomMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, cell * 8)
        cellWidth: width / cols
        cellHeight: 132
        clip: true
        visible: root.mode === "apps"
        model: root.apps
        currentIndex: root.index
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 140
        highlight: Rectangle {
            radius: 22
            color: Theme.alpha("#ffffff", 0.12)
            border.width: 1
            border.color: Theme.alpha("#ffffff", 0.16)
        }

        delegate: Item {
            id: cellItem
            required property var modelData
            required property int index
            readonly property bool sel: index === root.index
            width: grid.cellWidth
            height: grid.cellHeight

            // arrive one after another, then settle
            opacity: 0
            property real rise: 18
            transform: Translate { y: cellItem.rise }
            Component.onCompleted: if (Config.s.reducedMotion) { opacity = 1; rise = 0; } else arrive.start()
            SequentialAnimation {
                id: arrive
                PauseAnimation { duration: Math.min(cellItem.index, 24) * 14 }
                ParallelAnimation {
                    NumberAnimation { target: cellItem; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutQuad }
                    NumberAnimation { target: cellItem; property: "rise"; to: 0; duration: 380; easing.type: Easing.OutBack }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 12
                scale: cellItem.sel ? 1.06 : area.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: 60
                    source: Quickshell.iconPath(cellItem.modelData.icon, "application-x-executable")
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: grid.cellWidth - 16
                    horizontalAlignment: Text.AlignHCenter
                    text: cellItem.modelData.name
                    elide: Text.ElideRight
                    font.pixelSize: Theme.sm + 1
                    font.weight: cellItem.sel ? Font.DemiBold : Font.Normal
                    color: cellItem.sel ? "#ffffff" : Theme.alpha("#ffffff", 0.78)
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: 4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: root.index = cellItem.index
                onClicked: e => root.launch(cellItem.modelData, e.button === Qt.RightButton)
            }
        }
    }

    GridView {
        id: emojiGrid
        anchors.top: head.bottom
        anchors.topMargin: 40
        anchors.bottom: hints.top
        anchors.bottomMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, 96 * 10)
        cellWidth: width / Math.max(1, Math.floor(width / 96))
        cellHeight: 104
        clip: true
        visible: root.mode === "emoji"
        model: root.emojis
        currentIndex: root.index
        highlightMoveDuration: 120
        highlight: Rectangle { radius: 20; color: Theme.alpha("#ffffff", 0.12) }
        delegate: Item {
            id: em
            required property var modelData
            required property int index
            width: emojiGrid.cellWidth
            height: emojiGrid.cellHeight
            Column {
                anchors.centerIn: parent
                spacing: 6
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: em.modelData[0]; font.pixelSize: 44 }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: emojiGrid.cellWidth - 10
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: em.modelData[1]
                    font.pixelSize: Theme.xs
                    color: Theme.alpha("#ffffff", 0.6)
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.index = em.index
                onClicked: {
                    const emoji = em.modelData[0];
                    Ui.overlay = "";
                    Quickshell.execDetached(["sh", "-c", 'sleep 0.08; exec wtype -- "$1"', "sh", emoji]);
                }
            }
        }
    }

    Txt {
        id: hints
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        text: "enter  open        =  maths        >  run        ?  web        :  emoji        esc  close"
        font.family: Theme.mono
        font.pixelSize: Theme.xs + 1
        color: Theme.alpha("#ffffff", 0.4)
    }
}
