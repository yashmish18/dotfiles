import QtQuick
import qs.services
import qs.components

// the timer on the desktop. click: start / pause. right click: reset. scroll: ± a minute.
Item {
    id: root
    implicitWidth: 220
    implicitHeight: 220

    // the ring: what's gone, drawn over what's left
    Canvas {
        id: ring
        anchors.fill: parent
        property real p: Pomo.progress
        property color c: Pomo.onBreak ? Theme.tertiary : Theme.wallText
        onPChanged: requestPaint()
        onCChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const r = width / 2 - 6;
            g.lineCap = "round";
            g.lineWidth = 3;
            g.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.18);
            g.beginPath(); g.arc(width / 2, height / 2, r, 0, Math.PI * 2); g.stroke();
            if (p <= 0) return;
            g.lineWidth = 5;
            g.strokeStyle = c;
            g.beginPath(); g.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p); g.stroke();
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Pomo.text
            font.family: Theme.display
            font.pixelSize: 58
            color: Theme.wallText
            style: Text.Raised
            styleColor: Theme.wallShadow
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Pomo.onBreak ? "break" : Pomo.running ? "focus" : "paused"
            font.family: Theme.mono
            font.pixelSize: Theme.sm
            color: Theme.wallTextDim
        }
    }

    // breathes while it runs
    scale: Pomo.running ? 1 : 0.96
    opacity: Pomo.running ? 1 : 0.8
    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: 300 } }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: !Ui.editing
        onTapped: Pomo.toggle()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: Pomo.reset()
    }
    WheelHandler {
        acceptedModifiers: Qt.NoModifier
        onWheel: e => Pomo.nudge(e.angleDelta.y > 0 ? 1 : -1)
    }
}
