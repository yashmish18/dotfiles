import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// volume / brightness: a small glass capsule under the bar, gone after a second and a half.
PanelWindow {
    id: win
    screen: Hypr.activeScreen
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "kajukatli-osd"
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    margins.top: Ui.topInset + 14
    implicitWidth: 280
    implicitHeight: 48
    color: "transparent"
    mask: Region {}
    visible: shown || box.opacity > 0

    property bool shown: false
    property string kind: "sound"
    property real value: 0
    property bool muted: false

    function show(k: var, v: var, m: var) {
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
        function onVolumeChanged() { if (win.armed) { win.show("sound", Audio.volume, Audio.muted); Sounds.play("tick", 70); } }
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
        color: Theme.glassStrong
        border.width: 1
        border.color: Theme.alpha(Theme.surfaceText, 0.08)
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }

        Icon {
            id: ic
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            name: win.kind === "light" ? "sun" : Icons.volume(win.value, win.muted)
            level: win.value
            size: 18
            color: win.muted ? Theme.outline : Theme.primary
        }
        Rectangle {
            id: track
            anchors.left: ic.right
            anchors.leftMargin: 12
            anchors.right: num.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 8
            radius: 4
            color: Theme.surfaceHighest
            Rectangle {
                width: Math.max(height, parent.width * Math.max(0, Math.min(1, win.value)))
                height: parent.height
                radius: 4
                color: win.muted ? Theme.outline : Theme.primary
                Behavior on width { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
            }
        }
        Txt {
            id: num
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: win.muted ? "off" : Math.round(win.value * 100)
            font.family: Theme.mono
            font.pixelSize: Theme.md
            horizontalAlignment: Text.AlignRight
            width: 28
        }
    }
}
