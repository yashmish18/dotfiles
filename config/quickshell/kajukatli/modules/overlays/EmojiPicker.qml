import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

Item {
    id: root
    property var emojiAll: []
    property int index: 0
    property string category: "recent"

    readonly property var categories: [
        { key: "recent", label: "Recent", prefix: "" },
        { key: "smile", label: "Smile", prefix: "SMILING|GRINNING|FACE|HAPPY" },
        { key: "people", label: "People", prefix: "PERSON|HAND|THUMB|WAVE" },
        { key: "nature", label: "Nature", prefix: "CAT|DOG|FLOWER|TREE|SUN|MOON|FIRE|RAIN" },
        { key: "food", label: "Food", prefix: "FOOD|FRUIT|APPLE|PIZZA|COFFEE|BREAD" },
        { key: "activity", label: "Activity", prefix: "BALL|SPORT|GAME|PARTY|MUSIC|GUITAR" },
        { key: "travel", label: "Travel", prefix: "CAR|TRAIN|PLANE|HOUSE|MAP|BUILDING" },
        { key: "symbols", label: "Symbols", prefix: "HEART|ARROW|CHECK|CROSS|STAR" }
    ]

    readonly property var recent: Store.s.recentEmojis || ["😀","😂","🥰","😊","👍","🎉","❤️","🔥","✨","😎","🤔","👀"]

    FileView {
        id: emojiFile
        path: Config.home + "/.cache/kajukatli/emoji.tsv"
        printErrors: false
        onLoaded: root.emojiAll = text().split("\n").filter(l => l).map(l => l.split("\t"))
        onLoadFailed: emojiMake.running = true
    }
    Process { id: emojiMake; command: [Config.bin + "kk-emoji-list"]; onExited: emojiFile.reload() }

    readonly property var emojis: {
        const query = search.text.trim().toLowerCase();
        if (root.category === "recent" && query === "") return root.recent.map(e => [e, "recent"]);
        let out = [];
        const active = root.categories.find(c => c.key === root.category);
        const re = active && active.prefix ? new RegExp(active.prefix) : null;
        for (const e of root.emojiAll) {
            if (query !== "" && e[1].indexOf(query) === -1) continue;
            if (re && !re.test(e[1])) continue;
            out.push(e);
            if (out.length >= 160) break;
        }
        return out;
    }

    function insertEmoji(emoji) {
        const recent = [emoji].concat((Store.s.recentEmojis || []).filter(e => e !== emoji)).slice(0, 16);
        Store.s.recentEmojis = recent;
        Ui.overlay = "";
        Quickshell.execDetached(["sh", "-c", 'sleep 0.08; exec wtype -- "$1"', "sh", emoji]);
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 620)
        height: Math.min(parent.height - 48, 520)
        radius: 18
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.outlineVariant

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    height: 42
                    font.pixelSize: Theme.lg
                    color: Theme.surfaceText
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText
                    Component.onCompleted: forceActiveFocus()
                    onTextChanged: root.index = 0
                    Keys.onEscapePressed: Ui.overlay = ""
                    Keys.onReturnPressed: if (root.emojis.length) root.insertEmoji(root.emojis[Math.min(root.index, root.emojis.length - 1)][0])
                    Keys.onLeftPressed: root.index = Math.max(0, root.index - 1)
                    Keys.onRightPressed: root.index = Math.min(root.emojis.length - 1, root.index + 1)
                    Keys.onUpPressed: root.index = Math.max(0, root.index - grid.cols)
                    Keys.onDownPressed: root.index = Math.min(root.emojis.length - 1, root.index + grid.cols)
                }
                Rectangle {
                    implicitWidth: 150
                    implicitHeight: 42
                    radius: 10
                    color: Theme.surfaceHigh
                    Txt {
                        anchors.centerIn: parent
                        text: search.text === "" ? "Search emoji" : search.text
                        color: search.text === "" ? Theme.surfaceTextDim : Theme.surfaceText
                    }
                }
            }

            Row {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: root.categories
                    delegate: Rectangle {
                        width: 68
                        height: 34
                        radius: 17
                        color: root.category === modelData.key ? Theme.primaryContainer : Theme.surfaceHigh
                        required property var modelData
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root.category = parent.modelData.key; root.index = 0; }
                        }
                        Txt {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            font.pixelSize: Theme.xs
                            color: root.category === parent.modelData.key ? Theme.primaryContainerText : Theme.surfaceTextDim
                        }
                    }
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property int cols: 8
                cellWidth: width / cols
                cellHeight: 54
                clip: true
                model: root.emojis
                currentIndex: root.index
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    radius: 10
                    color: index === root.index ? Theme.primaryContainer : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: modelData[0]
                        font.pixelSize: 30
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.index = index
                        onClicked: root.insertEmoji(modelData[0])
                    }
                }
            }
        }
    }
}
