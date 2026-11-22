import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.services

// a plain analog face: twelve ticks, two hands, a dot of the accent in the middle
Item {
    id: root
    implicitWidth: 170
    implicitHeight: 170
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property real r: width / 2
    readonly property real minuteA: clock.date.getMinutes() * 6
    readonly property real hourA: (clock.date.getHours() % 12) * 30 + clock.date.getMinutes() * 0.5

    Repeater {
        model: 12
        Rectangle {
            required property int index
            readonly property bool major: index % 3 === 0
            width: major ? 4 : 2
            height: major ? 14 : 8
            radius: width / 2
            color: Theme.alpha(Theme.wallText, major ? 0.9 : 0.5)
            x: root.r - width / 2
            y: 4
            transform: Rotation { origin.x: width / 2; origin.y: root.r - 4; angle: index * 30 }
        }
    }
    // hour hand
    Rectangle {
        width: 6
        height: root.r * 0.5
        radius: 3
        color: Theme.wallText
        x: root.r - width / 2
        y: root.r - height
        transform: Rotation { origin.x: 3; origin.y: root.r * 0.5; angle: root.hourA }
    }
    // minute hand
    Rectangle {
        width: 4
        height: root.r * 0.78
        radius: 2
        color: Theme.wallText
        x: root.r - width / 2
        y: root.r - height
        transform: Rotation { origin.x: 2; origin.y: root.r * 0.78; angle: root.minuteA }
    }
    Rectangle {
        width: 12
        height: 12
        radius: 6
        anchors.centerIn: parent
        color: Theme.primary
    }
}
