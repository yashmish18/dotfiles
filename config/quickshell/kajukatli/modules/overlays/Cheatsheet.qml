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
    // keys that work inside the shell's own screens (hyprland doesn't know these)
    readonly property var inside: [
        { keys: ["overview", "← →"], what: "move the highlight · enter: go there" },
        { keys: ["overview", "super + tab"], what: "again: next one · let go of super: go" },
        { keys: ["overview", "n"], what: "a new workspace" },
        { keys: ["overview", "drag"], what: "a window to a workspace, a new one, or another screen" },
        { keys: ["overview", "middle-click"], what: "close that window" },
        { keys: ["emoji", "type"], what: "search · tab: next group · enter: put it in" },
        { keys: ["control center", "icon"], what: "switch it on/off · the rest of the tile: its page" },
        { keys: ["tray icon", "click"], what: "everything the app offers · right-click: open it" },
        { keys: ["widgets", "right-click"], what: "its menu · drag the corner dot to resize · double-click: back to normal" },
        { keys: ["launcher", "right-click"], what: "start that app on the nvidia card" },
        { keys: ["displays", "drag"], what: "arrange your screens (they snap edge to edge)" }
    ]

    function mods(mask: var): var {
        const out = [];
        if (mask & 64) out.push("super");
        if (mask & 4) out.push("ctrl");
        if (mask & 8) out.push("alt");
        if (mask & 1) out.push("shift");
        return out;
    }
    function keyName(k: var): string {
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
                    root.binds = out.concat(root.inside);
                } catch (e) {
                    root.binds = root.inside;
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
