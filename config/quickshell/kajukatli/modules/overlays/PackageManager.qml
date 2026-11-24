import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// super + shift + i: software, in one place (kk-pkg does the work).
//   Search      the official repos, the aur and flathub together, each one labelled
//   Installed   what you installed yourself, its size; remove anything
//   Updates     what has a newer version, and "update everything"
//   Developer   ready-made setups (python, node, rust, docker…) and a check of the basics
// install / remove run in a terminal, so you see exactly what happens and type your password
// there; the lists refresh by themselves when it's done.
Item {
    id: root
    focus: true
    property string tab: "search"
    property string status: ""
    property var results: []
    property var installed: []
    property var updates: []
    property var bundles: []
    property var picked: null          // the package whose details show
    property string details: ""
    property string filter: ""
    Keys.onEscapePressed: Ui.overlay = ""

    function jsonLines(text) {
        const out = [];
        for (const l of text.split("\n")) { try { if (l.trim()) out.push(JSON.parse(l)); } catch (e) {} }
        return out;
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                const all = root.jsonLines(text);
                // exact name first, then installed, then the repos before the aur before flathub
                const q = searchInput.text.trim().toLowerCase();
                const rank = { repo: 0, aur: 1, flatpak: 2 };
                all.sort((a, b) => ((b.name.toLowerCase() === q) - (a.name.toLowerCase() === q)) || (rank[a.source] - rank[b.source]));
                root.results = all.slice(0, 200);
                root.status = all.length ? all.length + " found" : "Nothing by that name";
            }
        }
    }
    Timer { id: searchSoon; interval: 400; onTriggered: root.search() }
    function search() {
        const q = searchInput.text.trim();
        if (q.length < 2) { results = []; status = ""; return; }
        status = "Searching…";
        searchProc.running = false;
        searchProc.command = [Config.bin + "kk-pkg", "search", q];
        searchProc.running = true;
    }
    Process {
        id: instProc
        command: [Config.bin + "kk-pkg", "installed"]
        stdout: StdioCollector { onStreamFinished: { root.installed = root.jsonLines(text).sort((a, b) => a.name.localeCompare(b.name)); } }
    }
    Process {
        id: updProc
        command: [Config.bin + "kk-pkg", "updates"]
        stdout: StdioCollector { onStreamFinished: { root.updates = root.jsonLines(text); root.checking = false; } }
    }
    property bool checking: false
    Process {
        id: bunProc
        command: [Config.bin + "kk-pkg", "bundles"]
        stdout: StdioCollector { onStreamFinished: root.bundles = root.jsonLines(text) }
    }
    Process {
        id: infoProc
        stdout: StdioCollector { onStreamFinished: root.details = text.trim() }
    }
    Process {
        id: devProc
        command: [Config.bin + "kk-pkg", "dev"]
        stdout: StdioCollector { onStreamFinished: root.devReport = text.trim() }
    }
    property string devReport: ""
    Component.onCompleted: { instProc.running = true; searchInput.forceActiveFocus(); }
    onTabChanged: {
        picked = null;
        if (tab === "installed" && !instProc.running) instProc.running = true;
        if (tab === "updates" && !updProc.running) { checking = true; updProc.running = true; }
        if (tab === "developer") { if (!bunProc.running) bunProc.running = true; if (!devProc.running) devProc.running = true; }
    }
    function pick(p) {
        picked = p;
        details = "…";
        infoProc.command = [Config.bin + "kk-pkg", "info", p.name, p.source];
        infoProc.running = true;
    }

    // the terminal doing the work; everything refreshes when it closes
    Process {
        id: termProc
        onExited: {
            root.status = "Done";
            instProc.running = true;
            if (root.tab === "updates") { root.checking = true; updProc.running = true; }
            if (root.tab === "developer") bunProc.running = true;
            if (searchInput.text.trim().length >= 2) root.search();
        }
    }
    function runInTerminal(args, what) {
        status = what + " in the terminal…";
        termProc.command = ["kitty", "--class", "kk-float", "--title", what, "sh", "-c",
            '"$@"; s=$?; echo; [ $s = 0 ] && echo "done. this closes in a moment." || echo "that didn\'t work (exit $s). press enter."; [ $s = 0 ] && sleep 2 || read _', "sh"].concat(args);
        termProc.running = true;
    }
    function install(p) { runInTerminal([Config.bin + "kk-pkg", "install", p.name, p.source], "Installing " + p.name); }
    function remove(p) { runInTerminal([Config.bin + "kk-pkg", "remove", p.name, p.source], "Removing " + p.name); }

    readonly property var tabs: [
        { key: "search", label: "Search", icon: "search" },
        { key: "installed", label: "Installed", icon: "check" },
        { key: "updates", label: "Updates", icon: "download" },
        { key: "developer", label: "Developer", icon: "spark" }
    ]
    readonly property var shownInstalled: {
        const q = filter.trim().toLowerCase();
        return q ? installed.filter(p => p.name.toLowerCase().indexOf(q) !== -1 || (p.desc || "").toLowerCase().indexOf(q) !== -1) : installed;
    }

    // a source badge: where it comes from
    component Badge: Rectangle {
        property string source: "repo"
        width: bt.implicitWidth + 12
        height: 18
        radius: 9
        color: source === "aur" ? Theme.alpha(Theme.tertiary, 0.25) : source === "flatpak" ? Theme.alpha(Theme.secondary, 0.25) : Theme.alpha(Theme.primary, 0.2)
        Txt { id: bt; anchors.centerIn: parent; text: parent.source === "repo" ? "arch" : parent.source; font.pixelSize: Theme.xs; font.family: Theme.mono }
    }
    // one package in a list
    component PkgRow: Rectangle {
        id: pr
        property var p: ({})
        property var host: null           // the page (inline components can't see its id)
        property bool showSize: false
        signal act()
        height: 52
        radius: 10
        color: pr.host && pr.host.picked && pr.host.picked.name === p.name && pr.host.picked.source === p.source ? Theme.alpha(Theme.primary, 0.16) : prArea.containsMouse ? Theme.surfaceHigh : "transparent"
        MouseArea { id: prArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pr.host.pick(pr.p) }
        Column {
            x: 12
            width: parent.width - 200
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Row {
                spacing: 8
                Txt { text: pr.p.name || ""; font.weight: Font.DemiBold }
                Badge { source: pr.p.source || "repo"; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: pr.p.version || ""; font.family: Theme.mono; font.pixelSize: Theme.xs + 1; color: Theme.outline; anchors.verticalCenter: parent.verticalCenter }
            }
            Txt { width: parent.width; text: pr.p.desc || ""; elide: Text.ElideRight; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Txt { visible: pr.showSize; anchors.verticalCenter: parent.verticalCenter; text: pr.p.size || ""; font.family: Theme.mono; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
            Btn {
                text: pr.p.installed ? "Remove" : "Install"
                danger: pr.p.installed === true
                primary: !pr.p.installed
                onClicked: pr.p.installed ? pr.host.remove(pr.p) : pr.host.install(pr.p)
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, 1100)
        height: Math.min(parent.height, 740)
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
                Txt { text: "Software"; font.pixelSize: Theme.xl; font.weight: Font.Bold; Layout.rightMargin: 14 }
                Repeater {
                    model: root.tabs
                    delegate: Btn {
                        required property var modelData
                        text: modelData.label + (modelData.key === "updates" && root.updates.length ? " (" + root.updates.length + ")" : "")
                        icon: modelData.icon
                        active: root.tab === modelData.key
                        onClicked: root.tab = modelData.key
                    }
                }
                Item { Layout.fillWidth: true }
                Txt { text: root.status; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                Btn { icon: "close"; onClicked: Ui.overlay = "" }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.tabs.findIndex(t => t.key === root.tab)

                    // ---------------------------------------------- search
                    ColumnLayout {
                        spacing: 10
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: 22
                            color: Theme.surfaceHigh
                            Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16; color: Theme.surfaceTextDim }
                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                anchors.leftMargin: 40
                                anchors.rightMargin: 14
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Theme.sans
                                font.pixelSize: Theme.md
                                color: Theme.surfaceText
                                selectionColor: Theme.primary
                                onTextChanged: searchSoon.restart()
                                Keys.onReturnPressed: root.search()
                                Keys.onEscapePressed: Ui.overlay = ""
                            }
                            Txt {
                                anchors.left: parent.left; anchors.leftMargin: 40
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchInput.text === ""
                                text: "Search apps and packages: arch, aur and flathub"
                                color: Theme.outline
                            }
                        }
                        ListView {
                            id: resList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.results
                            delegate: PkgRow { required property var modelData; host: root; p: modelData; width: resList.width }
                        }
                    }

                    // ---------------------------------------------- installed
                    ColumnLayout {
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Field { Layout.preferredWidth: 280; size: Theme.md; placeholder: "Filter what's installed"; onTextChanged: root.filter = text }
                            Item { Layout.fillWidth: true }
                            Txt { text: root.installed.length + " installed by you"; color: Theme.surfaceTextDim; font.pixelSize: Theme.sm }
                        }
                        ListView {
                            id: instList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.shownInstalled
                            delegate: PkgRow { required property var modelData; host: root; p: modelData; showSize: true; width: instList.width }
                        }
                    }

                    // ---------------------------------------------- updates
                    ColumnLayout {
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Txt { text: root.checking ? "Checking…" : root.updates.length ? root.updates.length + " updates" : "Everything is up to date"; font.weight: Font.DemiBold; Layout.fillWidth: true }
                            Btn { icon: "restart"; enabled: !root.checking; onClicked: { root.checking = true; updProc.running = true; } }
                            Btn { text: "Update everything"; primary: true; enabled: root.updates.length > 0; onClicked: root.runInTerminal([Config.bin + "kk-pkg", "upgrade"], "Updating") }
                        }
                        ListView {
                            id: updList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: root.updates
                            delegate: Rectangle {
                                required property var modelData
                                width: updList.width
                                height: 36
                                radius: 8
                                color: "transparent"
                                Row {
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Txt { text: modelData.name; font.weight: Font.DemiBold }
                                    Badge { source: modelData.source; anchors.verticalCenter: parent.verticalCenter }
                                    Txt { text: modelData.desc + " → " + modelData.version; font.family: Theme.mono; font.pixelSize: Theme.sm; color: Theme.surfaceTextDim }
                                }
                            }
                        }
                    }

                    // ---------------------------------------------- developer
                    Flickable {
                        clip: true
                        contentHeight: devCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: devCol
                            width: parent.width
                            spacing: 10
                            Txt { text: "READY-MADE SETUPS"; font.pixelSize: Theme.xs + 1; font.letterSpacing: 1.2; font.weight: Font.DemiBold; color: Theme.outline }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 10
                                Repeater {
                                    model: root.bundles
                                    delegate: Rectangle {
                                        id: bn
                                        required property var modelData
                                        readonly property bool done: modelData.total > 0 && modelData.have === modelData.total
                                        width: 236; height: 104
                                        radius: 16
                                        color: Theme.surfaceHigh
                                        border.width: done ? 2 : 0
                                        border.color: Theme.primary
                                        Column {
                                            x: 14; y: 12
                                            width: parent.width - 28
                                            spacing: 3
                                            Txt { text: bn.modelData.title; font.weight: Font.Bold }
                                            Txt { width: parent.width; text: bn.modelData.packages; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; font.family: Theme.mono; font.pixelSize: Theme.xs; color: Theme.surfaceTextDim }
                                        }
                                        Btn {
                                            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
                                            text: bn.done ? "Installed" : bn.modelData.have > 0 ? "Finish (" + bn.modelData.have + "/" + bn.modelData.total + ")" : "Set up"
                                            primary: !bn.done
                                            enabled: !bn.done
                                            onClicked: root.runInTerminal([Config.bin + "kk-pkg", "bundle", bn.modelData.key], "Setting up " + bn.modelData.title)
                                        }
                                    }
                                }
                            }
                            Txt { text: "THE BASICS"; font.pixelSize: Theme.xs + 1; font.letterSpacing: 1.2; font.weight: Font.DemiBold; color: Theme.outline; Layout.topMargin: 8 }
                            Txt { Layout.fillWidth: true; text: root.devReport || "…"; font.family: Theme.mono; font.pixelSize: Theme.sm; wrapMode: Text.WordWrap }
                            Row {
                                spacing: 8
                                Btn { text: "Set git identity"; onClicked: root.runInTerminal([Config.bin + "kk-git-identity"], "Git identity") }
                                Btn { text: "Make an ssh key"; onClicked: root.runInTerminal(["ssh-keygen", "-t", "ed25519"], "SSH key") }
                                Btn { text: "Log in to GitHub"; onClicked: root.runInTerminal(["gh", "auth", "login"], "GitHub") }
                            }
                        }
                    }
                }

                // details of the picked package
                Rectangle {
                    visible: root.picked !== null
                    Layout.preferredWidth: 340
                    Layout.fillHeight: true
                    radius: 16
                    color: Theme.surfaceLow
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Txt { text: root.picked ? root.picked.name : ""; font.pixelSize: Theme.lg; font.weight: Font.Bold; Layout.fillWidth: true; elide: Text.ElideRight }
                            Btn { icon: "close"; flat: true; onClicked: root.picked = null }
                        }
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentHeight: info.implicitHeight
                            Txt { id: info; width: parent.width; text: root.details; wrapMode: Text.WrapAnywhere; font.family: Theme.mono; font.pixelSize: Theme.xs + 1; color: Theme.surfaceTextDim }
                        }
                        Btn {
                            Layout.fillWidth: true
                            text: root.picked && root.picked.installed ? "Remove" : "Install"
                            danger: root.picked !== null && root.picked.installed === true
                            primary: root.picked !== null && !root.picked.installed
                            onClicked: root.picked.installed ? root.remove(root.picked) : root.install(root.picked)
                        }
                    }
                }
            }
        }
    }
}
