import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// leave. the dangerous ones ask twice: press once, it says "again?", press again.
Item {
    id: root
    implicitWidth: 380
    implicitHeight: col.implicitHeight + 6
    focus: true

    property int index: 0
    property string armed: ""

    readonly property var actions: [
        { key: "lock", word: "lock", hint: "l", cmd: ["kk-lock"], ask: false },
        { key: "sleep", word: "sleep", hint: "s", cmd: ["systemctl", "suspend"], ask: false },
        { key: "logout", word: "log out", hint: "o", cmd: ["sh", "-c", "command -v hyprshutdown >/dev/null && exec hyprshutdown; exec hyprctl dispatch 'hl.dsp.exit()'"], ask: true },
        { key: "reboot", word: "restart", hint: "r", cmd: ["systemctl", "reboot"], ask: true },
        { key: "off", word: "shut down", hint: "p", cmd: ["systemctl", "poweroff"], ask: true }
    ]

    function run(i) {
        const a = actions[i];
        if (!a) return;
        if (a.ask && armed !== a.key) {
            armed = a.key;
            disarm.restart();
            return;
        }
        Ui.panel = "";
        Quickshell.execDetached(a.cmd);
    }
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

    Keys.onEscapePressed: Ui.panel = ""
    Keys.onLeftPressed: index = (index + actions.length - 1) % actions.length
    Keys.onRightPressed: index = (index + 1) % actions.length
    Keys.onReturnPressed: run(index)
    Keys.onPressed: e => {
        const i = actions.findIndex(a => a.hint === e.text);
        if (i !== -1) { index = i; run(i); e.accepted = true; }
    }
    Component.onCompleted: forceActiveFocus()

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        Txt {
            text: root.armed !== "" ? "again, to be sure." : "leaving already?"
            font.family: Theme.serif
            font.italic: true
            font.pixelSize: Theme.xl - 4
            color: root.armed !== "" ? Theme.danger : Theme.paper
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: root.actions
                delegate: Btn {
                    required property var modelData
                    required property int index
                    text: modelData.word
                    size: Theme.md
                    mono: false
                    active: root.index === index
                    danger: modelData.ask
                    onClicked: { root.index = index; root.run(index); }
                }
            }
        }

        Txt {
            text: "l  s  o  r  p   or arrows and enter"
            font.family: Theme.mono
            font.pixelSize: Theme.xs
            color: Theme.faint
        }
    }
}
