import QtQuick
import Quickshell
import qs.services
import qs.components

// super + esc. arrows or the underlined letter to pick, enter to do it.
// restart, shut down and log out ask once more: press again.
Item {
    id: root
    focus: true

    readonly property var acts: [
        { key: "lock", word: "Lock", icon: "lock", hint: "l", cmd: [Config.bin + "kk-lock"], ask: false },
        { key: "sleep", word: "Sleep", icon: "moon", hint: "s", cmd: ["systemctl", "suspend"], ask: false },
        { key: "hibernate", word: "Hibernate", icon: "snow", hint: "h", cmd: ["systemctl", "hibernate"], ask: false },
        { key: "logout", word: "Log out", icon: "logout", hint: "o", cmd: ["sh", "-c", "command -v hyprshutdown >/dev/null && exec hyprshutdown; exec hyprctl dispatch 'hl.dsp.exit()'"], ask: true },
        { key: "reboot", word: "Restart", icon: "restart", hint: "r", cmd: ["systemctl", "reboot"], ask: true },
        { key: "off", word: "Shut down", icon: "power", hint: "p", cmd: ["systemctl", "poweroff"], ask: true }
    ]
    property int index: 1
    property string armed: ""      // the one waiting for its second press

    function run(i) {
        const a = acts[i];
        index = i;
        if (a.ask && armed !== a.key) { armed = a.key; disarm.restart(); return; }
        Ui.overlay = "";
        Quickshell.execDetached(a.cmd);
    }
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

    Keys.onEscapePressed: Ui.overlay = ""
    Keys.onLeftPressed: { index = (index + acts.length - 1) % acts.length; armed = ""; }
    Keys.onRightPressed: { index = (index + 1) % acts.length; armed = ""; }
    Keys.onTabPressed: { index = (index + 1) % acts.length; armed = ""; }
    Keys.onReturnPressed: run(index)
    Keys.onEnterPressed: run(index)
    Keys.onPressed: e => {
        const i = acts.findIndex(a => a.hint === e.text.toLowerCase());
        if (i !== -1) { run(i); e.accepted = true; }
    }
    Component.onCompleted: forceActiveFocus()

    Column {
        anchors.centerIn: parent
        spacing: 40

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22
            Repeater {
                model: root.acts
                delegate: Item {
                    id: act
                    required property var modelData
                    required property int index
                    readonly property bool sel: root.index === index
                    readonly property bool armedHere: root.armed === modelData.key
                    width: 112
                    height: 150

                    opacity: 0
                    property real rise: 24
                    transform: Translate { y: act.rise }
                    Component.onCompleted: if (Config.s.reducedMotion) { opacity = 1; rise = 0; } else enter.start()
                    SequentialAnimation {
                        id: enter
                        PauseAnimation { duration: act.index * 35 }
                        ParallelAnimation {
                            NumberAnimation { target: act; property: "opacity"; to: 1; duration: 240 }
                            NumberAnimation { target: act; property: "rise"; to: 0; duration: 420; easing.type: Easing.OutBack }
                        }
                    }

                    Rectangle {
                        id: disc
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 96; height: 96; radius: 48
                        color: act.armedHere ? Theme.error : act.sel ? Theme.primary : Theme.alpha("#ffffff", area.containsMouse ? 0.16 : 0.08)
                        border.width: act.sel ? 0 : 1
                        border.color: Theme.alpha("#ffffff", 0.14)
                        scale: act.sel ? 1.08 : area.pressed ? 0.94 : 1
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Icon {
                            anchors.centerIn: parent
                            name: act.modelData.icon
                            size: 32
                            color: act.armedHere ? Theme.errorText : act.sel ? Theme.primaryText : "#ffffff"
                        }
                    }
                    Txt {
                        anchors.top: disc.bottom
                        anchors.topMargin: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: act.armedHere ? "again" : act.modelData.word
                        font.pixelSize: Theme.md
                        font.weight: act.sel ? Font.DemiBold : Font.Normal
                        color: act.sel || act.armedHere ? "#ffffff" : Theme.alpha("#ffffff", 0.7)
                    }
                    Txt {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: act.modelData.hint
                        font.family: Theme.mono
                        font.pixelSize: Theme.xs
                        color: Theme.alpha("#ffffff", 0.35)
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.index = act.index
                        onClicked: root.run(act.index)
                    }
                }
            }
        }
    }
}
