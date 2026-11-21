import QtQuick
import Quickshell
import qs.services
import qs.components

Item {
    id: root
    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Txt {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, "ddd d").toLowerCase() + "  ·  " +
              Qt.formatDateTime(clock.date, Config.s.clock24h ? "HH:mm" : "h:mm ap").toLowerCase()
        font.family: Theme.mono
        font.pixelSize: Theme.sm
        color: Ui.panel === "calendar" ? Theme.accent : Theme.paper
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.toggle("calendar")
    }
}
