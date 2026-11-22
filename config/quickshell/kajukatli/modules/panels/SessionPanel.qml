import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// leave. five big cards. the ones that lose your work ask once more: press again to confirm.
// keys: l s o r p, or arrows and enter.
Item {
    id: root
    implicitWidth: 440
    implicitHeight: col.implicitHeight
    focus: true

    property int index: 0
    property string armed: ""

    readonly property var actions: [
        { key: "lock", word: "Lock", icon: "lock", hint: "l", cmd: [Config.bin + "kk-lock"], ask: false },
        { key: "sleep", word: "Sleep", icon: "moon", hint: "s", cmd: ["systemctl", "suspend"], ask: false },
        { key: "logout", word: "Log out", icon: "logout", hint: "o", cmd: ["sh", "-c", "command -v hyprshutdown >/dev/null && exec hyprshutdown; exec hyprctl dispatch 'hl.dsp.exit()'"], ask: true },
        { key: "reboot", word: "Restart", icon: "restart", hint: "r", cmd: ["systemctl", "reboot"], ask: true },
        { key: "off", word: "Shut down", icon: "power", hint: "p", cmd: ["systemctl", "poweroff"], ask: true }
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: root.actions
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool sel: root.index === index
                    readonly property bool hot: root.armed === modelData.key
                    Layout.fillWidth: true
                    implicitHeight: 76
                    radius: Theme.radius
                    color: hot ? Theme.error : sel ? Theme.alpha(Theme.primary, 0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    scale: area.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: card.modelData.icon
                            size: 24
                            color: card.hot ? Theme.errorText : card.sel ? Theme.primary : Theme.surfaceText
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.hot ? "again" : card.modelData.word
                            font.pixelSize: Theme.sm
                            font.weight: Font.Medium
                            color: card.hot ? Theme.errorText : card.sel ? Theme.primary : Theme.surfaceTextDim
                        }
                    }
                    Txt {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        text: card.modelData.hint
                        font.family: Theme.mono
                        font.pixelSize: Theme.xs
                        color: card.hot ? Theme.errorText : Theme.outline
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.index = card.index
                        onClicked: root.run(card.index)
                    }
                }
            }
        }
    }
}
