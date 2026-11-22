import QtQuick
import qs.services
import qs.components

// rain or snow over the wallpaper when it's raining or snowing where you are.
// a few dozen light items, each falling on its own loop; nothing runs when the sky is clear.
Item {
    id: root
    property bool active: true
    clip: true

    Uses { service: Weather; active: root.active }

    // wttr.in condition codes
    readonly property var rainCodes: [176, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 353, 356, 359, 386, 389]
    readonly property var snowCodes: [179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377, 392, 395]
    readonly property string kind: !Weather.ready ? "" : rainCodes.indexOf(Weather.code) !== -1 ? "rain"
                                 : snowCodes.indexOf(Weather.code) !== -1 ? "snow" : ""
    readonly property bool heavy: [302, 305, 308, 314, 356, 359, 389, 329, 332, 335, 338, 371, 395].indexOf(Weather.code) !== -1
    readonly property int count: !active || kind === "" ? 0 : kind === "rain" ? (heavy ? 90 : 50) : (heavy ? 70 : 40)

    opacity: count > 0 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 1500 } }

    Repeater {
        model: root.count
        delegate: Rectangle {
            id: drop
            required property int index
            readonly property bool snow: root.kind === "snow"
            readonly property real depth: 0.4 + ((index * 37) % 60) / 100      // nearer drops: bigger, faster
            width: snow ? 3 + depth * 4 : 1.4
            height: snow ? width : 12 + depth * 18
            radius: snow ? width / 2 : 1
            color: Theme.wallText
            opacity: snow ? 0.35 + depth * 0.4 : 0.14 + depth * 0.22
            property real drift: 0
            x: ((index * 7919) % 1000) / 1000 * root.width + drift

            NumberAnimation on y {
                from: -40 - (drop.index * 53) % root.height
                to: root.height + 40
                duration: (drop.snow ? 9000 : 900) / drop.depth
                loops: Animation.Infinite
                running: root.count > 0
            }
            // snow drifts side to side
            SequentialAnimation on drift {
                running: drop.snow && root.count > 0
                loops: Animation.Infinite
                NumberAnimation { from: -12; to: 12; duration: 2400 + (drop.index * 37) % 1400; easing.type: Easing.InOutSine }
                NumberAnimation { from: 12; to: -12; duration: 2400 + (drop.index * 37) % 1400; easing.type: Easing.InOutSine }
            }
        }
    }
}
