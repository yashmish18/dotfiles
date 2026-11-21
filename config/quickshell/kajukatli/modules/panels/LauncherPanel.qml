import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.components

// type to find an app. a few prefixes:
//   =  calculator        (= 12*7)
//   >  run a command     (> htop)   opens in kitty
//   ?  search the web
Item {
    id: root
    implicitWidth: 460
    implicitHeight: col.implicitHeight + 6

    property int index: 0
    readonly property string q: field.text.trim()
    readonly property string mode: q.startsWith("=") ? "calc" : q.startsWith(">") ? "run" : q.startsWith("?") ? "web" : "apps"

    function score(app, s) {
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
            const v = score(a, s);
            if (v > 0) scored.push({ app: a, v: v });
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

    function launch(app) {
        if (!app) return;
        Ui.panel = "";
        if (app.runInTerminal)
            Quickshell.execDetached({ command: ["kitty", "--"].concat(app.command), workingDirectory: app.workingDirectory || Config.home });
        else
            Quickshell.execDetached({ command: app.command, workingDirectory: app.workingDirectory || Config.home });
    }

    function accept() {
        if (mode === "apps") launch(results[index]);
        else if (mode === "calc" && calc !== "") { Quickshell.execDetached(["wl-copy", calc]); Ui.panel = ""; }
        else if (mode === "run" && q.length > 1) { Ui.panel = ""; Quickshell.execDetached(["kitty", "--hold", "sh", "-c", q.slice(1).trim()]); }
        else if (mode === "web" && q.length > 1) { Ui.panel = ""; Qt.openUrlExternally("https://duckduckgo.com/?q=" + encodeURIComponent(q.slice(1).trim())); }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        Field {
            id: field
            Layout.fillWidth: true
            placeholder: "what are we opening?"
            size: Theme.lg + 2
            Component.onCompleted: focusNow()
            onTextChanged: root.index = 0
            onAccepted: root.accept()
            onEscaped: Ui.panel = ""
            onDownPressed: root.index = Math.min(root.index + 1, Math.max(0, root.results.length - 1))
            onUpPressed: root.index = Math.max(0, root.index - 1)
            onTabPressed: root.index = (root.index + 1) % Math.max(1, root.results.length)
        }

        Repeater {
            model: root.results
            delegate: Rectangle {
                id: item
                required property var modelData
                required property int index
                readonly property bool sel: index === root.index
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 6
                color: sel ? Theme.raised : "transparent"
                border.width: sel ? 1 : 0
                border.color: Theme.line

                IconImage {
                    id: icon
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 20
                    source: Quickshell.iconPath(item.modelData.icon, "application-x-executable")
                }
                Txt {
                    anchors.left: icon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.5
                    text: item.modelData.name
                    font.pixelSize: Theme.md + 1
                    color: item.sel ? Theme.paper : Theme.muted
                }
                Txt {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.38
                    horizontalAlignment: Text.AlignRight
                    text: (item.modelData.genericName || item.modelData.comment || "").toLowerCase()
                    font.family: Theme.serif
                    font.italic: true
                    font.pixelSize: Theme.sm
                    color: Theme.faint
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.index = item.index
                    onClicked: root.launch(item.modelData)
                }
            }
        }

        Txt {
            visible: root.mode !== "apps" || root.results.length === 0
            Layout.fillWidth: true
            Layout.leftMargin: 2
            text: root.mode === "calc" ? (root.calc !== "" ? "= " + root.calc + "    enter copies it" : "keep typing…")
                : root.mode === "run" ? "enter runs it in a terminal"
                : root.mode === "web" ? "enter searches the web"
                : root.q === "" ? "" : "no app by that name. try > to run it, or ? to search."
            font.family: root.mode === "calc" && root.calc !== "" ? Theme.mono : Theme.serif
            font.italic: !(root.mode === "calc" && root.calc !== "")
            font.pixelSize: root.mode === "calc" && root.calc !== "" ? Theme.lg : Theme.sm
            color: root.mode === "calc" && root.calc !== "" ? Theme.accent : Theme.muted
        }

        Txt {
            text: "=  math      >  command      ?  web      ↑↓  choose"
            font.family: Theme.mono
            font.pixelSize: Theme.xs
            color: Theme.faint
            Layout.topMargin: 2
        }
    }
}
