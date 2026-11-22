import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// clipboard history from cliphist. type to filter, enter to copy back, delete to forget.
Item {
    id: root
    implicitWidth: 460
    implicitHeight: col.implicitHeight + 6

    property var entries: []      // [{ id, text }]
    property int index: 0
    readonly property var shown: {
        const s = field.text.trim().toLowerCase();
        return (s ? entries.filter(e => e.text.toLowerCase().indexOf(s) !== -1) : entries).slice(0, 9);
    }

    function pick(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", e.id]);
        Ui.panel = "";
    }
    function forget(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\t%s\\n" "$1" "$2" | cliphist delete', "sh", e.id, e.raw]);
        entries = entries.filter(x => x.id !== e.id);
    }

    Process {
        running: true
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 1) continue;
                    const raw = line.slice(tab + 1);
                    const img = raw.match(/^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) (\d+x\d+) \]\]$/i);
                    out.push({ id: line.slice(0, tab), raw: raw, text: img ? "image · " + img[2] : raw });
                }
                root.entries = out;
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 6

        Field {
            id: field
            Layout.fillWidth: true
            placeholder: "something you copied…"
            size: Theme.lg
            Component.onCompleted: focusNow()
            onTextChanged: root.index = 0
            onAccepted: root.pick(root.shown[root.index])
            onEscaped: Ui.panel = ""
            onDownPressed: root.index = Math.min(root.index + 1, Math.max(0, root.shown.length - 1))
            onUpPressed: root.index = Math.max(0, root.index - 1)
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
                implicitHeight: 34
                radius: 6
                color: sel ? Theme.raised : "transparent"
                Txt {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.text.replace(/\s+/g, " ")
                    font.family: Theme.mono
                    font.pixelSize: Theme.sm
                    color: row.sel ? Theme.paper : Theme.muted
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.index = row.index
                    onClicked: root.pick(row.modelData)
                }
            }
        }

        Txt {
            visible: root.shown.length === 0
            text: root.entries.length === 0 ? "nothing copied yet." : "no match."
            color: Theme.muted
        }
        Txt {
            text: "enter copies  ·  delete forgets  ·  " + root.entries.length + " kept"
            font.family: Theme.mono
            font.pixelSize: Theme.xs
            color: Theme.faint
            Layout.topMargin: 4
        }
    }
}
