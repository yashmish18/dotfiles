import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// volume / brightness: a short hairline under the pill, gone after a second and a half.
PanelWindow {
    id: win
    screen: {
        const mon = Hyprland.focusedMonitor;
        return Quickshell.screens.find(s => mon && s.name === mon.name) || Quickshell.screens[0];
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kajukatli-osd"
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    margins.top: Theme.barHeight + 16
    implicitWidth: 260
    implicitHeight: 40
    color: "transparent"
    mask: Region {}
    visible: shown || box.opacity > 0

    property bool shown: false
    property string kind: "sound"
    property real value: 0
    property bool muted: false

    function show(k, v, m) {
        kind = k;
        value = v;
        muted = m;
        shown = true;
        hide.restart();
    }
    Timer { id: hide; interval: 1500; onTriggered: win.shown = false }

    // ignore the first values pipewire reports while starting up
    property bool armed: false
    Timer { running: true; interval: 2500; onTriggered: win.armed = true }

    Connections {
        target: Audio.ready ? Audio.sink.audio : null
        function onVolumeChanged() { if (win.armed) win.show("sound", Audio.volume, Audio.muted); }
        function onMutedChanged() { if (win.armed) win.show("sound", Audio.volume, Audio.muted); }
    }
    Connections {
        target: Bright
        function onChangedByUser() { win.show("light", Bright.value, false); }
    }

    Rectangle {
        id: box
        anchors.fill: parent
        radius: height / 2
        color: Theme.ink
        border.width: 1
        border.color: Theme.line
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

        Txt {
            id: label
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            text: win.muted ? "muted" : win.kind
            font.family: Theme.mono
            font.pixelSize: Theme.xs
            color: Theme.muted
            width: 44
        }
        Item {
            anchors.left: label.right
            anchors.right: num.left
            anchors.margins: 8
            height: parent.height
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.line }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.max(0, Math.min(1, win.value))
                height: 2
                color: win.muted ? Theme.faint : Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.fast } }
            }
        }
        Txt {
            id: num
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(win.value * 100)
            font.family: Theme.mono
            font.pixelSize: Theme.xs
            horizontalAlignment: Text.AlignRight
            width: 24
        }
    }
}
