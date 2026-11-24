import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// every bind that has a description, read live from hyprland (so it's never out of date).
Item {
    id: root
    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onPressed: e => { Ui.overlay = ""; e.accepted = true; }

    property var binds: []

    function mods(mask): string {
        const out = [];
        if (mask & 64) out.push("super");
        if (mask & 4) out.push("ctrl");
        if (mask & 8) out.push("alt");
        if (mask & 1) out.push("shift");
        return out;
    }
    function keyName(k): string {
        const map = { "Return": "enter", "Space": "space", "slash": "/", "grave": "`", "period": ".", "comma": ",", "Escape": "esc", "Tab": "tab", "Print": "print" };
        return map[k] || k.toLowerCase();
    }

    Process {
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text);
                    const seen = {};
                    const out = [];
                    for (const b of all) {
                        if (!b.description || seen[b.description]) continue;
                        seen[b.description] = true;
                        out.push({ keys: root.mods(b.modmask).concat([root.keyName(b.key)]), what: b.description });
                    }
                    root.binds = out;
                } catch (e) {
                    root.binds = [];
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 26

        Txt {
            text: "Keys"
            font.pixelSize: 40
            font.weight: Font.Light
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            flow: GridLayout.TopToBottom
            rows: Math.max(1, Math.ceil(root.binds.length / 3))
            columnSpacing: 56
            rowSpacing: 9

            Repeater {
                model: root.binds
                delegate: RowLayout {
                    required property var modelData
                    spacing: 14
                    Layout.alignment: Qt.AlignTop
                    Txt {
                        Layout.preferredWidth: 170
                        text: modelData.keys.join(" + ")
                        font.family: Theme.mono
                        font.pixelSize: Theme.sm
                        color: Theme.accent
                    }
                    Txt {
                        text: modelData.what
                        font.pixelSize: Theme.md
                        color: Theme.paper
                    }
                }
            }
        }

        Txt {
            text: "super + 1…0 workspaces  ·  super + shift + 1…0 send window  ·  super + drag move  ·  super + right-drag resize  ·  any key closes this"
            font.family: Theme.mono
            font.pixelSize: Theme.xs
            color: Theme.faint
        }
    }
}
