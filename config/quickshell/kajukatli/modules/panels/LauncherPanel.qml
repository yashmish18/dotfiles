import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.services
import qs.components

// type to find an app. a few prefixes:
//   =  calculator        (= 12*7)
//   >  run a command     (> htop)   opens in kitty
//   ?  search the web
//   /  find a file in your home folder
// with nothing typed, the apps you open most come first.
Item {
    id: root
    implicitWidth: 520
    implicitHeight: col.implicitHeight + 6

    property int index: 0
    readonly property string q: field.text.trim()
    readonly property string mode: q.startsWith("=") ? "calc" : q.startsWith(">") ? "run" : q.startsWith("?") ? "web" : q.startsWith("/") ? "files" : "apps"
    readonly property var launches: Store.s.launches || ({})
    function used(app: var): int { return launches[app.id] || 0; }

    function score(app: var, s: var): real {
        const name = (app.name || "").toLowerCase();
        if (!s) return 1;
        if (name.startsWith(s)) return 100 - name.length * 0.1;
        if (name.split(/[\s\-_]/).some(w => w.startsWith(s))) return 60;
        if (name.indexOf(s) !== -1) return 40;
        const extra = [app.genericName, app.comment, (app.keywords || []).join(" ")].join(" ").toLowerCase();
        if (extra.indexOf(s) !== -1) return 20;
        // letters in order ("ffx" → firefox)
        let i = 0;
        for (const c of name) if (c === s[i]) i++;
        return i === s.length ? 10 : 0;
    }

    readonly property var results: {
        if (mode !== "apps") return [];
        const s = q.toLowerCase();
        const all = DesktopEntries.applications.values;
        const scored = [];
        for (const a of all) {
            // what you open often floats up; with nothing typed, that's the whole order
            const v = score(a, s) * (s ? 1 : 0) + Math.min(30, used(a) * 2) + (s ? 0 : 0.01);
            if (s ? score(a, s) > 0 : true) scored.push({ app: a, v: v });
        }
        scored.sort((x, y) => y.v - x.v || x.app.name.localeCompare(y.app.name));
        return scored.slice(0, 8).map(x => x.app);
    }

    readonly property string calc: {
        if (mode !== "calc") return "";
        const expr = q.slice(1).replace(/\^/g, "**").replace(/×/g, "*").replace(/÷/g, "/");
        if (!/^[\d\s+\-*/().%e*]*$/.test(expr) || expr.trim() === "") return "";
        try {
            const v = Function('"use strict"; return (' + expr + ")")();
            return typeof v === "number" && isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) {
            return "";
        }
    }

    function launch(app: var, onGpu: var) {
        if (!app) return;
        Ui.panel = "";
        const l = Object.assign({}, Store.s.launches || {});
        l[app.id] = (l[app.id] || 0) + 1;
        Store.s.launches = l;
        if (app.runInTerminal)
            Quickshell.execDetached({ command: ["kitty", "--"].concat(app.command), workingDirectory: app.workingDirectory || Config.home });
        else
            Quickshell.execDetached({ command: Gpu.wrap(app.command, app, onGpu === true), workingDirectory: app.workingDirectory || Config.home });
    }

    function accept() {
        if (mode === "apps") launch(results[index]);
        else if (mode === "calc" && calc !== "") { Quickshell.execDetached(["wl-copy", calc]); Ui.panel = ""; }
        else if (mode === "run" && q.length > 1) { Ui.panel = ""; Quickshell.execDetached(["kitty", "--hold", "sh", "-c", q.slice(1).trim()]); }
        else if (mode === "web" && q.length > 1) { Ui.panel = ""; Qt.openUrlExternally("https://duckduckgo.com/?q=" + encodeURIComponent(q.slice(1).trim())); }
        else if (mode === "files" && files.length > 0) openFile(files[Math.min(index, files.length - 1)]);
    }

    // ---------------------------------------------------------------- files
    property var files: []
    function openFile(path: var) {
        Ui.panel = "";
        Quickshell.execDetached(["xdg-open", path]);
    }
    Timer {
        id: findLater
        interval: 160
        onTriggered: {
            const term = root.q.slice(1).trim();
            if (term.length < 2) { root.files = []; return; }
            if (finder.running) return;     // onExited looks again if the text moved on
            finder.asked = term;
            finder.command = ["sh", "-c",
                'cd "$HOME" && if command -v fd >/dev/null; then fd -i -t f -t d --max-results 8 -- "$1"; '
                + 'else find . -maxdepth 5 -not -path "*/.*" -iname "*$1*" 2>/dev/null | head -n 8 | sed "s|^\\./||"; fi',
                "sh", term];
            finder.running = true;
        }
    }
    onQChanged: if (mode === "files") findLater.restart(); else files = []
    Process {
        id: finder
        property string asked: ""
        onExited: if (root.mode === "files" && root.q.slice(1).trim() !== asked) findLater.restart()
        stdout: StdioCollector {
            onStreamFinished: if (root.q.slice(1).trim() === finder.asked) root.files = text.split("\n").filter(x => x !== "").map(x => Config.home + "/" + x)
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        Field {
            id: field
            Layout.fillWidth: true
            placeholder: "Search"
            size: Theme.lg + 2
            Component.onCompleted: focusNow()
            onTextChanged: root.index = 0
            onAccepted: root.accept()
            onEscaped: Ui.panel = ""
            onDownPressed: root.index = Math.min(root.index + 1, Math.max(0, (root.mode === "files" ? root.files.length : root.results.length) - 1))
            onUpPressed: root.index = Math.max(0, root.index - 1)
            onTabPressed: root.index = (root.index + 1) % Math.max(1, (root.mode === "files" ? root.files : root.results).length)
        }

        Repeater {
            model: root.results
            delegate: Rectangle {
                id: item
                required property var modelData
                required property int index
                readonly property bool sel: index === root.index
                Layout.fillWidth: true
                implicitHeight: 50
                radius: Theme.radius
                color: sel ? Theme.primaryContainer : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                IconImage {
                    id: icon
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 30
                    source: Quickshell.iconPath(item.modelData.icon, "application-x-executable")
                }
                Txt {
                    anchors.left: icon.right
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.5
                    text: item.modelData.name
                    font.pixelSize: Theme.md + 1
                    font.weight: item.sel ? Font.DemiBold : Font.Medium
                    color: item.sel ? Theme.primaryContainerText : Theme.surfaceText
                }
                Txt {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.38
                    horizontalAlignment: Text.AlignRight
                    text: item.modelData.genericName || item.modelData.comment || ""
                    font.pixelSize: Theme.sm
                    color: item.sel ? Theme.alpha(Theme.primaryContainerText, 0.75) : Theme.outline
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: root.index = item.index
                    onClicked: e => root.launch(item.modelData, e.button === Qt.RightButton)
                }
            }
        }

        Repeater {
            model: root.mode === "files" ? root.files : []
            delegate: Rectangle {
                id: frow
                required property var modelData
                required property int index
                readonly property bool sel: index === root.index
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Theme.radius
                color: sel ? Theme.primaryContainer : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Txt {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: frow.modelData.slice(Config.home.length + 1)
                    elide: Text.ElideMiddle
                    font.family: Theme.mono
                    font.pixelSize: Theme.sm
                    color: frow.sel ? Theme.primaryContainerText : Theme.surfaceText
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.index = frow.index
                    onClicked: root.openFile(frow.modelData)
                }
            }
        }

        Txt {
            visible: (root.mode !== "apps" && !(root.mode === "files" && root.files.length > 0)) || (root.mode === "apps" && root.results.length === 0)
            Layout.fillWidth: true
            Layout.leftMargin: 2
            text: root.mode === "calc" ? (root.calc !== "" ? "= " + root.calc + "    enter copies it" : "keep typing…")
                : root.mode === "run" ? "enter runs it in a terminal"
                : root.mode === "web" ? "enter searches the web"
                : root.mode === "files" ? (root.q.length < 3 ? "a file or folder name" : "nothing in your home folder by that name")
                : root.q === "" ? "" : "no app by that name. try > to run it, or ? to search."
            font.family: root.mode === "calc" && root.calc !== "" ? Theme.mono : Theme.sans
            font.pixelSize: root.mode === "calc" && root.calc !== "" ? Theme.lg : Theme.sm
            color: root.mode === "calc" && root.calc !== "" ? Theme.primary : Theme.surfaceTextDim
        }

        Txt {
            text: "=  math      >  command      ?  web      /  files      ↑↓  choose"
            font.family: Theme.mono
            font.pixelSize: Theme.xs + 1
            color: Theme.outline
            Layout.topMargin: 2
        }
    }
}
