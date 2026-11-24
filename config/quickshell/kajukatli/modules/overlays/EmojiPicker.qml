import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// the emoji picker: super + period. a small card floating right by the pointer (where you
// were working), never stuck in a corner. drag it by its search bar to move it.
// type to search, arrows to move, enter (or a click) types it into the window you were in,
// and copies it too. tabs along the top narrow it down; the first one is what you used last.
LazyLoader {
    active: Ui.emojiOpen

    PanelWindow {
        id: win
        screen: Hypr.activeScreen
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "kajukatli-emoji"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors { left: true; top: true }
        margins { left: Math.max(0, spotX); top: Math.max(0, spotY) }
        implicitWidth: 348
        implicitHeight: 392
        color: "transparent"

        // where it floats: right by the pointer (just above it, or below when there's no room),
        // inside the screen and clear of the bar. worked out once when it opens; drag the
        // search bar to move it somewhere else.
        property int spotX: -1
        property int spotY: -1
        visible: spotX >= 0
        function place(cx: var, cy: var) {
            const sw = screen ? screen.width : 1920, sh = screen ? screen.height : 1080;
            const sx = screen ? screen.x : 0, sy = screen ? screen.y : 0;
            const w = implicitWidth, h = implicitHeight, pad = 14, gap = 18;
            const barBottom = Ui.barVisible && Config.s.barStyle !== "none" && Config.s.barStyle !== "rail" && Config.s.barPosition === "bottom" ? Theme.barHeight + 10 : 0;
            const top = pad + Ui.topInset, bottom = sh - h - pad - barBottom;
            let x = cx - sx - w / 2;
            let y = cy - sy - h - gap;                    // above the pointer
            if (y < top) y = cy - sy + gap;                // no room: below it
            if (cx < 0) { x = (sw - w) / 2; y = (sh - h) / 2; }   // no pointer: the middle
            spotX = Math.round(Math.max(pad, Math.min(sw - w - pad, x)));
            spotY = Math.round(Math.max(top, Math.min(bottom, y)));
        }
        Process {
            id: cursor
            running: true
            command: ["hyprctl", "cursorpos", "-j"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { const c = JSON.parse(text); win.place(c.x, c.y); } catch (e) { win.place(-1, -1); }
                }
            }
            onExited: code => { if (code !== 0 && win.spotX < 0) win.place(-1, -1); }
        }
        function moveBy(dx: var, dy: var) {
            const sw = screen ? screen.width : 1920, sh = screen ? screen.height : 1080;
            spotX = Math.round(Math.max(0, Math.min(sw - implicitWidth, spotX + dx)));
            spotY = Math.round(Math.max(0, Math.min(sh - implicitHeight, spotY + dy)));
        }

        // a click anywhere else closes it
        HyprlandFocusGrab {
            windows: [win]
            active: true
            onCleared: Ui.emojiOpen = false
        }

        property var all: []            // [[emoji, name]]
        property int index: 0
        property string tab: "recent"
        property string hovered: ""

        FileView {
            id: list
            path: Config.home + "/.cache/kajukatli/emoji.tsv"
            printErrors: false
            onLoaded: win.all = text().split("\n").filter(l => l).map(l => l.split("\t"))
            onLoadFailed: make.running = true
        }
        Process { id: make; command: [Config.bin + "kk-emoji-list"]; onExited: list.reload() }

        // tabs: an emoji for a label, and the words its names contain
        readonly property var tabs: [
            { key: "recent", glyph: "🕘", words: "" },
            { key: "faces", glyph: "😀", words: "face|smiling|grinning|winking|kissing|crying|tears|tongue|eyes" },
            { key: "people", glyph: "👋", words: "hand|hands|thumbs|person|man|woman|boy|girl|baby|clapping|waving|finger|fist|flexed" },
            { key: "nature", glyph: "🐱", words: "cat|dog|animal|flower|tree|leaf|sun|moon|cloud|fire|snowflake|rain|bird|fish|monkey|bear|horse|blossom|rose|wave" },
            { key: "food", glyph: "🍕", words: "food|fruit|apple|pizza|coffee|bread|cake|hamburger|banana|grapes|beer|wine|tea|rice|noodles|cookie|candy|chocolate|taco|sushi" },
            { key: "things", glyph: "⚽", words: "ball|game|party|musical|guitar|trophy|medal|die|ticket|art|gift|balloon|camera|phone|laptop|book" },
            { key: "places", glyph: "✈️", words: "car|train|airplane|house|map|building|ship|bus|rocket|bicycle|mountain|beach|city|tent" },
            { key: "symbols", glyph: "❤️", words: "heart|arrow|check|cross|star|sparkles|sign|symbol|mark|circle|square" }
        ]
        readonly property var recent: Store.s.recentEmojis && Store.s.recentEmojis.length
            ? Store.s.recentEmojis : ["😀", "😂", "🥰", "😊", "👍", "🎉", "❤️", "🔥", "✨", "😎", "🤔", "👀", "🙏", "😭", "💀", "🫡"]

        readonly property var shown: {
            const q = search.text.trim().toLowerCase();
            if (q === "" && tab === "recent") return recent.map(e => [e, ""]);
            const t = tabs.find(x => x.key === tab);
            const re = q === "" && t && t.words ? new RegExp("\\b(" + t.words + ")\\b") : null;
            const words = q.split(/\s+/).filter(w => w);
            const out = [];
            for (const e of all) {
                if (words.length && !words.every(w => e[1].indexOf(w) !== -1)) continue;
                if (re && !re.test(e[1])) continue;
                out.push(e);
                if (out.length >= 240) break;
            }
            return out;
        }

        function pick(e: var) {
            if (!e) return;
            Store.s.recentEmojis = [e].concat((Store.s.recentEmojis || []).filter(x => x !== e)).slice(0, 24);
            Ui.emojiOpen = false;
            // into the window you were typing in (once it has the keyboard back), and the clipboard
            Quickshell.execDetached([Config.bin + "kk-emoji-type", e]);
        }
        function move(d: var) {
            if (!shown.length) return;
            index = Math.max(0, Math.min(shown.length - 1, index + d));
            grid.positionViewAtIndex(index, GridView.Contain);
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Theme.radius + 8
            color: Theme.glassStrong
            border.width: 1
            border.color: Theme.alpha(Theme.surfaceText, 0.08)
            // arrives from the corner
            opacity: 0
            scale: 0.94
            transformOrigin: Item.BottomLeft
            Component.onCompleted: { opacity = 1; scale = 1; }
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            // the grip along the top: drag it to move the card
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 5
                width: 36; height: 4; radius: 2
                color: Theme.alpha(Theme.surfaceText, grip.containsMouse || grip.pressed ? 0.4 : 0.18)
            }
            MouseArea {
                id: grip
                width: parent.width
                height: 14
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point from
                onPressed: m => from = Qt.point(m.x, m.y)
                onPositionChanged: m => { if (pressed) win.moveBy(m.x - from.x, m.y - from.y); }
            }

            // search
            Item {
                id: head
                x: 16; y: 14
                width: parent.width - 32
                height: 34
                TextInput {
                    id: search
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.sans
                    font.pixelSize: Theme.lg
                    color: Theme.surfaceText
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText
                    focus: true
                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: { win.index = 0; grid.positionViewAtBeginning(); }
                    Keys.onEscapePressed: Ui.emojiOpen = false
                    Keys.onReturnPressed: win.pick(win.shown.length ? win.shown[Math.min(win.index, win.shown.length - 1)][0] : "")
                    Keys.onEnterPressed: win.pick(win.shown.length ? win.shown[Math.min(win.index, win.shown.length - 1)][0] : "")
                    Keys.onLeftPressed: win.move(-1)
                    Keys.onRightPressed: win.move(1)
                    Keys.onUpPressed: win.move(-grid.cols)
                    Keys.onDownPressed: win.move(grid.cols)
                    Keys.onTabPressed: { const i = win.tabs.findIndex(t => t.key === win.tab); win.tab = win.tabs[(i + 1) % win.tabs.length].key; win.index = 0; }
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Search emoji"
                    font.pixelSize: Theme.lg
                    color: Theme.outline
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.alpha(Theme.surfaceText, 0.1)
                }
            }

            // tabs (hidden while searching: the search covers everything)
            Row {
                id: tabRow
                anchors.top: head.bottom
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                opacity: search.text === "" ? 1 : 0.35
                Repeater {
                    model: win.tabs
                    delegate: Rectangle {
                        id: tb
                        required property var modelData
                        readonly property bool on: win.tab === modelData.key && search.text === ""
                        width: 38; height: 32; radius: 10
                        color: on ? Theme.alpha(Theme.primary, 0.22) : ta.containsMouse ? Theme.surfaceHigh : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: tb.modelData.glyph; font.pixelSize: 17; opacity: tb.on ? 1 : 0.7 }
                        Rectangle {
                            visible: tb.on
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 14; height: 2; radius: 1
                            color: Theme.primary
                        }
                        MouseArea { id: ta; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { search.text = ""; win.tab = tb.modelData.key; win.index = 0; } }
                    }
                }
            }

            GridView {
                id: grid
                readonly property int cols: 8
                anchors.top: tabRow.bottom
                anchors.topMargin: 6
                anchors.bottom: foot.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                cellWidth: width / cols
                cellHeight: cellWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.shown
                currentIndex: win.index
                highlightMoveDuration: 90
                highlight: Rectangle { radius: 10; color: Theme.alpha(Theme.primary, 0.22) }
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData[0]
                        font.pixelSize: 24
                        scale: ca.pressed ? 0.85 : ca.containsMouse ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: 110 } }
                    }
                    MouseArea {
                        id: ca
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { win.index = cell.index; }
                        onClicked: win.pick(cell.modelData[0])
                    }
                }
            }

            // the name of the one you're on
            Txt {
                id: foot
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 14
                height: 18
                elide: Text.ElideRight
                readonly property var cur: win.shown.length ? win.shown[Math.min(win.index, win.shown.length - 1)] : null
                text: cur ? (cur[1] !== "" ? cur[0] + "  " + cur[1] : cur[0] + "  recently used") : (win.all.length ? "nothing by that name" : "")
                font.family: Theme.mono
                font.pixelSize: Theme.xs + 1
                color: Theme.surfaceTextDim
            }
        }
    }
}
