import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// clipboard history from cliphist. type to filter, enter to copy back, delete to forget,
// tab pins (pinned things stay at the top, even after cliphist forgets them).
// copied pictures show as pictures.
Item {
    id: root
    implicitWidth: 500
    implicitHeight: col.implicitHeight + 6

    property var entries: []      // [{ id, raw, text, img }]
    property int index: 0
    readonly property var pins: Store.s.clipPins || []
    readonly property string thumbs: Config.runtimeDir + "/kk-clip"
    readonly property var shown: {
        const s = field.text.trim().toLowerCase();
        const pinned = pins.map(t => ({ id: "", raw: t, text: t, img: false, pinned: true }));
        const rest = entries.filter(e => pins.indexOf(e.raw) === -1);
        const all = pinned.concat(rest);
        return (s ? all.filter(e => e.text.toLowerCase().indexOf(s) !== -1) : all).slice(0, 10);
    }

    function pick(e: var) {
        if (!e) return;
        if (e.pinned) Quickshell.execDetached(["wl-copy", "--", e.raw]);
        else Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", e.id]);
        Ui.panel = "";
    }
    function forget(e: var) {
        if (!e) return;
        if (e.pinned) { togglePin(e); return; }
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\t%s\\n" "$1" "$2" | cliphist delete', "sh", e.id, e.raw]);
        entries = entries.filter(x => x.id !== e.id);
    }
    function togglePin(e: var) {
        if (!e || e.img) return;
        const p = pins.slice();
        const i = p.indexOf(e.raw);
        if (i === -1) p.unshift(e.raw); else p.splice(i, 1);
        Store.s.clipPins = p.slice(0, 20);
    }

    Process {
        running: true
        // pictures are decoded once into small files the list can show
        command: ["sh", "-c", 'mkdir -p "$1"; cliphist list | head -n 60 | while IFS="$(printf "\\t")" read -r id rest; do '
            + 'case "$rest" in "[[ binary data"*) [ -f "$1/$id.png" ] || cliphist decode "$id" > "$1/$id.png" 2>/dev/null ;; esac; '
            + 'printf "%s\\t%s\\n" "$id" "$rest"; done', "sh", root.thumbs]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 1) continue;
                    const raw = line.slice(tab + 1);
                    const img = raw.match(/^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) (\d+x\d+) \]\]$/i);
                    out.push({ id: line.slice(0, tab), raw: raw, text: img ? "picture " + img[2] : raw, img: !!img });
                }
                root.entries = out;
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 4

        Field {
            id: field
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            placeholder: "Search"
            size: Theme.lg
            Component.onCompleted: focusNow()
            onTextChanged: root.index = 0
            onAccepted: root.pick(root.shown[root.index])
            onEscaped: Ui.panel = ""
            onDownPressed: root.index = Math.min(root.index + 1, Math.max(0, root.shown.length - 1))
            onUpPressed: root.index = Math.max(0, root.index - 1)
            onTabPressed: root.togglePin(root.shown[root.index])
            captureDelete: true
            onDeletePressed: root.forget(root.shown[root.index])
        }

        Repeater {
            model: root.shown
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === root.index
                Layout.fillWidth: true
                implicitHeight: modelData.img ? 92 : 36
                radius: Theme.radiusSmall
                color: sel ? Theme.surfaceHighest : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                Image {
                    id: pic
                    visible: row.modelData.img
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 76
                    width: Math.min(220, implicitWidth > 0 ? implicitWidth * 76 / Math.max(1, implicitHeight) : 120)
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.height: 152
                    asynchronous: true
                    cache: false
                    source: row.modelData.img ? "file://" + root.thumbs + "/" + row.modelData.id + ".png" : ""
                }
                Txt {
                    anchors.left: row.modelData.img ? pic.right : parent.left
                    anchors.right: mark.left
                    anchors.leftMargin: row.modelData.img ? 14 : 12
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.text.replace(/\s+/g, " ")
                    elide: Text.ElideRight
                    font.family: Theme.mono
                    font.pixelSize: Theme.sm
                    color: row.sel ? Theme.surfaceText : Theme.surfaceTextDim
                }
                // the pin: always shown when pinned, on hover otherwise
                Rectangle {
                    id: mark
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: 12
                    visible: !row.modelData.img && (row.modelData.pinned || row.sel)
                    color: row.modelData.pinned ? Theme.primary : pinArea.containsMouse ? Theme.surfaceHigh : "transparent"
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6; height: 6; radius: 3
                        color: row.modelData.pinned ? Theme.primaryText : Theme.outline
                    }
                    MouseArea { id: pinArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePin(row.modelData) }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 36
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.index = row.index
                    onClicked: root.pick(row.modelData)
                }
            }
        }

        Txt {
            text: "enter  copy      tab  pin      del  forget"
            font.family: Theme.mono
            font.pixelSize: Theme.xs + 1
            color: Theme.outline
            Layout.topMargin: 6
        }
    }
}
