import QtQuick
import qs.services
import qs.components

// right-click on the music bars: the few things you change often, in plain words.
// the rest (colour, see-through, smoothness, sparks) lives in settings → desktop.
// the box itself is resized by dragging its corner, like every widget.
Rectangle {
    id: root
    signal done()

    readonly property bool across: Config.s.visualizerSpan !== "widget"
    readonly property bool wave: Config.s.visualizer === "wave"

    width: 300
    height: col.implicitHeight + 28
    radius: 18
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.outlineVariant

    // swallow clicks so the "click outside closes it" area behind doesn't fire
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    function clamp(v: real, lo: real, hi: real): real { return Math.max(lo, Math.min(hi, v)); }

    Column {
        id: col
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 12

        Item {
            width: parent.width
            height: 22
            Txt { anchors.verticalCenter: parent.verticalCenter; text: "Music bars"; font.pixelSize: Theme.md; font.weight: Font.DemiBold }
            Txt {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: Theme.surfaceTextDim
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.done() }
            }
        }

        Choice {
            width: parent.width
            label: "Shape"
            options: [{ value: "bars", label: "Bars" }, { value: "wave", label: "Wave" }, { value: "mirror", label: "Mirrored" }, { value: "both", label: "Wave + bars" }]
            value: Config.s.visualizer
            onPicked: v => Config.s.visualizer = v
        }
        Choice {
            width: parent.width
            label: "Where"
            options: [{ value: "full", label: "Across the screen" }, { value: "widget", label: "In a box" }]
            value: root.across ? "full" : "widget"
            onPicked: v => Config.s.visualizerSpan = v
        }
        Choice {
            width: parent.width
            visible: root.across
            label: "Along the"
            options: [{ value: "bottom", label: "Bottom" }, { value: "top", label: "Top" }, { value: "middle", label: "Middle" }]
            value: Config.s.visualizerEdge
            onPicked: v => Config.s.visualizerEdge = v
        }

        Slider {
            width: parent.width
            visible: !root.wave
            label: "How many bars"
            value: (Config.s.visualizerBars - 16) / (128 - 16)
            valueText: String(Config.s.visualizerBars)
            onMoved: v => Config.s.visualizerBars = Math.round(16 + v * (128 - 16))
        }
        Slider {
            width: parent.width
            visible: !root.wave
            label: "Space between bars"
            value: Config.s.visualizerGap / 12
            valueText: Config.s.visualizerGap === 0 ? "none" : Config.s.visualizerGap + " px"
            onMoved: v => Config.s.visualizerGap = Math.round(v * 12)
        }
        Slider {
            width: parent.width
            visible: !root.wave
            label: "How rounded"
            value: Config.s.visualizerRoundness
            valueText: Config.s.visualizerRoundness < 0.05 ? "square" : Config.s.visualizerRoundness > 0.95 ? "round" : Math.round(Config.s.visualizerRoundness * 100) + "%"
            onMoved: v => Config.s.visualizerRoundness = Math.round(v * 20) / 20
        }
        Slider {
            width: parent.width
            visible: root.across
            label: "How tall"
            value: (Config.s.visualizerHeight - 0.05) / (0.6 - 0.05)
            valueText: Math.round(Config.s.visualizerHeight * 100) + "% of the screen"
            onMoved: v => Config.s.visualizerHeight = Math.round(root.clamp(0.05 + v * 0.55, 0.05, 0.6) * 100) / 100
        }
        Txt {
            width: parent.width
            visible: !root.across
            wrapMode: Text.WordWrap
            text: "Drag the box to move it. Drag its corner to make it bigger or smaller."
            font.pixelSize: Theme.sm
            color: Theme.surfaceTextDim
        }

        Row {
            spacing: 8
            Btn { text: "Edit layout"; flat: true; onClicked: { root.done(); Ui.editing = true; } }
            Btn { text: "More settings"; flat: true; onClicked: { root.done(); Ui.settings("desktop"); } }
            Btn { text: "Turn off"; danger: true; flat: true; onClicked: { root.done(); Config.s.visualizer = "off"; } }
        }
    }
}
